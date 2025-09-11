import "%ui/hud/map/map_hover_hint.nut" as mapHoverableMarker
from "%ui/components/colors.nut" import OrangeHighlightColor
from "%ui/fonts_style.nut" import fontawesome
from "%ui/ui_library.nut" import *
import "%ui/components/fontawesome.map.nut" as fa

let { deathPoints } = require("%ui/hud/state/death_points_state.nut")

let markerSize = hdpxi(18)

let mkDeathMarkers = function(deathPointsMap, transform) {
  return deathPointsMap.map(function(v, eid) {
    return mapHoverableMarker({worldPos = v.pos, clampToBorder = true},
                                  transform,
                                  loc("marker_tooltip/death"),
                                  @(stateWatched) function(){
      let isHover = stateWatched.get() & S_HOVER
      let color = isHover ? OrangeHighlightColor : Color(200, 0, 0)

      return {
        watch = stateWatched
        key = color
        rendObj = ROBJ_TEXT
        text = fa["close"]
        size = markerSize
        color
        behavior = DngBhv.OpacityByComponent
        opacityComponentEntity = eid
        opacityComponentName = "map_object_marker__opacity"
      }.__update(fontawesome)
    })
  }).values()
}

return {
  deathPos = {
    watch = deathPoints
    ctor = @(p) mkDeathMarkers(deathPoints.get(), p?.transform ?? {})
  }
}
