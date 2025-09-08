import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let movingZoneInfo = Watched(null)

ecs.register_es("hud_moving_zone_pos_ui_es",
  {
    [["onInit", "onChange"]] = function(_evt, _eid, comp){
      movingZoneInfo.set({
        worldPos=comp["transform"][3]
        radius=comp["sphere_zone__radius"]
        endTime = comp["moving_zone__startEndTime"].x
        collapseTime = comp["moving_zone__collapseTime"]
      })
    }
    function onDestroy(_evt, _eid, _comp) {
      movingZoneInfo.set(null)
    }
  },
  {
    comps_track = [
      ["transform", ecs.TYPE_MATRIX],
      ["sphere_zone__radius", ecs.TYPE_FLOAT],
      ["moving_zone__targetPos", ecs.TYPE_POINT3],
      ["moving_zone__targetRadius", ecs.TYPE_FLOAT],
      ["moving_zone__startEndTime", ecs.TYPE_POINT2],
      ["moving_zone__collapseTime", ecs.TYPE_FLOAT],
    ]
  }
)

return {
  movingZoneInfo
}
