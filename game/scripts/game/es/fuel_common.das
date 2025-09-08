module fuel_common shared
require ecs
require ecs.common
require game.es.inventory_common
require game.events.events_game
require game.events.events


def find_vehicle_fuel_in_inventory(actor_eid : EntityId) : ecs::EntityId
  return find_item_with_comp(actor_eid, "vehicle_fuel__amount")


def use_fuel_from_inventory(fuel_eid : EntityId;
                            actor_eid : EntityId)
  if is_actor_has_item(actor_eid, fuel_eid)
    sendEventImmediate(actor_eid, EventOnLootUse(itemEid = fuel_eid))
    destroyEntity(fuel_eid)
    return true
  return false