require ecs
require ecs.safe
require ecs.common
require strings
require game.es.item_equip_common
require game.events.inventory_events
require game.events.events_active_matter
require game.es.damage_systems.damage_model_armor_common
require DagorMath
require DagorSystem


def process_armor_equipment_item_equipped(equipment_eid : EntityId;
                                          actor_eid : EntityId)
  query(equipment_eid) <| $ [es(REQUIRE=slot_attach__attachedTo)] (dm_part_armor__partName : string)
    query(actor_eid) <| $ [es] (var human_damage_model__armorMods : EidList;
                                var human_damage_model__parts : Object)
      if human_damage_model__armorMods |> find_index(equipment_eid) < 0
        human_damage_model__armorMods |> push(equipment_eid)

      recalculate_protection_for_part(dm_part_armor__partName, human_damage_model__armorMods, human_damage_model__parts)


def process_armor_equipment_item_unequipped(equipment_eid : EntityId;
                                            actor_eid : EntityId)
  query(equipment_eid) <| $ [es] (dm_part_armor__partName : string)
    query(actor_eid) <| $ [es] (var human_damage_model__armorMods : EidList;
                                var human_damage_model__parts : Object)
      let equipmentIndex = human_damage_model__armorMods |> find_index(equipment_eid)
      if equipmentIndex < 0
        return

      human_damage_model__armorMods |> erase(equipmentIndex)

      recalculate_protection_for_part(dm_part_armor__partName, human_damage_model__armorMods, human_damage_model__parts)


[es(tag=server, on_appear, REQUIRE=(equipment_item, dm_part_armor__protection))]
def armor_equipment_item_appear(evt : Event;
                                eid aka equipment_eid : EntityId;
                                slot_attach__attachedTo aka equipment_slot_attach__attachedTo : EntityId)
  query(equipment_slot_attach__attachedTo) <| $ [es(REQUIRE=human_damage_model__armorMods)] ()
    process_armor_equipment_item_equipped(equipment_eid, equipment_slot_attach__attachedTo)


[es(tag=server, on_disappear, REQUIRE=(equipment_item, dm_part_armor__protection), before=unequip_equipment_on_destroy)]
def armor_equipment_item_disappear(evt : Event;
                                   eid aka equipment_eid : EntityId;
                                   slot_attach__attachedTo aka equipment_slot_attach__attachedTo : EntityId)
  query(equipment_slot_attach__attachedTo) <| $ [es(REQUIRE=human_damage_model__armorMods)] ()
    process_armor_equipment_item_unequipped(equipment_eid, equipment_slot_attach__attachedTo)


[es(tag=server, REQUIRE=human_damage_model__armorMods)]
def armor_equipment_item_equipped(evt : EventOnEquipmentEquipped;
                                  eid aka actor_eid : EntityId)
  query(evt.equipmentEid) <| $ [es(REQUIRE=(equipment_item, dm_part_armor__protection))] ()
    process_armor_equipment_item_equipped(evt.equipmentEid, actor_eid)


[es(tag=server, REQUIRE=human_damage_model__armorMods)]
def armor_equipment_item_unequipped(evt : EventOnEquipmentUnequipped;
                                    eid aka actor_eid : EntityId)
  query(evt.equipmentEid) <| $ [es(REQUIRE=(equipment_item, dm_part_armor__protection))] ()
    process_armor_equipment_item_unequipped(evt.equipmentEid, actor_eid)


[es(tag=server, track=item__hp, REQUIRE=(equipment_item, item__hp, dm_part_armor__protection))]
def armor_equipment_item_hp_changed(evt : Event;
                                    dm_part_armor__partName : string;
                                    slot_attach__attachedTo aka equipment_slot_attach__attachedTo : EntityId)
  query(equipment_slot_attach__attachedTo) <| $ [es] (human_damage_model__armorMods : EidList;
                                                      var human_damage_model__parts : Object)
    recalculate_protection_for_part(dm_part_armor__partName, human_damage_model__armorMods, human_damage_model__parts)

