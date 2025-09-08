options no_aot

require AnimV20
require app
require DagorConsole
require DagorDebug3D
require DagorMath
require DaWeaponProps
require DaWeapons
require DngDm
require DngWeapon
require ecs
require game.es.damage_systems.damage_model_armor_common
require game.es.damage_systems.damage_model_common
require game.es.net_console_macro
require game.events.events_game
require game.utils.hero
require GeomNodeTree
require Gun
require math.base
require NetPropsRegistry
require PhysMat



[console_cmd(name="damage_model.compare")]
def damage_model_compare_debug()
  let heroEid = get_controlled_hero()

  query(heroEid) <| $ [es] (hitpoints__hp : float; human_damage_model__parts : Object)
    let sumPartsHp = human_damage_model_get_total_hp(human_damage_model__parts)

    console_print("hitpoints__hp = {hitpoints__hp}, sum parts hp = {sumPartsHp}")


[net_console_cmd(name="damage_model.set_part_hp")]
def damage_model_set_part_hp(part_name : string; value : float; @net_hero eid : EntityId)
  query(eid) <| $ [es] (var human_damage_model__parts : Object)
    var obj = getRW_ecs_object(human_damage_model__parts[part_name])
    if obj == null
      console_print("Part {part_name} not found")
      return
    var part <- make_object_of_body_part(part_name, *obj, human_damage_model__parts)
    human_damage_model_set_part_hp(eid, value, part)
    send_net_event(eid, CmdHeartRateHpReset())


[net_console_cmd(name="damage_model.set_hp_ratio")]
def damage_model_set_hp_ratio(value = 1.0; @net_hero eid : EntityId)
  human_damage_model_set_hp_in_percent(eid, value)
  send_net_event(eid, CmdHeartRateHpReset())


[es(on_event=CmdHeartRateHpReset)]
def rest_heartrate_hp(evt : Event; var heartrate__hpinfo__hp : FloatList; var heartrate__hpinfo__tick : IntList)
  clear(heartrate__hpinfo__hp)
  clear(heartrate__hpinfo__tick)
  heartrate__hpinfo__hp |> push(.0)
  heartrate__hpinfo__tick |> push(0)


[es(tag=server, on_appear, REQUIRE=(human_damage_model__parts, hitpoints_god_mode_on_appear))]
def hitpoints_god_mode_on_appear(evt : Event; eid : EntityId)
  human_damage_model_set_hp_in_percent(eid, 99999f)
  send_net_event(eid, CmdHeartRateHpReset())


[net_console_cmd(name="damage_model.set_armor_hp_ratio")]
def damage_model_set_armor_hp_ratio(value = 1.0; @net_hero eid : EntityId)
  human_damage_model_set_armor_hp_in_percent(eid, value)


[net_console_cmd(name="damage_model.destroy_all_armor")]
def damage_model_set_armor_hp_ratio(@net_hero eid : EntityId)
  human_damage_model_destroy_all_armor(eid)


[net_console_cmd(name="damage_model.damage_part")]
def cmd_damage_model_damage_part(part_name : string = "body";
                                 damage : float = 5.0;
                                 damage_type : int = int(DamageType.DM_PROJECTILE);
                                 @net_hero eid : EntityId)
  query(eid) <| $ [es] (entity_mod_values : Object; var human_damage_model__parts : Object)
    var obj = getRW_ecs_object(human_damage_model__parts[part_name])
    if obj == null
      console_print("Part {part_name} not found")
      return
    var partsForDamage : array<BodyPart>
    partsForDamage |> emplace(make_object_of_body_part(part_name, *obj, human_damage_model__parts))
    human_damage_model_damage_parts(eid, damage, damage_type, entity_mod_values, human_damage_model__parts, partsForDamage)


[net_console_cmd(name="damage_model.shoot_the_leg")]
def damage_model_shoot_the_leg(shots : int = 1)
  query() <| $ [es(REQUIRE=hero)] (animchar : AnimcharBaseComponent;
                                   human_damage_model__parts : Object)
    let launchOffset = float3(10.0, 1.0, 0.0)
    let leftLeg = get_ecs_object(human_damage_model__parts["left_leg"])
    if leftLeg == null
      error("Left leg not found")
      return
    let nodesList = get_ecs_IntList(leftLeg, "nodeIds")
    if nodesList == null || (*nodesList).length() < 3
      error("Left leg nodes list not found, {(*nodesList).length()}")
      return
    // Bip01 L Thigh
    let node = (*nodesList)[2]

    let wpos = *animchar.nodeTree |> geomtree_getNodeWpos(node)

    draw_debug_sphere_buffered(wpos, 0.1, E3DCOLOR(0xffffffff), 360)
    draw_debug_line_buffered(wpos, wpos + launchOffset, E3DCOLOR(0xffffffff), 360)

    var launchTm = IDENT_TM
    launchTm[3] = wpos + launchOffset
    let dir = normalize(wpos - launchTm[3])

    let shell = "gamedata/weapons/bullets/5.56x45.blk"

    using() <| $(var shell_props : ShellPropIds#)
      shell_props.shellId = int16(register_net_props(shell, "shell"))
      shell_props.damageId = int16(register_net_props(shell, "damage"))
      shell_props.ballisticsId = int16(register_net_props(shell, "ballistics"))

      shell_start_get_props(int(shell_props.shellId)) <| $(shellStartProps : ShellStartProps)
        let vel = dir * shellStartProps.speed

        using() <| $(var launchDesc : LaunchDesc#)
          launchDesc.shellId := shell_props
          launchDesc.gunPropsId = int16(-1)
          launchDesc.atTime = get_sync_time()
          launchDesc.initialLifeTime = 1f
          launchDesc.tm = launchTm
          launchDesc.vel = vel
          launchDesc.firingMode = uint(0)
          launchDesc.bombBayHeight = 0.0
          launchDesc.disableShellEjection = true

          createEntity("bullet_projectile") <| $(var init : ComponentsInitializer)
            init |> set("ownerEid", INVALID_ENTITY_ID)
            init |> set("gunEid", INVALID_ENTITY_ID)
            init |> set("launch_desc", launchDesc)
            init |> set("shell__shell_id__shell_id", int(launchDesc.shellId.shellId))
            init |> set("shell__shell_id__damage_id", int(launchDesc.shellId.damageId))
            init |> set("shell__shell_id__ballistics_id", int(launchDesc.shellId.ballisticsId))
            init |> set("projectile__traceRayMatId", get_material_id("bulletRay"))
