import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let isUnderWater = Watched(false)
let isSwimming = Watched(false)

ecs.register_es("hero_water_state_ui_es", {
  [["onChange", "onInit"]] = function(_eid,comp) {
    isUnderWater.set(comp.human_breath__isUnderWater)
    isSwimming.set(comp.human_net_phys__isSwimming)
  }
  onDestroy = function(_eid, _comp) {
    isUnderWater.set(false)
    isSwimming.set(false)
  }
}, {
  comps_track = [
    ["human_breath__isUnderWater", ecs.TYPE_BOOL, false],
    ["human_net_phys__isSwimming", ecs.TYPE_BOOL, false],
  ]
  comps_rq=["watchedByPlr"]
})

return {
  isUnderWater
  isSwimming
}