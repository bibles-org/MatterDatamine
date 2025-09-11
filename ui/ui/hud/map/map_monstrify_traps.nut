import "%ui/hud/map/map_hover_hint.nut" as mapHoverableMarker
from "%ui/components/colors.nut" import OrangeHighlightColor

from "%ui/ui_library.nut" import *

let { monstrifyTraps } = require("%ui/hud/state/monstrify_state.nut")

let markerSize = hdpxi(18)

let mkMonstrifyTrapMarkers = function(monstrifyTrapPosValue, transform) {
  return monstrifyTrapPosValue.map(function(pos) {
    return mapHoverableMarker({worldPos = pos.pos, clampToBorder = true},
                                  transform,
                                  loc("marker_tooltip/monstrifyTrapPos"),
                                  @(stateWatched) function(){
      let isHover = stateWatched.get() & S_HOVER
      let color = isHover ? OrangeHighlightColor : Color(255, 255, 255, 255)

      return {
        watch = stateWatched
        key = $"{color}"
        rendObj = ROBJ_IMAGE
        image = Picture($"{pos.icon}:{0}:{0}:K".subst(markerSize))
        size = markerSize
        color
      }
    })
  })
}

return {
  monstrifyTrapPos = {
    watch = monstrifyTraps
    ctor = @(p) mkMonstrifyTrapMarkers(monstrifyTraps.get().values(), p?.transform ?? {})
  }
}
