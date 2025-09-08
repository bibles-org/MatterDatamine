require ecs
require app
require math.base
require game.events.vehicle_events
require DagorSystem
require DngNet
require vehicle
require game.utils.net_utils
require game.events.events_active_matter
require game.es.fuel_common
require game.events.events


[es(tag=server, no_order)]
def vehicle_fuel_es(act : CmdPostPhysUpdate;
                    vehicle__fuelUse : float;
                    vehicle__currentDriver : EntityId;
                    vehicle__fuelAutoUse : bool;
                    vehicle_net_phys : VehiclePhysActor;
                    var vehicle__refuelingInProgress : bool&;
                    var vehicle__fuel : float&)
  assume state = vehicle_net_phys.phys.currentState
  if abs(state.throttle) > FLT_EPSILON
    vehicle__fuel = max(0.0, vehicle__fuel - vehicle__fuelUse * act.dt)
  if vehicle__fuel == 0.0 && !vehicle__refuelingInProgress && vehicle__fuelAutoUse
    let fuelEid = find_vehicle_fuel_in_inventory(vehicle__currentDriver)
    if fuelEid != INVALID_ENTITY_ID
      sendEvent(fuelEid, EventOnLootItemUsed(target = vehicle__currentDriver))
      vehicle__refuelingInProgress = true


[es(after=vehicle_fuel_es)]
def vehicle_fuel_engine_effect(act : CmdPostPhysUpdate;
                               vehicle__fuelUse : float;
                               vehicle__fuel : float&;
                               var vehicle_net_phys : VehiclePhysActor)
  vehicle_net_phys.phys.maxMomentMult = vehicle__fuelUse <= 0.0 || vehicle__fuel > 0.0 ? 1.0 : 0.0


[es(tag=gameClient, no_order)]
def vehicle_fuel_alert_es(act : CmdPostPhysUpdate;
                          vehicle_net_phys : VehiclePhysActor;
                          vehicle__currentDriver : EntityId;
                          vehicle__fuelAutoUse : bool;
                          vehicle__fuel : float;
                          vehicle__fuelAmountForAlert : float = 2.0;
                          var vehicle__fuelAlert : bool&)
  assume state = vehicle_net_phys.phys.currentState

  let notEnoughFuel = vehicle__fuel <= vehicle__fuelAmountForAlert
  var notEnoughFuelInInventory = true

  if vehicle__fuelAutoUse
    query(vehicle__currentDriver) <| $ [es] (vehicle__inventoryFuelAmount : float)
      notEnoughFuelInInventory = vehicle__inventoryFuelAmount == 0.0
  vehicle__fuelAlert = abs(state.throttle) > FLT_EPSILON && notEnoughFuel && notEnoughFuelInInventory


[es(tag=gameClient, track=itemContainer)]
def vehicle_inventory_fuel_es(evt : Event;
                              itemContainer : EidList;
                              var vehicle__inventoryFuelCount : int&;
                              var vehicle__inventoryFuelAmount : float&)
  vehicle__inventoryFuelCount = 0
  vehicle__inventoryFuelAmount = 0.0
  for itemEid in itemContainer
    let itemFuelAmount = get_float(itemEid, "vehicle_fuel__amount") ?? 0.0
    if itemFuelAmount > 0.0
      vehicle__inventoryFuelCount += 1
      vehicle__inventoryFuelAmount += itemFuelAmount


[es(tag=server, before=jetpack_fuel_used_es)]
def vehicle_fuel_used_es(evt : EventOnLootItemUsed; eid : EntityId; vehicle_fuel__amount : float)
  ecs::query(evt.target) <| $ [es] (human_anim__vehicleSelected : EntityId)
    ecs::query(human_anim__vehicleSelected) <| $ [es] (var vehicle__fuel : float&; var vehicle__refuelingInProgress : bool&; vehicle__maxFuel : float)
      if vehicle__fuel < vehicle__maxFuel && vehicle__maxFuel > 0.0
        if use_fuel_from_inventory(eid, evt.target)
          vehicle__fuel = min(vehicle__fuel + vehicle_fuel__amount, vehicle__maxFuel)
          vehicle__refuelingInProgress = false