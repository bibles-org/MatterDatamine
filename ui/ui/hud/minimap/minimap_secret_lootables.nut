from "%ui/ui_library.nut" import *

let {secretLootables} = require("%ui/hud/state/markers.nut")
let minimapHoverableMarker = require("minimap_hover_hint.nut")


let secretLootableMarkers = function(secretLootablesPoints, transform) {
  return secretLootablesPoints.values().map(function(secretLootable) {
    return minimapHoverableMarker({worldPos = secretLootable.pos, clampToBorder = true}, transform, loc("hint/secretLootableMinimapMarker"), @(stateWatched) @(){
      watch = stateWatched
      rendObj = ROBJ_IMAGE
      image = Picture("!ui/skin#bagpack_icon.svg")
      color = stateWatched.value & S_HOVER ? Color(255, 255, 0) : Color(255, 255, 255)
      size = [hdpxi(16), hdpxi(16)]
    })
  })
}
return {
  watch = secretLootables
  ctor = @(p) secretLootableMarkers(secretLootables.value, p?.transform ?? {})
}
