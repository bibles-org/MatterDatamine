require ecs
require ecs.common
require game.events.inventory_events
require DagorMath
require DagorSystem
require game.es.inventory_checks_common


[es(tag=server, REQUIRE=heroForPlayer)]
def item_extra_inventory_equipped(evt : EventOnEquipmentEquipped;
                                  var inventories_owner__inventoryEids : EidList)
  query(evt.equipmentEid) <| $ [es(REQUIRE=inventory__name, REQUIRE_NOT=passive_chronogenes_stash)] ()
    inventories_owner__inventoryEids |> push(evt.equipmentEid)


[es(tag=server, REQUIRE=heroForPlayer)]
def item_extra_inventory_unequipped(evt : EventOnEquipmentUnequipped;
                                    var inventories_owner__inventoryEids : EidList)
  query(evt.equipmentEid) <| $ [es(REQUIRE=inventory__name, REQUIRE_NOT=passive_chronogenes_stash)] ()
    let idx = inventories_owner__inventoryEids |> find_index(evt.equipmentEid)
    if idx >= 0
      inventories_owner__inventoryEids |> erase(idx)


[es(tag=server, REQUIRE=inventory__name, on_event=EventEntityCreated, REQUIRE_NOT=passive_chronogenes_stash)]
def item_equipped_extra_inventory_appear(evt : Event;
                                         eid, slot_attach__attachedTo : EntityId)
  query(slot_attach__attachedTo) <| $ [es(REQUIRE=heroForPlayer)] (var inventories_owner__inventoryEids : EidList)
    inventories_owner__inventoryEids |> push(eid)


[es(tag=server, track=inventories_owner__inventoryEids)]
def militant_extra_inventories_track_backpack_eid(evt : Event;
                                                  inventories_owner__inventoryEids : EidList;
                                                  var militant_extra_inventories__backpackEid : EntityId&)
  militant_extra_inventories__backpackEid = INVALID_ENTITY_ID
  for extraInventoryEid in inventories_owner__inventoryEids
    if is_backpack(extraInventoryEid)
      militant_extra_inventories__backpackEid = extraInventoryEid


[es(tag=server, track=inventories_owner__inventoryEids)]
def militant_extra_inventories_track_safepack_eid(evt : Event;
                                                  inventories_owner__inventoryEids : EidList;
                                                  var militant_extra_inventories__safepackEid : EntityId&)
  militant_extra_inventories__safepackEid = INVALID_ENTITY_ID
  for extraInventoryEid in inventories_owner__inventoryEids
    if is_safepack(extraInventoryEid)
      militant_extra_inventories__safepackEid = extraInventoryEid


[es(tag=server, on_appear, REQUIRE=itemContainer)]
def add_main_inventory_to_inventory_list(evt : Event;
                                         eid : EntityId;
                                         var inventories_owner__inventoryEids : EidList;
                                         var inventory__humanOwnerEid : EntityId&)
  inventories_owner__inventoryEids |> push(eid)
  inventory__humanOwnerEid = eid


[es(tag=server, on_appear, track=item__humanOwnerEid)]
def set_inventory_owner_on_item_owner_change(evt : Event; item__humanOwnerEid : EntityId; var inventory__humanOwnerEid : EntityId&)
  inventory__humanOwnerEid = item__humanOwnerEid