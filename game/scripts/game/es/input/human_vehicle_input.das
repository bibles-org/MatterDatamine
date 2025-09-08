require ecs
require strings
require game.events.input_events
require game.events.vehicle_events
require DagorInput
require HumanPhys


def init(human_input__seatCount : int;
         var human_input__seats : IntList&;
         var human_input__seatNext : int&;
         var human_input__driverSeat : int&;
         var human_input__vehicleMaintenance : int&)
  if length(human_input__seats) != human_input__seatCount
    human_input__seats |> resize(human_input__seatCount)
  human_input__seatNext            = int(get_action_handle("Human.SeatNext", TYPEGRP_DIGITAL))
  human_input__driverSeat          = int(get_action_handle("Human.DriverSeat", TYPEGRP_DIGITAL))
  human_input__vehicleMaintenance  = int(get_action_handle("Human.VehicleMaintenance", TYPEGRP_DIGITAL))
  for i in range(0, human_input__seatCount)
    let seatNum = i < 9 ? "0{i + 1}" : "{i + 1}" // 01, 02, 03 ... 09, 10, 11 ...
    human_input__seats[i]          = int(get_action_handle("Human.Seat{seatNum}", TYPEGRP_DIGITAL))



def reset(human_input__seatCount : int;
          var human_input__seats : IntList&;
          var human_input__seatNext : int&;
          var human_input__driverSeat : int&;
          var human_input__vehicleMaintenance : int&)
  if length(human_input__seats) != human_input__seatCount
    human_input__seats |> resize(human_input__seatCount)
  human_input__seatNext            = int(BAD_ACTION_HANDLE)
  human_input__driverSeat          = int(BAD_ACTION_HANDLE)
  human_input__vehicleMaintenance  = int(BAD_ACTION_HANDLE)
  for i in range(0, human_input__seatCount)
    human_input__seats[i]          = int(BAD_ACTION_HANDLE)

[es(tag=input, on_appear)]
def vehicle_input_appear_es(evt : Event;
                            human_input__seatCount : int;
                            var human_input__seats : IntList&;
                            var human_input__seatNext : int&;
                            var human_input__driverSeat : int&;
                            var human_input__vehicleMaintenance : int&)
  init(human_input__seatCount, human_input__seats, human_input__seatNext,
       human_input__driverSeat, human_input__vehicleMaintenance)

[es(tag=input)]
def human_vehicle_input_es(evt : EventDaInputInit;
                           human_input__seatCount : int;
                           var human_input__seats : IntList&;
                           var human_input__seatNext : int&;
                           var human_input__driverSeat : int&;
                           var human_input__vehicleMaintenance : int&)
  if evt.init
    init(human_input__seatCount, human_input__seats, human_input__seatNext,
         human_input__driverSeat, human_input__vehicleMaintenance)
  else
    reset(human_input__seatCount, human_input__seats, human_input__seatNext,
         human_input__driverSeat, human_input__vehicleMaintenance)


[es(tag=input)]
def human_change_seat_input_es(evt : EventDaInputActionTriggered;
                               eid : EntityId;
                               human_anim__vehicleSelected : EntityId;
                               human_input__seats : IntList;
                               human_input__seatNext : int;
                               human_input__driverSeat : int;
                               isInVehicle : bool;
                               input__enabled : bool)
  if !input__enabled && !isInVehicle
    return
  let action = int(evt.action)
  for i in range(0, length(human_input__seats))
    if action == human_input__seats[i]
      sendEvent(human_anim__vehicleSelected, CmdVehiclePlaceSeat(eid = eid, seat = i))
      return
  if action == human_input__seatNext
    sendEvent(human_anim__vehicleSelected, CmdVehiclePlaceNextSeat(eid = eid))
  elif action == human_input__driverSeat
    sendEvent(human_anim__vehicleSelected, CmdVehiclePlaceDriverSeat(eid = eid))

[es(tag=input)]
def human_vehicle_maintenance_start_input_es(evt : EventDaInputActionTriggered;
                                             eid : EntityId;
                                             maintenance__target : EntityId;
                                             maintenance__hasTarget : bool;
                                             human_input__vehicleMaintenance : int;
                                             input__enabled : bool)
  if input__enabled && maintenance__hasTarget && int(evt.action) == human_input__vehicleMaintenance
    sendEvent(eid, CmdStartMaintenance(target = maintenance__target))

[es(tag=input)]
def human_vehicle_maintenance_stop_input_es(evt : EventDaInputActionTerminated;
                                            eid : EntityId;
                                            maintenance__target : EntityId;
                                            maintenance__hasTarget : bool;
                                            human_input__vehicleMaintenance : int;
                                            input__enabled : bool)
  if input__enabled && maintenance__hasTarget && int(evt.action) == human_input__vehicleMaintenance
    sendEvent(eid, CmdStopMaintenance(target = maintenance__target))
