module inventory_common shared
require ecs
require strings
require DngNet
require ecs.safe
require ecs.common
require DagorSystem
require game.es.inventory_checks_common
require game.es.inventory_slots_common
require game.events.inventory_events
require game.es.ecs_common
require game.es.status_tip_common
require game.es.entity_mods_common


enum CanUseItemResponse
  Approved
  Declined
  BlockedByHuman
  BlockedByItem
  NoUseTime
  NotOwner
  ItemNotExists
  OtherItemInUse
  Move
  Sprint
  Crawl
  Crouch
  StanceChange
  Climb
  Dodge
  Swim
  InAir
  Landing
  Zoom
  Shoot
  Melee
  Throw
  Reload
  WeaponSwitch
  AimInVehicle
  NotInVehicle
  Driver
  Downed
  NotAlive
  TooMuchDelay
  ForbiddenOnPlayerBase
  End


def debug_use_item_decline_reason(item : EntityId; reasonString : string; prefix : string; declined_from_server : bool = false)
  print("[{prefix} ({declined_from_server ? "SERVER" : "CLIENT"})] Decline of using item({get_entity_info(item)}) reason: {reasonString}")


def create_tip_for_use_item_decline_reason(item : EntityId; reason : int; prefix : string; declined_from_server : bool = false)
  debug_use_item_decline_reason(item, "{reason}", prefix, declined_from_server)
  if declined_from_server
    return
  if reason == int(CanUseItemResponse.Crawl)
    create_status_tip("status_tip_use_item_failed_on_crawl")
  elif reason == int(CanUseItemResponse.InAir)
    create_status_tip("status_tip_use_item_failed_in_air")
  elif reason == int(CanUseItemResponse.Downed)
    create_status_tip("status_tip_use_item_failed_in_downed")
  elif reason == int(CanUseItemResponse.NotInVehicle)
    create_status_tip("status_tip_use_item_failed_not_in_vehicle")
  elif reason == int(CanUseItemResponse.ForbiddenOnPlayerBase)
    create_status_tip("status_tip_use_item_forbidden_on_player_base")


def inventory_item_prepare_using(human_eid : EntityId;
                                 item : EntityId;
                                 target : EntityId;
                                 start_time : float;
                                 duration : float = -1.0;
                                 progress_bar_duration : float = -1.0;
                                 no_interrupt_start_time : float = -1.0;
                                 manual_use : bool = false)
  query(human_eid) <| $ [es] (var human_inventory__entityToUse : EntityId&;
                              var human_inventory__targetToUse : EntityId&;
                              var human_inventory__entityUseStart : float&;
                              var human_inventory__entityUseEnd : float&;
                              var human_inventory__progressBarEnd : float&;
                              var human_inventory__noInterruptPoint : float&;
                              var human_inventory__entityManualUse : bool&)
    human_inventory__entityToUse = item
    human_inventory__targetToUse = target
    human_inventory__entityUseStart = start_time

    if duration > 0.0
      human_inventory__entityUseEnd = start_time + duration
    else
      human_inventory__entityUseEnd = -1.0

    if progress_bar_duration > 0.0
      human_inventory__progressBarEnd = start_time + progress_bar_duration
    else
      human_inventory__progressBarEnd = human_inventory__entityUseEnd

    if no_interrupt_start_time >= 0.0
      human_inventory__noInterruptPoint = start_time + no_interrupt_start_time
    else
      human_inventory__noInterruptPoint = -1.0

    human_inventory__entityManualUse = manual_use


def inventory_item_reset_using(human_eid : EntityId)
  query(human_eid) <| $ [es] (var human_inventory__entityToUse : EntityId&;
                              var human_inventory__targetToUse : EntityId&;
                              var human_inventory__entityUseStart : float&;
                              var human_inventory__entityUseEnd : float&;
                              var human_inventory__progressBarEnd : float&;
                              var human_inventory__noInterruptPoint : float&;
                              var human_inventory__entityManualUse : bool&)
    inventory_item_reset_using(human_inventory__entityToUse, human_inventory__targetToUse, human_inventory__entityUseStart, human_inventory__entityUseEnd,
                               human_inventory__progressBarEnd, human_inventory__noInterruptPoint, human_inventory__entityManualUse)


def inventory_item_reset_using(var human_inventory__entityToUse : EntityId&;
                               var human_inventory__targetToUse : EntityId&;
                               var human_inventory__entityUseStart : float&;
                               var human_inventory__entityUseEnd : float&;
                               var human_inventory__progressBarEnd : float&;
                               var human_inventory__noInterruptPoint : float&;
                               var human_inventory__entityManualUse : bool&)
  human_inventory__entityToUse = INVALID_ENTITY_ID
  human_inventory__targetToUse = INVALID_ENTITY_ID
  human_inventory__entityUseStart = -1.0
  human_inventory__entityUseEnd = -1.0
  human_inventory__progressBarEnd = -1.0
  human_inventory__noInterruptPoint = -1.0
  human_inventory__entityManualUse = false


def get_item_use_time(var use_time : float;
                      downed_time_multiplier : float;
                      is_downed : bool;
                      is_usage_speed_mod_affected : bool;
                      entity_mod_values : Object)
  if is_downed
    use_time *= downed_time_multiplier
  return get_item_use_time(use_time, is_usage_speed_mod_affected, entity_mod_values)


def get_item_use_time(var use_time : float;
                      is_usage_speed_mod_affected : bool;
                      entity_mod_values : Object)
  if is_usage_speed_mod_affected
    use_time /= get_mod_value("itemUsageSpeed", entity_mod_values, 1.0)
  return max(0.001f, use_time)


struct ItemPickupScore
  itemDot : float
  score : float
  useful : bool


def choose_best_equipment_slot_for_item(eid : EntityId;
                                        item_eid : EntityId;
                                        equip_slots : StringList)
  var bestSlot = ""

  query(eid) <| $ [es] (human_equipment__slots : Object)
    query(item_eid) <| $ [es] (item__equipmentSlots : StringList;
                               item__isPickable : Tag const?)
      if length(human_equipment__slots) == 0
        return

      if item__isPickable == null
        return
      // find unequipped slot or default to first slot
      for name in equip_slots
        let slotItemEid = human_equipment__slots[string(name)] ?? INVALID_ENTITY_ID
        if slotItemEid != INVALID_ENTITY_ID
          continue

        for slotName in item__equipmentSlots
          if slotName == name
            bestSlot = string(name)
            break
        break
  return bestSlot


def is_equip_to_slot_cause_inventory_overflow(hero_eid : EntityId;
                                              item_eid : EntityId;
                                              to_slot : string;
                                              drop_prev_to_cont : EntityId = INVALID_ENTITY_ID)
  var res = false
  if empty(to_slot)
    return res
  query(hero_eid) <| $ [es] (human_equipment__slots : Object;
                             human_inventory__maxVolumeInt : int;
                             human_inventory__currentVolume : int)
    var newVolume = human_inventory__currentVolume
    var newMaxVolume = human_inventory__maxVolumeInt

    query(item_eid) <| $ [es] (item__containerOwnerEid : EntityId;
                               item__volume aka del_item__volume : float = 0.f;
                               item__inventoryExtension aka new_item__inventoryExtension : float = 0.f)
      if item__containerOwnerEid == hero_eid
        newVolume -= convert_volume_to_int(del_item__volume)
      newMaxVolume += convert_volume_to_int(new_item__inventoryExtension)

    let equippedItemEid = human_equipment__slots[to_slot] ?? INVALID_ENTITY_ID
    query(equippedItemEid) <| $ [es] (item__volume aka add_item__volume : float = 0.f;
                                      item__inventoryExtension aka prev_item__inventoryExtension : float = 0.f)
      if drop_prev_to_cont == hero_eid
        newVolume += convert_volume_to_int(add_item__volume)
      newMaxVolume -= convert_volume_to_int(prev_item__inventoryExtension)

    let extraVolume = newVolume - newMaxVolume
    if newMaxVolume < human_inventory__maxVolumeInt && extraVolume > 0
      res = true
  return res


def is_equip_to_slot_cause_from_pocket_drop(hero_eid : EntityId;
                                            item_eid : EntityId;
                                            to_slot : string;
                                            drop_prev_to_cont : EntityId = INVALID_ENTITY_ID)
  var res = false
  if empty(to_slot)
    return res

  query(hero_eid) <| $ [es] (human_equipment__slots : Object;
                             militant_extra_inventories__backpackEid : EntityId;
                             human_inventory__maxVolumeInt : int;
                             human_inventory__currentVolume : int)
    var newVolume = human_inventory__currentVolume
    var newMaxVolume = human_inventory__maxVolumeInt

    query(item_eid) <| $ [es] (item__containerOwnerEid : EntityId;
                               item__volume aka del_item__volume : float = 0.f;
                               item__inventoryExtension aka new_item__inventoryExtension : float = 0.f)
      if item__containerOwnerEid == hero_eid
        newVolume -= convert_volume_to_int(del_item__volume)
      newMaxVolume += convert_volume_to_int(new_item__inventoryExtension)

    let equippedItemEid = human_equipment__slots[to_slot] ?? INVALID_ENTITY_ID
    query(equippedItemEid) <| $ [es] (equipment_mods__curModInSlots : Object;
                                      item__volume aka add_item__volume : float = 0.f;
                                      item__inventoryExtension aka prev_item__inventoryExtension : float = 0.f)
      if drop_prev_to_cont == hero_eid
        newVolume += convert_volume_to_int(add_item__volume)
      newMaxVolume -= convert_volume_to_int(prev_item__inventoryExtension)

      var inventoryVolumeExtensions : table<EntityId; int>
      for mod in equipment_mods__curModInSlots
        if mod.key |> starts_with(pocket_slots_prefix)
          let modEid = mod.value ?? INVALID_ENTITY_ID
          query(modEid) <| $ [es] (item__volume aka mod_item__volume : float = 0.f)
            let modVolume = convert_volume_to_int(mod_item__volume)
            let heroExtension = inventoryVolumeExtensions?[hero_eid] ?? 0
            let backpackExtension = inventoryVolumeExtensions?[militant_extra_inventories__backpackEid] ?? 0
            if newVolume + modVolume + heroExtension <= newMaxVolume
              inventoryVolumeExtensions.insert(hero_eid, modVolume + heroExtension)
            elif is_inventory_have_free_volume(militant_extra_inventories__backpackEid, modVolume + backpackExtension)
              inventoryVolumeExtensions.insert(militant_extra_inventories__backpackEid, modVolume + backpackExtension)
            else
              res = true
        if res
          break
  return res


def is_autoequip_cause_inventory_overflow(eid, item_eid : EntityId)
  var res = false
  query(item_eid) <| $ [es] (item__equipmentSlots : StringList)
    if length(item__equipmentSlots) != 0
      let bestSlot = choose_best_equipment_slot_for_item(eid, item_eid, item__equipmentSlots)
      res = is_equip_to_slot_cause_inventory_overflow(eid, item_eid, bestSlot)
  return res


def find_item_with_comp(item_container : EidList;
                        comp : string;
                        comp_hash : uint;
                        var out_index : int&)
  for idx, itemEid in iter_range(item_container), item_container
    if has(itemEid, comp, comp_hash)
      out_index = idx
      return itemEid
  return INVALID_ENTITY_ID


def find_item_with_comp(human_eid : EntityId;
                        comp : string;
                        comp_hash : uint)
  var res = INVALID_ENTITY_ID
  query(human_eid) <| $ [es] (inventories_owner__inventoryEids : EidList)
    for inventoryEid in inventories_owner__inventoryEids
      if res != INVALID_ENTITY_ID
        return
      query(inventoryEid) <| $ [es] (itemContainer : EidList)
        var itemIndex = -1
        res = find_item_with_comp(itemContainer, comp, comp_hash, itemIndex)
  return res


def find_item_with_comp(human_eid : EntityId;
                        comp : string)
  return find_item_with_comp(human_eid, comp, ecs_hash(comp))


def has_item_with_comp(human_eid : EntityId;
                       comp : string;
                       comp_hash : uint)
  return find_item_with_comp(human_eid, comp, comp_hash) != INVALID_ENTITY_ID


def has_item_with_comp(human_eid : EntityId;
                       comp : string)
  return find_item_with_comp(human_eid, comp) != INVALID_ENTITY_ID


def has_item_with_template(human_eid : EntityId;
                           template_name : string)
  var res = false
  query(human_eid) <| $ [es] (itemContainer : EidList)
    for itemEid in itemContainer
      query(itemEid) <| $ [es] (item__proto : string)
        res = item__proto == template_name
      if res
        return
  return res


def destroy_item_with_comp(human_eid : EntityId;
                           comp : string;
                           comp_hash : uint)
  var res = false
  query(human_eid) <| $ [es] (itemContainer : EidList)
    var itemIndex = -1
    let itemEid = find_item_with_comp(itemContainer, comp, comp_hash, itemIndex)
    if itemEid != INVALID_ENTITY_ID
      destroyEntity(itemEid)
      res = true
  return res


def destroy_item_with_comp(human_eid : EntityId;
                           comp : string)
  return destroy_item_with_comp(human_eid, comp, ecs_hash(comp))


def get_item_key(item__useMessage : das_string const?;
                 item__useTime : float const?;
                 item__name : das_string const?;
                 item__unusableName : das_string const?)
  let useMsg = item__useMessage ?? ""
  let isUsable = item__useTime ?? 0.0 > 0.0 || useMsg != ""

  return isUsable ? (item__name ?? "") : item__unusableName ?? item__name ?? "unknown"


def build_item_key(eid : EntityId)
  var itemKey : string
  query(eid) <| $ [es] (item__useMessage : das_string const?;
                        item__useTime : float const?;
                        item__name : das_string const?;
                        item__unusableName : das_string const?)
    itemKey = get_item_key(item__useMessage, item__useTime, item__name, item__unusableName)

  return itemKey


def is_item_mods_same(mod_in_slots_a : Object const?;
                      mod_in_slots_b : Object const?)
  if mod_in_slots_a == null && mod_in_slots_b == null
    return true

  if mod_in_slots_a == null || mod_in_slots_b == null || length(*mod_in_slots_a) != length(*mod_in_slots_b)
    return false

  for slotA in *mod_in_slots_a
    let modKeyA = slotA.key
    let modEidA = slotA.value ?? INVALID_ENTITY_ID
    let modEidB = (*mod_in_slots_b)[modKeyA] ?? INVALID_ENTITY_ID
    if get_ecs_string(modEidA, "item__name") ?? "" != get_ecs_string(modEidB, "item__name") ?? ""
      return false

  return true


def is_item_mods_same(item_a : EntityId;
                      item_b : EntityId)
  var result = false
  query(item_a) <| $ [es] (gun_mods__curModInSlots aka a_gun_mods__curModInSlots : Object const?;
                           equipment_mods__curModInSlots aka a_equipment_mods__curModInSlots : Object const?)
    query(item_b) <| $ [es] (gun_mods__curModInSlots aka b_gun_mods__curModInSlots : Object const?;
                             equipment_mods__curModInSlots aka b_equipment_mods__curModInSlots : Object const?)
      result = (is_item_mods_same(a_gun_mods__curModInSlots, b_gun_mods__curModInSlots) &&
                is_item_mods_same(a_equipment_mods__curModInSlots, b_equipment_mods__curModInSlots))
  return result


// isItemIdentical function from nut
def is_items_identical(item_a : EntityId;
                       item_b : EntityId)
  var result = false
  query(item_a) <| $ [es] (item__useMessage aka a_item__useMessage : das_string const?;
                           item__useTime aka a_item__useTime : float const?;
                           item__name aka a_item__name : das_string const?;
                           item__unusableName aka a_item__unusableName : das_string const?;
                           item__count aka a_item__count : int const?;
                           item__amount aka a_item__amount : int const?;
                           am_storage__value aka a_am_storage__value : int const?;
                           item__currentBoxedItemCount aka a_item__currentBoxedItemCount : int const?;
                           gun__ammo aka a_gun__ammo : int const?;
                           item_enriched aka a_item_enriched : Tag const?;
                           item__doesntStack aka a_item__doesntStack : Tag const?;
                           itemContainer aka a_itemContainer : EidList const?)
    let itemKeyA = get_item_key(a_item__useMessage, a_item__useTime, a_item__name, a_item__unusableName)
    let itemContainerLenA = a_itemContainer != null ? length(*a_itemContainer) : 0
    query(item_b) <| $ [es] (item__useMessage aka b_item__useMessage : das_string const?;
                             item__useTime aka b_item__useTime : float const?;
                             item__name aka b_item__name : das_string const?;
                             item__unusableName aka b_item__unusableName : das_string const?;
                             item__count aka b_item__count : int const?;
                             item__amount aka b_item__amount : int const?;
                             am_storage__value aka b_am_storage__value : int const?;
                             item__currentBoxedItemCount aka b_item__currentBoxedItemCount : int const?;
                             gun__ammo aka b_gun__ammo : int const?;
                             item_enriched aka b_item_enriched : Tag const?;
                             item__doesntStack aka b_item__doesntStack : Tag const?;
                             itemContainer aka b_itemContainer : EidList const?)
      let itemKeyB = get_item_key(b_item__useMessage, b_item__useTime, b_item__name, b_item__unusableName)
      let itemContainerLenB = b_itemContainer != null ? length(*b_itemContainer) : 0
      result = (itemKeyA == itemKeyB &&
                a_item__count ?? 0 == b_item__count ?? 0 &&
                a_item__amount ?? 0 == b_item__amount ?? 0 &&
                a_am_storage__value ?? 0 == b_am_storage__value ?? 0 &&
                a_item__currentBoxedItemCount ?? 0 == b_item__currentBoxedItemCount ?? 0 &&
                a_gun__ammo ?? 0 == b_gun__ammo ?? 0 &&
                (a_item_enriched != null) == (b_item_enriched != null) &&
                is_item_mods_same(item_a, item_b) &&
                (itemContainerLenA == 0 && itemContainerLenB == 0) &&
                (a_item__doesntStack != null) == (b_item__doesntStack != null))
  return result


def get_item_in_container_template(item_name : string)
  let itemTempl = getOrBuildTemplateByName(item_name)
  if itemTempl == null
    logerr("[Inventory common] Can't find template for item : < {item_name} > ")
    return ""
  let containerSubTemplate = getTemplateComponent(*itemTempl, "item__recreateInInventory") ?? ""
  let newName = add_sub_template_name(item_name, containerSubTemplate)
  return newName


def find_item_in_item(item_eid : EntityId;
                      find_cb : block<(item_eid : EntityId) : bool>)
  if find_cb |> invoke(item_eid)
    return true

  var res = false
  query(item_eid) <| $ [es] (gun_mods__curModInSlots : Object const?;
                             equipment_mods__curModInSlots : Object const?)
    if gun_mods__curModInSlots != null
      for slotData in *gun_mods__curModInSlots
        if find_item_in_item(slotData.value ?? INVALID_ENTITY_ID, find_cb)
          res = true
          return
    if equipment_mods__curModInSlots != null
      for slotData in *equipment_mods__curModInSlots
        if find_item_in_item(slotData.value ?? INVALID_ENTITY_ID, find_cb)
          res = true
          return
  return res


def find_item_in_inventory(inventory_eid : EntityId;
                           find_cb : block<(item_eid : EntityId) : bool>)
  var res = false
  query(inventory_eid) <| $ [es] (itemContainer : EidList)
    for itemEid in itemContainer
      if find_item_in_item(itemEid, find_cb)
        res = true
        return
  return res


def find_item_in_actor(actor_eid : EntityId;
                       find_cb : block<(item_eid : EntityId) : bool>)
  var res = false
  query(actor_eid) <| $ [es] (inventories_owner__inventoryEids : EidList;
                              human_weap__gunEids : EidList;
                              human_equipment__slots : Object)
    for inventoryEid in inventories_owner__inventoryEids
      if find_item_in_inventory(inventoryEid, find_cb)
        res = true
        return
    for gunEid in human_weap__gunEids
      if find_item_in_item(gunEid, find_cb)
        res = true
        return
    for equipmentSlotData in human_equipment__slots
      if find_item_in_item(equipmentSlotData.value ?? INVALID_ENTITY_ID, find_cb)
        res = true
        return
  return res


def is_actor_has_item(actor_eid : EntityId;
                      item_eid : EntityId)
  return find_item_in_actor(actor_eid) <| $(inventory_item_eid : EntityId)
    return inventory_item_eid == item_eid


def private split_item_to_inventory(hero_eid, item_eid, inventory_eid : EntityId; item__currentBoxedItemCount, count : int)
  if item__currentBoxedItemCount == -1
    return // this box will be removed
  var wishCount = min(item__currentBoxedItemCount, count)
  if inventory_eid != INVALID_ENTITY_ID
    wishCount = get_boxed_item_count_to_fit_inventory(inventory_eid, item_eid, wishCount)
  if wishCount == 0
    query(item_eid) <| $ [es] (item__containerOwnerEid : EntityId = INVALID_ENTITY_ID; item__countPerStack : int = -1)
      logerr("[INVENTORY] Wish to split zero ammo of {get_entity_info(item_eid)} from {get_entity_info(item__containerOwnerEid)} to {get_entity_info(inventory_eid)};; ammoCount = {item__currentBoxedItemCount}; countPerStack = {item__countPerStack}")
    return
  if inventory_eid == INVALID_ENTITY_ID
    send_net_event(hero_eid, CmdSplitItemToGround(itemEid = item_eid, count = wishCount))
  else
    send_net_event(hero_eid, CmdSplitItemToInventory(itemEid = item_eid, toInventoryEid = inventory_eid, count = wishCount))



def move_item_to_inventory(item_eid, inventory_eid : EntityId; count : int)
  var proceed = false

  query() <| $ [es(REQUIRE=hero)] (eid aka hero_eid : EntityId)
    query(item_eid) <| $ [es] (item__isOnGround : bool = false;
                               item__containerOwnerEid : EntityId;
                               slot_attach__weaponSlotIdx : int = -1;
                               equipable_item__curSlot : string = "";
                               gunAttachable__slotName : string = "";
                               equipmentAttachable__slotName : string = "";
                               weaponMod : Tag const?;
                               boxedItem : Tag const?;
                               equipmentMod : Tag const?;
                               slot_attach__attachedTo : EntityId = INVALID_ENTITY_ID;
                               item__currentBoxedItemCount : int = -1)
      let isBoxed = boxedItem != null

      //ground -> inventory
      if item__isOnGround
        if isBoxed
          split_item_to_inventory(hero_eid, item_eid, inventory_eid, item__currentBoxedItemCount, count)
        else
          send_net_event(hero_eid, CmdMoveItemFromGroundToInventory(itemEid = item_eid, toInventoryEid = inventory_eid))
        proceed = true
        return

      //inventory -> inventory or ground
      if item__containerOwnerEid != INVALID_ENTITY_ID
        if isBoxed
          split_item_to_inventory(hero_eid, item_eid, inventory_eid, item__currentBoxedItemCount, count)
        else
          if inventory_eid == INVALID_ENTITY_ID
            send_net_event(hero_eid, CmdDropItemFromInventory(itemEid = item_eid))
          else
            send_net_event(hero_eid, CmdMoveItemFromInventoryToInventory(itemEid = item_eid, toInventoryEid = inventory_eid))
        proceed = true
        return

      //weapon slot -> inventory or ground
      if slot_attach__weaponSlotIdx >= 0
        send_net_event(hero_eid, CmdMoveWeaponToInventory(slotId = slot_attach__weaponSlotIdx, toInventoryEid = inventory_eid))
        proceed = true
        return

      //equipment (flashlight, pouches etc) -> inventory or ground
      if !empty(equipable_item__curSlot)
        send_net_event(hero_eid, CmdMoveEquipmentToInventory(slotName = equipable_item__curSlot, toInventoryEid = inventory_eid))
        proceed = true
        return

      //weapon mod (magazine, scope etc) -> inventory or ground
      if weaponMod != null
        query(slot_attach__attachedTo) <| $ [es] (slot_attach__weaponSlotIdx aka mod_slot_attach__weaponSlotIdx : int&)
          send_net_event(hero_eid, CmdMoveWeaponModToInventory(
            slotId = mod_slot_attach__weaponSlotIdx, slotName = gunAttachable__slotName, toInventoryEid = inventory_eid))
          proceed = true
        return

      //equipment mod (NVD, armorplates) -> inventory or ground
      if equipmentMod != null
        send_net_event(hero_eid, CmdMoveEquipmentModToInventory(
          equipmentEid = slot_attach__attachedTo, slotName = equipmentAttachable__slotName, toInventoryEid = inventory_eid))
        proceed = true

  return proceed


def move_stack_to_inventory(item_eids : array<EntityId>; inventory_eid : EntityId; count : int)
  if item_eids[0] |> has("boxedItem") // stack is one boxed item
    return move_item_to_inventory(item_eids[0], inventory_eid, count)
  else
    let maxCount = get_stack_item_count_to_fit_inventory(inventory_eid, item_eids[0], count)
    var res = true
    for i in range(maxCount)
      res = res && move_item_to_inventory(item_eids[i], inventory_eid, 1)
    return maxCount > 0 && res
