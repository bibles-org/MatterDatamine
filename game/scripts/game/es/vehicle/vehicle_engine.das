require ecs
require ecs.safe
require vehicle
require game.events.events_active_matter


[es(tag=server, no_order)]
def vehicle_phys_update_state(evt : ParallelUpdateFrameDelayed;
                              vehicle_net_phys : VehiclePhysActor;
                              var vehicle_net_phys__isEngineDestroyed : bool&)
  // needed if someone fixes engine while driver is still in car
  vehicle_net_phys__isEngineDestroyed = vehicle_net_phys.phys.engineReadyness < 0.01


[es(on_appear, on_event=EventOnSeatOwnersChanged, track=vehicle_net_phys__isEngineDestroyed)]
def vehicle_phys_update_engine_state(evt : Event;
                                     vehicle_seats__seatEids : EidList;
                                     @shared_comp vehicle_seats__seats : Array;
                                     vehicle_net_phys__isEngineDestroyed : bool;
                                     var vehicle_net_phys : VehiclePhysActor&)
  var hasCrew = false
  for i in iter_range(vehicle_seats__seats)
    let seatIsDriver = (vehicle_seats__seats[i] as Object)?.seatOwnsEntityControl ?? false
    if seatIsDriver && i < length(vehicle_seats__seatEids) // in case seats are not yet created
      // Note that this does not check if driver is alive, so engine will not stop when driver dies
      query(vehicle_seats__seatEids[i]) <| $ [es] (seat__isPlayer : bool)
        hasCrew ||= seat__isPlayer
    if hasCrew
      break

  let isEngineWorking = hasCrew && !vehicle_net_phys__isEngineDestroyed

  vehicle_net_phys.phys.disableEngineOmega = !isEngineWorking // TODO: in vehiclePhys disable omega when isICEWorking=false
  vehicle_phys_setIsICEWorking(vehicle_net_phys.phys, isEngineWorking)
