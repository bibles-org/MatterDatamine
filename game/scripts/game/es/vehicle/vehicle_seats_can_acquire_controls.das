require ecs
require ecs.safe
require vehicle
require game.es.vehicle.vehicle_seats_common

[es(on_appear)]
def vehicle_seats_can_acquire_controls_init_es(evt : Event;
                                               @shared_comp vehicle_seats__seats : Array;
                                               @shared_comp vehicle_seats__canAcquireControls : Object;
                                               var vehicle_seats_can_acquire_controls : ecs::IntList)

  resize(vehicle_seats_can_acquire_controls, length(vehicle_seats__seats))

  for seatNo in iter_range(vehicle_seats_can_acquire_controls)
    let seat = vehicle_seats__seats[seatNo] as Object
    let controls = vehicle_seats__canAcquireControls[get_string(seat, "name", "")] ?as Object
    if controls != null
      if (*controls).movement ?? false
        vehicle_seats_can_acquire_controls[seatNo] |= int(VehicleControlTypes.VEHICLE_CONTROLS_MOVEMENT)
      if (*controls).turrets ?? false
        vehicle_seats_can_acquire_controls[seatNo] |= int(VehicleControlTypes.VEHICLE_CONTROLS_TURRETS)
      if (*controls).camera ?? false
        vehicle_seats_can_acquire_controls[seatNo] |= int(VehicleControlTypes.VEHICLE_CONTROLS_CAMERA)
