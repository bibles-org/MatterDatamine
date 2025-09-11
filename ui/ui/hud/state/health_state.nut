import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


let isAliveState = Watched(false)
let isDownedState = Watched(false)

ecs.register_es("health_state_ui_es", {
  [["onChange", "onInit"]] = function trackComponentsHero(_eid,comp) {
    isAliveState.set(comp["isAlive"])
    isDownedState.set(comp["isDowned"])
  }

}, {
  comps_track = [
    ["isAlive", ecs.TYPE_BOOL, true],
    ["isDowned", ecs.TYPE_BOOL, false],
  ]
  comps_rq=["watchedByPlr"]
})



return {
  isAlive = isAliveState
  isDowned = isDownedState
}
