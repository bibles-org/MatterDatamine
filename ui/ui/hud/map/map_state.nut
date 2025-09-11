import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let mapHgt = min(fsh(63), sw(45)) 
let mapSize = [mapHgt, mapHgt]


const DefRad = 1000.0
let mapDefaultVisibleRadius = Watched(DefRad)
let currentMapVisibleRadius = Watched(DefRad)

ecs.register_es("set_map_default_visible_radius_es", {
    function onInit(_eid, comp) {
      mapDefaultVisibleRadius.set(comp["level__mapDefaultVisibleRadius"])
    }
    onDestroy = @(...) mapDefaultVisibleRadius.set(DefRad)
  },
  {
    comps_rq = ["level"]
    comps_ro = [["level__mapDefaultVisibleRadius", ecs.TYPE_INT]]
  }
)

return {
  mapSize
  mapDefaultVisibleRadius
  currentMapVisibleRadius
}