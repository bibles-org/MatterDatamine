from "%ui/ui_library.nut" import *
from "vehicle.behaviors" import VehicleCrosshair

let { controlledVehicleEid, inPlane } = require("%ui/hud/state/vehicle_state.nut")
let {
  mainTurretAmmo, mainTurretEid, turretsReload, vehicleTurrets
} = require("%ui/hud/state/vehicle_turret_state.nut")
let {mkCountdownTimer} = require("%ui/helpers/timers.nut")

let circleProgressImage = Picture("ui/skin#scanner_range.avif")
let aim_color = Color(200, 200, 200, 150)
let aim_bgcolor = Color(0,62,115,75)
let overheatFg = Color(160, 0, 0, 180)
let overheatBg = Color(0, 0, 0, 0)
let overheat = require("%ui/hud/state/vehicle_turret_overheat_state.nut")

let hasAmmo = Computed(@() (mainTurretAmmo.get()?.curAmmo ?? 0) + (mainTurretAmmo.get()?.totalAmmo ?? 0) > 0)
let mainTurretReload = Computed(@() turretsReload.get()?[mainTurretEid.get()] ?? {})
let reloadEndTime = Computed(@() mainTurretReload.get()?.endTime ?? -1)
let changeAmmoTypeEndTime = Computed(@() mainTurretReload.get()?.changeAmmoTypeEndTime ?? -1)

let reloadTimer = mkCountdownTimer(reloadEndTime)
let changeAmmoTypeTimer = mkCountdownTimer(changeAmmoTypeEndTime)
let vehicleReloadProgress = Computed(@()
  !hasAmmo.get() ? 0
    : (mainTurretReload.get()?.changeAmmoTypeTotalTime ?? -1) > 0 ? max(0, (1 - (changeAmmoTypeTimer.get() / mainTurretReload.get().changeAmmoTypeTotalTime)))
    : (mainTurretReload.get()?.progressStopped ?? -1) >= 0 ? mainTurretReload.get().progressStopped
    : (mainTurretReload.get()?.totalTime ?? -1) > 0 ? max(0, (1 - (reloadTimer.get() / mainTurretReload.get().totalTime)))
    : 1.0
)

let bgAim = @(width) {
  color = aim_bgcolor
  fillColor = Color(0, 0, 0, 0)
  rendObj = ROBJ_VECTOR_CANVAS
  size = [width, width]
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  commands = [
    [VECTOR_WIDTH, hdpx(4)],
    [VECTOR_ELLIPSE, 50, 50, 50, 50],
  ]
}

function aim(){
  return {
    color = aim_color
    fillColor = Color(0, 0, 0, 0)
    rendObj = ROBJ_VECTOR_CANVAS
    size = fsh(4.0)
    watch = vehicleReloadProgress
    commands = [
      [VECTOR_WIDTH, hdpx(1)],
      [VECTOR_SECTOR, 50, 50, 50, 50, -90.0, -90.0 + (vehicleReloadProgress.get() ?? 1.0) * 360.0],
    ]
  }
}

function overheatBlock() {
  return {
    watch = overheat
    opacity = min(1.0, overheat.get()*2.0)
    fValue = overheat.get()
    rendObj = ROBJ_PROGRESS_CIRCULAR
    image = circleProgressImage
    size = fsh(4)
    fgColor = overheatFg
    bgColor = overheatBg
  }
}

let crosshair = @() {
  watch = [controlledVehicleEid, inPlane]
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  behavior = VehicleCrosshair
  transform = {}
  eid = controlledVehicleEid.get()
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER

  children = [
    bgAim(inPlane.get() ? hdpx(5) : fsh(4))
    aim
    overheatBlock]
}

let isCrosshairEnabled = Computed(@() vehicleTurrets.get().turrets.findvalue(@(turret) turret.showCrosshair && !turret.isLocalControlLocked) != null)

function root() {
  return {
    watch = [isCrosshairEnabled]
    size = flex()
    children = isCrosshairEnabled.get() ? crosshair : null
  }
}


return root
