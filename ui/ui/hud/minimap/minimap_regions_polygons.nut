from "%ui/ui_library.nut" import *

import "%ui/hud/state/regions_state.nut" as regionsState
from "%ui/fonts_style.nut" import sub_txt
from "%ui/hud/minimap/map_state.nut" import currentMapVisibleRadius
from "dagor.math" import Point2, Point3

let fillColor = mul_color(Color(220, 220, 220, 255), 0.1)
let lineColor = mul_color(Color(220, 220, 220, 255), 0.6)

let makeRegionPolygons = @(regions, transform, map_size)
  regions.map(@(region) function() {
    let range = region.visibleRange
    if (range.y > 0 && (currentMapVisibleRadius.get() < range.x || currentMapVisibleRadius.get() > range.y))
      return { watch = currentMapVisibleRadius }

    let points = region.points
    let [lt, rb] = points.reduce(@(acc, p) [
        Point2(min(acc[0].x, p.x), min(acc[0].y, p.y)),
        Point2(max(acc[1].x, p.x), max(acc[1].y, p.y))
      ], [Point2(100000, 100000), Point2(-100000, -100000)])

    let center = Point2((lt.x + rb.x) / 2.0, (lt.y + rb.y) / 2.0)
    let radius = currentMapVisibleRadius.get()
    let polygonSize = [(rb.x - lt.x) / radius * map_size[0] * 0.5, (rb.y - lt.y) / radius * map_size[1] * 0.5]
    let relativePoints = points.map(function(p) {
      let point = Point2(p.x - center.x, p.y - center.y)
      
      
      return Point2(50.0 + point.x / (rb.x - lt.x) * 100.0, 50.0 - point.y / (rb.y - lt.y) * 100.0)
    })

    let polygon = relativePoints.reduce(@(acc, point) acc.append(point.x, point.y), [VECTOR_POLY])

    return {
      watch = currentMapVisibleRadius
      data = {
        worldPos = Point3(center.x, 0, center.y),
        clampToBorder = false
      }
      transform = transform
      rendObj = ROBJ_VECTOR_CANVAS
      size = polygonSize
      commands = [
        [VECTOR_WIDTH, hdpx(1.4)],
        [VECTOR_FILL_COLOR, fillColor],
        [VECTOR_COLOR, lineColor],
        polygon
      ]
    }
  })

return {
  watch = regionsState
  ctor = @(p) makeRegionPolygons(regionsState.get(), p?.transform ?? {}, p.size)
}
