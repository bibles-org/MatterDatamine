options no_aot
require app
require ecs
require app
require ecs.common
require math.base
require DagorConsole
require DagorSystem
require DagorRandom
require DagorDebug3D
require Dacoll
require strings
require DngNet
require DagorMath
require DngDm
require matching
require DngHuman
require game.events.events_game
require game.es.teleport_common
require game.es.server_debug_common
require game.utils.hero
require game.events.events
require game.utils.net_utils
require game.es.net_console_macro
require game.events.events_active_matter
require game.es.revive_common
require game.es.underground_zone_common


[console_cmd(name="am.create_marker_at_camera_pos")]
def console_create_marker_at_camera_pos()
  find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if !camera__active
      return false

    createEntity("debug_marker_box") <| $(init)
      init |> set("transform", transform)
    return true


[net_console_cmd(name="am.kill_fauna")]
def console_am_kill_fauna()
  query() <| $ [es(REQUIRE=xenos)] (eid : EntityId; var hitpoints__hp : float&)
    teleport_or_request(eid, float3(0.0, 0.0, 0.0))
    hitpoints__hp = 0.0
  query() <| $ [es(REQUIRE=spider)] (eid : EntityId; var hitpoints__hp : float&)
    teleport_or_request(eid, float3(0.0, 0.0, 0.0))
    hitpoints__hp = 0.0
  query() <| $ [es(REQUIRE=swarm_cluster__damage)] (eid : EntityId)
    destroyEntity(eid)

def add_bot_to_team(ref_hero_eid : EntityId; team : int; beh_tree__enabled : bool)
  var tm : float3x4
  query() <| $ [es(REQUIRE=respbase)] (transform : float3x4)
    tm = transform
  query(ref_hero_eid) <| $ [es] (transform : float3x4)
    tm = transform
    tm[3] += tm[0]
  var templ = "am_militant_bot+equipped_bot+equip_cortical_vault+allow_friendly_damage"
  query() <| $ [es] (bot_spawner__heroTemplates : StringList)
    if !empty(bot_spawner__heroTemplates)
      let heroTemplate := string(bot_spawner__heroTemplates[grnd() % length(bot_spawner__heroTemplates)])
      if !empty(heroTemplate)
        templ := heroTemplate
  createEntity("{templ}+create_bot_player_for_hero") <| $(init)
    init |> set("team", team)
    init |> set("transform", tm)
    init |> set("beh_tree__enabled", beh_tree__enabled)

[net_console_cmd(name="am.add_bot_teammate")]
def console_add_bot_teammate(beh_tree__enabled = true; @net_player player_eid : EntityId)
  query(player_eid) <| $ [es] (team : int; possessed : EntityId)
    add_bot_to_team(possessed, team, beh_tree__enabled)

[net_console_cmd(name="am.add_bot_enemy")]
def console_add_bot_enemy(beh_tree__enabled = true; @net_player player_eid : EntityId)
  query(player_eid) <| $ [es] (team : int; possessed : EntityId)
    add_bot_to_team(possessed, team + 1, beh_tree__enabled)


[net_console_cmd(name="am.kill_bot_teammate")]
def console_kill_bot_teammate(@net_player player_eid : EntityId)
  query(player_eid) <| $ [es] (team aka player_team : int)
    query() <| $ [es(REQUIRE=am_militant_bot)] (eid : EntityId; team aka bot_team : int)
      if player_team == bot_team
        let dd = DamageDesc(DamageType.DM_HOLD_BREATH, 10000f, float3(), float3())
        damage_entity(eid, eid, dd)

[net_console_cmd(name="am.kill_bot_enemy")]
def console_kill_bot_enemy(@net_player player_eid : EntityId)
  query(player_eid) <| $ [es] (team aka player_team : int)
    query() <| $ [es(REQUIRE=playerIsBot)] (possessed : EntityId; team aka bot_team : int)
      if player_team != bot_team
        let dd = DamageDesc(DamageType.DM_HOLD_BREATH, 10000f, float3(), float3())
        damage_entity(possessed, possessed, dd)


[net_console_cmd(name="am.kill_bot")]
def console_kill_bot(@net_hero hero : EntityId)
  let dd = DamageDesc(DamageType.DM_HOLD_BREATH, 10000f, float3(), float3())
  damage_entity(hero, hero, dd)


[net_console_cmd(name="am.down_bot_teammates")]
def console_down_bot_teammates(@net_player player_eid : EntityId)
  query(player_eid) <| $ [es] (team aka player_team : int)
    query() <| $ [es(REQUIRE=playerIsBot)] (possessed : EntityId; team aka bot_team : int)
      if player_team == bot_team
        query(possessed) <| $ [es] (hitpoints__hp : float)
          let dd = DamageDesc(DamageType.DM_HOLD_BREATH, hitpoints__hp, float3(), float3())
          damage_entity(possessed, possessed, dd)


[net_console_cmd(name="am.respawn_my_team")]
def console_respawn_my_team(@net_player player_eid : EntityId)
  query(player_eid) <| $ [es] (team aka ref_team : int; possessed : EntityId)
    var respbase = INVALID_ENTITY_ID
    query(possessed) <| $ [es] (isAlive : bool)
      if isAlive
        respbase = possessed
    if respbase == INVALID_ENTITY_ID
      query() <| $ [es(REQUIRE=respbase)] (eid : EntityId)
        respbase = eid
    if respbase == INVALID_ENTITY_ID
      logerr("No respawn bases, can't respawn.")
      return
    query() <| $ [es] (possessed, eid : EntityId; team aka another_team : int)
      if ref_team == another_team
        var hasAlivePossessed = false
        query(possessed) <| $ [es] (isAlive : bool)
          hasAlivePossessed = isAlive
          if !isAlive
            destroyEntity(possessed)
        if !hasAlivePossessed
          query(respbase) <| $ [es] (transform : float3x4)
            sendEvent(eid, CmdSpawnEntity(tm = transform))


[es(tag=server, on_appear, REQUIRE=create_bot_player_for_hero)]
def create_bot_player_for_hero_es(evt : Event; eid : EntityId; team : int)
  var hasTemplate = false
  query() <| $ [es] (bot_spawner__playerTemplate : string)
    hasTemplate = true
    createEntity("{bot_spawner__playerTemplate}+bind_player_to_hero") <| $(init)
      init |> set("possessed", eid)
      init |> set("connid", INVALID_CONNECTION_ID)
      init |> set("name", "Winnifred {eid}")
      init |> set("userid", INVALID_USER_ID)
      init |> set("team", team)
  remote_remove_sub_template(eid, "create_bot_player_for_hero")

  if !hasTemplate
    logerr("No player created. bot_spawner__playerTemplate is missing. ")

[es(tag=server, on_appear, REQUIRE=bind_player_to_hero)]
def bind_player_to_hero_es(evt : Event; eid : EntityId; possessed : EntityId; team : int)
  query(possessed) <| $ [es] (var possessedByPlr : EntityId&)
    possessedByPlr = eid
    broadcastEvent(EventTeamMemberJoined(eid = eid, team = team))
  remote_remove_sub_template(eid, "bind_player_to_hero")


[net_console_cmd(name="replay.addLabel")]
def console_replay_start_label(name = "")
  find_query() <| $ [es] (replay__startAt : float; var replay__timeLabels : Array&)
    using() <| $(var timeLabel : Object)
      timeLabel |> set("name", empty(name) ? "label " + fmt(":.2f", get_sync_time()) : name)
      timeLabel |> set("time", floor((get_sync_time() - replay__startAt) * 100.f) / 100.f)
      replay__timeLabels |> push(timeLabel)
    return true


[net_console_cmd(name="am.large_bag_volume")]
def console_large_bag_volume()
  query() <| $ [es] (var human_inventory__maxVolume : float&)
    human_inventory__maxVolume *= 10.0

[net_console_cmd(name="am.infinite_ammo")]
def console_infinite_ammo(@net_hero eid : EntityId)
  query(eid) <| $ [es] (infiniteAmmo : Tag const?)
    assume templName = getEntityTemplateName(eid)
    assume additionalTemplate = "infinite_ammo"
    if infiniteAmmo == null
      createEntity("infinite_ammo_effect") <| $(init)
        set(init, "game_effect__attachedTo", eid)
    else
      assume hero_eid = eid
      find_query() <| $ [es(REQUIRE=infinite_ammo_effect)] (game_effect__attachedTo : EntityId; eid aka effect_eid : EntityId)
        if game_effect__attachedTo == hero_eid
          destroyEntity(effect_eid)
          return true
        return false

[net_console_cmd(name="am.bring_teammates_to_me")]
def console_bring_bring_teammates_to_me(@net_hero eid : EntityId)
  query(eid) <| $ [es] (team aka requester_team : int; transform : float3x4)
    query() <| $ [es(REQUIRE=human)] (eid aka other_eid : EntityId; team aka other_team : int)
      if (other_eid != eid) && (requester_team == other_team)
        teleport_eid_to(other_eid, transform[3], false)


[net_console_cmd(name="am.recharge_liana_anomalies")]
def console_recharge_liana_anomalies()
  query() <| $ [es(REQUIRE=lianaWallTentacle)] (eid : EntityId)
    destroyEntity(eid)
  query() <| $ [es(REQUIRE=lianaAnomaly)] (var liana_anomaly__triggered : bool&)
    liana_anomaly__triggered = false


[net_console_cmd(name="am.increase_random_am_pile_count")]
def console_change_random_am_pile_count()
  var opts : array<EntityId>
  query() <| $ [es(REQUIRE=item__am)] (eid : EntityId)
    opts |> push(eid)
  if length(opts) == 0
    console_print("No active matter items found")
    return
  let rndAM = opts[grnd() % length(opts)]
  query(rndAM) <| $ [es] (var item__count : int&)
    item__count += rnd_int(1, 10)


[net_console_cmd(name="am.respawn_point_here")]
def console_respawn_point_here(@net_player player_eid : EntityId)
  query(player_eid) <| $ [es] (possessed : EntityId)
    query(possessed) <| $ [es] (transform : float3x4)
      var hasSavePoint = false
      query() <| $ [es] (save_point__playerEid : EntityId; var save_point__tm : float3x4)
        if save_point__playerEid == player_eid
          save_point__tm = transform
          hasSavePoint = true
      if !hasSavePoint
        createEntity("save_point") <| $(init)
          init |> set("save_point__playerEid", player_eid)
          init |> set("save_point__tm", transform)


[es(tag=server)]
def resurrect_player_with_save_point(evt : EventEntityDied; eid, possessedByPlr : EntityId)
  query() <| $ [es] (save_point__playerEid : EntityId; save_point__tm : float3x4)
    if possessedByPlr == save_point__playerEid
      removeSubTemplate(eid, "observed_local")
      sendEvent(possessedByPlr, CmdSpawnEntity(tm = save_point__tm))


[es(tag=server, track=possessedByPlr, REQUIRE_NOT=recreated_possessed)]
def teleport_player_with_save_point(evt : Event; eid : EntityId; possessedByPlr : EntityId)
  query() <| $ [es] (save_point__playerEid : EntityId; save_point__tm : float3x4)
    if possessedByPlr == save_point__playerEid
      teleport_eid_to(eid, save_point__tm[3], false)


[net_console_cmd(name="am.super_stamina")]
def console_super_stamina(@net_hero eid : EntityId)
  var attachedEffect = INVALID_ENTITY_ID
  find_query() <| $ [es(REQUIRE=infinity_stamina)] (eid aka effect_eid, game_effect__attachedTo : EntityId)
    if game_effect__attachedTo == eid
      attachedEffect = effect_eid
      return true
    return false
  if attachedEffect != INVALID_ENTITY_ID
    destroyEntity(attachedEffect)
  else
    createEntity("infinity_stamina") <| $(var init)
      init |> set("game_effect__attachedTo", eid)


[net_console_cmd(name="am.super_reload")]
def console_super_reload(@net_hero eid : EntityId)
  query(eid) <| $ [es] (var entity_mods__reloadMultMods : Object&)
    set(entity_mods__reloadMultMods, "cheat", 0.1)
    sendEvent(eid, EventOnModsChanged())


[net_console_cmd(name="am.no_breath_shake")]
def console_no_breath_shake(@net_hero eid : EntityId)
  query(eid) <| $ [es] (var human_net_phys : HumanActor)
    human_net_phys.phys.currentState.breathShakeMult = .0


[net_console_cmd(name="am.unarm")]
def console_unarm(@net_hero eid : EntityId)
  sendEventImmediate(eid, HumanWeapSetCurrentGun(slot = uint8(HUWeaponSlots.EWS_UNARMED)))


[net_console_cmd(name="null_item_recognition_in_unowned_containers")]
def console_null_item_recognition_in_unowned_containers()
  query() <| $ [es] (var item__recognizedByPlayers : EidList; item__humanOwnerEid, item__containerOwnerEid : EntityId)
    if item__humanOwnerEid == INVALID_ENTITY_ID || item__containerOwnerEid == INVALID_ENTITY_ID
      clear(item__recognizedByPlayers)


[console_cmd(name="am.verify_custom_points")]
def console_verify_custom_points(tolerance : float = 0.0)
  query() <| $ [es] (transform : float3x4; custom_game_object__name : string)
    let posXZ = transform[3].xz
    let lh = traceht_lmesh(posXZ)
    if lh > transform[3].y + tolerance
      if !is_in_underground_zone(transform[3])
        logerr("Object '{custom_game_object__name}' below ground at {transform[3]}")
        draw_debug_sphere_buffered(transform[3], 2.0, E3DCOLOR(0xffffffff), 10000)
        draw_debug_line_buffered(transform[3], transform[3] + float3(0, 100, 0), E3DCOLOR(0xffffffff), 10000)


def set_human_net_phys_walk_speed(eid : EntityId;
                                  walk_speed : float;
                                  sprint_speed : float)
  query(eid) <| $ [es] (var human_net_phys : HumanActor)
    human_net_phys.phys |> human_phys_setWalkSpeed(HUStandState.ESS_STAND, HUMoveState.EMS_WALK, walk_speed)
    human_net_phys.phys |> human_phys_setWalkSpeed(HUStandState.ESS_STAND, HUMoveState.EMS_SPRINT, sprint_speed)

    human_control_state_set_walk_speed(human_net_phys.phys.producedCT, walk_speed)
    human_control_state_set_walk_speed(human_net_phys.phys.appliedCT, walk_speed)


[net_console_cmd(name="am.super_speed_server")]
def console_super_speed_server(@net_hero eid : EntityId;
                               walk_speed : float = 10.0;
                               sprint_speed : float = 30.0)
  set_human_net_phys_walk_speed(eid, walk_speed, sprint_speed)


[console_cmd(name="am.super_speed")]
def console_super_speed(walk_speed : float = 10.0;
                        sprint_speed : float = 30.0)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    set_human_net_phys_walk_speed(eid, walk_speed, sprint_speed)
    if !is_server()
      exec_server_cmd("am.super_speed_server {eid} {walk_speed} {sprint_speed}")


[console_cmd(name="am.rambo_mode")]
def console_rambo_mode()
  visual_log("RAMBO MODE!", E3DCOLOR(0xFFFFAA00))
  console_command("hitpoints.hero_god_mode")
  console_command("am.heartrate_set 0")
  console_command("am.hand_stamina_set 0")
  console_command("am.infinite_ammo")
  console_command("am.no_breath_shake")


[console_cmd(name="am.get_time")]
def console_app_get_time()
  console_print("{get_sync_time()}")


[console_cmd(name="am.is_server")]
def console_is_server()
  console_print("{is_server()}")


[net_console_cmd(name="am.toggle_ai_control")]
def console_toggle_ai_overtake(@net_hero eid : EntityId)
  assume hero_eid = eid
  let wasEnabled = find_query() <| $ [es(REQUIRE=bot_overtake_effect)] (game_effect__attachedTo : EntityId; eid aka effect_eid : EntityId)
    if game_effect__attachedTo == hero_eid
      destroyEntity(effect_eid)
      visual_log("Remove ai control from hero")
      return true
    return false

  if wasEnabled
    return

  createEntity("bot_overtake_effect") <| $(init)
    set(init, "game_effect__attachedTo", hero_eid)
    visual_log("Overtake hero with ai")


[net_console_cmd(name="am.teleport_my_teammates_to_me")]
def console_teleport_my_teammates_to_me(@net_hero hero_eid : EntityId)
  var pos = float3()
  var hteam = -1
  query(hero_eid) <| $ [es] (transform : float3x4; team : int)
    pos = transform[3]
    hteam = team
  query() <| $ [es(REQUIRE=heroForPlayer)] (team : int; eid : EntityId)
    if team == hteam
      teleport_eid_to(eid, pos)


[net_console_cmd(name="am.teleport_players_to_me")]
def console_teleport_players_to_me(@net_hero hero_eid : EntityId)
  var pos = float3()
  query(hero_eid) <| $ [es] (transform : float3x4)
    pos = transform[3]
  query() <| $ [es(REQUIRE=heroForPlayer)] (eid : EntityId)
    teleport_eid_to(eid, pos)