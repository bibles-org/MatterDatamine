from "dagor.math" import Point3
from "%ui/helpers/parseSceneBlk.nut" import get_zone_info

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { lastBattleResult } = require("%ui/profile/profileState.nut")
let { journalBattleResult } = require("%ui/profile/battle_results.nut")
let { currentMapVisibleRadius } = require("%ui/hud/map/map_state.nut")

function makeZone(map_size) {
  let battleResult = lastBattleResult.get() ?? journalBattleResult.get()
  let scene = battleResult?.battleAreaInfo?.scene

  if (scene == null)
    return null

  let zoneInfo = get_zone_info(scene)

  let battleAreaRadius = zoneInfo?.radius
  let battleAreaCenter = zoneInfo?.sourcePos

  if (battleAreaRadius == null || battleAreaCenter == null)
    return null
  let color = Color(70,70,70,128)

  function zone(){
    let realVisRadius = currentMapVisibleRadius.get()
    if (realVisRadius == 0.0) {
      return null
    }
    let canvasRadius = battleAreaRadius / realVisRadius * 50
    let {x, y, z} = battleAreaCenter
    return {
      watch = currentMapVisibleRadius
      data = {
        worldPos = Point3(x, y, z)
        clampToBorder = false
      }
      transform = {
        pivot = [0.5, 0.5]
      }
      rendObj = ROBJ_VECTOR_CANVAS
      ignoreEarlyClip = true
      lineWidth = hdpx(2)
      color = color
      fillColor = Color(0, 0, 0, 0)
      size = map_size
      commands = [
        
        [VECTOR_COLOR, Color(0, 0, 0, 0)],
        [VECTOR_MID_COLOR, Color(20, 20, 20, 230)],
        [VECTOR_FILL_COLOR, Color(0, 0, 0, 0)],
        [VECTOR_WIDTH, map_size ? map_size[0] : 100],
        [VECTOR_OUTER_LINE],
        [VECTOR_ELLIPSE, 50, 50, canvasRadius, canvasRadius],
        [VECTOR_CENTER_LINE],
        [VECTOR_MID_COLOR],

        
        [VECTOR_COLOR, Color(0, 0, 0, 100)],
        [VECTOR_WIDTH, hdpx(2) * 1.5],
        [VECTOR_ELLIPSE, 50, 50, canvasRadius, canvasRadius],

        
        [VECTOR_WIDTH],
        [VECTOR_COLOR],
        [VECTOR_ELLIPSE, 50, 50, canvasRadius, canvasRadius],
      ]
    }
  }
  return zone
}

return {
  watch = [lastBattleResult, journalBattleResult]
  ctor = @(p) makeZone(p?.size)
}
