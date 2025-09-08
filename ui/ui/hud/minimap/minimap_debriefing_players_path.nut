from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

from "dagor.math" import Point2, Point3

let { playerPath } = require("%ui/mainMenu/debriefing/debriefing_player_path_state.nut")
let { currentMapVisibleRadius } = require("%ui/hud/minimap/minimap_state.nut")


let lineColor = mul_color(Color(255, 100, 100), 200.0/255)

function mkPlayerPath(transform, map_size, path) {
  if (path == null) {
    return null
  }
  let {
    pathSegments = null
    transPortalPointsToDraw = null
    center = null
    width = 0
    height = 0
  } = path

  if (pathSegments == null || transPortalPointsToDraw == null || center == null)
    return null

  return function() {
    let radius = currentMapVisibleRadius.get()
    if (radius == 0) {
      return null
    }
    let polygonSize = [max(1, width / radius * map_size[0] * 0.5), max(1, height / radius * map_size[1] * 0.5)]

    let polygons = pathSegments.map(@(segment) segment.reduce(@(acc, point) acc.append(point.x, point.y), [VECTOR_LINE]))
    let portals = transPortalPointsToDraw.reduce(function(allCommands, fromToPoints) {
      let [from, to] = fromToPoints
      let scale = min(polygonSize[0], polygonSize[1])
      let line = [VECTOR_LINE_DASHED, from.x, from.y, to.x, to.y, 0.02 * scale, 0.02 * scale]
      return allCommands.append(
        [VECTOR_COLOR, Color(130, 130, 130, 128)],
        line,
        [VECTOR_COLOR, lineColor])
    }, [[VECTOR_FILL_COLOR Color(150, 150, 150, 160)]])

    return {
      watch = [currentMapVisibleRadius]
      data = {
        worldPos = Point3(center.x, 0, center.y),
        clampToBorder = false
      }
      color = Color(240, 240, 240)
      transform = transform
      rendObj = ROBJ_VECTOR_CANVAS
      size = polygonSize
      commands = [
        [VECTOR_WIDTH, hdpx(2)],
        [VECTOR_COLOR, lineColor],
      ].extend(polygons, portals)
    }
  }
}

return {
  watch = playerPath
  ctor = @(p) mkPlayerPath(p?.transform, p?.size, playerPath.get())
}
