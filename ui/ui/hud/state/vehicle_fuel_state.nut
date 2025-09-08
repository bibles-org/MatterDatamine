import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let vehicleFuel = Watched(0.0)
let vehicleMaxFuel = Watched(0.0)
let vehicleFuelAlert = Watched(false)

ecs.register_es("vehicle_fuel_ui_es",
  {
    function onInit (_evt, _eid, comp) {
      vehicleFuel(comp.vehicle__fuel)
      vehicleMaxFuel(comp.vehicle__maxFuel)
    },
    function onChange (_evt, _eid, comp) {
      vehicleFuel(comp.vehicle__fuel)
    },
    function onDestroy(_evt, _eid, _comp){
      vehicleFuel(0.0)
      vehicleMaxFuel(0.0)
    }
  },
  {
    comps_track = [
      ["vehicle__fuel", ecs.TYPE_FLOAT],
      ["vehicle__maxFuel", ecs.TYPE_FLOAT],
    ],
    comps_rq=["vehicleWithWatched"]
  }
)

ecs.register_es("vehicle_fuel_alert_ui_es",
  {
    [["onInit", "onChange"]] = function(_evt, _eid, comp) {
      vehicleFuelAlert(comp.vehicle__fuelAlert)
    },
    function onDestroy(_evt, _eid, _comp){
      vehicleFuelAlert(false)
    }
  },
  {
    comps_track = [
      ["vehicle__fuelAlert", ecs.TYPE_BOOL]
    ],
    comps_rq=["vehicleWithWatched"]
  }
)


return {
  vehicleFuel
  vehicleMaxFuel
  vehicleFuelAlert
}