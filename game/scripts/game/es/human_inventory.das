require ecs
require DngNet
require DngHuman
require ecs.common
require game.es.action_common
require game.es.gun_jamming_common
require game.events.inventory_events
require game.es.inventory_item_common
require game.es.inventory_checks_common
require game.es.inventory_weapon_common
require game.es.inventory_equipment_common
require game.es.inventory_equipment_mod_common
require game.es.inventory_weapon_mod_common
require game.events.events
require game.es.human_weap_common
require game.events.events_active_matter
require game.es.boxed_ammo_reload_common
require game.es.inventory_transactions_common
require game.es.inventory_slots_common
require strings
require game.es.human_inventory_postponed_usage_common


[es(tag=server, on_appear)]
def inventory_item_push_es(evt : Event; eid : EntityId;
                           item__containerOwnerEid : EntityId;
                           item__appearInItemContainer : bool = true)
  if !item__appearInItemContainer
    return
  // use create_item_in_inventory_container to avoid issues
  query(item__containerOwnerEid) <| $ [es] (itemContainer : EidList)
    if !has_value(itemContainer, eid)
      move_item_to_inventory_container(eid, item__containerOwnerEid, INVALID_ENTITY_ID)


[es(tag=server, on_disappear, on_event=(EventEntityDied), before=interrupt_item_use_es)]
def human_inventory_on_death(evt : Event; eid, human_inventory__entityToUse : EntityId)
  if human_inventory__entityToUse != INVALID_ENTITY_ID
    sendEventImmediate(eid, EventInterruptItemUse())


[es(tag=server, on_appear, REQUIRE=state__interruptItemUsage)]
def human_inventory_on_state_change(evt : Event; game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (human_inventory__entityToUse : EntityId)
    if human_inventory__entityToUse != INVALID_ENTITY_ID
      sendEventImmediate(game_effect__attachedTo, EventInterruptItemUse())


[es(tag=server, after=before_human_inventory_use_update)]
def human_inventory_server_es(info : UpdateStageInfoAct;
                              eid : EntityId;
                              human_inventory__entityUseEnd : float;
                              human_inventory__entityManualUse : bool;
                              human_inventory__targetToUse : EntityId;
                              var human_inventory__entityToUse : EntityId&;
                              var human_inventory__lastUsedItemDevice : EntityId&;
                              human_inventory_postponed_usage__state : int = 0)
  if info.curTime < human_inventory__entityUseEnd || human_inventory__entityManualUse
    return

  if human_inventory_postponed_usage__state == int(PostponedUsageState.WaitForSwapToUnarmed) || !doesEntityExist(human_inventory__entityToUse)
    return

  if has(human_inventory__entityToUse, "deviceItem")
    human_inventory__lastUsedItemDevice = human_inventory__entityToUse

  if (has(human_inventory__entityToUse, "canBeUsedOutOfInventory") ||
      has(human_inventory__entityToUse, "item__notConsumedWhenUsed"))
    sendEventImmediate(human_inventory__entityToUse, EventOnLootItemUsed(target = human_inventory__targetToUse))
    human_inventory__entityToUse = INVALID_ENTITY_ID

  else
    query(human_inventory__entityToUse) <| $ [es] (item__containerOwnerEid : EntityId)
      query(item__containerOwnerEid) <| $ [es] (itemContainer : EidList)
        if itemContainer |> has_value(human_inventory__entityToUse)
          sendEventImmediate(human_inventory__entityToUse, EventOnLootItemUsed(target = human_inventory__targetToUse))
          sendEventImmediate(eid, EventOnLootUse(itemEid = human_inventory__entityToUse))
          destroyEntity(human_inventory__entityToUse)

  sendEventImmediate(eid, EventInterruptItemUse(forced = true))


[es(REQUIRE=human_inventory, REQUIRE_NOT=deadEntity)]
def human_inventory_pickup(evt : RequestItemPickup; eid : EntityId)
  if !is_hero_can_pickup_items(eid)
    return

  let itemEid = evt.itemEid
  let itemPickupBlockReason = get_item_pickup_block_reason(itemEid, eid)
  if !empty(itemPickupBlockReason)
    sendEvent(eid, EventOnActionDisabled(action = itemPickupBlockReason))
    return

  if is_can_pickup_item(eid, itemEid)
    run_action(eid, "pickup")
    send_net_event(eid, CmdItemPickup(item = itemEid))


[es(tag=server, REQUIRE=human_inventory, REQUIRE_NOT=deadEntity)]
def item_pickup(evt : CmdItemPickup; eid, human_weap__currentGunEid : EntityId)
  let itemEid = evt.item
  if !is_hero_can_pickup_items(eid) || !empty(get_item_pickup_block_reason(itemEid, eid))
    return
  if !is_actor_can_move_item(eid, itemEid)
    return

  let equipInsteadOfPickup = has(itemEid, "item__equipInsteadOfPickup")

  let weaponSlotIdx = get_weapon_slot_for_item(eid, itemEid)
  if weaponSlotIdx != -1
    pickup_gun(eid, itemEid, weaponSlotIdx)
    return

  let equipmentSlotName = get_equipment_slot_for_item(eid, itemEid, equipInsteadOfPickup)
  if !empty(equipmentSlotName)
    equip_equipment_to_slot(itemEid, equipmentSlotName, eid)
    return

  let weaponModSlotName = get_current_gun_free_slot_for_mod(human_weap__currentGunEid, itemEid)
  let itemValuableForWeapon = is_mod_valuable_for_weapon(itemEid)
  if !empty(weaponModSlotName) && itemValuableForWeapon
    start_equip_weapon_mod_to_slot(itemEid, weaponModSlotName, human_weap__currentGunEid, eid, INVALID_ENTITY_ID)
    return

  var equipToEquipment = false
  using <| $(var slot_equip_mod : Object)
    get_slot_and_equipment_for_mod(slot_equip_mod, eid, itemEid)
    if has(slot_equip_mod, "equipment") && has(slot_equip_mod, "slot")
      let equipment = get_Eid(slot_equip_mod["equipment"]) ?? INVALID_ENTITY_ID
      let slot = get_string(slot_equip_mod["slot"], "")
      equip_equipment_mod_to_slot(itemEid, slot, equipment, eid)
      equipToEquipment = true
  if equipToEquipment
    return

  let inventoryContainerEid = get_inventory_for_item(eid, itemEid)
  if inventoryContainerEid != INVALID_ENTITY_ID
    move_item_to_inventory_container(itemEid, inventoryContainerEid, eid)
    return


[es(tag=server, REQUIRE=human_inventory, REQUIRE_NOT=deadEntity)]
def on_move_weapon_mod_to_inventory_server(evt : CmdMoveWeaponModToInventory;
                                           eid : EntityId;
                                           human_weap__gunEids : EidList;
                                           isInVehicle : bool;
                                           human_net_phys : HumanActor;
                                           hero : Tag const?;
                                           uniqueId aka human_uniqueId : das_string const?)
  let weaponEid = human_weap__gunEids[evt.slotId]
  var weaponModEid = INVALID_ENTITY_ID
  query(weaponEid) <| $ [es] (gun_mods__curModInSlots : Object)
    weaponModEid = get_Eid(gun_mods__curModInSlots[evt.slotName]) ?? INVALID_ENTITY_ID

  if weaponModEid == INVALID_ENTITY_ID
    return
  if weaponEid == INVALID_ENTITY_ID
    return
  if is_item_inventory_move_blocked(weaponModEid)
    return
  if evt.slotName == "magazine"
    if isInVehicle && !is_human_aiming(eid, weaponEid, human_net_phys)
      return
    if is_jamming_fix_in_progress(weaponEid)
      return
  if !is_can_move_item_in_inventory(weaponModEid, evt.toInventoryEid)
    return
  if is_inventory_in_use(evt.toInventoryEid)
    return
  if !is_actor_can_move_item(eid, weaponEid)
    return

  start_unequip_weapon_mod_from_slot(evt.slotName, weaponEid, eid, evt.toInventoryEid)
  if !is_true_net_server() && hero != null && human_uniqueId != null
    query(evt.toInventoryEid) <| $ [es] (uniqueId : string; profile_server__slotName : string)
      report_item_move_transaction(weaponModEid, uniqueId, profile_server__slotName)

[es(tag=server, REQUIRE=human_inventory, REQUIRE_NOT=deadEntity)]
def on_equip_weapon_mod_from_inventory_server(evt : CmdEquipWeaponModFromInventory;
                                              eid : EntityId;
                                              isInVehicle : bool;
                                              human_net_phys : HumanActor;
                                              hero : Tag const?;
                                              uniqueId aka human_uniqueId : das_string const?)
  if evt.itemEid == INVALID_ENTITY_ID
    return
  if evt.weaponEid == INVALID_ENTITY_ID
    return
  if is_item_inventory_move_blocked(evt.itemEid)
    return
  if evt.slotName == "magazine"
    if isInVehicle && !is_human_aiming(eid, evt.weaponEid, human_net_phys)
      return
    if is_jamming_fix_in_progress(evt.weaponEid)
      return

  var isReloading = false
  var oldWeaponModEid = INVALID_ENTITY_ID
  query(evt.weaponEid) <| $ [es] (gun_mods__curModInSlots : Object;
                                  gun__isReloading : bool)
    oldWeaponModEid = get_Eid(gun_mods__curModInSlots[evt.slotName]) ?? INVALID_ENTITY_ID
    isReloading = gun__isReloading

  if oldWeaponModEid == evt.itemEid
    return

  if isReloading
    return

  if !is_on_equip_weapon_mod_prev_can_fit(evt.itemEid, oldWeaponModEid, evt.fromInventoryEid)
    return

  if !is_actor_can_move_item(eid, evt.itemEid)
    return

  start_equip_weapon_mod_to_slot(evt.itemEid, evt.slotName, evt.weaponEid, eid, evt.fromInventoryEid)
  if !is_true_net_server() && hero != null && human_uniqueId != null
    query(evt.weaponEid) <| $ [es] (uniqueId : string)
      report_item_move_transaction(evt.itemEid, uniqueId, evt.slotName)


[es(tag=server, REQUIRE=human_inventory, REQUIRE_NOT=deadEntity)]
def on_unload_ammo_from_gun_to_inventory_server(evt : CmdUnloadAmmoFromGunToInventory; eid : EntityId; human_weap__gunEids : EidList)
  let weaponEid = human_weap__gunEids[evt.slotId]
  if weaponEid == INVALID_ENTITY_ID
    return

  var validWeapon = false
  query(weaponEid) <| $ [es] (gun__ammo : int;
                              gun_boxed_ammo_reload__reloadState : int const?;
                              gun__boxedAmmoHolderTemplate : string)
    validWeapon = gun__boxedAmmoHolderTemplate != "" && (gun_boxed_ammo_reload__reloadState != null ? gun__ammo > 0 : gun__ammo == 1)
  if !validWeapon
    return

  start_unload_boxed_ammo_from_gun(weaponEid, eid, evt.toInventoryEid)


[es(tag=server, REQUIRE=human_inventory, REQUIRE_NOT=deadEntity)]
def on_load_ammo_from_inventory_to_gun_server(evt : CmdLoadAmmoFromInventoryToGun;
                                              eid : EntityId;
                                              isInVehicle : bool;
                                              human_net_phys : HumanActor)
  if evt.ammoEid == INVALID_ENTITY_ID
    return
  if evt.gunEid == INVALID_ENTITY_ID
    return
  if is_item_use_blocked(evt.ammoEid) || is_item_inventory_move_blocked(evt.ammoEid)
    return
  if isInVehicle && !is_human_aiming(eid, evt.gunEid, human_net_phys)
    return
  if !is_ammo_for_gun(evt.ammoEid, evt.gunEid)
    return
  if !is_actor_can_move_item(eid, evt.ammoEid) || !is_actor_can_move_item(eid, evt.gunEid)
    return

  var validWeapon = false
  query(evt.gunEid) <| $ [es] (gun__ammo, gun__maxAmmo : int;
                               gun__boxedAmmoHolderTemplate : string)
    validWeapon = gun__boxedAmmoHolderTemplate != "" && gun__ammo < gun__maxAmmo
  if !validWeapon
    return

  start_load_boxed_ammo_to_gun(evt.ammoEid, evt.gunEid, eid)


[es(tag=server, REQUIRE=human_inventory, REQUIRE_NOT=deadEntity)]
def on_equip_equipment_mod_from_inventory_server(evt : CmdEquipEquipmentModFromInventory;
                                                 eid : EntityId;
                                                 hero : Tag const?;
                                                 uniqueId : das_string const?)
  if evt.itemEid == INVALID_ENTITY_ID
    return
  if evt.equipmentEid == INVALID_ENTITY_ID
    return
  if is_item_inventory_move_blocked(evt.itemEid)
    return

  if !is_on_equip_equipment_mod_prev_can_fit(evt.itemEid, evt.slotName, evt.equipmentEid, evt.fromInventoryEid)
    return
  if !is_actor_can_move_item(eid, evt.itemEid)
    return

  equip_equipment_mod_to_slot(evt.itemEid, evt.slotName, evt.equipmentEid, eid, evt.fromInventoryEid)
  if !is_true_net_server() && hero != null && uniqueId != null
    query(evt.equipmentEid) <| $ [es] (uniqueId : string)
      if evt.slotName |> starts_with(pocket_slots_prefix)
        report_item_move_to_pocket_transaction(evt.itemEid, uniqueId, evt.slotName)
      else
        report_item_move_transaction(evt.itemEid, uniqueId, evt.slotName)

[es(tag=server, REQUIRE_NOT=deadEntity)]
def on_split_equip_mod_from_inventory_to_slot_server(evt : CmdSplitItemToEquipmentModSlot;
                                                     eid : EntityId;
                                                     hero : Tag const?;
                                                     uniqueId aka human_uniqueId : das_string const?)
  if evt.itemEid == INVALID_ENTITY_ID
    return
  if evt.equipmentEid == INVALID_ENTITY_ID
    return
  if is_item_inventory_move_blocked(evt.itemEid)
    return

  if !is_on_equip_equipment_mod_prev_can_fit(evt.itemEid, evt.slotName, evt.equipmentEid, evt.fromInventoryEid)
    return
  if !is_actor_can_move_item(eid, evt.itemEid)
    return

  var moveStack = false
  var hasStackInfo = false
  query(evt.itemEid) <| $ [es] (item__currentBoxedItemCount : int)
    hasStackInfo = true
    if item__currentBoxedItemCount == 1
      moveStack = true
      return

  if !hasStackInfo
    return

  var sameModType = false
  query(evt.equipmentEid) <| $ [es] (equipment_mods__curModInSlots : Object)
    let oldEquipmentModEid = get_Eid(equipment_mods__curModInSlots[evt.slotName]) ?? INVALID_ENTITY_ID
    query(oldEquipmentModEid) <| $[es] (boxed_item__template aka old_boxed_item__template : string)
      query(evt.itemEid) <| $[es] (boxed_item__template aka new_boxed_item__template : string)
        sameModType = old_boxed_item__template == new_boxed_item__template

  if sameModType
    // actually don't need to split, cause the state will be the same but currently causes bugs
    return

  if moveStack
    equip_equipment_mod_to_slot(evt.itemEid, evt.slotName, evt.equipmentEid, eid, evt.fromInventoryEid)
  else
    split_item_to_equipment(evt.itemEid, evt.slotName, evt.equipmentEid, eid, 1, evt.fromInventoryEid)

  query(evt.itemEid) <| $ [es] (var boxed_item__actionsBlock : bool&)
    boxed_item__actionsBlock = true

  if !is_true_net_server() && hero != null && human_uniqueId != null
    query(evt.equipmentEid) <| $ [es] (uniqueId : string)
      report_item_move_to_pocket_transaction(evt.itemEid, uniqueId, evt.slotName, !moveStack)


[es(tag=server, REQUIRE=human_inventory, REQUIRE_NOT=deadEntity)]
def on_move_equipment_mod_to_inventory_server(evt : CmdMoveEquipmentModToInventory;
                                              eid : EntityId;
                                              hero : Tag const?;
                                              uniqueId aka human_uniqueId : das_string const?)
  var equipmentModEid = INVALID_ENTITY_ID
  query(evt.equipmentEid) <| $ [es] (equipment_mods__curModInSlots : Object)
    equipmentModEid = get_Eid(equipment_mods__curModInSlots[evt.slotName]) ?? INVALID_ENTITY_ID

  if equipmentModEid == INVALID_ENTITY_ID
    return
  if evt.equipmentEid == INVALID_ENTITY_ID
    return
  if is_item_inventory_move_blocked(equipmentModEid)
    return
  if !is_can_move_item_in_inventory(equipmentModEid, evt.toInventoryEid)
    return
  if is_inventory_in_use(evt.toInventoryEid)
    return
  if !is_actor_can_move_item(eid, equipmentModEid)
    return

  unequip_equipment_mod_from_slot(evt.slotName, evt.equipmentEid, eid, evt.toInventoryEid)
  if !is_true_net_server() && hero != null && human_uniqueId != null
    query(evt.toInventoryEid) <| $ [es] (uniqueId : string; profile_server__slotName : string)
      report_item_move_transaction(equipmentModEid, uniqueId, profile_server__slotName)


[es(on_appear)]
def drop_item_cb(evt : Event;
                 eid : EntityId;
                 drop_item_cb__lootCleanupTime : float)
  if drop_item_cb__lootCleanupTime >= 0.f
    eid |> sendEvent(CmdBodyCleanup(time = drop_item_cb__lootCleanupTime))
  removeSubTemplate(eid, "drop_item_cb")


[es(tag=server, REQUIRE=human_inventory, REQUIRE_NOT=deadEntity)]
def human_inventory_on_drop_request(evt : CmdDropItemFromInventory; eid : EntityId)
  if !is_can_move_item_to_ground(evt.itemEid)
    return

  var itemHeroOwner = INVALID_ENTITY_ID
  query(evt.itemEid) <| $ [es] (item__humanOwnerEid : EntityId)
    itemHeroOwner = item__humanOwnerEid
  if is_item_inventory_move_blocked(evt.itemEid)
    return
  if itemHeroOwner != INVALID_ENTITY_ID && itemHeroOwner != eid
    // INVALID_ENTITY_ID itemHeroOwner means that item stored in standalone container
    return

  drop_item_from_inventory_container(evt.itemEid, eid)
