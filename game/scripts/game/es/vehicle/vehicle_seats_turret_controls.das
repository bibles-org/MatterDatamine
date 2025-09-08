require ecs
require ecs.safe
require ecs.common
require strings
require DngNet
require game.events.events
require game.events.vehicle_events
require DagorSystem
require game.utils.hero
require game.utils.team
require game.utils.net_utils
require DngActor
require DngHuman
require DngWeapon
require vehicle
require app


[es(tag=server, on_appear)]
def init_vehicle_seats_controls(evt : Event;
                                seat__id : int;
                                seat__vehicleEid : EntityId;
                                var seat__availableControls : VehicleControlsState)
  query(seat__vehicleEid) <| $ [es] (@shared_comp vehicle_seats__seats : Array)
    let seat = get_ecs_object(vehicle_seats__seats, seat__id)
    if seat == null
      return

    seat__availableControls.canControlVehicle = (*seat).seatOwnsEntityControl ?? false


[es(tag=server, on_appear)]
def init_vehicle_seats_hatch_controls(evt : Event;
                                      seat__id : int;
                                      seat__vehicleEid : EntityId;
                                      var seat__availableHatchControls : VehicleControlsState)
  query(seat__vehicleEid) <| $ [es] (@shared_comp vehicle_seats__seats : Array)
    let seat = get_ecs_object(vehicle_seats__seats, seat__id)
    if seat == null
      return

    seat__availableHatchControls.canControlVehicle = (*seat).seatOwnsEntityControl ?? false
