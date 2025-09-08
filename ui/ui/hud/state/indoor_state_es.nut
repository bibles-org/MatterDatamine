import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let isIndoor = Watched(false)
let indoorExposureMaxValue = 15.0

ecs.register_es("indoor_state_es", {
  [["onChange", "onInit"]] = @(_evt,_eid,comp) isIndoor.set(comp.exposure_readback__currectValue > indoorExposureMaxValue)
  onDestroy = @(...) isIndoor.set(false)
}, {
  comps_track = [["exposure_readback__currectValue", ecs.TYPE_FLOAT]],
}, {tags = "gameClient"})

return {
  isIndoor
}