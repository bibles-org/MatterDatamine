from "dagor.math" import Point2
from "dagor.debug" import logerr

from "%ui/ui_library.nut" import *
let { lastBattleResult } = require("%ui/profile/profileState.nut")
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")
let { journalBattleResult } = require("%ui/profile/battle_results.nut")


let playerPath = Computed(function() {
  if (!isOnPlayerBase.get()
    || (lastBattleResult.get()?.trackPoints == null && journalBattleResult.get()?.trackPoints == null)
  )
    return null

  let trackPoints = lastBattleResult.get()?.trackPoints ?? journalBattleResult.get().trackPoints
  if (trackPoints.len() < 2)
    return null

  let points = trackPoints.map(@(p) Point2(p.position.x, p.position.z))
  let [lt, rb] = points.reduce(@(acc, p) [
      Point2(min(acc[0].x, p.x), min(acc[0].y, p.y)),
      Point2(max(acc[1].x, p.x), max(acc[1].y, p.y))
    ], [Point2(100000, 100000), Point2(-100000, -100000)])
  let w = max(1, rb.x - lt.x) 
  let h = max(1, rb.y - lt.y)

  let center = Point2((lt.x + rb.x) / 2.0, (lt.y + rb.y) / 2.0)

  let relativePoints = points.map(function(p) {
    let point = Point2(p.x - center.x, p.y - center.y)
    
    
    return Point2(50.0 + point.x / w * 100.0, 50.0 - point.y / h * 100.0)
  })

  
  let pathSegments = []
  let pathSegmentIndices = []
  let transPortalPoints = []
  let transPortalPointsToDraw = []
  local curSegmentStart = 0
  for (local i = 0; i < relativePoints.len(); i++) {
    if (trackPoints[i].eventType == "transPortalFrom") {
      if (i + 1 >= relativePoints.len() || trackPoints[i + 1].eventType != "transPortalTo") {
        logerr($"Missing transPortalTo event for player track point {i}")
        continue
      }

      let curPoint = {
        fromPos = relativePoints[i]
        toPos = relativePoints[i + 1]
        fromEid = trackPoints[i]?.eid ?? 0
        toEid = trackPoints[i + 1]?.eid ?? 0
      }

      let eidPair = curPoint.fromEid < curPoint.toEid
        ? [curPoint.fromEid, curPoint.toEid]
        : [curPoint.toEid, curPoint.fromEid]

      
      let prevPairIdx = transPortalPoints.findindex(function(value) {
        let otherPair = value.fromEid < value.toEid ? [value.fromEid, value.toEid] : [value.toEid, value.fromEid]
        return isEqual(otherPair, eidPair)
      })
      let needDraw = curPoint.fromEid == 0 || curPoint.toEid == 0 || prevPairIdx == null

      transPortalPoints.append(curPoint)
      if (needDraw) {
        transPortalPointsToDraw.append([curPoint.fromPos, curPoint.toPos])
      }

      pathSegmentIndices.append([curSegmentStart, i + 1])
      pathSegments.append(relativePoints.slice(curSegmentStart, i + 1))
      curSegmentStart = i + 1
      i += 1 
      continue
    } else if (trackPoints[i].eventType == "died") {
      pathSegmentIndices.append([curSegmentStart, i + 1])
      pathSegments.append(relativePoints.slice(curSegmentStart, i + 1))
    } else if (trackPoints[i].eventType == "respawned") {
      if (i != 0) {
        pathSegmentIndices.append([curSegmentStart, i])
        pathSegments.append(relativePoints.slice(curSegmentStart, i))
      }
      curSegmentStart = i
    } else if (trackPoints[i].eventType == "positionPoint") {
      continue
    }
  }
  pathSegmentIndices.append([curSegmentStart, relativePoints.len()])
  pathSegments.append(relativePoints.slice(curSegmentStart))

  return {
    pathSegments,
    transPortalPoints,
    transPortalPointsToDraw,
    center,
    relativePoints,
    width = w,
    height = h,
    pathSegmentIndices
  }
})

return {
  playerPath
}
