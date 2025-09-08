require ecs
require app
require DaWeaponProps
require DagorDataBlock
require DagorSystem
require DngDm
require DagorMath
require dm
require game.es.ecs_common


[es(tag=gameClient, on_appear, track=melee_weapon__propsId, after=(melee_item_created_es, melee_weapon_created_es))]
def melee_weapon_stats_init(evt : Event;
                            melee_weapon__propsId : int;
                            melee_weapon__attackTime : float;
                            gun__melee : bool;
                            var weapon_stat__damage : float&;
                            var weapon_stat__dps : float&)
  if gun__melee && melee_weapon__propsId >= 0
    melee_get_props(melee_weapon__propsId) <| $(meleeProps : MeleeProps)
      weapon_stat__damage = meleeProps.hitPower
      if melee_weapon__attackTime > 0.0
        weapon_stat__dps = weapon_stat__damage / melee_weapon__attackTime


[es(tag=gameClient, on_appear, REQUIRE=item__grenadeType, after=shell_item_es)]
def grenade_stats_init(evt : Event;
                       shell_props : ShellPropIds;
                       var weapon_stat__damage : float&)
  weapon_stat__damage = 0.0


  // splashDamage
  splash_params_get_props(int(shell_props.damageId)) <| $(props : SplashParamsProps)
    weapon_stat__damage += props.damage

  // splash
  splash_get_props(int(shell_props.damageId)) <| $(props : SplashProps)
    weapon_stat__damage += props.damage

  weapon_stat__damage *= 0.7 // approx final explosion damage


[es(tag=gameClient, on_appear, after=(gun_init_shell_prop_ids_es))]
def gun_stats_init(evt : Event;
                   gun__shell_prop_ids : GunShellPropIds;
                   gun__shotFreq : float;
                   var weapon_stat__rpm : float&;
                   var weapon_stat__damage : float&;
                   var weapon_stat__damageCount : int&;
                   var weapon_stat__dps : float&)
  weapon_stat__rpm = gun__shotFreq * 60.0

  if length(gun__shell_prop_ids) > 0
    assume shellPropId = gun__shell_prop_ids[0]
    weapon_stat__damage = get_shell_damage(int(shellPropId.damageId))
    weapon_stat__dps = weapon_stat__damage * gun__shotFreq

    let spawnProps = shell_spawn_try_get_props(int(shellPropId.shellId))
    if spawnProps != null
      weapon_stat__damageCount = spawnProps.maxCount