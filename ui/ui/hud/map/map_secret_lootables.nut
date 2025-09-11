import "%ui/hud/map/map_hover_hint.nut" as mapHoverableMarker

from "%ui/ui_library.nut" import *

let { secretLootables } = require("%ui/hud/state/markers.nut")


let secretLootableMarkers = function(secretLootablesPoints, transform) {
  return secretLootablesPoints.values().map(function(secretLootable) {
    return mapHoverableMarker({worldPos = secretLootable.pos, clampToBorder = true}, transform, loc("hint/secretLootableMinimapMarker"), @(stateWatched) @(){
      watch = stateWatched
      rendObj = ROBJ_IMAGE
      image = Picture("!ui/skin#bagpack_icon.svg")
      color = stateWatched.get() & S_HOVER ? Color(255, 255, 0) : Color(255, 255, 255)
      size = hdpxi(16)
    })
  })
}
return {
  watch = secretLootables
  ctor = @(p) secretLootableMarkers(secretLootables.get(), p?.transform ?? {})
}
