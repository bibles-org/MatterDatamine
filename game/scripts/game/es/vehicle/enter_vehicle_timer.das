require ecs
require game.events.events
require game.es.vehicle.vehicle_seats_common
require game.events.events_active_matter

[es(tag=server, no_order)]
def enter_vehicle_timer_es(info : ParallelUpdateFrameDelayed;
                           eid : EntityId;
                           isAlive : bool;
                           isDowned : bool;
                           possessedByPlr : EntityId;
                           enter_vehicle__vehicleEid : EntityId;
                           var enter_vehicle__atTime : float&;
                           var enter_vehicle__isInitDataSaved : bool&)
  if enter_vehicle__atTime < 0.f
    return
  if possessedByPlr == INVALID_ENTITY_ID || isDowned || !isAlive
    enter_vehicle__atTime = -1.f
    return
  if info.curTime < enter_vehicle__atTime
    return
  enter_vehicle__atTime = -1.f
  query(enter_vehicle__vehicleEid) <| $ [es] (vehicle_seats__seatEids : EidList)
    let requestSeatNo = find_highest_free_seat(possessedByPlr, vehicle_seats__seatEids)
    if requestSeatNo < 0
      return
    enter_vehicle_now(eid, enter_vehicle__vehicleEid, requestSeatNo)
    enter_vehicle__isInitDataSaved = false
