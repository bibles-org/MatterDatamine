import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


let binocularsUseRequest = Watched(false)
let binocularsUseState = Watched(0)
let binocularsWatchingState = Watched(0)


ecs.register_es("binoculars_ui_es",
  {
    [["onChange", "onInit"]] = function trackComponentsHero(_eid, comp) {
      binocularsUseRequest.set(comp["binoculars_controller__useRequest"])
      binocularsUseState.set(comp["binoculars_controller__useState"])
      binocularsWatchingState.set(comp["binoculars_controller__watchingState"])
    }
  },
  {
    comps_track = [
      ["binoculars_controller__useRequest", ecs.TYPE_BOOL],
      ["binoculars_controller__useState", ecs.TYPE_INT],
      ["binoculars_controller__watchingState", ecs.TYPE_INT],
    ]
    comps_rq=["watchedByPlr"]
  }
)


return {
  binocularsUseRequest
  binocularsUseState
  binocularsWatchingState
}
