module inventory_checks_common shared
require ecs
require ecs.safe
require strings
require math.base
require inventory
require CollRes
require AnimV20
require HumanPhys
require ecs.common
require game.utils.team
require DagorMath
require DagorSystem
require DaWeaponProps
require GeomNodeTree
require game.es.inventory_item_mod_common
require game.es.ecs_common
require game.utils.hero
require game.es.inventory_slots_common
require game.es.equipment_enums_common


def convert_volume_to_int(volume : float) : int
  return int(ceil(volume * 10.0))


def calc_stacked_item_volume(stack_size, count : int; stack_volume : float) : int
  return ceili(float(convert_volume_to_int(stack_volume)) * float(count) / float(stack_size))


def is_hero_can_pickup_items(hero_eid : EntityId) : bool
  var result = true
  query(hero_eid) <| $ [es] (isAlive, isDowned : bool; human__canPickupItems : bool)
    result = isAlive && !isDowned && human__canPickupItems
  return result


def is_actor_can_use_item(actor_eid : EntityId;
                          item_eid : EntityId) : bool
  var result = true
  query(item_eid) <| $ [es] (item__humanOwnerEid : EntityId)
    result = item__humanOwnerEid == actor_eid // can use only items that belong to actor
  return result


def is_actor_can_move_item(actor_eid : EntityId;
                           item_eid : EntityId) : bool
  var result = true
  query(item_eid) <| $ [es] (item__humanOwnerEid : EntityId)
    result = item__humanOwnerEid == actor_eid || item__humanOwnerEid == INVALID_ENTITY_ID
  return result


def is_hero_can_use_item(item_eid : EntityId) : bool
  return is_actor_can_use_item(get_controlled_hero(), item_eid)


def is_item_use_blocked(item_eid : EntityId) : bool
  var boxedBlocked = false
  query(item_eid) <| $[es] (boxed_item__actionsBlock : bool)
    boxedBlocked = boxed_item__actionsBlock
  return has(item_eid, "item__blockUse") || boxedBlocked


def is_item_inventory_move_blocked(item_eid : EntityId) : bool
  var boxedBlocked = false
  query(item_eid) <| $[es] (boxed_item__actionsBlock : bool)
    boxedBlocked = boxed_item__actionsBlock
  return (has(item_eid, "item__blockInventoryMove") || boxedBlocked) && !has(item_eid, "ignore_block_item_move")


def is_can_move_item_to_backpack(item_eid : EntityId) : bool
  return !has(item_eid, "item__blockMoveToBackpack") || has(item_eid, "ignore_block_item_move")


def is_can_move_item_to_safepack(item_eid : EntityId) : bool
  return !has(item_eid, "item__blockMoveToSafepack") || has(item_eid, "ignore_block_item_move")


def is_can_move_item_to_ground(item_eid : EntityId) : bool
  return !has(item_eid, "item__blockMoveToGround") || has(item_eid, "ignore_block_item_move")


def is_can_move_item_to_item_container(item_eid : EntityId) : bool
  if (item_eid == INVALID_ENTITY_ID)
    return true //in case of unloading ammo from gun
  return !has(item_eid, "item__blockMoveToItemContainer") || has(item_eid, "ignore_block_item_move")


def is_can_move_item_in_inventory(item_eid, inventory_eid : EntityId)
  if has(item_eid, "hammerspace_item")
    return false

  if is_item_container(inventory_eid) && !is_can_move_item_to_item_container(item_eid)
    return false
  if is_backpack(inventory_eid) && !is_can_move_item_to_backpack(item_eid)
    return false
  if is_safepack(inventory_eid) && !is_can_move_item_to_safepack(item_eid)
    return false
  if inventory_eid == INVALID_ENTITY_ID && !is_can_move_item_to_ground(item_eid)
    return false
  return true


def is_can_move_to_safepack_with_overflow(inventory_eid, item_eid : EntityId)
  if !is_safepack(inventory_eid)
    return false
  if has(item_eid, "itemContainer")
    return false

  var res = false
  query(inventory_eid) <| $ [es] (itemContainer : EidList)
    res = empty(itemContainer)
  return res


def is_inventory_in_use(inventory_eid : EntityId)
  if inventory_eid == INVALID_ENTITY_ID || !has(inventory_eid, "itemContainer")
    return false
  return find_query() <| $ [es] (human_inventory__entityToUse : EntityId)
    return human_inventory__entityToUse == inventory_eid


def is_backpack(inventory_eid : EntityId) : bool
  var res = false
  query(inventory_eid) <| $ [es] (inventory__name : string)
    res = inventory__name == "backpack"
  return res


def is_safepack(inventory_eid : EntityId) : bool
  var res = false
  query(inventory_eid) <| $ [es] (inventory__name : string)
    res = inventory__name == "safepack"
  return res


def is_item_container(inventory_eid : EntityId) : bool
  var res = false
  query(inventory_eid) <| $ [es] (inventory__name : string)
    res = inventory__name == "itemContainer"
  return res


def is_human_inventory(inventory_eid, human_eid : EntityId) : bool
  var res = false
  query(human_eid) <| $ [es] (inventories_owner__inventoryEids : EidList)
    res = inventories_owner__inventoryEids |> has_value(inventory_eid)
  return res


def is_item_in_human_inventory(item_eid, human_eid : EntityId) : bool
  var res = false
  query(item_eid) <| $ [es] (item__humanOwnerEid : EntityId)
    res = item__humanOwnerEid == human_eid
  return res


def is_item_in_inventory(item_eid, inventory_eid : EntityId) : bool
  var res = false
  query(item_eid) <| $ [es] (item__containerOwnerEid : EntityId = INVALID_ENTITY_ID)
    res = item__containerOwnerEid == inventory_eid
  return res


def is_item_on_ground(item_eid : EntityId) : bool
  var res = false
  query(item_eid) <| $ [es] (item__isOnGround : bool)
    res = item__isOnGround
  return res


// note: little bit obscure, but it is reflects the equipped state immediately without delay of the event processing
//       with subtemplates like `item__recreateInEquipment`, so it is safe way to forbid some actions with item
def is_item_equipped(item_eid : EntityId) : bool
  var res = false
  query(item_eid) <| $ [es] (item__containerOwnerEid : EntityId;
                             item__humanOwnerEid : EntityId)
    if item__containerOwnerEid == INVALID_ENTITY_ID && item__humanOwnerEid != INVALID_ENTITY_ID
      res = true
  return res


def get_item_pickup_block_reason(item_eid : EntityId; hero_eid = INVALID_ENTITY_ID) : string
  var result = ""
  query(item_eid) <| $ [es] (item__isOnGround : bool = true;
                             item__disablePickup : bool = false;
                             quest_item__disablePickupMessage : string = "";
                             item__actionDisabledMessage : string = "pickup_locked")
    if item__disablePickup || is_item_inventory_move_blocked(item_eid)
      result = item__actionDisabledMessage
      return
    if !item__isOnGround
      result = "item_not_on_ground"
    if is_quest_item_for_other_player_by_hero(item_eid, hero_eid) || is_item_hidden_for_player_by_hero(item_eid, hero_eid)
      result = quest_item__disablePickupMessage
    if is_inventory_in_use(item_eid)
      result = "inventory_in_use"
  return result


def get_weapon_slot_for_item(hero_eid, item_eid : EntityId) : int
  var result = -1
  query(item_eid) <| $ [es] (item__weaponSlots : StringList)
    query(hero_eid) <| $ [es] (human_weap__gunEids : EidList)
      for slotName in item__weaponSlots
        let slotIdx = int(HUWeaponSlots(string(slotName)))
        if !is_weapon_slot_available_for_equip(hero_eid, slotIdx)
          continue
        let itemInSlotEid = human_weap__gunEids[slotIdx]
        if itemInSlotEid == INVALID_ENTITY_ID || has(itemInSlotEid, "default_stub_item")
          result = slotIdx
          return
  return result


def is_can_pickup_item_in_weapon_slots(hero_eid, item_eid : EntityId) : bool
  return get_weapon_slot_for_item(hero_eid, item_eid) != -1


def get_current_gun_free_slot_for_mod(gun_eid, item_eid : EntityId) : string
  var result = ""
  query(item_eid) <| $ [es] (item__proto, gunAttachable__slotName : string)
    query(gun_eid) <| $ [es] (@shared_comp gun_mods__slots : Object;
                              gun_mods__curModInSlots : Object)
      if has(gun_mods__curModInSlots, gunAttachable__slotName)
        return
      get_item_slot_available_mods(gun_mods__slots, gunAttachable__slotName) <| $ [es] (available_items : StringList)
        if has_value(available_items, item__proto)
          result = gunAttachable__slotName
  return result


def is_mod_valuable_for_weapon(item_eid : EntityId) : bool
  var result = true
  query(item_eid) <| $ [es] (item__currentBoxedItemCount = 1)
    result = item__currentBoxedItemCount > 0
  return result


def is_can_pickup_item_in_weapon_mod_slot(hero_eid, item_eid : EntityId) : bool
  var success = false
  query(hero_eid) <| $ [es] (human_weap__currentGunEid : EntityId)
    success = !empty(get_current_gun_free_slot_for_mod(human_weap__currentGunEid, item_eid))
  return success


def is_equipment_slot_removed(slot_name : string;
                              human_equipment__slotsFlags : Object) : bool
  let flags = human_equipment__slotsFlags[slot_name] ?? 0
  return (flags & int(EquipmentSlotFlags.REMOVED)) != 0


def get_equipment_slot_for_item(hero_eid, item_eid : EntityId;
                                force : bool = false) : string
  var result = ""
  query(item_eid) <| $ [es] (item__equipmentSlots : StringList)
    query(hero_eid) <| $ [es] (human_equipment__slots : Object;
                               human_equipment__slotsFlags : Object)
      for slotName in item__equipmentSlots
        let itemSlot = human_equipment__slots[string(slotName)]
        if itemSlot == null || is_equipment_slot_removed(string(slotName), human_equipment__slotsFlags)
          continue

        let itemInSlotEid = itemSlot ?? INVALID_ENTITY_ID
        if force || itemInSlotEid == INVALID_ENTITY_ID || has(itemInSlotEid, "default_stub_item")
          result = string(slotName)
          return
  return result


def hero_has_slot(hero_eid : EntityId; slotName : string) : bool
  var slotValid = false
  query(hero_eid) <| $ [es] (human_equipment__slots : Object;
                             human_equipment__slotsFlags : Object)
    for it in human_equipment__slots
      if is_equipment_slot_removed(string(it.key), human_equipment__slotsFlags)
        continue

      let itemInSlotEid = get_Eid(it.value)
      if itemInSlotEid != null && string(it.key) == slotName
        slotValid = true
        return

  return slotValid


def is_can_pickup_item_in_equipment_slots(hero_eid, item_eid : EntityId) : bool
  if has(item_eid, "item__equipInsteadOfPickup")
    return true

  return !empty(get_equipment_slot_for_item(hero_eid, item_eid))


def foreach_pocket_slot(hero_eid : EntityId;
                        callback : block<(idx : int; equipment : tuple<slot : string; eid : EntityId>; mod : tuple<slot : string; eid : EntityId>) : void>)
  var pocketSlots : array<tuple<equipment : tuple<slot : string; eid : EntityId>; mod : tuple<slot : string; eid : EntityId>>>
  query(hero_eid) <| $ [es] (human_equipment__slots : Object)
    for equipmentSlot in human_equipment__slots
      let equipmentEid = get_Eid(equipmentSlot.value) ?? INVALID_ENTITY_ID
      query(equipmentEid) <| $ [es] (@shared_comp equipment_mods__slots : Object; equipment_mods__curModInSlots : Object)
        for slot in equipment_mods__slots
          if starts_with(slot.key, pocket_slots_prefix)
            let equipment =  (equipmentSlot.key, equipmentEid)
            let mod =  (slot.key, equipment_mods__curModInSlots[slot.key] ?? INVALID_ENTITY_ID)
            pocketSlots |> push((equipment, mod))
  pocketSlots |> sort() <| $(a, b)
    let a_isSuit = a.equipment.slot == "chronogene_primary_1"
    let b_isSuit = b.equipment.slot == "chronogene_primary_1"
    if a_isSuit != b_isSuit
      return a_isSuit
    return a.equipment.slot < b.equipment.slot || (a.equipment.eid == b.equipment.eid && a.mod.slot < b.mod.slot)
  for idx, pocket in iter_range(pocketSlots), pocketSlots
    callback |> invoke(idx, pocket.equipment, pocket.mod)


def get_slot_and_equipment_for_mod(var result : Object&; hero_eid, item_eid : EntityId)
  var found = false
  query(item_eid) <| $ [es] (item__proto : string)
    foreach_pocket_slot(hero_eid) <| $ [unused_argument(idx)] (idx : int;
                                                               equipment : tuple<slot : string; eid : EntityId>;
                                                               mod : tuple<slot : string; eid : EntityId>)
      if !found && mod.eid == INVALID_ENTITY_ID
        query(equipment.eid) <| $ [es] (@shared_comp equipment_mods__slots : Object)
          get_item_slot_available_mods(equipment_mods__slots, mod.slot) <| $ [es] (available_items : StringList)
            if available_items |> find_index(item__proto) != -1
              result |> set("slot", mod.slot)
              result |> set("equipment", equipment.eid)
              found = true
    if found
      return
    query(hero_eid) <| $ [es] (human_equipment__slots : Object)
      for equipment in human_equipment__slots
        let equipmentEid = get_Eid(equipment.value) ?? INVALID_ENTITY_ID
        query(equipmentEid) <| $ [es] (@shared_comp equipment_mods__slots : Object; equipment_mods__curModInSlots : Object)
          for slot in equipment_mods__slots
            if (equipment_mods__curModInSlots[slot.key] ?? INVALID_ENTITY_ID) == INVALID_ENTITY_ID
              get_item_slot_available_mods(equipment_mods__slots, slot.key) <| $ [es] (available_items : StringList)
                if available_items |> find_index(item__proto) != -1
                  result |> set("slot", slot.key)
                  result |> set("equipment", equipmentEid)
                  found = true
            if found
              return


def is_can_pickup_item_in_equipment_mod_slot(hero_eid, item_eid : EntityId) : bool
  var success = false
  using <| $(var slot_equip_mod : Object)
    get_slot_and_equipment_for_mod(slot_equip_mod, hero_eid, item_eid)
    if has(slot_equip_mod, "equipment")
      success = true
  return success


def get_equipment_from_slot(hero_eid : EntityId; slot_name : string) : EntityId
  var result = INVALID_ENTITY_ID
  query(hero_eid) <| $ [es] (human_equipment__slots : Object)
    result = human_equipment__slots[slot_name] ?? INVALID_ENTITY_ID
  return result


def get_inventory_for_item_by_volume(hero_eid, item_eid : EntityId) : EntityId
  var result = INVALID_ENTITY_ID
  query(item_eid) <| $ [es] (item__volume : float)
    result = get_inventory_for_volume(hero_eid, item__volume)
  return result


def get_inventory_for_item(hero_eid, item_eid : EntityId) : EntityId
  var result = INVALID_ENTITY_ID
  query(item_eid) <| $ [es] (item__volume : float)
    query(hero_eid) <| $ [es] (inventories_owner__inventoryEids : EidList)
      for inventoryEid in inventories_owner__inventoryEids
        if is_inventory_have_free_volume(inventoryEid, item__volume) && is_can_move_item_in_inventory(item_eid, inventoryEid)
          result = inventoryEid
          break
  return result


def is_inventory_have_free_volume(inventory_eid : EntityId; volume : int) : bool
  var result = false
  query(inventory_eid) <| $ [es] (human_inventory__currentVolume, human_inventory__maxVolumeInt : int)
    result = human_inventory__currentVolume + volume <= human_inventory__maxVolumeInt || human_inventory__maxVolumeInt < 0
  return result


def is_inventory_have_free_volume(inventory_eid : EntityId; volume : float) : bool
  return is_inventory_have_free_volume(inventory_eid, convert_volume_to_int(volume))


def is_inventory_have_volume_for_item(inventory_eid, item_eid : EntityId) : bool
  if is_can_move_to_safepack_with_overflow(inventory_eid, item_eid)
    return true
  var result = false
  query(item_eid) <| $ [es] (item__volume : float)
    result = is_inventory_have_free_volume(inventory_eid, item__volume)
  return result


def is_inventory_read_only(inventory_eid) : bool
  return has(inventory_eid, "readOnlyInventory")


def get_inventory_for_volume(hero_eid : EntityId; volume : float) : EntityId
  var result = INVALID_ENTITY_ID
  query(hero_eid) <| $ [es] (inventories_owner__inventoryEids : EidList)
    for inventoryEid in inventories_owner__inventoryEids
      if is_inventory_have_free_volume(inventoryEid, volume)
        result = inventoryEid
        break
  return result


def get_stack_item_count_to_fit_inventory(inventory_eid, item_eid : EntityId; count : int) : int
  var result = inventory_eid == INVALID_ENTITY_ID ? count : 0
  query(inventory_eid) <| $ [es] (human_inventory__currentVolume, human_inventory__maxVolumeInt : int)
    if human_inventory__maxVolumeInt == -1
      result = count
      return
    query(item_eid) <| $ [es] (item__volume : float)
      let freeVolume = human_inventory__maxVolumeInt - human_inventory__currentVolume
      result = (convert_volume_to_int(item__volume) == 0 ? count :
                min(count, freeVolume / convert_volume_to_int(item__volume)))
  if result == 0 && is_can_move_to_safepack_with_overflow(inventory_eid, item_eid)
    result = 1
  return result


def get_boxed_item_count_to_fit_inventory(inventory_eid : EntityId;
                                          item__countPerStack : int;
                                          item__volumePerStack : float;
                                          item__boxTemplateName : string;
                                          wish_count : int = -1) : int
  var result = 0
  if wish_count == 0
    logerr("[INVENTORY CHECK] try to get ammo count of <{item__boxTemplateName}> to fit invetory {get_entity_info(inventory_eid)} with wish_count = 0")
    return result
  if item__volumePerStack == .0 && wish_count == -1
    logerr("[INVENTORY CHECK] try to get ammo count of <{item__boxTemplateName}> to fit invetory {get_entity_info(inventory_eid)} with item_volumePerStack = 0 no wish_count.")
    return result
  elif item__volumePerStack == .0
    result = wish_count
    return result
  query(inventory_eid) <| $ [es] (itemContainer : EidList; human_inventory__currentVolume, human_inventory__maxVolumeInt : int)
    let freeVolume = human_inventory__maxVolumeInt - human_inventory__currentVolume
    let lowerBound = freeVolume * item__countPerStack / convert_volume_to_int(item__volumePerStack)
    if wish_count >= 0 && (lowerBound >= wish_count || human_inventory__maxVolumeInt < 0)
      result = wish_count
      return

    var existingCount = 0
    for item in itemContainer
      query(item) <| $ [es] (boxed_item__template : string; item__currentBoxedItemCount : int)
        if boxed_item__template == item__boxTemplateName
          existingCount = item__currentBoxedItemCount
      if existingCount != 0
        break

    let countRemainder = existingCount % item__countPerStack
    let volumeRemainder = calc_stacked_item_volume(item__countPerStack, countRemainder, item__volumePerStack)
    let volumeForAmmo = volumeRemainder + freeVolume
    let maxAmmo = volumeForAmmo * item__countPerStack / convert_volume_to_int(item__volumePerStack)
    result = maxAmmo - countRemainder

  return wish_count >= 0 ? min(result, wish_count) : result


def get_boxed_item_count_to_fit_inventory(inventory_eid : EntityId; box_eid : EntityId; wish_count : int = -1) : int
  var result = 0
  query(box_eid) <| $ [es] (item__countPerStack : int; item__volumePerStack : float; boxed_item__template : string)
    result = get_boxed_item_count_to_fit_inventory(inventory_eid, item__countPerStack, item__volumePerStack, boxed_item__template, wish_count)
  return result


def get_boxed_item_count_to_fit_inventory(inventory_eid : EntityId; box_template : string; wish_count : int = -1) : int
  var result = 0
  let boxTemplate = getOrBuildTemplateByName(box_template)
  if boxTemplate != null
    let item__countPerStack = getTemplateComponent(*boxTemplate, "item__countPerStack") ?? 1
    let item__volumePerStack = getTemplateComponent(*boxTemplate, "item__volumePerStack") ?? 0.1
    result = get_boxed_item_count_to_fit_inventory(inventory_eid, item__countPerStack, item__volumePerStack, box_template, wish_count)
  return result


def is_can_pickup_item_in_inventory(hero_eid, item_eid : EntityId) : bool
  return get_inventory_for_item_by_volume(hero_eid, item_eid) != INVALID_ENTITY_ID


def is_fast_equip_item_possible(hero_eid, item_eid : EntityId) : bool
  if is_can_pickup_item_in_weapon_slots(hero_eid, item_eid)
    return true
  elif is_can_pickup_item_in_equipment_slots(hero_eid, item_eid)
    return true
  elif is_can_pickup_item_in_weapon_mod_slot(hero_eid, item_eid)
    return true
  elif is_can_pickup_item_in_equipment_mod_slot(hero_eid, item_eid)
    return true
  return false


def is_can_pickup_item(hero_eid, item_eid : EntityId) : bool
  if is_item_inventory_move_blocked(item_eid)
    return false
  if is_quest_item_for_other_player_by_hero(item_eid, hero_eid) || is_item_hidden_for_player_by_hero(item_eid, hero_eid)
    return false
  if is_fast_equip_item_possible(hero_eid, item_eid)
    return true
  elif is_can_pickup_item_in_inventory(hero_eid, item_eid)
    return true
  return false


def is_ammo_useful(hero_eid, item_eid : EntityId) : bool
  var result = false
  query(hero_eid) <| $ [es] (human_weap__gunEids : EidList)
    query(item_eid) <| $ [es] (shell_props : ShellPropIds; ammo_holder__id : int)
      for gunEid in human_weap__gunEids
        query(gunEid) <| $ [es] (gun__shell_prop_ids : GunShellPropIds;
                                 gun__ammoHolderIds : IntList;
                                 gun__secondaryAmmoHolderIds : IntList const?)
          if gun__ammoHolderIds |> find_index(ammo_holder__id) != -1
            result = true
            return
          if gun__secondaryAmmoHolderIds != null && (*gun__secondaryAmmoHolderIds |> find_index(ammo_holder__id) != -1)
            result = true
            return
          for i in iter_range(gun__shell_prop_ids)
            if gun__shell_prop_ids[i].shellId == shell_props.shellId
              result = true
              return
  return result


def get_free_slot_for_mod(hero_eid, item_eid : EntityId) : EntityId
  var result = INVALID_ENTITY_ID
  query(hero_eid) <| $ [es] (human_weap__gunEids : EidList)
    query(item_eid) <| $ [es] (item__proto, gunAttachable__slotName : string)
      for gunEid in human_weap__gunEids
        query(gunEid) <| $ [es] (@shared_comp gun_mods__slots : Object;
                                 gun_mods__curModInSlots : Object;
                                 gun__isReloading : bool)
          let occupated = (gun_mods__curModInSlots[gunAttachable__slotName] ?? INVALID_ENTITY_ID) != INVALID_ENTITY_ID
          if occupated
            return
          if gunAttachable__slotName == "magazine" && gun__isReloading
            return
          get_item_slot_available_mods(gun_mods__slots, gunAttachable__slotName) <| $ [es] (available_items : StringList)
            if available_items |> find_index(item__proto) != -1
              result = gunEid
        if result != INVALID_ENTITY_ID
          return
  if result != INVALID_ENTITY_ID
    return result

  return result


def is_mod_useful(hero_eid, item_eid : EntityId) : bool
  var result = false
  query(hero_eid) <| $ [es] (human_weap__gunEids : EidList)
    query(item_eid) <| $ [es] (item__proto, gunAttachable__slotName : string)
      for gunEid in human_weap__gunEids
        query(gunEid) <| $ [es] (@shared_comp gun_mods__slots : Object)
          get_item_slot_available_mods(gun_mods__slots, gunAttachable__slotName) <| $ [es] (available_items : StringList)
            if available_items |> find_index(item__proto) != -1
              result = true
        if result
          return
  return result


def is_item_useful_for_weapon(hero_eid, item_eid : EntityId) : bool
  let isAmmoUseful = is_ammo_useful(hero_eid, item_eid)
  let isModUseful = is_mod_useful(hero_eid, item_eid)
  return isAmmoUseful || isModUseful


def is_item_useful(hero_eid, item_eid : EntityId) : bool
  if !is_hero_can_pickup_items(hero_eid) || !empty(get_item_pickup_block_reason(item_eid))
    return false

  if is_can_pickup_item_in_equipment_slots(hero_eid, item_eid)
    return true
  if is_can_pickup_item_in_weapon_slots(hero_eid, item_eid)
    return true

  var isItemUseful = false
  query(item_eid) <| $ [es] (item__useTime, item__useTimeToTarget : float const?;
                             item__alwaysUseful : Tag const?)
    isItemUseful = (item__alwaysUseful != null) || (item__useTime != null || item__useTimeToTarget != null)
  if isItemUseful
    return true

  return is_item_useful_for_weapon(hero_eid, item_eid)


def find_gunslot_to_change_weapon(eid : EntityId;
                                  item_eid : EntityId;
                                  var have_gun : bool&) : int
  var res = -1
  have_gun = false

  query(eid) <| $ [es] (human_weap__gunEids : EidList)
    query(item_eid) <| $ [es] (item__weaponSlots : StringList;
                               item__id : int)
      let weaponId = item__id
      for slotName in item__weaponSlots
        let slotIdx = HUWeaponSlots(string(slotName))
        let gunEid = human_weap__gunEids[int(slotIdx)]
        let totalAmmo = get_int(gunEid, "gun__totalAmmo") ?? 0 + get_int(gunEid, "gun__ammo") ?? 0
        if gunEid != INVALID_ENTITY_ID && has(gunEid, "disableItemDrop")
          continue
        let isMeleeOrUnarmed = (slotIdx == HUWeaponSlots.EWS_MELEE) || (slotIdx == HUWeaponSlots.EWS_UNARMED)
        let noAmmo = (totalAmmo <= 0 && !isMeleeOrUnarmed
                      && weaponId != get_int(human_weap__gunEids[int(slotIdx)], "item__id") ?? INVALID_ITEM_ID)
        if gunEid == INVALID_ENTITY_ID || noAmmo
          res = int(slotIdx)
          have_gun = (gunEid != INVALID_ENTITY_ID)
          if !have_gun
            break
  return res


def find_best_weap_slot_id(eid, item_eid : EntityId;
                           slot_id, currentSlot : int) : int
  var slotId = slot_id
  query(eid) <| $ [es] (human_weap__gunEids : EidList)
    query(item_eid) <| $ [es] (item__weaponSlots : StringList)
      for slotName in item__weaponSlots
        let slotIdx = int(HUWeaponSlots(string(slotName)))
        if slotIdx == -1
          logerr("incorrect weap slot name '{slotName}' for weapon {item_eid}<{getEntityTemplateName(item_eid)}>")
          continue

        if has(human_weap__gunEids[slotIdx], "disableItemDrop")
          continue
        if slotId < 0 || slotIdx == currentSlot
          slotId = slotIdx

  return slotId


def is_quest_item(item_eid : EntityId) : bool
  return has(item_eid, "questItem")


def is_quest_item_for_player(item_eid, player_eid : EntityId) : bool
  var result = false
  query(item_eid) <| $ [es] (quest_item__playerEid : EntityId;
                             quest_item__canBeTakenByAll : bool)
    result = quest_item__playerEid == player_eid || quest_item__canBeTakenByAll
  return result


def is_quest_item_for_player_by_hero(item_eid, hero_eid : EntityId) : bool
  var result = false
  query(hero_eid) <| $ [es] (possessedByPlr : EntityId)
    result = is_quest_item_for_player(item_eid, possessedByPlr)
  return result

def is_quest_item_for_other_player(item_eid, player_eid : EntityId) : bool
  return is_quest_item(item_eid) && !is_quest_item_for_player(item_eid, player_eid)

def is_quest_item_for_other_player_by_hero(item_eid, hero_eid : EntityId) : bool
  return is_quest_item(item_eid) && !is_quest_item_for_player_by_hero(item_eid, hero_eid)


def is_item_hidden_for_player(item_eid, player_eid : EntityId) : bool
  var itemHidden = false
  query(item_eid) <| $ [es] (playerItemOwner : EntityId;
                             playerItemHideForEnemies : Tag const?)
    if playerItemHideForEnemies != null
      query(player_eid) <| $ [es] (team aka player_team : int = TEAM_UNASSIGNED)
        query(playerItemOwner) <| $ [es] (team aka item_team : int = TEAM_UNASSIGNED)
          itemHidden = (player_team != item_team)
  return itemHidden

def is_item_hidden_for_player_by_hero(item_eid, hero_eid : EntityId) : bool
  var itemHidden = false
  query(hero_eid) <| $ [es] (possessedByPlr : EntityId)
    itemHidden = is_item_hidden_for_player(item_eid, possessedByPlr)
  return itemHidden


def get_current_move_mod_for_weapon(delayed_unequip_eid, delayed_equip_eid : EntityId) : EntityId
  return (!!delayed_unequip_eid ? delayed_unequip_eid : delayed_equip_eid)


def get_current_move_mod_for_weapon(weapon_eid : EntityId) : EntityId
  var curMoveEid = INVALID_ENTITY_ID
  query(weapon_eid) <| $ [es] (weapon_mods__modDelayedUnequipEid : EntityId;
                               weapon_mods__modDelayedEquipEid : EntityId)
    curMoveEid = get_current_move_mod_for_weapon(weapon_mods__modDelayedUnequipEid, weapon_mods__modDelayedEquipEid)
  return curMoveEid


def is_move_mod_from_weapon(item_eid : EntityId) : bool
  var toWeapon = false
  query(item_eid) <| $ [es] (weapon_mod_move__weaponEid : EntityId)
    query(weapon_mod_move__weaponEid) <| $ [es] (weapon_mods__modDelayedUnequipEid : EntityId)
      toWeapon = item_eid == weapon_mods__modDelayedUnequipEid
  return toWeapon


def is_human_have_permission_to_use_inventory(hero_eid : EntityId;
                                              inventory_eid : EntityId) : bool
  if hero_eid == inventory_eid
    return true

  var havePermission = true
  query(inventory_eid) <| $ [es] (item__humanOwnerEid : EntityId)
    havePermission = (item__humanOwnerEid == INVALID_ENTITY_ID || item__humanOwnerEid == hero_eid)

  return havePermission


def free_inventory_volume(inventory_eid : EntityId) : int
  var freeVolume = 0
  query(inventory_eid) <| $ [es] (human_inventory__currentVolume, human_inventory__maxVolumeInt : int)
    freeVolume = human_inventory__maxVolumeInt - human_inventory__currentVolume
  return freeVolume


def get_item_inventory_extension(item_eid : EntityId) : float
  var extension = 0.f
  query(item_eid) <| $ [es] (item__inventoryExtension : float)
    extension = item__inventoryExtension
  return extension


def is_weapon_slot_available_for_equip(hero_eid : EntityId;
                                       slot_id : int)
  var res = true

  query(hero_eid) <| $ [es] (human_weap__gunSlotFlags : IntList const?)
    let slotFlags = (human_weap__gunSlotFlags != null && slot_id < length(*human_weap__gunSlotFlags)) ? (*human_weap__gunSlotFlags)[slot_id] : 0

    let isSlotRemoved = (slotFlags & int(GunSlotFlags REMOVED)) != 0
    let isSlotLocked = (slotFlags & int(GunSlotFlags LOCKED)) != 0

    if isSlotRemoved || isSlotLocked
      res = false
      return

  return res


def is_on_equip_weapon_prev_can_fit(weapon_eid : EntityId;
                                    slot_id : int;
                                    hero_eid : EntityId;
                                    drop_prev_to_cont_eid : EntityId = INVALID_ENTITY_ID) : bool
  var res = false

  if drop_prev_to_cont_eid == INVALID_ENTITY_ID
    res = true
  else
    query(hero_eid) <| $ [es] (human_weap__gunEids : EidList)
      if human_weap__gunEids[slot_id] == INVALID_ENTITY_ID // to empty slot
        res = true
      elif weapon_eid != INVALID_ENTITY_ID && find_index(human_weap__gunEids, weapon_eid) != -1 // swap between weapon slots
        res = true
      elif has(human_weap__gunEids[slot_id], "default_stub_item") // change stub item
        res = true
      else // can previous weapon fit into inventory?
        query(weapon_eid) <| $ [es] (item__containerOwnerEid : EntityId;
                                     item__volume : float = 0.f)
          var checkVolumeValue = get_float(human_weap__gunEids[slot_id], "item__volume") ?? 0.f
          if drop_prev_to_cont_eid == item__containerOwnerEid
            checkVolumeValue -= item__volume
          res = is_inventory_have_free_volume(drop_prev_to_cont_eid, max(0.f, checkVolumeValue))
  return res


def is_on_equip_weapon_mod_prev_can_fit(weapon_mod_eid : EntityId;
                                        slot_name : string;
                                        weapon_eid : EntityId;
                                        drop_prev_to_cont_eid : EntityId = INVALID_ENTITY_ID) : bool
  if drop_prev_to_cont_eid == INVALID_ENTITY_ID
    return true

  var res = false
  query(weapon_eid) <| $ [es] (gun_mods__curModInSlots : Object)
    let oldWeaponModEid = get_Eid(gun_mods__curModInSlots[slot_name]) ?? INVALID_ENTITY_ID
    res = is_on_equip_weapon_mod_prev_can_fit(weapon_mod_eid, oldWeaponModEid, drop_prev_to_cont_eid)
  return res


def is_on_equip_weapon_mod_prev_can_fit(new_weapon_mod_eid : EntityId;
                                        old_weapon_mod_eid : EntityId;
                                        drop_prev_to_cont_eid : EntityId = INVALID_ENTITY_ID) : bool
  if old_weapon_mod_eid == INVALID_ENTITY_ID
    return true
  if drop_prev_to_cont_eid == INVALID_ENTITY_ID
    return true

  var res = false
  query(new_weapon_mod_eid) <| $ [es] (item__containerOwnerEid : EntityId;
                                       weapon_mod_move__inventoryEid : EntityId const?;
                                       item__volume : float = 0.f)
    var checkVolumeValue = get_float(old_weapon_mod_eid, "item__volume") ?? 0.f // can previous weapon mod fit into inventory?
    let fromInventoryEid = (weapon_mod_move__inventoryEid != null) ? *weapon_mod_move__inventoryEid : item__containerOwnerEid
    if drop_prev_to_cont_eid == fromInventoryEid
      checkVolumeValue -= item__volume
    res = is_inventory_have_free_volume(drop_prev_to_cont_eid, max(0.f, checkVolumeValue))
  return res


def is_on_equip_equipment_prev_can_fit(equipment_eid : EntityId;
                                       slot_name : string;
                                       hero_eid : EntityId;
                                       drop_prev_to_cont_eid : EntityId = INVALID_ENTITY_ID) : bool
  var res = false

  if drop_prev_to_cont_eid == INVALID_ENTITY_ID
    res = true
  else
    query(hero_eid) <| $ [es] (human_equipment__slots : Object)
      let slotObjectEid = get_Eid(human_equipment__slots[slot_name]) ?? INVALID_ENTITY_ID
      if slotObjectEid == INVALID_ENTITY_ID // to empty slot
        res = true
      else // can previous equipment fit into inventory?
        query(equipment_eid) <| $ [es] (item__containerOwnerEid : EntityId;
                                        item__volume aka equip_item__volume : float = 0.f;
                                        item__inventoryExtension aka equip_item__inventoryExtension : float  = 0.f)
          query(slotObjectEid) <| $ [es] (slot_attach__attachedTo : EntityId;
                                          item__volume aka unequip_item__volume : float = 0.f;
                                          item__inventoryExtension aka unequip_item__inventoryExtension : float  = 0.f;
                                          default_stub_item : Tag const?)
            if default_stub_item != null
              res = true
              return

            var checkVolumeValue = unequip_item__volume
            if drop_prev_to_cont_eid == item__containerOwnerEid
              checkVolumeValue -= equip_item__volume
            if drop_prev_to_cont_eid == hero_eid
              checkVolumeValue -= equip_item__inventoryExtension
            if drop_prev_to_cont_eid == slot_attach__attachedTo
              checkVolumeValue += unequip_item__inventoryExtension
            res = is_inventory_have_free_volume(drop_prev_to_cont_eid, max(0.f, checkVolumeValue))
  return res


def is_on_equip_equipment_mod_prev_can_fit(equipment_mod_eid : EntityId;
                                           slot_name : string;
                                           equipment_eid : EntityId;
                                           drop_prev_to_cont_eid : EntityId = INVALID_ENTITY_ID;
                                           boxed_item_count_to_equip : int = 1) : bool
  var res = false

  if drop_prev_to_cont_eid == INVALID_ENTITY_ID
    res = true
  else
    var oldEquipmentModEid = INVALID_ENTITY_ID
    query(equipment_eid) <| $ [es] (equipment_mods__curModInSlots : Object)
      oldEquipmentModEid = get_Eid(equipment_mods__curModInSlots[slot_name]) ?? INVALID_ENTITY_ID
      if oldEquipmentModEid == INVALID_ENTITY_ID || oldEquipmentModEid == equipment_mod_eid // to empty slot or to the very same slot
        res = true
        return

      for equipmentModInSlot in equipment_mods__curModInSlots
        if (get_Eid(equipmentModInSlot.value) ?? INVALID_ENTITY_ID) == equipment_mod_eid // swap between equipment mod slots
          res = true
          return

      query(equipment_mod_eid) <| $ [es] (item__containerOwnerEid : EntityId; // can previous equipment mod fit into inventory?
                                          item__volume : float = 0.f;
                                          item__countPerStack : int = 0;
                                          item__volumePerStack : float = 0.0f;
                                          boxedItem : Tag const?)
        var checkVolumeValue = 0.f
        query(oldEquipmentModEid) <| $ [es] (item__volume aka old_item__volume : float = 0.f;
                                             item__countPerStack aka old_item__countPerStack : int = 0;
                                             item__currentBoxedItemCount aka old_item__currentBoxedItemCount : int = 0;
                                             item__volumePerStack aka old_item__volumePerStack : float = 0.0f;
                                             boxedItem aka old_boxedItem : Tag const?)
          if boxedItem == null
            checkVolumeValue = old_item__volume
          else
            checkVolumeValue = float(calc_stacked_item_volume(old_item__countPerStack, old_item__currentBoxedItemCount, old_item__volumePerStack)) / 10.0

        if drop_prev_to_cont_eid == item__containerOwnerEid
          if boxedItem == null
            checkVolumeValue -= item__volume
          else
            checkVolumeValue -= float(calc_stacked_item_volume(item__countPerStack, boxed_item_count_to_equip, item__volumePerStack)) / 10.0

        res = is_inventory_have_free_volume(drop_prev_to_cont_eid, max(0.f, checkVolumeValue))

  return res


def is_item_accessible_by_distance(human_inventory__lookNodeId : int;
                                   animchar : AnimcharBaseComponent;
                                   hero_transform : float3x4;
                                   pickup_radius, pickup_height : float;
                                   item_transform : float3x4;
                                   item_collres : CollisionResource const? = null) : bool
  let pickupRadiusSq = square(pickup_radius)
  let pickupHeightSq = square(pickup_height)
  var checkFromPos = hero_transform[3]
  var itemPos = item_transform[3]
  // There are two ways people expect to pick up items: from the ground in inventory and from eye node otherwise.
  // When people are picking up items from ground they tend to stend in some 'middle' place of the loot (dead body, usually)
  // and look down expecting to see all loot around in inventory.
  // In such cases checking loot availibility distance from eye position skips a lot of loot as eye node will be ~1.3m from ground position.
  // To make both cases feel good we check loot availability from the closest of eye or transform position to loot.
  if human_inventory__lookNodeId >= 0
    let lookNodePos = geomtree_getNodeWpos(*animchar.nodeTree, human_inventory__lookNodeId)
    if length_sq(checkFromPos - itemPos) > length_sq(lookNodePos - itemPos)
      checkFromPos = lookNodePos

  if item_collres != null
    let itemRelativeCheckPos = inverse(item_transform) * checkFromPos
    let bboxPositionClosestToCheckPos = item_transform * float3(
      clamp(itemRelativeCheckPos.x, item_collres.boundingBox.boxMin.x, item_collres.boundingBox.boxMax.x),
      clamp(itemRelativeCheckPos.y, item_collres.boundingBox.boxMin.y, item_collres.boundingBox.boxMax.y),
      clamp(itemRelativeCheckPos.z, item_collres.boundingBox.boxMin.z, item_collres.boundingBox.boxMax.z)
    )
    // If the collres is broken (offseted a lot) item center might be closer, so override it only if it's actually further than bbox pos
    if length_sq(itemPos - checkFromPos) > length_sq(bboxPositionClosestToCheckPos - checkFromPos)
      itemPos = bboxPositionClosestToCheckPos

  let upDir = hero_transform[1]
  let diff = checkFromPos - item_transform[3]
  let verticalDiff = dot(diff, upDir) * upDir
  let verticalDistSq = length_sq(verticalDiff)
  let horizontalDistSq = length_sq(diff - verticalDiff)
  return horizontalDistSq < pickupRadiusSq && verticalDistSq < pickupHeightSq


def is_item_accessible_by_distance(hero_eid, item_eid : EntityId;
                                   pickup_radius, pickup_height : float) : bool
  var res = false
  query(hero_eid) <| $ [es] (human_inventory__lookNodeId : int;
                             animchar : AnimcharBaseComponent;
                             transform aka hero_transform : float3x4)
    query(item_eid) <| $ [es] (transform aka item_transform : float3x4; collres : CollisionResource const? = null)
      res = is_item_accessible_by_distance(human_inventory__lookNodeId, animchar, hero_transform, pickup_radius, pickup_height, item_transform, collres)
  return res


def can_hero_acess_item_relaxed(user_eid, item_eid, item__humanOwnerEid, item__containerOwnerEid : EntityId;
                                user_pos : float3;
                                use_radius : float) : bool
  if item__humanOwnerEid == user_eid
    return true
  if item__humanOwnerEid != INVALID_ENTITY_ID
    return false
  var res = false
  if item__containerOwnerEid == INVALID_ENTITY_ID
    query(item_eid) <| $ [es] (transform : float3x4)
      res = distance(transform[3], user_pos) < use_radius + 2.0 //relaxed check
  else
    query(item__containerOwnerEid) <| $ [es] (transform : float3x4)
      res = distance(transform[3], user_pos) < use_radius + 2.0
  return res


def is_ammo_for_gun(ammo_eid, gun_eid : EntityId) : bool
  var res = false
  query(ammo_eid) <| $ [es] (boxed_item__template : string)
    query(gun_eid) <| $ [es] (gun__boxedAmmoHolderTemplate : string)
      res = boxed_item__template == gun__boxedAmmoHolderTemplate
  query(ammo_eid) <| $ [es] (ammo_holder__id : int)
    query(gun_eid) <| $ [es] (gun__ammoHolderIds : IntList)
      res ||= has_value(gun__ammoHolderIds, ammo_holder__id)
  return res