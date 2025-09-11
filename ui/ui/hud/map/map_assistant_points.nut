from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

import "%ui/hud/map/map_hover_hint.nut" as mapHoverableMarker
from "%ui/components/colors.nut" import TextNormal, MapIconHover


let pointHeight = hdpxi(20)
let activityPoints = Watched({})
ecs.register_es("track_assistant_points", {
    onInit = function(eid, comp) {
      activityPoints.mutate(@(v) v[eid] <- { owner = comp.activity_helper_marker__ownerEid, pos = comp.transform[3] })
    },
    onDestroy = function(eid, _) {
      activityPoints.mutate(@(v) v.$rawdelete(eid))
    }
  },
  {
    comps_ro = [
      ["activity_helper_marker__ownerEid", ecs.TYPE_EID],
      ["transform", ecs.TYPE_MATRIX],
    ]
  }
)

function mkCompassAssistanPoint(eid, info) {
  let helperIcon = @(sf){
    rendObj = ROBJ_IMAGE
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    image = Picture($"ui/skin#eye.svg:{pointHeight}:{pointHeight}:P")
    color = (sf.get() & S_HOVER) ? MapIconHover : TextNormal
    size = [pointHeight, pointHeight]
    behavior=DngBhv.OpacityByComponent
    opacityComponentEntity = eid
    opacityComponentName = "hud_marker__opacity"
  }

  return mapHoverableMarker(
    { worldPos = info.pos, clampToBorder = true },
    static {},
    loc("marker_tooltip/actionHelper"),
    helperIcon
  )
}

let mkAssistantPoints = @(state) {
  watch = state
  function ctor(_) {
    let res = []
    foreach(eid, info in state.get())
      res.append(mkCompassAssistanPoint(eid, info))

    return res
  }
}

return {
  assistantPoints = mkAssistantPoints(activityPoints)
  activityPoints
}
