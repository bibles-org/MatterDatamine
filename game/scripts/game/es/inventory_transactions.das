require ecs
require ecs.safe
require DngNet
require DagorSystem
require game.events.inventory_events
require game.es.inventory_transactions_common
require game.es.ecs_common
require game.es.inventory_slots_common
require strings


def add_children_for_loadout(parentsIds : array<string>;
                             player_profile__allItems : Array;
                             var player_profile__loadout : Array)
  if length(parentsIds) <= 0
    return

  var childrenIds : array<string>
  for item in player_profile__allItems
    var itemObj = get_ecs_object(item)
    if itemObj == null
      continue

    let itemId = (*itemObj)["itemId"] ?? "-1"
    if itemId == "-1"
      continue
    let itemIndex = find_index(parentsIds, itemId)
    if itemIndex != -1
      continue // Item already in list

    let parentItemId = (*itemObj)["parentItemId"] ?? "-1"
    if parentItemId == "-1"
      continue
    let parentIndex = find_index(parentsIds, parentItemId)
    if parentIndex != -1
      childrenIds |> push(itemId)
      player_profile__loadout |> push(item)
  add_children_for_loadout(childrenIds, player_profile__allItems, player_profile__loadout)


[es(tag=gameClient, track=player_profile__allItems, on_appear)]
def update_loadout_by_all_items(evt : Event;
                                player_profile__allItems : Array;
                                var player_profile__loadout : Array)
  print("[ALL ITEMS] Update loadout by allItems")
  var loadoutItemsIds : array<string>
  clear(player_profile__loadout)
  for item in player_profile__allItems
    var itemObj = get_ecs_object(item)
    if itemObj == null
      continue
    let itemId = (*itemObj)["itemId"] ?? "-1"
    if itemId == "-1"
      continue
    let slotName = (*itemObj)["slotName"] ?? ""
    let parentItemId = (*itemObj)["parentItemId"] ?? "0"
    if parentItemId == "0" && slotName != "stash" && slotName != "reserve"
      loadoutItemsIds |> push(itemId)
      player_profile__loadout |> push(item)
  add_children_for_loadout(loadoutItemsIds, player_profile__allItems, player_profile__loadout)


[es(tag=gameClient, REQUIRE=(hero, uniqueId))]
def report_gun_ammo_load(evt : NotifyGunBoxedAmmoLoadingEnd)
  report_item_ammo_loading_transaction(evt.boxedId, evt.gunEid, evt.count)


[es(tag=gameClient, REQUIRE=(hero, uniqueId))]
def report_gun_ammo_unload(evt : NotifyGunBoxedAmmoUnoadingEnd)
  query(evt.inventoryEid) <| $ [es] (uniqueId : string;
                                     profile_server__slotName : string)
    report_item_ammo_unloading_transaction(evt.gunEid, uniqueId, profile_server__slotName, evt.count)


[es(tag=gameClient, REQUIRE=(hero, uniqueId))]
def report_magazine_ammo_load(evt : NotifyItemHolderLoadingEnd)
  if evt.count > 0
    query(evt.inventoryEid) <| $ [es] (uniqueId : string;
                                       profile_server__slotName : string)
      report_item_ammo_unloading_transaction(evt.holderEid, uniqueId, profile_server__slotName, evt.count)
  elif evt.count < 0
    report_item_ammo_loading_transaction(evt.boxedId, evt.holderEid, -evt.count)


[es(tag=gameClient, REQUIRE=watchedPlayerItem, track=item__containerOwnerEid)]
def all_items_update_parent_and_slot_for_item_in_inventory(evt : Event;
                                                           eid : EntityId;
                                                           item__humanOwnerEid : EntityId;
                                                           item__containerOwnerEid : EntityId;
                                                           uniqueId aka item_uniqueId : string)
  if !has(item__humanOwnerEid, "uniqueId") || item__containerOwnerEid == INVALID_ENTITY_ID || uniqueId == "-1"
    return

  query(item__containerOwnerEid) <| $ [es] (uniqueId : string;
                                            profile_server__slotName : string)
    update_all_items_on_item_move_transaction(item_uniqueId, eid, uniqueId, profile_server__slotName)


[es(tag=gameClient, REQUIRE=watchedPlayerItem, track=slot_attach__weaponSlotIdx)]
def all_items_update_parent_and_slot_for_item_in_weapon_slot(evt : Event;
                                                             eid : EntityId;
                                                             item__humanOwnerEid : EntityId;
                                                             slot_attach__weaponSlotIdx : int;
                                                             uniqueId aka item_uniqueId : string)
  if slot_attach__weaponSlotIdx < 0 || uniqueId == "-1"
    return

  query(item__humanOwnerEid) <| $ [es] (uniqueId : string)
    let slot = slot_attach__weaponSlotIdx < 0 ? "" : "weapon_{slot_attach__weaponSlotIdx}"
    update_all_items_on_item_move_transaction(item_uniqueId, eid, uniqueId, slot)


[es(tag=gameClient, REQUIRE=watchedPlayerItem, track=gun_mods__curModInSlots)]
def all_items_update_parent_and_slot_for_item_in_weapon_mods(evt : Event;
                                                             item__humanOwnerEid : EntityId;
                                                             gun_mods__curModInSlots : Object;
                                                             uniqueId aka weapon_uniqueId : string)
  if !has(item__humanOwnerEid, "uniqueId") || weapon_uniqueId == "-1"
    return

  for gunMod in gun_mods__curModInSlots
    let gunModEid = get_Eid(gunMod.value) ?? INVALID_ENTITY_ID
    query(gunModEid) <| $ [es] (uniqueId : string)
      if uniqueId == "-1"
        return
      update_all_items_on_item_move_transaction(uniqueId, gunModEid, weapon_uniqueId, gunMod.key)


[es(tag=gameClient, REQUIRE=watchedPlayerItem, track=(slot_attach__attachedTo, equipmentAttachable__slotName))]
def all_items_update_parent_and_slot_for_item_in_equipment_mods(evt : Event;
                                                                eid : EntityId;
                                                                item__humanOwnerEid : EntityId;
                                                                slot_attach__attachedTo : EntityId;
                                                                uniqueId aka item_uniqueId : string;
                                                                equipmentAttachable__slotName : string)
  if !has(item__humanOwnerEid, "uniqueId") || slot_attach__attachedTo == INVALID_ENTITY_ID || uniqueId == "-1"
    return

  query(slot_attach__attachedTo) <| $ [es] (uniqueId : string)
    update_all_items_on_item_move_transaction(item_uniqueId, eid, uniqueId, equipmentAttachable__slotName)


[es(tag=gameClient, REQUIRE=watchedPlayerItem, track=(slot_attach__attachedTo, equipable_item__curSlot))]
def all_items_update_parent_and_slot_for_item_in_equipment_slot(evt : Event;
                                                                eid : EntityId;
                                                                item__humanOwnerEid : EntityId;
                                                                slot_attach__attachedTo : EntityId;
                                                                uniqueId aka item_uniqueId : string;
                                                                equipable_item__curSlot : string)
  if !has(item__humanOwnerEid, "uniqueId") || slot_attach__attachedTo == INVALID_ENTITY_ID || uniqueId == "-1"
    return

  query(slot_attach__attachedTo) <| $ [es] (uniqueId : string)
    let slot = empty(equipable_item__curSlot) ? "" : "equipment_{equipable_item__curSlot}"
    update_all_items_on_item_move_transaction(item_uniqueId, eid, uniqueId, slot)


[es(tag=gameClient, REQUIRE=watchedPlayerItem, track=item__currentBoxedItemCount)]
def all_items_update_charges_for_item_in_inventory_boxed_item(evt : Event;
                                                              eid : EntityId;
                                                              item__humanOwnerEid : EntityId;
                                                              uniqueId : string;
                                                              item__currentBoxedItemCount : int;
                                                              slot_attach__attachedTo : EntityId const?;
                                                              gunAttachable__slotName : das_string const?)
  let isMagazineInWeapon = gunAttachable__slotName != null && slot_attach__attachedTo != null && *slot_attach__attachedTo != INVALID_ENTITY_ID
  if !has(item__humanOwnerEid, "uniqueId") || item__currentBoxedItemCount < 0 || uniqueId == "-1" || isMagazineInWeapon
    return

  update_all_items_on_item_move_transaction(uniqueId, eid, "", "", item__currentBoxedItemCount)


[es(tag=gameClient, REQUIRE=watchedPlayerItem, track=item__hp)]
def all_items_update_charges_for_item_in_inventory_armor(evt : Event;
                                                         eid : EntityId;
                                                         item__humanOwnerEid : EntityId;
                                                         uniqueId : string;
                                                         item__hp : float)
  if !has(item__humanOwnerEid, "uniqueId") || uniqueId == "-1"
    return

  update_all_items_on_item_move_transaction(uniqueId, eid, "", "", ceili(item__hp))


[es(tag=gameClient, REQUIRE=watchedPlayerItem, track=(gun__ammo, gun__isAmmoLoaded))]
def all_items_update_charges_for_ammo_in_weapon(evt : Event;
                                                eid : EntityId;
                                                item__humanOwnerEid : EntityId;
                                                uniqueId aka gun_uniqueId : string;
                                                gun__ammo : int;
                                                gun__isAmmoLoaded : bool;
                                                gun_mods__curModInSlots : Object const?)
  if !has(item__humanOwnerEid, "uniqueId") || uniqueId == "-1"
    return

  if gun_mods__curModInSlots != null && has(*gun_mods__curModInSlots, "magazine")
    let magazineEid = get_Eid((*gun_mods__curModInSlots)["magazine"]) ?? INVALID_ENTITY_ID
    let ammoInChamber = gun__isAmmoLoaded ? 1 : 0
    let ammoInMagazine = gun__ammo - ammoInChamber
    query(magazineEid) <| $ [es] (uniqueId aka magazine_uniqueId : string)
      update_all_items_on_item_move_transaction(magazine_uniqueId, magazineEid, "", "", ammoInMagazine)
    update_all_items_on_item_move_transaction(gun_uniqueId, eid, "", "", ammoInChamber)
    return

  update_all_items_on_item_move_transaction(gun_uniqueId, eid, "", "", gun__ammo)


[es(tag=gameClient, REQUIRE=watchedPlayerItem, on_disappear)]
def all_items_update_on_item_destroy(evt : Event;
                                     eid : EntityId;
                                     item__humanOwnerEid : EntityId;
                                     uniqueId : string)
  if !has(item__humanOwnerEid, "uniqueId") || uniqueId == "-1"
    return

  try_update_all_items_on_item_remove_transaction(uniqueId, eid)
