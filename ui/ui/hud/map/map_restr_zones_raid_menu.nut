from "dagor.math" import Point3

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { currentMapVisibleRadius } = require("%ui/hud/map/map_state.nut")

let zeroPos = Point3(0,0,0)
let currentZone = Color(70,70,70,128)

let ellipseCmd = [VECTOR_ELLIPSE, 50, 50, 50, 50]

let raidZoneInfo = Watched(null)

function makeZone(map_size) {
  let zone = raidZoneInfo.get()
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
      let czone = raidZoneInfo.get()
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
  if (raidZoneInfo.get()==null)
    return []

  return makeZone(size)
}

return freeze({
  raidZoneInfo,
  raidZone = {
    watch = raidZoneInfo
    ctor = @(p) zones(p?.size)
  }
})
