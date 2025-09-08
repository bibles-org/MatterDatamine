require ecs
require ecs.common
require game.events.events
require game.events.vehicle_events
require game.es.vehicle.vehicle_seats_common
require DngActor
require DngHuman
require DngNet


[es(tag=netClient)]
def vehicle_seats_enter_exit_seat_client_es(evt : CmdAcquireVehicleSeat;
                                            eid : EntityId)
  send_net_event(eid, RequestVehicleSeat(requester = evt.requester, seat_no = evt.seat_no))


[es(tag=server, REQUIRE=vehicle_seats__seats)]
def vehicle_seats_enter_exit_seat_request_es(evt : RequestVehicleSeat;
                                             eid : EntityId)
  sendEvent(eid, CmdAcquireVehicleSeat(requester = evt.requester, seat_no = evt.seat_no))


def private attach_human_to_seat(eid : EntityId; vehicleEid : EntityId; seat__component : int; should_hide : bool = false)
  let hasVehicle = vehicleEid != INVALID_ENTITY_ID

  query(eid) <| $ [es] (var isInVehicle : bool&;
                        var isInVehicleHidden : bool&;
                        var human_anim__vehicleSelected : EntityId&)
    isInVehicle = hasVehicle
    isInVehicleHidden = should_hide && hasVehicle
    human_anim__vehicleSelected = vehicleEid

  setOptional(eid, "", uint(seat__component), hasVehicle)


[es(tag=server, REQUIRE_NOT=deadEntity)]
def vehicle_seats_enter_exit_seat_server_es(evt : CmdAcquireVehicleSeat;
                                            eid : EntityId;
                                            vehicle_seats__seatEids : EidList;
                                            vehicle_seats_hide_owner : BoolList)
  let requester     = evt.requester
  let requestSeatNo = evt.seat_no

  let canTakeSeat = get_bool(requester, "human_vehicle__can_take_seat") ?? true
  if (!canTakeSeat)
    return

  if !(requestSeatNo >= 0 && requestSeatNo < length(vehicle_seats__seatEids))
    return

  let reqSeatEid : EntityId = vehicle_seats__seatEids[ requestSeatNo ]

  let adjacentSeatNo = get_int(reqSeatEid, "seat__adjacentSeat") ?? -1
  if adjacentSeatNo > -1
    let adjacentSeatEid = vehicle_seats__seatEids[ adjacentSeatNo ]
    let adjacentSeatOwnerEid = get_Eid(adjacentSeatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID
    if adjacentSeatOwnerEid != INVALID_ENTITY_ID && (get_bool(adjacentSeatOwnerEid, "isAlive") ?? false)
      return

  let playerEid = get_Eid(requester, "possessedByPlr") ?? INVALID_ENTITY_ID
  if playerEid == INVALID_ENTITY_ID
    query(reqSeatEid) <| $ [es] (seat__component : int;
                                 var seat__isPlayer : bool&;
                                 var seat__ownerEid : EntityId&;
                                 var seat__playerEid : EntityId&)
      if seat__ownerEid != INVALID_ENTITY_ID
        if !(get_bool(seat__ownerEid, "isAlive") ?? true)
          kick_from_vehicle(seat__ownerEid, eid, vehicle_seats__seatEids)
        else
          return

      seat__isPlayer  = false
      seat__ownerEid  = requester
      seat__playerEid = INVALID_ENTITY_ID

      attach_human_to_seat(requester, eid, seat__component, vehicle_seats_hide_owner[ requestSeatNo ])

      send_enter_vehicle_event(requester, eid, requestSeatNo, true)
    return

  let seatOwnerEid  = get_Eid(reqSeatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID
  let seatPlayerEid = get_Eid(reqSeatEid, "seat__playerEid") ?? INVALID_ENTITY_ID
  let isOwnerAlive  = get_bool(seatOwnerEid, "isAlive") ?? true
  if isOwnerAlive && seatOwnerEid != INVALID_ENTITY_ID && seatPlayerEid != playerEid
    return

  // query to see if we're already in some vehicle and block our request then
  let alreadyInVehicle = find_query() <| $ [es] (vehicle_seats__seatEids aka that_vehicle_seats__seatEids : EidList)
    for thatSeatEid in that_vehicle_seats__seatEids
      if (get_Eid(thatSeatEid, "seat__ownerEid") ?? INVALID_ENTITY_ID) == requester
        return true
    return false

  if alreadyInVehicle
    return

  if seatOwnerEid != INVALID_ENTITY_ID
    kick_from_vehicle(seatOwnerEid, eid, vehicle_seats__seatEids)

  query(reqSeatEid) <| $ [es] (seat__component : int;
                               var seat__isPlayer : bool&;
                               var seat__ownerEid : EntityId&;
                               var seat__playerEid : EntityId&)
    seat__isPlayer  = true
    seat__ownerEid  = requester
    seat__playerEid = playerEid

    attach_human_to_seat(requester, eid, seat__component, vehicle_seats_hide_owner[ requestSeatNo ])

    query(requester) <| $ [es] (var human_net_phys : HumanActor&)
      human_net_phys |> base_phys_actor_resetAAS()

    send_enter_vehicle_event(requester, eid, requestSeatNo, true)
