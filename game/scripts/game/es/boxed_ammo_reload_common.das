module boxed_ammo_reload_common shared
require daslib/enum_trait
require ecs
require app
require DngNet
require game.events.inventory_events
require game.events.events
require DaWeaponProps
require DagorMath
require DagorRandom
require game.es.human.human_reload_common
require game.es.human_weap_common
require game.es.boxed_item_common
require game.events.events_game


enum BoxedAmmoReloadState
  NONE = -1
  WAIT
  PREPARE
  LOOP
  POST


def private boxed_ammo_add_reload_templ(boxed_ammo_eid, gun_eid : EntityId)
  query(boxed_ammo_eid) <| $ [es] (item__recreateOnReload = "")
    remote_add_sub_template(boxed_ammo_eid, item__recreateOnReload) <| $(var init)
      init |> set("boxed_ammo__reloadGunEid", gun_eid)


def private start_load_boxed_ammo_to_gun(ammo_eid : EntityId;
                                         gun_eid : EntityId;
                                         need_pause : bool)
  query(gun_eid) <| $ [es] (gun_boxed_ammo_reload__loadPrepareTime : float;
                            gun__ammo : int;
                            gun_boxed_ammo_reload__firstBulletPrepareTime : float = -1.f;
                            var gun_boxed_ammo_reload__ammoCountBeforeReload : int&;
                            var gun_boxed_ammo_reload__isReloadRequested : bool&;
                            var gun_boxed_ammo_reload__isLoad : bool&;
                            var gun_boxed_ammo_reload__reloadState : int&;
                            var gun_boxed_ammo_reload__startTime : float&;
                            var gun_boxed_ammo_reload__atTime : float&;
                            var gun_boxed_ammo_reload__ammoEid : EntityId&;
                            var gun_boxed_ammo_reload__ammoId : das_string&;
                            var gun__boxedAmmoHolderTemplate : das_string&)
    if gun_boxed_ammo_reload__reloadState != int(BoxedAmmoReloadState.NONE)
      return

    gun_boxed_ammo_reload__isReloadRequested = true
    gun_boxed_ammo_reload__isLoad = true
    gun_boxed_ammo_reload__ammoEid = ammo_eid
    query(ammo_eid) <| $ [es] (item__proto : string = "";
                               uniqueId : string = "0")
      gun__boxedAmmoHolderTemplate := item__proto
      gun_boxed_ammo_reload__ammoId := uniqueId
    boxed_ammo_add_reload_templ(ammo_eid, gun_eid)
    gun_boxed_ammo_reload__ammoCountBeforeReload = gun__ammo
    if need_pause
      gun_boxed_ammo_reload__reloadState = int(BoxedAmmoReloadState.WAIT)
    else
      gun_boxed_ammo_reload__reloadState = int(BoxedAmmoReloadState.PREPARE)
      gun_boxed_ammo_reload__startTime = get_sync_time()
      if gun_boxed_ammo_reload__firstBulletPrepareTime >= 0.f && gun__ammo == 0
        gun_boxed_ammo_reload__atTime = gun_boxed_ammo_reload__startTime + gun_boxed_ammo_reload__firstBulletPrepareTime
      else
        gun_boxed_ammo_reload__atTime = gun_boxed_ammo_reload__startTime + gun_boxed_ammo_reload__loadPrepareTime


def private load_boxed_ammo_to_gun_with_magazine(ammo_eid : EntityId;
                                                 gun_eid : EntityId;
                                                 hero_eid : EntityId)
  // load ammo in barrel for guns with magazines
  query(gun_eid) <| $ [es] (gun__ammo, gun__maxAmmo : int;
                            gun__shell_prop_ids : GunShellPropIds;
                            var shell_props aka gun_shell_props : ShellPropIds&;
                            var gun__curShellId : ShellPropIds&)
    var ammoId : string
    gun_shell_props = length(gun__shell_prop_ids) > 0 ? gun__shell_prop_ids[0] : ShellPropIds()
    query(ammo_eid) <| $ [es] (uniqueId : string = "0")
      ammoId := uniqueId
    query(ammo_eid) <| $ [es] (shell_props aka ammo_shell_props : ShellPropIds)
      gun_shell_props = ammo_shell_props
    gun__curShellId = gun_shell_props

    var delta = gun__maxAmmo - gun__ammo
    var newGunAmmo = gun__ammo
    draw_boxed_item_from(ammo_eid, newGunAmmo, delta)

    sendEventImmediate(gun_eid, CmdLoadAmmo(loadAmmoCount = newGunAmmo - gun__ammo))
    sendEvent(hero_eid, NotifyGunBoxedAmmoLoadingEnd(gunEid = gun_eid, boxedId = ammoId, count = newGunAmmo - gun__ammo))


def start_load_boxed_ammo_to_gun(ammo_eid : EntityId;
                                 gun_eid, hero_eid : EntityId)
  var instantReload = false
  query(hero_eid) <| $ [es] (human_inventory__instantReload : bool)
    instantReload = human_inventory__instantReload
  let hasLoadAnim = has(gun_eid, "gun_boxed_ammo_reload__reloadState")
  if hasLoadAnim && !instantReload
    let needPause = set_current_hero_weapon(gun_eid, hero_eid)
    start_load_boxed_ammo_to_gun(ammo_eid, gun_eid, needPause)
    sendEvent(hero_eid, CmdHeroGunWithBoxedAmmoReloadStarted(gunEid = gun_eid))
  elif instantReload
    load_boxed_ammo_to_gun_with_magazine(ammo_eid, gun_eid, hero_eid)


def interrupt_boxed_ammo_guns_reload(actor_eid : EntityId;
                                     immediate : bool = false)
  query(actor_eid) <| $ [es] (human_weap__gunEids : EidList)
    for weaponEid in human_weap__gunEids
      query(weaponEid) <| $ [es] (gun_boxed_ammo_reload__reloadState : int)
        if gun_boxed_ammo_reload__reloadState != int(BoxedAmmoReloadState.NONE)
          sendEvent(weaponEid, CmdInterruptReloadGunWithBoxedAmmo(humanEid = actor_eid, immediately = immediate))


def private start_unload_boxed_ammo_from_gun(gun_eid : EntityId;
                                             inventory_eid : EntityId;
                                             need_pause : bool)
  query(gun_eid) <| $ [es] (gun__ammo : int;
                            gun_boxed_ammo_reload__unloadPrepareTime : float;
                            var gun_boxed_ammo_reload__ammoCountBeforeReload : int&;
                            var gun_boxed_ammo_reload__isReloadRequested : bool&;
                            var gun_boxed_ammo_reload__isLoad : bool&;
                            var gun_boxed_ammo_reload__reloadState : int&;
                            var gun_boxed_ammo_reload__startTime : float&;
                            var gun_boxed_ammo_reload__atTime : float&;
                            var gun_boxed_ammo_reload__inventoryEid : EntityId&)
    if gun_boxed_ammo_reload__reloadState != int(BoxedAmmoReloadState.NONE)
      return

    gun_boxed_ammo_reload__isReloadRequested = true
    gun_boxed_ammo_reload__isLoad = false
    gun_boxed_ammo_reload__ammoCountBeforeReload = gun__ammo
    gun_boxed_ammo_reload__inventoryEid = inventory_eid
    if need_pause
      gun_boxed_ammo_reload__reloadState = int(BoxedAmmoReloadState.WAIT)
    else
      gun_boxed_ammo_reload__reloadState = int(BoxedAmmoReloadState.PREPARE)
      gun_boxed_ammo_reload__startTime = get_sync_time()
      gun_boxed_ammo_reload__atTime = gun_boxed_ammo_reload__startTime + gun_boxed_ammo_reload__unloadPrepareTime


def private unload_boxed_ammo_from_gun_with_magazine(gun_eid : EntityId;
                                                     hero_eid : EntityId;
                                                     inventory_eid : EntityId)
  // unload ammo in barrel for guns with magazines
  query(gun_eid) <| $ [es] (gun__boxedAmmoHolderTemplate : string;
                            gun__ammo : int)
    let unloadAmmoCount = push_boxed_item_to_container_or_ground(hero_eid, gun__ammo, gun__boxedAmmoHolderTemplate, inventory_eid)
    sendEventImmediate(gun_eid, CmdUnloadAmmo(unloadAmmoCount = unloadAmmoCount))
    if unloadAmmoCount > 0
      sendEvent(hero_eid, NotifyGunBoxedAmmoUnoadingEnd(gunEid = gun_eid, inventoryEid = inventory_eid, count = unloadAmmoCount))


def start_unload_boxed_ammo_from_gun(gun_eid, hero_eid, inventory_eid : EntityId)
  var instantReload = false
  query(hero_eid) <| $ [es] (human_inventory__instantReload : bool)
    instantReload = human_inventory__instantReload
  let hasUnloadAnim = has(gun_eid, "gun_boxed_ammo_reload__reloadState") && has(gun_eid, "gun_boxed_ammo_reload__unloadEnabled")

  if hasUnloadAnim && !instantReload
    let needPause = set_current_hero_weapon(gun_eid, hero_eid)
    start_unload_boxed_ammo_from_gun(gun_eid, inventory_eid, needPause)
    sendEvent(hero_eid, CmdHeroGunWithBoxedAmmoReloadStarted(gunEid = gun_eid))
  else
    unload_boxed_ammo_from_gun_with_magazine(gun_eid, hero_eid, inventory_eid)
