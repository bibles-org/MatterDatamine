require ecs
require app
require DngNet
require ecs.safe
require game.events.events_game
require game.events.inventory_events
require game.es.human_weap_common
require DngHuman
require AnimV20
require game.es.ecs_common
require game.es.human.human_reload_common
require game.es.boxed_item_common
require game.es.boxed_ammo_reload_common
require game.es.inventory_checks_common
require game.events.events
require game.events.events_active_matter
require DaWeaponProps


[es(tag=gameClient, track=gun_boxed_ammo_reload__reloadState, before=client_track_reload_gun_with_boxed_ammo_state)]
def init_start_boxed_ammo_reload_client(evt : Event;
                                        gun__ammo : int;
                                        gun__isReloading : bool;
                                        gun_boxed_ammo_reload__reloadState : int;
                                        gun_boxed_ammo_reload__ammoEid : EntityId;
                                        var gun_boxed_ammo_reload__ammoCountBeforeReload : int&;
                                        var gun_boxed_ammo_reload__startTime : float&;
                                        var gun_boxed_ammo_reload__ammoId : das_string&)
  // don't init if reload already is in progress or gun is not reloading
  // (check "gun_boxed_ammo_reload__reloadState != int(BoxedAmmoReloadState PREPARE)" is not reliable,
  // cause if gun_boxed_ammo_reload__loadPrepareTime == 0.f, then on start reload client most likely will get LOAD-state
  // replicated from server without priorly getting PREPARE-state)
  if gun__isReloading || gun_boxed_ammo_reload__reloadState < int(BoxedAmmoReloadState.PREPARE)
    return

  gun_boxed_ammo_reload__ammoCountBeforeReload = gun__ammo
  gun_boxed_ammo_reload__startTime = get_sync_time()
  query(gun_boxed_ammo_reload__ammoEid) <| $ [es] (uniqueId : string)
    gun_boxed_ammo_reload__ammoId := uniqueId


[es(tag=server, track=human_net_phys__weapEquipCurSlot)]
def unpause_boxed_ammo_reload_on_set_weapon_in_hands(ecs : Event;
                                                     human_weap__gunEids : EidList;
                                                     human_net_phys__weapEquipCurSlot : int)
  query(human_weap__gunEids[human_net_phys__weapEquipCurSlot]) <| $ [es] (gun_boxed_ammo_reload__loadPrepareTime : float;
                                                                          gun_boxed_ammo_reload__unloadPrepareTime : float;
                                                                          gun_boxed_ammo_reload__isLoad : bool;
                                                                          gun__ammo : int;
                                                                          gun_boxed_ammo_reload__firstBulletPrepareTime : float = -1.f;
                                                                          var gun_boxed_ammo_reload__reloadState : int&;
                                                                          var gun_boxed_ammo_reload__startTime : float&;
                                                                          var gun_boxed_ammo_reload__atTime : float&)
    if gun_boxed_ammo_reload__reloadState != int(BoxedAmmoReloadState.WAIT)
      return

    gun_boxed_ammo_reload__reloadState = int(BoxedAmmoReloadState.PREPARE)
    gun_boxed_ammo_reload__startTime = get_sync_time()
    if gun_boxed_ammo_reload__isLoad
      if gun_boxed_ammo_reload__firstBulletPrepareTime >= 0.f && gun__ammo == 0
        gun_boxed_ammo_reload__atTime = gun_boxed_ammo_reload__startTime + gun_boxed_ammo_reload__firstBulletPrepareTime
      else
        gun_boxed_ammo_reload__atTime = gun_boxed_ammo_reload__startTime + gun_boxed_ammo_reload__loadPrepareTime
    else
      gun_boxed_ammo_reload__atTime = gun_boxed_ammo_reload__startTime + gun_boxed_ammo_reload__unloadPrepareTime


def private get_load_ammo_count(gun_eid : EntityId;
                                ammo_eid : EntityId;
                                wish_load_num : int)
  var loadNum = 0
  query(gun_eid) <| $ [es] (gun__ammo : int;
                            gun__maxAmmo : int)
    query(ammo_eid) <| $ [es] (item__currentBoxedItemCount : int)
      loadNum = min(wish_load_num, gun__maxAmmo - gun__ammo)
      loadNum = min(loadNum, item__currentBoxedItemCount)
  return loadNum


def private take_ammo_from_box(gun_eid : EntityId;
                               ammo_eid, human_eid : EntityId;
                               wish_load_num : int;
                               var load_num : int&)
  var ammoBoxEmptied = false
  query(human_eid) <| $ [es] (human_weap__reloadMode : int = int(ReloadAmmoMode.CONSUME))
    query(gun_eid) <| $ [es] (gun__shell_prop_ids : GunShellPropIds;
                              gun__ammo : int;
                              var shell_props aka gun_shell_props : ShellPropIds&;
                              var gun__curShellId : ShellPropIds&)
      gun_shell_props = length(gun__shell_prop_ids) > 0 ? gun__shell_prop_ids[0] : ShellPropIds()
      query(ammo_eid) <| $ [es] (shell_props aka item_shell_props : ShellPropIds)
        gun_shell_props = item_shell_props
      gun__curShellId = gun_shell_props

      load_num = get_load_ammo_count(gun_eid, ammo_eid, wish_load_num)
      if human_weap__reloadMode == int(ReloadAmmoMode.CONSUME)
        var delta = load_num
        var newGunAmmo = gun__ammo
        ammoBoxEmptied = draw_boxed_item_from(ammo_eid, newGunAmmo, delta)

  return ammoBoxEmptied


def private get_take_ammo_count(gun__boxedAmmoHolderTemplate : string;
                                inventory_eid : EntityId;
                                var wish_unload_num : int&;
                                var new_box : bool&)
  if inventory_eid == INVALID_ENTITY_ID
    return false
  var maxUnloadNum = 0
  query(inventory_eid) <| $ [es] (itemContainer : EidList)
    let boxedItemEid = find_boxed_item_to_draw_from(gun__boxedAmmoHolderTemplate, itemContainer)
    new_box = boxedItemEid == INVALID_ENTITY_ID
    if boxedItemEid != INVALID_ENTITY_ID
      maxUnloadNum = get_boxed_item_count_to_fit_inventory(inventory_eid, boxedItemEid)
    else
      maxUnloadNum = get_boxed_item_count_to_fit_inventory(inventory_eid, gun__boxedAmmoHolderTemplate)
  wish_unload_num = min(wish_unload_num, maxUnloadNum)
  return maxUnloadNum == wish_unload_num


def private push_ammo_to_inventory(gun_eid : EntityId;
                                   human_eid, inventory_eid : EntityId;
                                   wish_unload_num : int;
                                   var unload_num : int&;
                                   var notify : bool&)
  var inventoryIsFull = false
  query(gun_eid) <| $ [es] (gun__boxedAmmoHolderTemplate : string)
    unload_num = wish_unload_num
    inventoryIsFull = get_take_ammo_count(gun__boxedAmmoHolderTemplate, inventory_eid, unload_num, notify)
    if is_server()
      if unload_num != 0
        push_boxed_item_to_container_or_ground(human_eid, unload_num, gun__boxedAmmoHolderTemplate, inventory_eid)
      else
        print("[INVENTORY] No free space in {get_entity_info(inventory_eid)} so pushing ammo to the ground")
        push_boxed_item_to_container_or_ground(human_eid, wish_unload_num, gun__boxedAmmoHolderTemplate, INVALID_ENTITY_ID)
  return inventoryIsFull


[es(no_order)]
def boxed_ammo_reload_move_to_next_reload_state(info : UpdateStageInfoAct;
                                                eid : EntityId;
                                                gun__owner : EntityId;
                                                gun__ammo : int const?;
                                                gun__maxAmmo : int;
                                                gun_boxed_ammo_reload__isLoad : bool;
                                                gun_boxed_ammo_reload__loadLoopTime : float;
                                                gun_boxed_ammo_reload__loadPostTime : float;
                                                gun_boxed_ammo_reload__unloadLoopTime : float;
                                                gun_boxed_ammo_reload__unloadPostTime : float;
                                                gun_boxed_ammo_reload__firstBulletLoopTime : float = -1.f;
                                                gun_boxed_ammo_reload__onEmptyPostTime : float = -1.f;
                                                var gun_boxed_ammo_reload__ammoCountBeforeReload : int&;
                                                var gun_boxed_ammo_reload__ammoEid : EntityId&;
                                                var gun_boxed_ammo_reload__inventoryEid : EntityId&;
                                                var gun_boxed_ammo_reload__ammoId : das_string&;
                                                var gun_boxed_ammo_reload__curLoopAmmoCount : int&;
                                                var gun_boxed_ammo_reload__isReloadRequested : bool&;
                                                var gun_boxed_ammo_reload__reloadState : int&;
                                                var gun_boxed_ammo_reload__startTime : float&;
                                                var gun_boxed_ammo_reload__atTime : float&;
                                                gun_boxed_ammo_reload__reloadMaxAmmo : int = 1)
  if gun_boxed_ammo_reload__reloadState < int(BoxedAmmoReloadState.PREPARE)
    return
  if info.curTime < gun_boxed_ammo_reload__atTime
    return

  if gun_boxed_ammo_reload__reloadState == int(BoxedAmmoReloadState.PREPARE)
    if gun_boxed_ammo_reload__isReloadRequested
      gun_boxed_ammo_reload__reloadState = int(BoxedAmmoReloadState.LOOP)
      if gun_boxed_ammo_reload__isLoad
        if gun_boxed_ammo_reload__firstBulletLoopTime > 0.f && *gun__ammo == 0
          gun_boxed_ammo_reload__atTime += gun_boxed_ammo_reload__firstBulletLoopTime
        else
          gun_boxed_ammo_reload__atTime += gun_boxed_ammo_reload__loadLoopTime
      else
        gun_boxed_ammo_reload__atTime += gun_boxed_ammo_reload__unloadLoopTime
    else
      gun_boxed_ammo_reload__reloadState = int(BoxedAmmoReloadState.POST)
      if gun_boxed_ammo_reload__isLoad
        if gun_boxed_ammo_reload__onEmptyPostTime > 0.f && gun_boxed_ammo_reload__ammoCountBeforeReload == 0
          gun_boxed_ammo_reload__atTime += gun_boxed_ammo_reload__onEmptyPostTime
        else
          gun_boxed_ammo_reload__atTime += gun_boxed_ammo_reload__loadPostTime
      else
        gun_boxed_ammo_reload__atTime += gun_boxed_ammo_reload__unloadPostTime
  elif gun_boxed_ammo_reload__reloadState == int(BoxedAmmoReloadState.LOOP)
    if gun_boxed_ammo_reload__isLoad

      let ammoBoxEmptied = take_ammo_from_box(eid, gun_boxed_ammo_reload__ammoEid, gun__owner, gun_boxed_ammo_reload__reloadMaxAmmo, gun_boxed_ammo_reload__curLoopAmmoCount)
      sendEventImmediate(eid, CmdLoadAmmo(loadAmmoCount = gun_boxed_ammo_reload__curLoopAmmoCount))
      if *gun__ammo < gun__maxAmmo && gun_boxed_ammo_reload__isReloadRequested && !ammoBoxEmptied
        gun_boxed_ammo_reload__atTime += gun_boxed_ammo_reload__loadLoopTime
      else // not immediatly interrupt or end of reload
        gun_boxed_ammo_reload__reloadState = int(BoxedAmmoReloadState.POST)
        if gun_boxed_ammo_reload__onEmptyPostTime > 0.f && gun_boxed_ammo_reload__ammoCountBeforeReload == 0
          gun_boxed_ammo_reload__atTime += gun_boxed_ammo_reload__onEmptyPostTime
        else
          gun_boxed_ammo_reload__atTime += gun_boxed_ammo_reload__loadPostTime
        sendEvent(gun__owner, NotifyGunBoxedAmmoLoadingEnd(gunEid = eid, boxedId = string(gun_boxed_ammo_reload__ammoId), count = (*gun__ammo - gun_boxed_ammo_reload__ammoCountBeforeReload)))
    else
      var notify = false // need send notification to create new box (from profile server)
      let inventoryIsFull = push_ammo_to_inventory(eid, gun__owner, gun_boxed_ammo_reload__inventoryEid, 1, gun_boxed_ammo_reload__curLoopAmmoCount, notify)
      sendEventImmediate(eid, CmdUnloadAmmo(unloadAmmoCount = gun_boxed_ammo_reload__curLoopAmmoCount))
      if *gun__ammo > 0 && gun_boxed_ammo_reload__isReloadRequested && !inventoryIsFull
        gun_boxed_ammo_reload__atTime += gun_boxed_ammo_reload__unloadLoopTime
        if notify
          sendEvent(gun__owner, NotifyGunBoxedAmmoUnoadingEnd(gunEid = eid, inventoryEid = gun_boxed_ammo_reload__inventoryEid, count = (gun_boxed_ammo_reload__ammoCountBeforeReload - *gun__ammo)))
          gun_boxed_ammo_reload__ammoCountBeforeReload = *gun__ammo
      else // not immediatly interrupt or end of reload
        gun_boxed_ammo_reload__reloadState = int(BoxedAmmoReloadState.POST)
        gun_boxed_ammo_reload__atTime += gun_boxed_ammo_reload__unloadPostTime
        sendEvent(gun__owner, NotifyGunBoxedAmmoUnoadingEnd(gunEid = eid, inventoryEid = gun_boxed_ammo_reload__inventoryEid, count = (gun_boxed_ammo_reload__ammoCountBeforeReload - *gun__ammo)))
  else
    gun_boxed_ammo_reload__reloadState = int(BoxedAmmoReloadState.NONE)
    if gun_boxed_ammo_reload__isLoad
      boxed_ammo_remove_reload_templ(gun_boxed_ammo_reload__ammoEid)
    gun_boxed_ammo_reload__ammoEid = INVALID_ENTITY_ID
    gun_boxed_ammo_reload__inventoryEid = INVALID_ENTITY_ID
    gun_boxed_ammo_reload__ammoId := "0"
    gun_boxed_ammo_reload__isReloadRequested = false

  if gun_boxed_ammo_reload__reloadState != int(BoxedAmmoReloadState.NONE)
    gun_boxed_ammo_reload__startTime = get_sync_time()


[es(track=(gun_boxed_ammo_reload__reloadState))]
def toggle_weapon_state_lock_on_boxed_ammo_reload(evt : Event;
                                                  eid : EntityId;
                                                  gun_boxed_ammo_reload__reloadState : int)
  if gun_boxed_ammo_reload__reloadState != int(BoxedAmmoReloadState.NONE)
    addSubTemplate(eid, "block_item_all_actions")
  else
    removeSubTemplate(eid, "block_item_all_actions")


[es(REQUIRE=gun_boxed_ammo_reload__reloadBatch, on_appear)]
def init_batch_reload_max_ammo(evt : Event;
                               gun__maxAmmo : int;
                               gun_boxed_ammo_reload__batchReloadTime : float = 1.f;
                               var gun_boxed_ammo_reload__reloadMaxAmmo : int&;
                               var gun_boxed_ammo_reload__loadLoopTime : float&)
  gun_boxed_ammo_reload__reloadMaxAmmo = gun__maxAmmo
  gun_boxed_ammo_reload__loadLoopTime = gun_boxed_ammo_reload__batchReloadTime


[es(REQUIRE=gun_boxed_ammo_reload__reloadBatchOnEmpty, on_appear, track=(gun__ammo, gun_boxed_ammo_reload__reloadState))]
def toggle_batch_reload_on_empty_max_ammo(evt : Event;
                                          gun__ammo : int;
                                          gun__maxAmmo : int;
                                          gun_boxed_ammo_reload__batchReloadTime : float = 1.f;
                                          item__weapTemplate : string;
                                          gun_boxed_ammo_reload__reloadState : int;
                                          gun_boxed_ammo_reload__bulletByBulletReloadPrepareTime : float = 1.f;
                                          gun_boxed_ammo_reload__bulletByBulletReloadLoopTime : float = 1.f;
                                          gun_boxed_ammo_reload__bulletByBulletReloadPostTime : float = 1.f;
                                          var gun_anim__customReloadStyleEnabled : bool&;
                                          var gun_boxed_ammo_reload__reloadMaxAmmo : int&;
                                          var gun_boxed_ammo_reload__loadPrepareTime : float&;
                                          var gun_boxed_ammo_reload__loadLoopTime : float&;
                                          var gun_boxed_ammo_reload__loadPostTime : float&)
  // don't toggle state if reload is in progress
  if gun_boxed_ammo_reload__reloadState != int(BoxedAmmoReloadState.NONE)
    return

  if gun__ammo > 0
    gun_anim__customReloadStyleEnabled = false
    let templ = getTemplateByName(item__weapTemplate)
    if templ != null
      gun_boxed_ammo_reload__reloadMaxAmmo = 1
      gun_boxed_ammo_reload__loadPrepareTime = gun_boxed_ammo_reload__bulletByBulletReloadPrepareTime
      gun_boxed_ammo_reload__loadLoopTime = gun_boxed_ammo_reload__bulletByBulletReloadLoopTime
      gun_boxed_ammo_reload__loadPostTime = gun_boxed_ammo_reload__bulletByBulletReloadPostTime
  else
    gun_anim__customReloadStyleEnabled = true
    gun_boxed_ammo_reload__reloadMaxAmmo = gun__maxAmmo
    gun_boxed_ammo_reload__loadPrepareTime = 0.f
    gun_boxed_ammo_reload__loadLoopTime = gun_boxed_ammo_reload__batchReloadTime
    gun_boxed_ammo_reload__loadPostTime = 0.f


[es]
def interupt_boxed_ammo_reload(evt : CmdInterruptReloadGunWithBoxedAmmo;
                               eid : EntityId;
                               gun__ammo : int;
                               gun_boxed_ammo_reload__ammoCountBeforeReload : int;
                               gun_boxed_ammo_reload__isLoad : bool;
                               var gun_boxed_ammo_reload__isReloadRequested : bool&;
                               var gun_boxed_ammo_reload__reloadState : int&;
                               var gun_boxed_ammo_reload__atTime : float&;
                               var gun_boxed_ammo_reload__ammoEid : EntityId&;
                               var gun_boxed_ammo_reload__inventoryEid : EntityId&;
                               var gun_boxed_ammo_reload__ammoId : das_string&)
  if gun_boxed_ammo_reload__reloadState == int(BoxedAmmoReloadState.NONE)
    return

  gun_boxed_ammo_reload__isReloadRequested = false

  if evt.immediately
    if gun_boxed_ammo_reload__reloadState == int(BoxedAmmoReloadState.LOOP)
      // send notification, current loop will not end
      if gun_boxed_ammo_reload__isLoad
        let loadAmmoCount = gun__ammo - gun_boxed_ammo_reload__ammoCountBeforeReload
        if loadAmmoCount > 0
          sendEventImmediate(evt.humanEid, NotifyGunBoxedAmmoLoadingEnd(gunEid = eid, boxedId = string(gun_boxed_ammo_reload__ammoId), count = loadAmmoCount))
      else
        let unloadAmmoCount = gun_boxed_ammo_reload__ammoCountBeforeReload - gun__ammo
        if unloadAmmoCount > 0
          sendEventImmediate(evt.humanEid, NotifyGunBoxedAmmoUnoadingEnd(gunEid = eid, inventoryEid = gun_boxed_ammo_reload__inventoryEid, count = unloadAmmoCount))

    // stop reload immediately
    gun_boxed_ammo_reload__reloadState = int(BoxedAmmoReloadState.NONE)
    gun_boxed_ammo_reload__atTime = -1.f
    if gun_boxed_ammo_reload__isLoad
      boxed_ammo_remove_reload_templ(gun_boxed_ammo_reload__ammoEid)
    gun_boxed_ammo_reload__ammoEid = INVALID_ENTITY_ID
    gun_boxed_ammo_reload__inventoryEid = INVALID_ENTITY_ID
    gun_boxed_ammo_reload__ammoId := "0"


def private boxed_ammo_remove_reload_templ(boxed_ammo_eid : EntityId)
  query(boxed_ammo_eid) <| $ [es] (item__recreateOnReload = "")
    removeSubTemplate(boxed_ammo_eid, item__recreateOnReload)


[es(no_order)]
def interrupt_reload_with_boxed_ammo_on_shoot(info : ecs::UpdateStageInfoAct;
                                              eid : EntityId;
                                              human_weap__currentGunEid : ecs::EntityId;
                                              human_net_phys : HumanActor&)
  if !is_control_bit_set(human_net_phys.phys.appliedCT, HumanPhysControlType.HCT_SHOOT)
    return

  query(human_weap__currentGunEid) <| $ [es] (gun_boxed_ammo_reload__reloadState : int;
                                              reload__shootImmediatelyInterruptSingleReload : Tag const?)
    if gun_boxed_ammo_reload__reloadState == int(BoxedAmmoReloadState.LOOP)
      sendEvent(human_weap__currentGunEid, CmdInterruptReloadGunWithBoxedAmmo(humanEid = eid, immediately = (reload__shootImmediatelyInterruptSingleReload != null)))


[es(track=item__isOnGround, REQUIRE=gun_boxed_ammo_reload__reloadState, REQUIRE_NOT=player_on_base_components__stashEid)]
def interrupt_reload_with_boxed_ammo_on_drop_weapon(evt : Event;
                                                    eid : EntityId;
                                                    item__isOnGround : bool)
  if item__isOnGround
    sendEvent(eid, CmdInterruptReloadGunWithBoxedAmmo(humanEid = INVALID_ENTITY_ID, immediately = true))


[es(track=human_net_phys__weapEquipNextSlot)]
def interrupt_reload_with_boxed_ammo_on_weapon_switched(evt : Event;
                                                        eid : EntityId;
                                                        human_weap__gunEids : EidList;
                                                        human_net_phys__weapEquipCurSlot : int;
                                                        human_net_phys__weapEquipNextSlot : int)
  if human_net_phys__weapEquipNextSlot != human_net_phys__weapEquipCurSlot // changing weapon -> abort boxed ammo reload for old weapon
    let curWeaponEid = human_weap__gunEids[human_net_phys__weapEquipCurSlot]
    query(curWeaponEid) <| $ [es] (gun_boxed_ammo_reload__reloadState : int)
      if gun_boxed_ammo_reload__reloadState != int(BoxedAmmoReloadState.NONE)
        sendEvent(curWeaponEid, CmdInterruptReloadGunWithBoxedAmmo(humanEid = eid, immediately = true))
  else // was changing weapon, but switched back -> abort scheduled boxed ammo reload for other weapons
    for weaponEid in human_weap__gunEids
      query(weaponEid) <| $ [es] (gun_boxed_ammo_reload__reloadState : int)
        if gun_boxed_ammo_reload__reloadState == int(BoxedAmmoReloadState.WAIT)
          sendEvent(weaponEid, CmdInterruptReloadGunWithBoxedAmmo(humanEid = eid, immediately = true))


[es(REQUIRE=human_inventory)]
def interrupt_reload_with_boxed_ammo_on_ammo_split_to_ground(evt : EventOnItemDrop;
                                                             eid : EntityId)
  query(evt.itemEid) <| $ [es] (boxed_ammo__reloadGunEid : EntityId)
    query(boxed_ammo__reloadGunEid) <| $ [es] (var gun_boxed_ammo_reload__ammoEid : EntityId&)
      gun_boxed_ammo_reload__ammoEid = INVALID_ENTITY_ID
    sendEvent(boxed_ammo__reloadGunEid, CmdInterruptReloadGunWithBoxedAmmo(humanEid = eid, immediately = false))


[es]
def interrupt_reload_with_boxed_ammo_on_ammo_split_to_inventory(evt : EventOnMovingBetweenInventories;
                                                                boxed_ammo__reloadGunEid : EntityId)
  query(boxed_ammo__reloadGunEid) <| $ [es] (var gun_boxed_ammo_reload__ammoEid : EntityId&)
    gun_boxed_ammo_reload__ammoEid = INVALID_ENTITY_ID
    sendEventImmediate(boxed_ammo__reloadGunEid, CmdInterruptReloadGunWithBoxedAmmo(humanEid = evt.actorEid, immediately = false))


[es(no_order)]
def interrupt_reload_with_boxed_ammo_on_stop_aim_in_vehicle(evt : UpdateStageInfoAct;
                                                            eid : EntityId;
                                                            gun__owner : EntityId;
                                                            gun_boxed_ammo_reload__reloadState : int)
  if gun_boxed_ammo_reload__reloadState == int(BoxedAmmoReloadState.NONE)
    return

  query(gun__owner) <| $ [es] (isInVehicle : bool; human_net_phys : HumanActor)
    if isInVehicle && !is_human_aiming(gun__owner, eid, human_net_phys)
      sendEventImmediate(eid, CmdInterruptReloadGunWithBoxedAmmo(humanEid = gun__owner, immediately = true))


[es(before=human_weap_request_reload_es)]
def interrupt_reload_with_boxed_ammo_on_rereload(evt : CmdRequestReload;
                                                 eid : EntityId;
                                                 human_weap__currentGunEid : ecs::EntityId)
  query(human_weap__currentGunEid) <| $ [es] (gun_boxed_ammo_reload__reloadState : int;
                                              var gun_boxed_ammo_reload__lastRequestReload : float&;
                                              reload__shootImmediatelyInterruptSingleReload : Tag const?)
    if gun_boxed_ammo_reload__reloadState == int(BoxedAmmoReloadState.LOOP) && gun_boxed_ammo_reload__lastRequestReload - evt.atTime > 0.1
      sendEvent(human_weap__currentGunEid, CmdInterruptReloadGunWithBoxedAmmo(humanEid = eid, immediately = (reload__shootImmediatelyInterruptSingleReload != null)))
    gun_boxed_ammo_reload__lastRequestReload = evt.atTime


[es(REQUIRE_NOT=player_on_base_components__stashEid)]
def interrupt_reload_with_boxed_ammo_on_container_close(evt : CmdCloseExternalInventoryRequest;
                                                        eid : EntityId;
                                                        human_weap__gunEids : EidList)
  for gun in human_weap__gunEids
    query(gun) <| $ [es] (gun_boxed_ammo_reload__reloadState : int;
                          gun_boxed_ammo_reload__ammoEid : EntityId;
                          var gun_boxed_ammo_reload__inventoryEid : EntityId&)
      if gun_boxed_ammo_reload__reloadState != int(BoxedAmmoReloadState.NONE)
        query(gun_boxed_ammo_reload__ammoEid) <| $ [es] (item__containerOwnerEid : EntityId)
          if item__containerOwnerEid == evt.inventoryEid
            sendEvent(gun, CmdInterruptReloadGunWithBoxedAmmo(humanEid = eid, immediately = false))
        gun_boxed_ammo_reload__inventoryEid = INVALID_ENTITY_ID


[es(REQUIRE=item_in_world, no_order)]
def interrupt_reload_with_boxed_ammo_on_box_far(info : ParallelUpdateFrameDelayed;
                                                transform aka box_transform : float3x4;
                                                boxed_ammo__reloadGunEid : EntityId)
  query(boxed_ammo__reloadGunEid) <| $ [es] (gun__owner : EntityId)
    query(gun__owner) <| $ [es] (transform aka hero_transform : float3x4;
                                 human_inventory__lookNodeId : int;
                                 animchar : AnimcharBaseComponent;
                                 human_inventory__pickupRemoveRadius : float;
                                 human_inventory__pickupRemoveHeight : float)
      if !is_item_accessible_by_distance(human_inventory__lookNodeId, animchar, hero_transform,
          human_inventory__pickupRemoveRadius, human_inventory__pickupRemoveHeight, box_transform)
        sendEvent(boxed_ammo__reloadGunEid, CmdInterruptReloadGunWithBoxedAmmo(humanEid = gun__owner, immediately = false))
