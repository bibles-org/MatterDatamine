import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *






let inTank = Watched(false)
let inPlane = Watched(false)
let inShip = Watched(false)
let inGroundVehicle = Watched(false)
let isVehicleAlive = Watched(false)

let state = {
  isDriver = Watched(false)
  isGunner = Watched(false)
  isPassenger = Watched(false)

  controlledVehicleEid = Watched(ecs.INVALID_ENTITY_ID)
  inGroundVehicle = inGroundVehicle
  inPlane = inPlane
  inTank = inTank
  inShip = inShip
  isVehicleAlive = isVehicleAlive
}
state.inVehicle <- Computed(@() inGroundVehicle.get() || inPlane.get())

ecs.register_es("ui_in_vehicle_eid_es",
  {
    [["onChange", "onInit"]] = function (_evt, eid, comp) {
      state.controlledVehicleEid.set(eid)
      let inPlaneC = comp["airplane"] != null
      let inTankC = comp["isTank"] != null
      let inShipC = comp["ship"] != null
      state.inPlane.set(inPlaneC)
      state.inGroundVehicle.set(!inPlaneC)
      state.inTank.set(inTankC)
      state.inShip.set(inShipC)

      state.isVehicleAlive.set(comp["isAlive"])
    },
    function onDestroy(_evt, _eid, _comp){
      state.inPlane.set(false)
      state.inGroundVehicle.set(false)
      state.inTank.set(false)
      state.inShip.set(false)
      state.controlledVehicleEid.set(ecs.INVALID_ENTITY_ID)
      state.isVehicleAlive.set(false)
    }
  },
  {
    comps_track = [
      ["isAlive", ecs.TYPE_BOOL, false],
    ],
    comps_ro = [
      ["airplane", ecs.TYPE_TAG, null],
      ["isTank", ecs.TYPE_TAG, null],
      ["ship", ecs.TYPE_TAG, null],
    ],
    comps_rq=["vehicleWithWatched"]
  }
)

ecs.register_es("ui_vehicle_role_es",
  {
    [["onChange", "onInit"]] = function (_evt, _eid, comp) {
      state.isDriver.set(comp["isDriver"] && comp["isInVehicle"])
      state.isGunner.set(comp["isGunner"] && comp["isInVehicle"])
      state.isPassenger.set(comp["isPassenger"] && comp["isInVehicle"])
    },
    function onDestroy(_evt, _eid, _comp) {
      state.isDriver.set(false)
      state.isGunner.set(false)
      state.isPassenger.set(false)
    }
  },
  {
    comps_track = [
      ["isInVehicle", ecs.TYPE_BOOL, false],
      ["isDriver", ecs.TYPE_BOOL, false],
      ["isGunner", ecs.TYPE_BOOL, false],
      ["isPassenger", ecs.TYPE_BOOL, false]
    ],
    comps_rq = ["watchedByPlr"]
  }
)

return state