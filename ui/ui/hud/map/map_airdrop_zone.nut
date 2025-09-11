from "dagor.math" import Point3
import "%ui/hud/map/map_hover_hint.nut" as mapHoverableMarker

from "%ui/ui_library.nut" import *

let { currentMapVisibleRadius } = require("%ui/hud/map/map_state.nut")

let zeroPos = Point3(0,0,0)

function makeAirdropZone(zone, transform, map_size, currentMapVisibleRadiusValue) {
  let radiusZone = zone.radius
  let canvasRadius = radiusZone * min(map_size[0], map_size[1]) / (2 * currentMapVisibleRadiusValue)

  function airdropCircles(stateWatched) {
    return {
      rendObj = ROBJ_VECTOR_CANVAS
      size = [2 * canvasRadius, 2 * canvasRadius]
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      commands = [
        [VECTOR_COLOR, zone.color],
        [VECTOR_FILL_COLOR, mul_color(zone.color, 0.4)],
        static [VECTOR_WIDTH, hdpxi(2)],
        static [VECTOR_ELLIPSE, 50, 50, 50, 50]
      ]
      children = {
        rendObj = ROBJ_IMAGE
        image = Picture("!ui/skin#{0}:{1}:{2}}:P".subst(zone.icon, hdpxi(18), hdpxi(32)))
        color = stateWatched.get() & S_HOVER ? Color(120, 220, 180) : Color(255, 255, 255)
        size = static [hdpxi(18), hdpxi(32)]
      }
    }
  }

  return mapHoverableMarker(
    {
      worldPos = zone.center ?? zeroPos
      clampToBorder = false
      dirRotate = false
    },
    transform,
    loc("marker_tooltip/airdropZone"),
    @(stateWatched) airdropCircles(stateWatched)
  )
}

function airdropZones(transform, map_size, airdropPredictedPositions, currentMapVisibleRadiusValue){
  let zonesArr = airdropPredictedPositions.values()
  return zonesArr.map(@(zone) makeAirdropZone(zone, transform, map_size, currentMapVisibleRadiusValue))
}

return @(airdropPredictedPositions) {
  watch = [airdropPredictedPositions, currentMapVisibleRadius]
  ctor = @(p) airdropZones(p?.transform ?? {}, p.size, airdropPredictedPositions.get(), currentMapVisibleRadius.get())
}
