require app
require ecs
require ecs.safe
require net
require game.es.ecs_common
require game.events.inventory_events
require game.es.inventory_equipment_mod_common


[es(tag=server, on_disappear, REQUIRE=equipment_mod_item)]
def unequip_equipment_mod_on_destroy(evt : Event;
                                     eid aka mod_eid : EntityId;
                                     slot_attach__attachedTo : EntityId;
                                     equipmentAttachable__slotName : string;
                                     item__humanOwnerEid : EntityId = INVALID_ENTITY_ID)
  unequip_equipment_mod_from_slot(equipmentAttachable__slotName, slot_attach__attachedTo, item__humanOwnerEid)
  print("[INVENTORY] Equipment mod {get_entity_info(mod_eid)} destroyed from {get_entity_info(slot_attach__attachedTo)}.")


def remove_mod_from_other_equipment(mod_eid, hero_eid, cur_equipment_eid : EntityId; slot_name : string)
  query(hero_eid) <| $ [es] (human_equipment__slots : Object)
    for equipment in human_equipment__slots
      let equipmentEid = get_Eid(equipment.value) ?? INVALID_ENTITY_ID
      query(equipmentEid) <| $ [es] (@shared_comp equipment_mods__slots : Object; var equipment_mods__curModInSlots : Object&)
        for slot in equipment_mods__slots
          if equipmentEid == cur_equipment_eid && slot.key == slot_name
            continue
          if (get_Eid(equipment_mods__curModInSlots[slot.key]) ?? INVALID_ENTITY_ID) == mod_eid
            equipment_mods__curModInSlots |> erase(slot.key)


[es(on_appear)]
def add_mod_to_equipment_mod_slot_on_appear(evt : Event;
                                            eid : EntityId;
                                            item__humanOwnerEid : EntityId;
                                            equipmentAttachable__slotName : string;
                                            slot_attach__attachedTo : EntityId)
  if empty(equipmentAttachable__slotName)
    return

  var added = false
  query(slot_attach__attachedTo) <| $ [es] (var equipment_mods__curModInSlots : Object&)
    equipment_mods__curModInSlots |> set(equipmentAttachable__slotName, eid)
    added = true
  if !added
    addSubTemplate(eid, "equipment_mod_waiting_for_equipment_appear") <| $(var init)
      init |> set("equipment_mod_waiting_for_equipment_appear", slot_attach__attachedTo)
      init |> set("equipment_mod_waiting_for_equipment_appear_slot", equipmentAttachable__slotName)
  else
    removeSubTemplate(eid, "equipment_mod_waiting_for_equipment_appear")
  remove_mod_from_other_equipment(eid, item__humanOwnerEid, slot_attach__attachedTo, equipmentAttachable__slotName)


[es(tag=netClient)]
def add_mod_to_equipment_mod_slot_on_equip(evt : EventOnEquipmentModEquippedToEquipment;
                                           eid : EntityId)
  var added = false
  query(evt.equipmentEid) <| $ [es] (var equipment_mods__curModInSlots : Object&)
    equipment_mods__curModInSlots |> set(evt.slotName, evt.equipmentModEid)
    added = true
  if !added
    addSubTemplate(evt.equipmentModEid, "equipment_mod_waiting_for_equipment_appear") <| $(var init)
      init |> set("equipment_mod_waiting_for_equipment_appear", evt.equipmentEid)
      init |> set("equipment_mod_waiting_for_equipment_appear_slot", evt.slotName)
  else
    removeSubTemplate(evt.equipmentModEid, "equipment_mod_waiting_for_equipment_appear")
  remove_mod_from_other_equipment(evt.equipmentModEid, eid, evt.equipmentEid, evt.slotName)


[es(tag=netClient)]
def add_mod_to_equipment_mod_slot_on_swap(evt : EventOnEquipmentModSwap;
                                          eid : EntityId)
  var added = false
  query(evt.firstEquipmentEid) <| $ [es] (var equipment_mods__curModInSlots : Object&)
    equipment_mods__curModInSlots |> set(evt.firstSlotName, evt.firstEquipmentModEid)
    added = true
  if !added
    addSubTemplate(evt.firstEquipmentModEid, "equipment_mod_waiting_for_equipment_appear") <| $(var init)
      init |> set("equipment_mod_waiting_for_equipment_appear", evt.firstEquipmentEid)
      init |> set("equipment_mod_waiting_for_equipment_appear_slot", evt.firstSlotName)
  else
    removeSubTemplate(evt.firstEquipmentModEid, "equipment_mod_waiting_for_equipment_appear")
  remove_mod_from_other_equipment(evt.firstEquipmentModEid, eid, evt.firstEquipmentEid, evt.firstSlotName)

  //second
  added = false
  query(evt.secondEquipmentEid) <| $ [es] (var equipment_mods__curModInSlots : Object&)
    equipment_mods__curModInSlots |> set(evt.secondSlotName, evt.secondEquipmentModEid)
    added = true
  if !added
    addSubTemplate(evt.secondEquipmentModEid, "equipment_mod_waiting_for_equipment_appear") <| $(var init)
      init |> set("equipment_mod_waiting_for_equipment_appear", evt.secondEquipmentEid)
      init |> set("equipment_mod_waiting_for_equipment_appear_slot", evt.secondSlotName)
  else
    removeSubTemplate(evt.secondEquipmentModEid, "equipment_mod_waiting_for_equipment_appear")
  remove_mod_from_other_equipment(evt.secondEquipmentModEid, eid, evt.secondEquipmentEid, evt.secondSlotName)


[es(on_appear, REQUIRE=equipmentMod)]
def try_add_mod_to_equipment_on_waiting_appear(evt : Event;
                                               eid, equipment_mod_waiting_for_equipment_appear : EntityId;
                                               equipment_mod_waiting_for_equipment_appear_slot : string)
  query(equipment_mod_waiting_for_equipment_appear) <| $ [es] (var equipment_mods__curModInSlots : Object&)
    equipment_mods__curModInSlots |> set(equipment_mod_waiting_for_equipment_appear_slot, eid)
    removeSubTemplate(eid, "equipment_mod_waiting_for_equipment_appear")


[es(on_appear)]
def add_mods_on_equipment_appear(evt : Event;
                                 eid aka equipment_eid : EntityId;
                                 var equipment_mods__curModInSlots : Object&)
  query() <| $ [es(REQUIRE=equipmentMod)] (eid aka mod_eid, equipment_mod_waiting_for_equipment_appear : EntityId;
                                           equipment_mod_waiting_for_equipment_appear_slot : string)
    if equipment_mod_waiting_for_equipment_appear == equipment_eid
      equipment_mods__curModInSlots |> set(equipment_mod_waiting_for_equipment_appear_slot, mod_eid)
      removeSubTemplate(mod_eid, "equipment_mod_waiting_for_equipment_appear")


[es(tag=netClient, REQUIRE=eid)]
def reset_equipment_mod_on_unequip(evt : EventOnEquipmentModUnequippedFromEquipment)
  removeSubTemplate(evt.equipmentModEid, "equipment_mod_waiting_for_equipment_appear")
  query(evt.equipmentEid) <| $ [es] (var equipment_mods__curModInSlots : Object&)
    for equipmentModSlot in equipment_mods__curModInSlots
      if (get_Eid(equipmentModSlot.value) ?? INVALID_ENTITY_ID) == evt.equipmentModEid
        equipment_mods__curModInSlots |> erase(equipmentModSlot.key)
        break


[es(on_disappear)]
def reset_equipment_mod_on_disappear(evt : Event; eid, slot_attach__attachedTo : EntityId; equipmentAttachable__slotName : string)
  removeSubTemplate(eid, "equipment_mod_waiting_for_equipment_appear")
  query(slot_attach__attachedTo) <| $ [es] (var equipment_mods__curModInSlots : Object&)
    if (get_Eid(equipment_mods__curModInSlots[equipmentAttachable__slotName]) ?? INVALID_ENTITY_ID) == eid
      equipment_mods__curModInSlots |> erase(equipmentAttachable__slotName)