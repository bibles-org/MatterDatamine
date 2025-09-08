require ecs
require DngNet
require game.events.events
require game.events.vehicle_events
require game.events.events_active_matter
require game.es.vehicle.vehicle_seats_common
require game.utils.team
require game.events.events_game


[es(REQUIRE_NOT=deadEntity)]
def vehicle_seats_es_enter_exit(evt : CmdUse;
                                eid : EntityId;
                                vehicle_seats__seatEids : EidList;
                                vehicle_seats__exitTime : float = 0.f;
                                vehicle_seats__enterTime : float = 0.f;
                                vehicle_seats__restrictToTeam : int const?)
  let requester = evt.requesterEid
  query(requester) <| $ [es] (team : int;
                              isInVehicle : bool;
                              human_vehicle__can_take_seat : bool = true;
                              human_use_object__lockVehicleUse : bool = false)
    if !isInVehicle && (!human_vehicle__can_take_seat || human_use_object__lockVehicleUse)
      send_net_event(requester, ShowStatusTip(statusTip = "status_tip_can_not_vehicle_use"))
      return
    if (vehicle_seats__restrictToTeam != null) && (*vehicle_seats__restrictToTeam != TEAM_UNASSIGNED) && (*vehicle_seats__restrictToTeam != team)
      return

    if find_seat_with_owner(requester, vehicle_seats__seatEids) >= 0
      exit_vehicle(requester, eid, vehicle_seats__exitTime)
    elif get_bool(requester, "human_vehicle__can_take_seat") ?? true
      enter_vehicle(requester, eid, vehicle_seats__seatEids, vehicle_seats__enterTime)

[es(REQUIRE=vehicle_seats__seats)]
def vehicle_seats_use_req(evt : CmdUseVehicle; eid : EntityId)
  let requester = evt.requester
  let seatNo = evt.seat_no
  if (seatNo >= 0)
    sendEvent(eid, CmdAcquireVehicleSeat(requester = requester, seat_no = seatNo))

[es(on_event=EventEntityDied)]
def vehicle_seats_client_exit_on_die_es(evt : Event; eid : EntityId; isInVehicle : bool)
  if isInVehicle
    cancel_exit_timer(eid)
