require app
require ecs
require ecs.safe
require net
require game.es.ecs_common
require game.events.inventory_events
require game.es.inventory_checks_common
require game.es.inventory_equipment_common
require game.es.inventory_drop_common
require DagorSystem


[es(tag=server, on_disappear, REQUIRE=equipment_item)]
def unequip_equipment_on_destroy(evt : Event;
                                 eid aka equipment_eid : EntityId;
                                 slot_attach__attachedTo : EntityId;
                                 equipable_item__curSlot : string)
  unequip_equipment_from_slot(equipable_item__curSlot, slot_attach__attachedTo)
  print("[INVENTORY] Equipment {get_entity_info(equipment_eid)} destroyed from hero {get_entity_info(slot_attach__attachedTo)}.")


[es(tag=server, REQUIRE=human_equipment__slots)]
def equip_equipment_mods_on_equip_equipment(evt : EventOnEquipmentEquipped;
                                            eid aka actor_eid : EntityId)
  query(evt.equipmentEid) <| $ [es] (equipment_mods__curModInSlots : Object)
    for curModInSlot in equipment_mods__curModInSlots
      let equipmentModEid = curModInSlot.value ?? INVALID_ENTITY_ID
      if equipmentModEid != INVALID_ENTITY_ID
        send_net_event(actor_eid, EventOnEquipmentModEquippedToHero(equipmentModEid = equipmentModEid, equipmentEid = evt.equipmentEid))


[es(tag=server, REQUIRE=human_equipment__slots)]
def unequip_equipment_mods_on_unequip_equipment(evt : EventOnEquipmentUnequipped;
                                                eid aka actor_eid : EntityId)
  query(evt.equipmentEid) <| $ [es] (equipment_mods__curModInSlots : Object)
    for curModInSlot in equipment_mods__curModInSlots
      let equipmentModEid = curModInSlot.value ?? INVALID_ENTITY_ID
      if equipmentModEid != INVALID_ENTITY_ID
        send_net_event(actor_eid, EventOnEquipmentModUnequippedFromHero(equipmentModEid = equipmentModEid))


enum SetEquipmentToSlotResult
  ADDED
  HERO_IS_NOT_EXISTS
  SLOT_IS_REMOVED


def set_equipment_to_slot(hero_eid, equipment_eid : EntityId; slot : string)
  var result = SetEquipmentToSlotResult.HERO_IS_NOT_EXISTS
  query(hero_eid) <| $ [es] (human_equipment__slotsFlags : Object;
                             var human_equipment__slots : Object&)
    if is_equipment_slot_removed(slot, human_equipment__slotsFlags)
      result = SetEquipmentToSlotResult.SLOT_IS_REMOVED
      return

    var slotObjectEid = getRW_Eid(human_equipment__slots[slot])
    if slotObjectEid != null
      *slotObjectEid = equipment_eid
    result = SetEquipmentToSlotResult.ADDED
  return result


[es(on_appear)]
def add_equipment_to_hero_slot_on_appear(evt : Event;
                                         eid : EntityId;
                                         equipable_item__curSlot : string;
                                         item__humanOwnerEid : EntityId)
  if empty(equipable_item__curSlot)
    return

  let result = set_equipment_to_slot(item__humanOwnerEid, eid, equipable_item__curSlot)

  if result == SetEquipmentToSlotResult.HERO_IS_NOT_EXISTS
    addSubTemplate(eid, "equipment_waiting_for_hero_appear") <| $(var init)
      init |> set("equipment_waiting_for_hero_appear", item__humanOwnerEid)
      init |> set("equipment_waiting_for_hero_appear_slot", equipable_item__curSlot)
  elif result == SetEquipmentToSlotResult.SLOT_IS_REMOVED
    logerr("[INVENTORY] Slot <{equipable_item__curSlot}> is removed! item={get_entity_info(eid)}, hero={get_entity_info(item__humanOwnerEid)}.")
    drop_item(eid, item__humanOwnerEid)
  elif result == SetEquipmentToSlotResult.ADDED
    removeSubTemplate(eid, "equipment_waiting_for_hero_appear")


[es(tag=netClient)]
def add_equipment_to_hero_slot_on_equip(evt : EventOnEquipmentEquipped;
                                        eid : EntityId)
  let result = set_equipment_to_slot(eid, evt.equipmentEid, evt.slotName)

  if result == SetEquipmentToSlotResult.HERO_IS_NOT_EXISTS
    addSubTemplate(evt.equipmentEid, "equipment_waiting_for_hero_appear") <| $(var init)
      init |> set("equipment_waiting_for_hero_appear", eid)
      init |> set("equipment_waiting_for_hero_appear_slot", evt.slotName)
  elif result == SetEquipmentToSlotResult.SLOT_IS_REMOVED
    logerr("[INVENTORY] Slot <{evt.slotName}> is removed! item={get_entity_info(evt.equipmentEid)}, hero={get_entity_info(eid)}.")
    drop_item(evt.equipmentEid, eid)
  elif result == SetEquipmentToSlotResult.ADDED
    removeSubTemplate(evt.equipmentEid, "equipment_waiting_for_hero_appear")


[es(on_appear)]
def try_set_equipment_on_waiting_appear(evt : Event; eid, equipment_waiting_for_hero_appear : EntityId; equipment_waiting_for_hero_appear_slot : string)
  if set_equipment_to_slot(equipment_waiting_for_hero_appear, eid, equipment_waiting_for_hero_appear_slot) == SetEquipmentToSlotResult.ADDED
    removeSubTemplate(eid, "equipment_waiting_for_hero_appear")


[es(on_appear)]
def set_equipment_on_hero_appear(evt : Event; eid aka hero_eid : EntityId)
  query() <| $ [es] (eid aka equipment_eid, equipment_waiting_for_hero_appear : EntityId; equipment_waiting_for_hero_appear_slot : string)
    if (hero_eid == equipment_waiting_for_hero_appear &&
        set_equipment_to_slot(hero_eid, equipment_eid, equipment_waiting_for_hero_appear_slot)  == SetEquipmentToSlotResult.ADDED)
      removeSubTemplate(eid, "equipment_waiting_for_hero_appear")


def take_equipment_from_slot(hero_eid, equipment_eid : EntityId; slot : string)
  removeSubTemplate(equipment_eid, "equipment_waiting_for_hero_appear")
  query(hero_eid) <| $ [es] (var human_equipment__slots : Object&)
    var slotObjectEid = getRW_Eid(human_equipment__slots[slot])
    if slotObjectEid != null && *slotObjectEid == equipment_eid
      *slotObjectEid = INVALID_ENTITY_ID


[es(tag=netClient)]
def reset_slot_on_equipment_unequip(evt : EventOnEquipmentUnequipped; eid : EntityId)
  take_equipment_from_slot(eid, evt.equipmentEid, evt.slotName)


[es(on_disappear)]
def reset_slot_on_equipment_disappear(evt : Event; eid, slot_attach__attachedTo : EntityId; equipable_item__curSlot : string)
  take_equipment_from_slot(slot_attach__attachedTo, eid, equipable_item__curSlot)
