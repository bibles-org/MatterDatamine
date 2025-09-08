require ecs
require ecs.common
require DagorSystem
require game.es.ecs_common
require game.events.inventory_events


def private remove_item_from_container(item_eid, container_eid : EntityId)
  query(container_eid) <| $ [es] (var itemContainer : EidList&)
    let idx = find_index(itemContainer, item_eid)
    if idx != -1
      itemContainer |> erase(idx)


def private move_item_to_container(item_eid, container_eid, last_container_eid : EntityId)

  if container_eid != INVALID_ENTITY_ID && container_eid == last_container_eid
    return

  // add to new container
  var addedToContainer = false
  query(container_eid) <| $ [es] (inventory__humanOwnerEid : EntityId;
                                  var itemContainer : EidList&)
    query(item_eid) <| $ [es] (var item__humanOwnerEid : EntityId&;
                               var item__recognizedByPlayers : EidList?)
      item__humanOwnerEid = inventory__humanOwnerEid
      if !has_value(itemContainer, item_eid)
        itemContainer |> push(item_eid)
      else
        print("Item {get_entity_info(item_eid)} is already in itemContainer {get_entity_info(container_eid)}")
      addedToContainer = true
      if item__recognizedByPlayers != null
        query(item__humanOwnerEid) <| $ [es] (possessedByPlr : EntityId)
          if possessedByPlr != INVALID_ENTITY_ID && !has_value(*item__recognizedByPlayers, possessedByPlr)
            *item__recognizedByPlayers |> push(possessedByPlr)
  if container_eid != INVALID_ENTITY_ID && !addedToContainer
    addSubTemplate(item_eid, "item_waiting_for_container_appear") <| $(var init)
      init |> set("item_waiting_for_container_appear", container_eid)
  else
    item_eid |> removeSubTemplate("item_waiting_for_container_appear")

  // remove from previous container
  remove_item_from_container(item_eid, last_container_eid)


// not on_appear, because we want skip removing of "item_waiting_for_container_appear"
[es(on_event=EventEntityCreated, REQUIRE_NOT=item_waiting_for_container_appear)]
def add_item_to_owners_container(evt : Event;
                                 eid, item__containerOwnerEid : EntityId)
  move_item_to_container(eid, item__containerOwnerEid, INVALID_ENTITY_ID)


[es(on_appear, REQUIRE=item_waiting_for_container_appear)]
def try_add_item_to_container_on_waiting_appear(evt : Event;
                                                eid, item_waiting_for_container_appear : EntityId)
  move_item_to_container(eid, item_waiting_for_container_appear, INVALID_ENTITY_ID)


[es(on_appear, REQUIRE=itemContainer)]
def process_items_that_waited_container(evt : Event;
                                        eid aka container_eid : EntityId)
  query() <| $ [es] (eid, item_waiting_for_container_appear : EntityId)
    if container_eid == item_waiting_for_container_appear
      move_item_to_container(eid, container_eid, INVALID_ENTITY_ID)


[es]
def add_item_to_owners_container_on_drop(evt : EventOnDropItem; eid : EntityId)
  move_item_to_container(eid, evt.newInventoryEid, evt.oldInventoryEid)


[es]
def add_item_to_owners_container_on_move(evt : EventOnMovingBetweenInventories; eid : EntityId)
  move_item_to_container(eid, evt.newInventoryEid, evt.oldInventoryEid)


[es]
def add_item_to_owners_container_on_item_unequipped(evt : EventOnUnequipingToInventory; eid : EntityId)
  move_item_to_container(eid, evt.newInventoryEid, INVALID_ENTITY_ID)


[es]
def add_item_to_owners_container_on_equipment_equipped(evt : EventOnEquipingAsEquipment; eid : EntityId)
  move_item_to_container(eid, INVALID_ENTITY_ID, evt.fromInventoryEid)


[es]
def add_item_to_owners_container_on_equipment_mod_equipped(evt : EventOnEquipingAsEquipmentMod; eid : EntityId)
  move_item_to_container(eid, INVALID_ENTITY_ID, evt.fromInventoryEid)


[es]
def add_item_to_owners_container_on_weapon_equipped(evt : EventOnEquipingAsWeapon; eid : EntityId)
  move_item_to_container(eid, INVALID_ENTITY_ID, evt.fromInventoryEid)


[es]
def add_item_to_owners_container_on_weapon_mod_equipped(evt : EventOnEquipingAsWeaponMod; eid : EntityId)
  move_item_to_container(eid, INVALID_ENTITY_ID, evt.fromInventoryEid)


[es(on_disappear)]
def remove_item_from_owners_container_on_destroy(evt : Event; eid, item__containerOwnerEid : EntityId)
  remove_item_from_container(eid, item__containerOwnerEid)
