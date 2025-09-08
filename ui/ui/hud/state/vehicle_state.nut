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
state.inVehicle <- Computed(@() inGroundVehicle.value || inPlane.value)

ecs.register_es("ui_in_vehicle_eid_es",
  {
    [["onChange", "onInit"]] = function (_evt, eid, comp) {
      state.controlledVehicleEid(eid)
      let inPlaneC = comp["airplane"] != null
      let inTankC = comp["isTank"] != null
      let inShipC = comp["ship"] != null
      state.inPlane(inPlaneC)
      state.inGroundVehicle(!inPlaneC)
      state.inTank(inTankC)
      state.inShip(inShipC)

      state.isVehicleAlive(comp["isAlive"])
    },
    function onDestroy(_evt, _eid, _comp){
      state.inPlane(false)
      state.inGroundVehicle(false)
      state.inTank(false)
      state.inShip(false)
      state.controlledVehicleEid(ecs.INVALID_ENTITY_ID)
      state.isVehicleAlive(false)
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
      state.isDriver(comp["isDriver"] && comp["isInVehicle"])
      state.isGunner(comp["isGunner"] && comp["isInVehicle"])
      state.isPassenger(comp["isPassenger"] && comp["isInVehicle"])
    },
    function onDestroy(_evt, _eid, _comp) {
      state.isDriver(false)
      state.isGunner(false)
      state.isPassenger(false)
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