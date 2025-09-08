require ecs
require ecs.common
require game.es.vehicle.vehicle_seats_common
require vehicle
require PhysObj
require DngPhysObj
require Ship
require DngShip


[es(after=vehicle_seats_update_player_es, before=before_net_phys_sync)]
def vehicle_seats_update_sleep_vehicle_es(info : UpdateStageInfoAct; vehicle_seats__seatEids : EidList; var vehicle_net_phys : VehiclePhysActor)
  if is_vehicle_with_alive_crew(vehicle_seats__seatEids)
    vehicle_net_phys.phys |> wakeUp()

[es(after=vehicle_seats_update_player_es, before=before_net_phys_sync)]
def vehicle_seats_update_sleep_physobj_es(info : UpdateStageInfoAct; vehicle_seats__seatEids : EidList; var phys_obj_net_phys : PhysObjActor)
  if is_vehicle_with_alive_crew(vehicle_seats__seatEids)
    phys_obj_net_phys.phys |> wakeUp()

[es(after=vehicle_seats_update_player_es, before=before_net_phys_sync)]
def vehicle_seats_update_sleep_ship_es(info : UpdateStageInfoAct; vehicle_seats__seatEids : EidList; var ship_net_phys : ShipActor)
  if is_vehicle_with_alive_crew(vehicle_seats__seatEids)
    ship_net_phys.phys |> ship_phys_wake_up()
