from "%ui/ui_library.nut" import *

let { currentMapVisibleRadius } = require("%ui/hud/minimap/map_state.nut")
let { Point3 } = require("dagor.math")
let minimapHoverableMarker = require("minimap_hover_hint.nut")

let zeroPos = Point3(0,0,0)

function makeVictimZone(zone, transform, map_size, currentMapVisibleRadiusValue) {
  let radiusZone = zone.currRadius
  let canvasRadius = radiusZone * min(map_size[0], map_size[1]) / (2 * currentMapVisibleRadiusValue)
  let victimCircles = {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [2 * canvasRadius, 2 * canvasRadius]
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    commands = [
      [VECTOR_COLOR, zone.color],
      [VECTOR_FILL_COLOR, mul_color(zone.color, 0.4)],
      [VECTOR_WIDTH, hdpxi(2)],
      [VECTOR_ELLIPSE, 50, 50, 50, 50]
    ]
  }

  return minimapHoverableMarker(
    {
      worldPos = Point3(zone.pos.x, 0.0, zone.pos.y) ?? zeroPos
      clampToBorder = false
      dirRotate = false
    },
    transform,
    loc("marker_tooltip/monsterVictims"),
    @(_) victimCircles
  )
}

function victimZones(transform, map_size, victimCirclesData, currentMapVisibleRadiusValue){
  let zonesArr = victimCirclesData.values()
  return zonesArr.map(@(zone) makeVictimZone(zone, transform, map_size, currentMapVisibleRadiusValue))
}

return @(monstrifyVictimCircles) {
  watch = [monstrifyVictimCircles, currentMapVisibleRadius]
  ctor = @(p) victimZones(p?.transform ?? {}, p.size, monstrifyVictimCircles.get(), currentMapVisibleRadius.get())
}
