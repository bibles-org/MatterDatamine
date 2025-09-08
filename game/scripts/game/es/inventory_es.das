require ecs
require app
require game.events.events_active_matter
require DngHuman
require DngNet
require game.utils.net_utils
require game.events.inventory_events
require game.es.inventory_common
require game.es.inventory_item_common
require game.es.inventory_weapon_common
require game.es.inventory_checks_common
require game.es.inventory_equipment_common
require game.es.inventory_transactions_common
require game.es.interrupt_item_use_common
require game.es.human_inventory_postponed_usage_common


let private PREFIX = "ITEM"


def item_use(human_eid : EntityId;
             item_eid : EntityId;
             target_eid : EntityId;
             start_time : float;
             duration : float;
             server : bool;
             var human_net_phys : HumanActor&)
  human_net_phys.phys.currentState |> human_phys_state_set_stoppedSprint(true)

  // Right now client just checking for ability to use item. In Future client should use item by himself and send to server time at which using has been started.
  if server
    inventory_item_prepare_using(human_eid, item_eid, human_eid, start_time, duration)
  else
    inventory_item_prepare_using(human_eid, item_eid, human_eid, start_time, -1.0, -1.0, -1.0, true)
    send_net_event(human_eid, RequestUseItem(itemEid = item_eid, targetEid = target_eid))
  sendEvent(item_eid, EventOnItemStartUse(userEid = human_eid, targetEid = target_eid))


[es(REQUIRE=item_common_use)]
def try_use_item(evt : TryUseItem;
                 eid aka item_eid : EntityId;
                 item__humanOwnerEid : EntityId = INVALID_ENTITY_ID;
                 item__unarmedUsage : bool = false;
                 item__useTime : float = -1.f;
                 item__useTimeToTarget : float = -1.f)
  query(evt.userEid) <| $ [es] (human_weap__currentGunEid : EntityId;
                                human_anim__vehicleSelected : EntityId;
                                isAlive : bool;
                                isDowned : bool;
                                isInVehicle : bool;
                                human_net_phys__isInAir : bool;
                                human_inventory__canUseItems : bool;
                                human_inventory__canHeal : bool;
                                human_inventory__canLoadCharges : bool;
                                human_weap_anim__reloadAtTime : float;
                                var human_net_phys : HumanActor&;
                                var human_inventory__entityToUse : EntityId&;
                                var human_inventory__targetToUse : EntityId&;
                                var human_inventory_postponed_usage__state : int&)
    var canUseItem = check_human_can_use_item(isAlive, human_inventory__canUseItems, human_inventory__entityToUse)
    if canUseItem != CanUseItemResponse.Approved
      if canUseItem == CanUseItemResponse.OtherItemInUse
        sendEvent(evt.userEid, EventInterruptItemUse())
      create_tip_for_use_item_decline_reason(item_eid, int(canUseItem), PREFIX)
      return

    let curTime = get_sync_time()
    canUseItem = check_item_can_be_used(evt.userEid, item_eid, human_weap__currentGunEid, human_anim__vehicleSelected, human_net_phys,
                                        curTime, curTime, human_weap_anim__reloadAtTime, isDowned, human_net_phys__isInAir, isInVehicle,
                                        human_inventory__canHeal, human_inventory__canLoadCharges)
    if canUseItem != CanUseItemResponse.Approved
      create_tip_for_use_item_decline_reason(item_eid, int(canUseItem), PREFIX)
      return

    if evt.userEid != item__humanOwnerEid
      create_tip_for_use_item_decline_reason(item_eid, int(CanUseItemResponse.NotOwner), PREFIX)
      return

    let useTime = !evt.targetEid || evt.targetEid == evt.userEid ? item__useTime : item__useTimeToTarget
    if useTime <= 0f
      create_tip_for_use_item_decline_reason(item_eid, int(CanUseItemResponse.NoUseTime), PREFIX)
      return

    if item__unarmedUsage && try_postponed_usage_on_unurmed_usage_item(evt.userEid, human_net_phys, human_inventory_postponed_usage__state)
      human_inventory__entityToUse = item_eid
      human_inventory__targetToUse = evt.targetEid
      return

    item_use(evt.userEid, item_eid, evt.targetEid, curTime, useTime, is_server(), human_net_phys)


[es(tag=server)]
def try_use_item_server(evt : RequestUseItem;
                        eid aka human_eid : EntityId;
                        human_weap__currentGunEid : EntityId;
                        human_anim__vehicleSelected : EntityId;
                        human_inventory__entityToUse : EntityId;
                        entity_mod_values : Object;
                        isAlive : bool;
                        isDowned : bool;
                        isInVehicle : bool;
                        human_net_phys__isInAir : bool;
                        human_inventory__canUseItems : bool;
                        human_inventory__canHeal : bool;
                        human_inventory__canLoadCharges : bool;
                        human_weap_anim__reloadAtTime : float;
                        var human_net_phys : HumanActor&)
  var canUseItem = check_human_can_use_item(isAlive, human_inventory__canUseItems, human_inventory__entityToUse)
  if canUseItem != CanUseItemResponse.Approved
    if canUseItem == CanUseItemResponse.OtherItemInUse
      sendEvent(human_eid, EventInterruptItemUse())
    send_net_event(human_eid, ResponseFailureUseItem(itemEid = evt.itemEid, reason = int(canUseItem)), target_entity_conn(human_eid))
    return

  let curTime = get_sync_time()
  canUseItem = check_item_can_be_used(human_eid, evt.itemEid, human_weap__currentGunEid, human_anim__vehicleSelected, human_net_phys,
                                      curTime, curTime, human_weap_anim__reloadAtTime, isDowned, human_net_phys__isInAir, isInVehicle,
                                      human_inventory__canHeal, human_inventory__canLoadCharges)
  if canUseItem != CanUseItemResponse.Approved
    send_net_event(human_eid, ResponseFailureUseItem(itemEid = evt.itemEid, reason = int(canUseItem)), target_entity_conn(human_eid))
    return

  query(evt.itemEid) <| $ [es] (item__usageSpeedModAffected : Tag const?;
                                item__humanOwnerEid : EntityId = INVALID_ENTITY_ID;
                                item__useTime : float = -1.f;
                                item__useTimeToTarget : float = -1.f;
                                item__downedTimeMultiplier : float = 1f)
    if human_eid != item__humanOwnerEid
      send_net_event(human_eid, ResponseFailureUseItem(itemEid = evt.itemEid, reason = int(CanUseItemResponse.NotOwner)), target_entity_conn(human_eid))
      return

    var useTime = !evt.targetEid || evt.targetEid == human_eid ? item__useTime : item__useTimeToTarget
    if useTime <= 0f
      send_net_event(human_eid, ResponseFailureUseItem(itemEid = evt.itemEid, reason = int(CanUseItemResponse.NoUseTime)), target_entity_conn(human_eid))
      return
    useTime = get_item_use_time(useTime, item__downedTimeMultiplier, isDowned, item__usageSpeedModAffected != null, entity_mod_values)

    item_use(human_eid, evt.itemEid, evt.targetEid, curTime, useTime, true, human_net_phys)


[es(tag=netClient, REQUIRE=hero)]
def inventory_use_item_on_failure(evt : ResponseFailureUseItem;
                                  eid aka human_eid : EntityId)
  inventory_item_reset_using(human_eid)
  create_tip_for_use_item_decline_reason(evt.itemEid, evt.reason, PREFIX, true)


[es(tag=server, REQUIRE=human_inventory, REQUIRE_NOT=deadEntity)]
def move_item_from_ground_to_inventory_server(evt : CmdMoveItemFromGroundToInventory; eid : EntityId)
  if !is_item_on_ground(evt.itemEid)
    return
  if is_item_in_inventory(evt.itemEid, evt.toInventoryEid)
    return
  if is_item_inventory_move_blocked(evt.itemEid)
    return
  if !is_can_move_item_in_inventory(evt.itemEid, evt.toInventoryEid)
    return
  if is_inventory_in_use(evt.toInventoryEid)
    return
  if is_inventory_in_use(evt.itemEid)
    return
  if !is_inventory_have_volume_for_item(evt.toInventoryEid, evt.itemEid)
    return
  if !is_actor_can_move_item(eid, evt.itemEid)
    return

  move_item_to_inventory_container(evt.itemEid, evt.toInventoryEid, eid)


[es(tag=server, REQUIRE=human_inventory, REQUIRE_NOT=deadEntity)]
def on_move_item_from_inventory_to_inventory_server(evt : CmdMoveItemFromInventoryToInventory;
                                                    eid aka human_eid : EntityId;
                                                    hero : Tag const?;
                                                    uniqueId aka human_uniqueId : das_string const?)
  if is_item_in_inventory(evt.itemEid, evt.toInventoryEid)
    return
  if is_inventory_read_only(evt.toInventoryEid)
    return
  if !is_can_move_item_in_inventory(evt.itemEid, evt.toInventoryEid)
    return
  if is_inventory_in_use(evt.toInventoryEid)
    return
  if is_inventory_in_use(evt.itemEid)
    return
  if evt.itemEid == INVALID_ENTITY_ID
    return
  if is_item_inventory_move_blocked(evt.itemEid)
    return
  if !is_inventory_have_volume_for_item(evt.toInventoryEid, evt.itemEid)
    return
  if !is_human_have_permission_to_use_inventory(human_eid, evt.toInventoryEid)
    return
  if !is_actor_can_move_item(eid, evt.itemEid)
    return
  if is_item_equipped(evt.itemEid)
    return

  move_item_to_inventory_container(evt.itemEid, evt.toInventoryEid, human_eid)
  if !is_true_net_server() && hero != null && human_uniqueId != null
    query(evt.toInventoryEid) <| $ [es] (uniqueId : string; profile_server__slotName : string)
      report_item_move_transaction(evt.itemEid, uniqueId, profile_server__slotName)


[es(tag=server, REQUIRE=human_inventory, REQUIRE_NOT=deadEntity)]
def on_split_item_to_ground_server(evt : CmdSplitItemToGround;
                                   eid : EntityId)
  if evt.itemEid == INVALID_ENTITY_ID
    return
  if is_item_inventory_move_blocked(evt.itemEid)
    return
  if !is_can_move_item_to_ground(evt.itemEid)
    return
  if !is_actor_can_move_item(eid, evt.itemEid)
    return

  var moveFull = false
  var itemHeroOwner = INVALID_ENTITY_ID
  var hasStackInfo = false
  query(evt.itemEid) <| $ [es] (item__currentBoxedItemCount : int; item__humanOwnerEid : EntityId)
    if item__currentBoxedItemCount == -1
      return
    if evt.count >= item__currentBoxedItemCount
      moveFull = true
    itemHeroOwner = item__humanOwnerEid
    hasStackInfo = true

  if !hasStackInfo
    return

  if moveFull
    if itemHeroOwner != INVALID_ENTITY_ID && itemHeroOwner != eid
      // INVALID_ENTITY_ID itemHeroOwner means that item stored in standalone container
      return
    drop_item_from_inventory_container(evt.itemEid, eid)
  else
    split_item_to_ground(evt.itemEid, eid, evt.count)


[es(tag=server, REQUIRE=human_inventory, REQUIRE_NOT=deadEntity)]
def on_split_item_to_inventory_server(evt : CmdSplitItemToInventory;
                                      eid : EntityId;
                                      hero : Tag const?;
                                      uniqueId aka human_uniqueId : das_string const?)
  if evt.itemEid == INVALID_ENTITY_ID
    return
  if is_inventory_read_only(evt.toInventoryEid)
    return
  if is_item_inventory_move_blocked(evt.itemEid)
    return
  if !is_can_move_item_in_inventory(evt.itemEid, evt.toInventoryEid)
    return
  if is_inventory_in_use(evt.toInventoryEid)
    return
  if !is_human_have_permission_to_use_inventory(eid, evt.toInventoryEid)
    return
  if !is_actor_can_move_item(eid, evt.itemEid)
    return

  var moveFull = false
  var hasStackInfo = false
  var hasErrors = false
  query(evt.itemEid) <| $ [es] (item__currentBoxedItemCount : int)
    if item__currentBoxedItemCount == -1
      return
    hasStackInfo = true
    if evt.count >= item__currentBoxedItemCount
      moveFull = true
      return

  if !hasStackInfo
    return

  let itemCountToFitInventory = get_boxed_item_count_to_fit_inventory(evt.toInventoryEid, evt.itemEid, evt.count)
  if itemCountToFitInventory < evt.count
    hasErrors = true
    return

  if hasErrors
    return

  if moveFull
    if is_item_in_inventory(evt.itemEid, evt.toInventoryEid)
      return
    else
      move_item_to_inventory_container(evt.itemEid, evt.toInventoryEid, eid)
  else
    split_item_to_inventory_container(evt.itemEid, evt.toInventoryEid, eid, evt.count)

  query(evt.itemEid) <| $ [es] (var boxed_item__actionsBlock : bool&)
    boxed_item__actionsBlock = true

  if !is_true_net_server() && hero != null && human_uniqueId != null
    query(evt.toInventoryEid) <| $ [es] (uniqueId : string; profile_server__slotName : string)
      if moveFull
        report_item_move_transaction(evt.itemEid, uniqueId, profile_server__slotName)
      else
        report_item_split_transaction(evt.itemEid, evt.count, uniqueId, profile_server__slotName)


[es(tag=server, REQUIRE=human_inventory, REQUIRE_NOT=deadEntity)]
def on_move_equipment_to_inventory_server(evt : CmdMoveEquipmentToInventory;
                                          eid : EntityId;
                                          hero : Tag const?;
                                          uniqueId aka human_uniqueId : das_string const?)
  let slotItemEid = get_equipment_from_slot(eid, evt.slotName)
  if slotItemEid == INVALID_ENTITY_ID
    return

  if is_item_inventory_move_blocked(slotItemEid)
    return
  if !is_can_move_item_in_inventory(slotItemEid, evt.toInventoryEid)
    return
  if is_inventory_in_use(evt.toInventoryEid)
    return
  if is_inventory_in_use(slotItemEid)
    return
  if slotItemEid == eid
    return
  if evt.toInventoryEid != INVALID_ENTITY_ID && !is_inventory_have_volume_for_item(evt.toInventoryEid, slotItemEid)
    return
  if !is_actor_can_move_item(eid, slotItemEid)
    return

  unequip_equipment_from_slot(evt.slotName, eid, evt.toInventoryEid)
  if !is_true_net_server() && hero != null && human_uniqueId != null
    query(evt.toInventoryEid) <| $ [es] (uniqueId : string; profile_server__slotName : string)
      report_item_move_transaction(slotItemEid, uniqueId, profile_server__slotName)

[es(tag=server, REQUIRE=human_inventory, REQUIRE_NOT=deadEntity)]
def on_equip_equipment_from_inventory_server(evt : CmdEquipEquipmentFromInventory;
                                             eid : EntityId;
                                             hero : Tag const?;
                                             uniqueId aka human_uniqueId : das_string const?)
  if evt.itemEid == INVALID_ENTITY_ID
    return
  if is_item_inventory_move_blocked(evt.itemEid)
    return
  if evt.fromInventoryEid == INVALID_ENTITY_ID
    return

  let slotValid = hero_has_slot(eid, evt.slotName)
  if !slotValid
    return

  if is_inventory_in_use(evt.itemEid)
    return

  if (!is_on_equip_equipment_prev_can_fit(evt.itemEid, evt.slotName, eid, evt.fromInventoryEid)
      && get_item_inventory_extension(evt.itemEid) == 0.f && get_item_inventory_extension(get_equipment_from_slot(eid, evt.slotName)) == 0.f)
    return
  if !is_actor_can_move_item(eid, evt.itemEid)
    return

  equip_equipment_to_slot(evt.itemEid, evt.slotName, eid, evt.fromInventoryEid)
  if !is_true_net_server() && hero != null && human_uniqueId != null
    report_item_move_transaction(evt.itemEid, string(*human_uniqueId), "equipment_{evt.slotName}")


[es(tag=server, REQUIRE=human_inventory, REQUIRE_NOT=deadEntity)]
def on_equip_equipment_from_ground_server(evt : CmdEquipEquipmentFromGround; eid : EntityId)
  if evt.itemEid == INVALID_ENTITY_ID
    return
  if is_item_inventory_move_blocked(evt.itemEid)
    return
  let slotValid = hero_has_slot(eid, evt.slotName)
  if !slotValid
    return
  if !is_actor_can_move_item(eid, evt.itemEid)
    return
  if is_inventory_in_use(evt.itemEid)
    return

  equip_equipment_to_slot(evt.itemEid, evt.slotName, eid)


[es(tag=server, REQUIRE=human_inventory, REQUIRE_NOT=deadEntity)]
def on_equip_weapon_server(evt : CmdEquipWeaponFromInventory;
                           eid : EntityId;
                           hero : Tag const?;
                           uniqueId aka human_uniqueId : das_string const?)
  if evt.itemEid == INVALID_ENTITY_ID
    return
  if is_item_inventory_move_blocked(evt.itemEid)
    return

  var oldWeaponEid = INVALID_ENTITY_ID
  query(eid) <| $ [es] (human_weap__gunEids : EidList)
    oldWeaponEid = human_weap__gunEids[evt.slotId]

  if oldWeaponEid != INVALID_ENTITY_ID && is_item_inventory_move_blocked(oldWeaponEid)
    return

  if !is_weapon_slot_available_for_equip(eid, evt.slotId)
    return
  if !is_on_equip_weapon_prev_can_fit(evt.itemEid, evt.slotId, eid, evt.fromInventoryEid)
    return
  if !is_actor_can_move_item(eid, evt.itemEid)
    return

  equip_weapon_to_slot(evt.itemEid, evt.slotId, eid, evt.fromInventoryEid)
  if !is_true_net_server() && hero != null && human_uniqueId != null
    report_item_move_transaction(evt.itemEid, string(*human_uniqueId), "weapon_{evt.slotId}")


[es(tag=server, REQUIRE=human_inventory, REQUIRE_NOT=deadEntity)]
def on_move_weapon_to_inventory_server(evt : CmdMoveWeaponToInventory;
                                       eid : EntityId;
                                       human_weap__gunEids : EidList;
                                       hero : Tag const?;
                                       uniqueId aka human_uniqueId : das_string const?)
  let weaponEid = human_weap__gunEids[evt.slotId]
  if weaponEid == INVALID_ENTITY_ID
    return
  if is_item_inventory_move_blocked(weaponEid)
    return
  if !is_can_move_item_in_inventory(weaponEid, evt.toInventoryEid)
    return
  if is_inventory_in_use(evt.toInventoryEid)
    return
  if !is_actor_can_move_item(eid, weaponEid)
    return

  unequip_weapon_from_slot(evt.slotId, eid, evt.toInventoryEid)
  if !is_true_net_server() && hero != null && human_uniqueId != null
    query(evt.toInventoryEid) <| $ [es] (uniqueId : string; profile_server__slotName : string)
      report_item_move_transaction(weaponEid, uniqueId, profile_server__slotName)
