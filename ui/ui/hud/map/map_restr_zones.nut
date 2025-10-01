import "%sqstd/math_ex.nut" as math
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
from "net" import get_sync_time


let { movingZoneInfo } = require("%ui/hud/state/hud_moving_zone_es.nut")
let { currentMapVisibleRadius } = require("%ui/hud/map/map_state.nut")

let zeroPos = math.Point3(0,0,0)
let currentZoneColor = Color(70,70,70,128)
let futureZoneColor = Color(220,220,220,128)

let ellipseCmd = [VECTOR_ELLIPSE, 50, 50, 50, 50]

function makeStaticZone(map_size, color, worldPos, radius, doOuter=false) {
  let canvasRadius = radius / currentMapVisibleRadius.get() * 50.0
  let cEllipseCmd = [VECTOR_ELLIPSE, 50, 50, canvasRadius, canvasRadius]
  let staticZoneCommands = [
    static [VECTOR_COLOR, Color(0, 0, 0, 100)],
    static [VECTOR_WIDTH, hdpx(2) * 1.5],
    cEllipseCmd,
    
    static [VECTOR_WIDTH],
    [VECTOR_COLOR, color],
    cEllipseCmd
  ]
  return @() {
    transform = static {
      pivot = [0.5, 0.5]
    }
    watch = currentMapVisibleRadius
    data = {
      worldPos
      clampToBorder = false
    }
    ignoreEarlyClip = true
    key = {}
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(2)
    color
    fillColor = Color(0, 0, 0, 0)
    size = map_size
    commands = !doOuter ? staticZoneCommands : [
      static [VECTOR_COLOR, Color(0, 0, 0, 0)],
      static [VECTOR_MID_COLOR, Color(20, 20, 20, 230)],
      static [VECTOR_FILL_COLOR, Color(0, 0, 0, 0)],
      [VECTOR_WIDTH, map_size ? map_size[0] : 100],
      static [VECTOR_OUTER_LINE],
      cEllipseCmd,
      static [VECTOR_CENTER_LINE],
      static [VECTOR_MID_COLOR],
    ].extend(staticZoneCommands)
    
  }
}

function makeDynamicZone(map_size, czone) {
  let cmd = [
    
    static [VECTOR_COLOR, Color(0, 0, 0, 0)],
    static [VECTOR_MID_COLOR, Color(20, 20, 20, 230)],
    static [VECTOR_FILL_COLOR, Color(0, 0, 0, 0)],
    [VECTOR_WIDTH, map_size ? map_size[0] : 100],
    static [VECTOR_OUTER_LINE],
    ellipseCmd,
    static [VECTOR_CENTER_LINE],
    static [VECTOR_MID_COLOR],

    
    static [VECTOR_COLOR, Color(0, 0, 0, 100)],
    static [VECTOR_WIDTH, hdpx(2) * 1.5],
    ellipseCmd,

    
    static [VECTOR_WIDTH],
    static [VECTOR_COLOR, currentZoneColor],
    ellipseCmd
  ]

  let updCacheTbl = {
    data = {
      worldPos = czone?["worldPos"] ?? zeroPos
      clampToBorder = false
    }
  }

  return {
    transform = static {
      pivot = [0.5, 0.5]
    }
    rendObj = ROBJ_VECTOR_CANVAS
    ignoreEarlyClip = true
    lineWidth = hdpx(2)
    fillColor = Color(0, 0, 0, 0)

    behavior = Behaviors.RtPropUpdate
    rtAlwaysUpdate = true
    size = map_size
    commands = cmd

    update = function() {
      let ctime = get_sync_time()
      let {sourcePos, sourceRadius, targetPos, targetRadius, startEndTime} = czone
      let radius = math.lerpClamped(startEndTime.x, startEndTime.y, sourceRadius, targetRadius, ctime)
      let worldPos = math.lerpClamped(startEndTime.x, startEndTime.y, sourcePos, targetPos, ctime)
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
  let czone = movingZoneInfo.get()
  if (czone==null)
    return []
  return czone.isCollapsing ? [
    makeDynamicZone(size, czone),
    makeStaticZone(size, futureZoneColor, czone.targetPos, czone.targetRadius)
  ] : [
    makeStaticZone(size, currentZoneColor, czone.sourcePos, czone.sourceRadius, true)
  ]
}

return {
  watch = movingZoneInfo
  ctor = @(p) zones(p?.size)
}
