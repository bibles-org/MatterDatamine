import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let movingZoneInfo = Watched(null)

ecs.register_es("hud_moving_zone_pos_ui_es",
  {
    [["onInit", "onChange"]] = function(_evt, _eid, comp){
      movingZoneInfo.set({
        startEndTime = comp["moving_zone__startEndTime"]
        collapseTime = comp["moving_zone__collapseTime"]
        targetRadius = comp["moving_zone__targetRadius"]
        sourceRadius = comp["moving_zone__sourceRadius"]
        targetPos = comp["moving_zone__targetPos"]
        sourcePos = comp["moving_zone__sourcePos"]
        isCollapsing = comp["moving_zone__isCollapsing"]
      })
    }
    function onDestroy(_evt, _eid, _comp) {
      movingZoneInfo.set(null)
    }
  },
  {
    comps_track = [
      ["moving_zone__isCollapsing", ecs.TYPE_BOOL, false],
      ["moving_zone__targetPos", ecs.TYPE_POINT3],
      ["moving_zone__targetRadius", ecs.TYPE_FLOAT],
      ["moving_zone__sourcePos", ecs.TYPE_POINT3],
      ["moving_zone__sourceRadius", ecs.TYPE_FLOAT],
      ["moving_zone__startEndTime", ecs.TYPE_POINT2],
      ["moving_zone__collapseTime", ecs.TYPE_FLOAT],
    ]
  }
)

return {
  movingZoneInfo
}
