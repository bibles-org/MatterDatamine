require ecs
require ecs.common
require ecs.safe
require DagorSystem
require AnimV20
require DngWalkerai
require game.es.vehicle.vehicle_seats_common
require game.events.events_active_matter


[es(on_appear)]
def init_vehicle_seats_enum_var(evt : Event; vehicle_seats__enumVarName : string; var vehicle_seats__enumVarId : int&)
  if vehicle_seats__enumVarName != ""
    vehicle_seats__enumVarId = animV20_add_enum_value(vehicle_seats__enumVarName)

def get_seat_template(seat, seat_templates)
  let seatName = get_string(seat, "name", "default")
  let seatTemplate = get_string(seat_templates, seatName, "")
  if seatTemplate != ""
    return seatTemplate
  return get_string(seat_templates, "default", "")

[es(tag=server, on_appear)]
def create_vehicle_seats(evt : Event;
                         eid : EntityId;
                         @shared_comp vehicle_seats__seats : Array;
                         @shared_comp vehicle_seats__seatTemplates : Object;
                         var vehicle_seats__seatEids : EidList)
  resize(vehicle_seats__seatEids, length(vehicle_seats__seats))
  for seatNo, item in iter_range(vehicle_seats__seats), vehicle_seats__seats
    let seat = get_ecs_object(item)
    if seat == null
      continue

    let seatTemplate = get_seat_template(*seat, vehicle_seats__seatTemplates)
    if seatTemplate == ""
      let seatName = get_string(seat, "name", "default")
      logerr("Seat template not found for seat '{seatName}' in entity {eid} ({getEntityTemplateName(eid)})")
      continue

    let seatEid = createEntitySync(seatTemplate) <| $(var init : ComponentsInitializer)
      set(init, "seat__id", seatNo)
      set(init, "seat__vehicleEid", eid)
      if has(*seat, "canPlaceManually")
        set(init, "seats_order__canPlaceManually", seat?.canPlaceManually ?? false)

    vehicle_seats__seatEids[seatNo] = seatEid


[es(REQUIRE=walker_agent, REQUIRE_NOT=deadEntity)]
def kick_walkers_from_vehicle_es(info : ParallelUpdateFrameDelayed;
                                 eid : EntityId;
                                 human_anim__vehicleSelected : EntityId;
                                 isInVehicle : bool)
  if !isInVehicle
    return

  if human_anim__vehicleSelected == INVALID_ENTITY_ID
    return

  let walkerEid = eid
  query(human_anim__vehicleSelected) <| $ [es] (eid : EntityId; vehicle_seats__seatEids : EidList; vehicle__isSafeToGetOut : bool = true)
    if !vehicle__isSafeToGetOut
      return
    var found = false
    for seatEid in vehicle_seats__seatEids
      query(seatEid) <| $ [es] (seat__ownerEid : EntityId; seat__isPlayer : bool)
        found = (seat__isPlayer || seat__ownerEid == INVALID_ENTITY_ID)
      if found
        return
    kick_from_vehicle(walkerEid, eid, vehicle_seats__seatEids)
