import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let climbingHintMarkers = Watched({})

ecs.register_es("update_climbing_hint_marker_info",
  {
    [["onChange", "onInit"]] = function(_evt, eid, comp) {
      climbingHintMarkers.mutate(function(v){
        if (comp.climbing_hint__hide){
          if (eid in v)
            climbingHintMarkers.mutate(@(val) val.$rawdelete(eid))
          return
        }
        local hintloc = comp.climbing_hint__loc
        if (!comp.climbing_hint__haveEnoughStamina)
          hintloc = comp.climbing_hint__locNoStamina
        else if (comp.climbing_hint__overObstacle)
          hintloc = comp.climbing_hint__locOverObstacle
        v[eid] <- {
          pos = comp.transform[3],
          haveEnoughStamina = comp.climbing_hint__haveEnoughStamina,
          text = hintloc
        }
      })
    }
    onDestroy = function(_evt, eid, _comp) {
      if (eid in climbingHintMarkers.get())
        climbingHintMarkers.mutate(@(v) v.$rawdelete(eid))
    }
  },
  {
    comps_track=[
      ["transform", ecs.TYPE_MATRIX],
      ["climbing_hint__haveEnoughStamina", ecs.TYPE_BOOL],
      ["climbing_hint__hide", ecs.TYPE_BOOL]
    ],
    comps_ro=[
      ["climbing_hint__loc", ecs.TYPE_STRING],
      ["climbing_hint__locNoStamina", ecs.TYPE_STRING],
      ["climbing_hint__locOverObstacle", ecs.TYPE_STRING],
      ["climbing_hint__overObstacle", ecs.TYPE_BOOL]
    ]
  }
)

return{
  climbingHintMarkers
}