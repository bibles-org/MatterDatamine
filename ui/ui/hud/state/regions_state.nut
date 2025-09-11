from "dagor.math" import Point3

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


let regions = Watched([])

ecs.register_es("load_level_regions_es", {
  onInit = function(_eid, comp){
    let idx = regions.get().findindex(@(i) i.name == comp.custom_region__name)
    regions.mutate(function(a){
      if (idx != null) {
        a[idx].points = comp.custom_region__points.getAll()
        a[idx].titleWorldPosOffset = comp.custom_region__titleWorldPosOffset
      }
      else
        a.append({
          name = comp.custom_region__name,
          points = comp.custom_region__points.getAll(),
          visibleRange = comp.custom_region__visibleRange
          titleAlignment = comp.custom_region__titleAlignment,
          titleWorldPosOffset = comp.custom_region__titleWorldPosOffset,
        })
    })
  }
  onDestroy = function(_eid, comp){
    let idx = regions.get().findindex(@(i) i.name == comp.custom_region__name)
    if (idx != null)
      regions.mutate(@(a) a.remove(idx))
  }
}, {
  comps_rq = ["custom_region__visibleOnMap"]
  comps_ro = [
    ["custom_region__name", ecs.TYPE_STRING],
    ["custom_region__points", ecs.TYPE_POINT2_LIST],
    ["custom_region__visibleRange", ecs.TYPE_POINT2],
    ["custom_region__titleAlignment", ecs.TYPE_INT, 0],
    ["custom_region__titleWorldPosOffset", ecs.TYPE_POINT3, Point3()]
  ]
})

return regions
