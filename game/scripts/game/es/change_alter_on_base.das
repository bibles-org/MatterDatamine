require ecs
require strings
require ecs.safe
require DngNet
require game.events.events_active_matter
require game.events.inventory_events
require game.es.inventory_equipment_common
require game.es.inventory_equipment_mod_common
require game.es.inventory_transactions_common


[es(tag=gameClient)]
def change_alter_on_base(evt : EventEquipAlter; possessed : EntityId)
  if evt.chronogenesList == null || !(find_query() <| $ [es(REQUIRE=player_base)] () => true)
    return

  var stashEid = INVALID_ENTITY_ID
  query() <| $ [es] (player_on_base_components__stashEid : EntityId)
    stashEid = player_on_base_components__stashEid

  var profileServerStashSlotName = ""
  query(stashEid) <| $ [es] (profile_server__slotName : string)
    profileServerStashSlotName = profile_server__slotName

  let primaryChronogenesArray = (*evt.chronogenesList) |> get_ecs_array("primaryChronogenes")
  if primaryChronogenesArray == null || length(*primaryChronogenesArray) == 0
    return

  let secondaryChronogenesArray = (*evt.chronogenesList) |> get_ecs_array("secondaryChronogenes")
  if secondaryChronogenesArray == null
    return

  query(possessed) <| $ [es] (var human_equipment__slots : Object&)
    for slot in human_equipment__slots
      let equipmentEid = slot.value ?? INVALID_ENTITY_ID
      if slot.key |> starts_with("chronogene_primary_")
        let primaryIndex = to_int(slice(slot.key, -1), true)
        if length(*primaryChronogenesArray) >= primaryIndex
          let chronogeneId = (*primaryChronogenesArray)[primaryIndex - 1] ?? "0"
          var isSame = false
          query(equipmentEid) <| $ [es] (uniqueId : string)
            isSame = uniqueId == chronogeneId

          if isSame
            continue

          find_query() <| $ [es] (eid aka chronogene_eid : EntityId;
                                  uniqueId : string)
            if chronogeneId == uniqueId

              query(equipmentEid) <| $ [es] (equipment_mods__curModInSlots : Object&)
                var mods : array<EntityId>
                for mod in equipment_mods__curModInSlots
                  let equipmentModEid = mod.value ?? INVALID_ENTITY_ID
                  if equipmentModEid != INVALID_ENTITY_ID
                    mods |> push(equipmentModEid)
                for equipmentModEid in mods
                  unequip_equipment_mod_from_slot(equipmentModEid, equipmentEid, possessed, stashEid)

              equip_equipment_to_slot(chronogene_eid, slot.key, possessed, stashEid)
              update_all_items_on_item_move_transaction(uniqueId, chronogene_eid, "", "{EQUIPMENT_PREFIX}{slot.key}")
              return true
            return false
        else
          return // all primary chronogenes must be installed
      elif slot.key |> starts_with("chronogene_secondary_")
        let secondaryIndex = to_int(slice(slot.key, -1), true)
        if length(*secondaryChronogenesArray) >= secondaryIndex
          let chronogeneId = (*secondaryChronogenesArray)[secondaryIndex - 1] ?? "0"
          if chronogeneId != "0"
            find_query() <| $ [es] (eid aka chronogene_eid : EntityId;
                                    uniqueId : string)
              if chronogeneId == uniqueId
                equip_equipment_to_slot(chronogene_eid, slot.key, possessed, stashEid)
                update_all_items_on_item_move_transaction(uniqueId, chronogene_eid, "", "{EQUIPMENT_PREFIX}{slot.key}")
                return true
              return false
          else
            unequip_equipment_from_slot(slot.key, possessed, stashEid)
        else
          unequip_equipment_from_slot(slot.key, possessed, stashEid)
