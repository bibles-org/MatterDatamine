require ecs
require ecs.common
require math
require game.events.events
require game.events.events_active_matter
require game.events.events_game
require DagorSystem
require game.es.fuel_common
require game.events.inventory_events
require game.events.vehicle_events

def find_fuel_in_inventory(itemContainer : EidList) : ecs::EntityId
  for itemEid in itemContainer
    if has(itemEid, "jetpack_fuel__amount")
      return itemEid
  return INVALID_ENTITY_ID


[es(tag=server, track=jetpack__fuel, track=item__containerOwnerEid)]
def jetpack_on_zero_fuel_es(evt : Event;
                            jetpack__fuel, jetpack__maxFuel : float;
                            item__containerOwnerEid : EntityId;
                            jetpack__fuelAutoUse : bool = false)
  if jetpack__fuelAutoUse && jetpack__fuel == 0.0 && jetpack__maxFuel > 0.0
    ecs::query(item__containerOwnerEid) <| $ [es] (itemContainer : EidList; isInVehicle : bool)
      if !isInVehicle
        let fuelEid = find_fuel_in_inventory(itemContainer)
        if fuelEid != INVALID_ENTITY_ID
          sendEvent(fuelEid, EventOnLootItemUsed(target = item__containerOwnerEid))


[es(tag=server)]
def jetpack_fuel_pickup_es(evt : EventOnItemPickup; eid, human_jetpack__eid : EntityId; isInVehicle : bool)
  if isInVehicle
    return
  let fuelAmount = get_float(evt.itemEid, "jetpack_fuel__amount") ?? 0.0
  if fuelAmount <= 0.0
    return
  ecs::query(human_jetpack__eid) <| $ [es] (jetpack__fuel, jetpack__maxFuel : float; jetpack__fuelAutoUse : bool = false)
    if jetpack__fuelAutoUse && jetpack__fuel == 0.0 && jetpack__maxFuel > 0.0
      sendEvent(evt.itemEid, EventOnLootItemUsed(target = eid))


[es(track=human_jetpack__eid)]
def check_fuel_on_jetpack_change_es(evt : Event; eid, human_jetpack__eid : EntityId; itemContainer : EidList; isInVehicle : bool)
  if isInVehicle
    return
  ecs::query(human_jetpack__eid) <| $ [es] (jetpack__fuel, jetpack__maxFuel : float; jetpack__fuelAutoUse : bool = false)
    if jetpack__fuelAutoUse && jetpack__fuel == 0.0 && jetpack__maxFuel > 0.0
      let fuelEid = find_fuel_in_inventory(itemContainer)
      if fuelEid != INVALID_ENTITY_ID
        sendEvent(fuelEid, EventOnLootItemUsed(target = eid))


[es(tag=server, REQUIRE=eid)]
def check_fuel_on_exiting_vehicle_es(evt : EventEnterVehicle)
  if !evt.enter
    query(evt.incomer) <| $ [es] (human_jetpack__eid : EntityId; itemContainer : EidList)
      ecs::query(human_jetpack__eid) <| $ [es] (jetpack__fuel, jetpack__maxFuel : float; jetpack__fuelAutoUse : bool = false)
        if jetpack__fuelAutoUse && jetpack__fuel == 0.0 && jetpack__maxFuel > 0.0
          let fuelEid = find_fuel_in_inventory(itemContainer)
          if fuelEid != INVALID_ENTITY_ID
            sendEvent(fuelEid, EventOnLootItemUsed(target = evt.incomer))


[es(tag=server)]
def jetpack_fuel_used_es(evt : EventOnLootItemUsed; eid : EntityId; jetpack_fuel__amount : float)
  ecs::query(evt.target) <| $ [es] (human_jetpack__eid : EntityId; isInVehicle : bool)
    if !isInVehicle
      ecs::query(human_jetpack__eid) <| $ [es] (var jetpack__fuel : float&; jetpack__maxFuel : float)
        if jetpack__fuel < jetpack__maxFuel && jetpack__maxFuel > 0.0
          if use_fuel_from_inventory(eid, evt.target)
            jetpack__fuel = min(jetpack__fuel + jetpack_fuel__amount, jetpack__maxFuel)


[es(tag=gameClient, track=itemContainer)]
def human_jetpack_inventory_fuel_es(evt : Event;
                                    itemContainer : EidList;
                                    var human_jetpack__inventoryFuelCount : int&;
                                    var human_jetpack__inventoryFuelAmount : float&)
  human_jetpack__inventoryFuelCount = 0
  human_jetpack__inventoryFuelAmount = 0.0
  for itemEid in itemContainer
    let itemFuelAmount = get_float(itemEid, "jetpack_fuel__amount") ?? 0.0
    if itemFuelAmount > 0.0
      human_jetpack__inventoryFuelCount += 1
      human_jetpack__inventoryFuelAmount += itemFuelAmount


[es(tag=gameClient, after=human_phys_es, REQUIRE=watchedByPlr)]
def human_jetpack_fuel_es(info : ParallelUpdateFrameDelayed;
                          human_jetpack__eid : EntityId;
                          var human_jetpack__fuel : float&;
                          var human_jetpack__maxFuel : float&;
                          human_jetpack__inventoryFuelCount : int;
                          var human_jetpack__fuelAlert : bool&;
                          human_jetpack__fuelAmountForAlert : float = 3.0)
  human_jetpack__fuel = 0f
  human_jetpack__maxFuel = 0f
  ecs::query(human_jetpack__eid) <| $ [es] (jetpack__fuel, jetpack__maxFuel, jetpack__fuelUse : float;
                                            jetpack__isInAir : bool)
    if jetpack__fuelUse == 0.0
      return
    human_jetpack__fuel = jetpack__fuel
    human_jetpack__maxFuel = jetpack__maxFuel
    let notEnoughFuel = human_jetpack__fuel <= human_jetpack__fuelAmountForAlert
    let notEnoughFuelInInventory = human_jetpack__inventoryFuelCount == 0
    human_jetpack__fuelAlert = jetpack__isInAir && notEnoughFuel && notEnoughFuelInInventory


[es(tag=server, before=human_phys_es)]
def jetpack_fuel_restore_es(info : ParallelUpdateFrameDelayed;
                            jetpack__isInAir : bool;
                            var jetpack__fuel : float&;
                            jetpack__maxFuel : float;
                            jetpack__fuelRestore : float)
  if !jetpack__isInAir
    jetpack__fuel = min(jetpack__fuel + jetpack__fuelRestore * info.dt, jetpack__maxFuel)
