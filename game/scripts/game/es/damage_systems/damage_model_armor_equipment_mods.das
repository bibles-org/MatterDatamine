require ecs
require ecs.safe
require ecs.common
require strings
require game.es.inventory_slots_common
require game.events.inventory_events
require game.events.events_active_matter
require game.es.damage_systems.damage_model_armor_common
require DagorMath
require DagorSystem


def convert_armor_equipment_mod_slot_name_to_part_name(slot_name : string)
  if slot_name |> starts_with(equipment_mod_slots_prefix)
    let startIndex = length(equipment_mod_slots_prefix)
    var i = length(slot_name)
    while --i >= 0
      if slot_name |> character_at(i) == '_'
        break
    if i > startIndex
      return slot_name |> chop(startIndex, i - startIndex)
  return ""


def calculate_armor_equipment_mod_part_name(equipment_mod_eid : EntityId; equipment_eid : EntityId)
  var res = ""
  query(equipment_eid) <| $ [es] (equipment_mods__curModInSlots : Object)
    for curModInSlot in equipment_mods__curModInSlots
      if curModInSlot.value ?? INVALID_ENTITY_ID == equipment_mod_eid
        res = convert_armor_equipment_mod_slot_name_to_part_name(curModInSlot.key)
        break
  return res


def process_armor_equipment_mod_equipped(equipment_mod_eid : EntityId;
                                         equipment_eid : EntityId;
                                         actor_eid : EntityId)
  query(equipment_mod_eid) <| $ [es(REQUIRE=slot_attach__attachedTo)] (var dm_part_armor__partName : das_string)
    query(actor_eid) <| $ [es] (var human_damage_model__armorMods : EidList;
                                var human_damage_model__parts : Object)
      let prevPartName := string(dm_part_armor__partName)
      let newPartName = calculate_armor_equipment_mod_part_name(equipment_mod_eid, equipment_eid)
      dm_part_armor__partName := newPartName

      if human_damage_model__armorMods |> find_index(equipment_mod_eid) < 0
        human_damage_model__armorMods |> push(equipment_mod_eid)

      recalculate_protection_for_part(prevPartName, human_damage_model__armorMods, human_damage_model__parts)
      recalculate_protection_for_part(newPartName, human_damage_model__armorMods, human_damage_model__parts)


def process_armor_equipment_mod_unequipped(equipment_mod_eid : EntityId;
                                           actor_eid : EntityId)
  query(equipment_mod_eid) <| $ [es] (var dm_part_armor__partName : das_string)
    query(actor_eid) <| $ [es] (var human_damage_model__armorMods : EidList;
                                var human_damage_model__parts : Object)
      let equipmentModIndex = human_damage_model__armorMods |> find_index(equipment_mod_eid)
      if equipmentModIndex < 0
        return

      human_damage_model__armorMods |> erase(equipmentModIndex)

      let prevPartName := string(dm_part_armor__partName)
      dm_part_armor__partName := ""

      recalculate_protection_for_part(prevPartName, human_damage_model__armorMods, human_damage_model__parts)


def process_armor_equipment_mods_swapped(first_equipment_mod_eid, second_equipment_mod_eid : EntityId;
                                         actor_eid : EntityId)
  query(first_equipment_mod_eid) <| $ [es(REQUIRE=slot_attach__attachedTo)] (var dm_part_armor__partName aka first_dm_part_armor__partName : das_string)
    query(second_equipment_mod_eid) <| $ [es(REQUIRE=slot_attach__attachedTo)] (var dm_part_armor__partName aka second_dm_part_armor__partName : das_string)
      query(actor_eid) <| $ [es] (human_damage_model__armorMods : EidList;
                                  var human_damage_model__parts : Object)
        let firstPartName := string(first_dm_part_armor__partName)
        let secondPartName := string(second_dm_part_armor__partName)
        first_dm_part_armor__partName := secondPartName
        second_dm_part_armor__partName := firstPartName

        recalculate_protection_for_part(firstPartName, human_damage_model__armorMods, human_damage_model__parts)
        recalculate_protection_for_part(secondPartName, human_damage_model__armorMods, human_damage_model__parts)


[es(tag=server, on_appear, REQUIRE=(equipment_mod_item, dm_part_armor__protection), after=add_mod_to_equipment_mod_slot_on_appear)]
def armor_equipment_mod_appear(evt : Event;
                               eid aka equipment_mod_eid : EntityId;
                               slot_attach__attachedTo aka mod_slot_attach__attachedTo : EntityId)
  query(mod_slot_attach__attachedTo) <| $ [es] (slot_attach__attachedTo aka equipment_slot_attach__attachedTo : EntityId)
    query(equipment_slot_attach__attachedTo) <| $ [es(REQUIRE=human_damage_model__armorMods)] ()
      process_armor_equipment_mod_equipped(equipment_mod_eid, mod_slot_attach__attachedTo, equipment_slot_attach__attachedTo)


[es(tag=server, on_disappear, REQUIRE=(equipment_mod_item, dm_part_armor__protection))]
def armor_equipment_mod_disappear(evt : Event;
                                  eid aka equipment_mod_eid : EntityId;
                                  slot_attach__attachedTo aka mod_slot_attach__attachedTo : EntityId)
  query(mod_slot_attach__attachedTo) <| $ [es] (slot_attach__attachedTo aka equipment_slot_attach__attachedTo : EntityId)
    query(equipment_slot_attach__attachedTo) <| $ [es(REQUIRE=human_damage_model__armorMods)] ()
      process_armor_equipment_mod_unequipped(equipment_mod_eid, equipment_slot_attach__attachedTo)


[es(tag=server, REQUIRE=human_damage_model__armorMods)]
def armor_equipment_mod_equipped(evt : EventOnEquipmentModEquippedToHero;
                                 eid aka actor_eid : EntityId)
  query(evt.equipmentModEid) <| $ [es(REQUIRE=(equipment_mod_item, dm_part_armor__protection))] ()
    process_armor_equipment_mod_equipped(evt.equipmentModEid, evt.equipmentEid, actor_eid)


[es(tag=server, REQUIRE=human_damage_model__armorMods)]
def armor_equipment_mod_unequipped(evt : EventOnEquipmentModUnequippedFromHero;
                                   eid aka actor_eid : EntityId)
  query(evt.equipmentModEid) <| $ [es(REQUIRE=(equipment_mod_item, dm_part_armor__protection))] ()
    process_armor_equipment_mod_unequipped(evt.equipmentModEid, actor_eid)


[es(tag=server, REQUIRE=human_damage_model__armorMods)]
def armor_equipment_mod_swapped(evt : EventOnEquipmentModSwap;
                                eid aka actor_eid : EntityId)
  if !evt.firstEquipmentModEid || !evt.secondEquipmentModEid
    let modEid = !!evt.firstEquipmentModEid ? evt.firstEquipmentModEid : evt.secondEquipmentModEid
    let equipmentEid = !!evt.firstEquipmentModEid ? evt.firstEquipmentEid : evt.secondEquipmentEid
    query(modEid) <| $ [es(REQUIRE=(equipment_mod_item, dm_part_armor__protection))] ()
      process_armor_equipment_mod_equipped(modEid, equipmentEid, actor_eid)
  else
    query(evt.firstEquipmentModEid) <| $ [es(REQUIRE=(equipment_mod_item, dm_part_armor__protection))] ()
      query(evt.secondEquipmentModEid) <| $ [es(REQUIRE=(equipment_mod_item, dm_part_armor__protection))] ()
        process_armor_equipment_mods_swapped(evt.firstEquipmentModEid, evt.secondEquipmentModEid, actor_eid)


[es(tag=server, track=item__hp, REQUIRE=(equipment_mod_item, item__hp, dm_part_armor__protection))]
def armor_equipment_mod_hp_changed(evt : Event;
                                   dm_part_armor__partName : string;
                                   slot_attach__attachedTo aka mod_slot_attach__attachedTo : EntityId)
  query(mod_slot_attach__attachedTo) <| $ [es] (slot_attach__attachedTo aka equipment_slot_attach__attachedTo : EntityId)
    query(equipment_slot_attach__attachedTo) <| $ [es] (human_damage_model__armorMods : EidList;
                                                        var human_damage_model__parts : Object)
      recalculate_protection_for_part(dm_part_armor__partName, human_damage_model__armorMods, human_damage_model__parts)


