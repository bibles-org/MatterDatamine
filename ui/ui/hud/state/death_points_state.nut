from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let deathPoints = Watched({})

ecs.register_es("death_points_state", {
  onInit = function(_evt, eid, comp) {
    deathPoints.mutate(@(points) points[eid] <- {
      pos = comp.minimap_death_point__position
    })
  }
  onDestroy = function(eid, _comp) {
    deathPoints.mutate(@(points) points.$rawdelete(eid))
  }
}, {
  comps_ro = [
    ["minimap_death_point__position", ecs.TYPE_POINT3],
  ]
}, {tags = "gameClient"})


return {
  deathPoints
}
