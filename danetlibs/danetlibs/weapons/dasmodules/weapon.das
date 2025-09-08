require ecs
require vehicle
options indenting = 2

[generic]
def can_control_turret(vehicle__localControls : VehicleControlsState; turretNo : int)
  return (int(vehicle__localControls.turretsMask) & (1 << turretNo)) != 0

[generic]
def can_control_turrets(vehicle__localControls : VehicleControlsState)
  return int(vehicle__localControls.turretsMask) != 0

[generic]
def set_control_turret(var vehicle__localControls : VehicleControlsState; turret_no : int; value : bool)
  var turretsMask = int(vehicle__localControls.turretsMask)
  if value
    turretsMask = turretsMask | (1 << turret_no)
  else
    turretsMask = turretsMask & ~(1 << turret_no)
  vehicle__localControls.turretsMask = uint(turretsMask)

[generic]
def can_control_turret(turret_no : int; seat_eids : EidList)
  var canTurretControl = false
  for seatEid in seat_eids
    query(seatEid) <| $ [es] (seat__ownerControls : VehicleControlsState)
      canTurretControl ||= can_control_turret(seat__ownerControls, turret_no)
  return canTurretControl
