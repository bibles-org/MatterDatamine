from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let {Point3} = require("dagor.math")

let {movingZoneInfo} = require("%ui/hud/state/hud_moving_zone_es.nut")
let {currentMapVisibleRadius} = require("%ui/hud/minimap/map_state.nut")

let zeroPos = Point3(0,0,0)
let currentZone = Color(70,70,70,128)

let ellipseCmd = [VECTOR_ELLIPSE, 50, 50, 50, 50]

function makeZone(map_size) {
  let zone = movingZoneInfo.get()
  let color = currentZone


  let cmd = [
    
    [VECTOR_COLOR, Color(0, 0, 0, 0)],
    [VECTOR_MID_COLOR, Color(20, 20, 20, 230)],
    [VECTOR_FILL_COLOR, Color(0, 0, 0, 0)],
    [VECTOR_WIDTH, map_size ? map_size[0] : 100],
    [VECTOR_OUTER_LINE],
    ellipseCmd,
    [VECTOR_CENTER_LINE],
    [VECTOR_MID_COLOR],

    
    [VECTOR_COLOR, Color(0, 0, 0, 100)],
    [VECTOR_WIDTH, hdpx(2) * 1.5],
    ellipseCmd,

    
    [VECTOR_WIDTH],
    [VECTOR_COLOR],
    ellipseCmd
  ]

  let updCacheTbl = {
    data = {
      worldPos = zone?["worldPos"] ?? zeroPos
      clampToBorder = false
    }
  }

  return {
    transform = {
      pivot = [0.5, 0.5]
    }
    rendObj = ROBJ_VECTOR_CANVAS
    ignoreEarlyClip = true
    lineWidth = hdpx(2)
    color = color
    fillColor = Color(0, 0, 0, 0)

    behavior = Behaviors.RtPropUpdate
    rtAlwaysUpdate = true
    size = map_size
    commands = cmd

    update = function() {
      let czone = movingZoneInfo.get()
      if (czone==null)
        return updCacheTbl
      let worldPos = czone["worldPos"]
      let radius = czone["radius"]
      let realVisRadius = currentMapVisibleRadius.get()
      let canvasRadius = radius / realVisRadius * 50.0

      ellipseCmd[3] = canvasRadius
      ellipseCmd[4] = canvasRadius

      updCacheTbl.data.worldPos <- worldPos
      return updCacheTbl
    }
  }
}


























































function zones(size = null){
  if (movingZoneInfo.get()==null)
    return []

  return makeZone(size)
}

return {
  watch = movingZoneInfo
  ctor = @(p) zones(p?.size)
}
