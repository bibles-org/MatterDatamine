import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
from "dasevents" import EventScanPointsOfInterest
from "math" import max, min

import "%ui/hud/map/map_hover_hint.nut" as mapHoverableMarker
from "%ui/hud/objectives/objective_components.nut" import mkObjectiveIdxMark
from "%ui/components/colors.nut" import colorblindPalette
from "%ui/hud/objectives/objective_components.nut" import color_common
from "%ui/helpers/timers.nut" import mkCountdownTimer
from "net" import get_sync_time

from "%sqGlob/dasenums.nut" import HumanScanPointType

let { objectives } = require("%ui/hud/state/objectives_vars.nut")

let { currentMapVisibleRadius } = require("%ui/hud/map/map_state.nut")

let scanPointsOfInterestMapMarks = Watched({})

let scanData = Watched(null)


function deleteEid(eid, state){
  if (eid in state.get())
    state.mutate(@(v) v.$rawdelete(eid))
}


ecs.register_es("scan_points_of_interest_map_mark_zones_ui_es",
  {
     [["onChange", "onInit"]] = function(eid, comp){
      if (!comp.map_object__show) {
        deleteEid(eid, scanPointsOfInterestMapMarks)
        return
      }

      scanPointsOfInterestMapMarks.mutate(@(v) v[eid] <- {
        pos = comp.transform[3],
        eid,
        radius = comp.map_object_zone__radius,
        pointType = comp.human_scan_point_of_interest_mark__pointType,
        objectiveEid = comp.human_scan_point_of_interest_mark__objectiveEid
      })
    },
    onDestroy = function(eid, _comp){
      deleteEid(eid, scanPointsOfInterestMapMarks)
    }
  },
  {
    comps_rq = [
      ["human_scan_point_of_interest_mark", ecs.TYPE_TAG]
    ],
    comps_track = [["map_object__show", ecs.TYPE_BOOL]],
    comps_ro = [
      ["transform", ecs.TYPE_MATRIX],
      ["map_object_zone__radius", ecs.TYPE_FLOAT],
      ["human_scan_point_of_interest_mark__pointType", ecs.TYPE_INT],
      ["human_scan_point_of_interest_mark__objectiveEid", ecs.TYPE_EID]
    ]
  }
)

function hideScanCircle() {
  scanData.set(null)
}

ecs.register_es("scan_points_of_interest_map_scan_started_1",
  {
    [[EventScanPointsOfInterest]] = function(_evt, _eid, comp){

      scanData.set({
        position = comp.transform[3]
        radius = comp.human_scan_points_of_interest__searchRange.y
        scanDur = comp.human_scan_points_of_interest__markShowDelayPerRelDist
      })
      gui_scene.setTimeout(comp.human_scan_points_of_interest__markShowDelayPerRelDist, hideScanCircle)
    }
  },
  {
    comps_rq = ["hero", "watchedByPlr"]
    comps_ro = [
      ["transform", ecs.TYPE_MATRIX],
      ["human_scan_points_of_interest__searchRange", ecs.TYPE_POINT2],
      ["human_scan_points_of_interest__markShowDelayPerRelDist", ecs.TYPE_FLOAT]
    ]
  }
)

let SCAN_POINTS_OF_INTEREST_MARK_COLOR = Color(140, 140,140)

function mkScanPointOfInterestMapMarkZone(zone, map_size){

  local nameLocKey = "hint/scan_points_of_interest_map_mark_unknown"
  local color = SCAN_POINTS_OF_INTEREST_MARK_COLOR

  let objectiveIdx = objectives.get()?.findindex(@(objective) objective?.eid == zone.objectiveEid) ?? -1

  if (objectiveIdx >= 0) {
    let { colorIdx = null } = objectives.get()?[objectiveIdx]
    color = colorblindPalette?[colorIdx] ?? color_common

    if (zone.pointType == HumanScanPointType.LOOT)
        nameLocKey = "hint/scan_points_of_interest_map_mark_objective_loot"
    else if (zone.pointType == HumanScanPointType.ENEMY)
        nameLocKey = "hint/scan_points_of_interest_map_mark_objective_enemy"
  }
  else {
    if (zone.pointType == HumanScanPointType.LOOT)
        nameLocKey = "hint/scan_points_of_interest_map_mark_loot"
    else if (zone.pointType == HumanScanPointType.ENEMY)
        nameLocKey = "hint/scan_points_of_interest_map_mark_enemy"
  }

  function objectiveIdxMark() {
    let realVisRadius = currentMapVisibleRadius.get()
    let canvasRadius = zone.radius * min(map_size[0], map_size[1]) / (2 * realVisRadius)
    let needTextMark = objectiveIdx >= 0 && (zone?.needIdxMark ?? true)

    return {
      watch = currentMapVisibleRadius
      children = mkObjectiveIdxMark(needTextMark ? $"{objectiveIdx + 1}" : "", [2 * canvasRadius, 2 * canvasRadius], color)
    }
  }

  let transform = static { pivot = [0.5, 0.5] }

  return mapHoverableMarker(
    {
      worldPos = zone.pos,
      clampToBorder = false
      dirRotate = false
    },
    transform,
    loc(nameLocKey),
    @(_) objectiveIdxMark,
    {
      animations = static [
        { prop=AnimProp.opacity, from=0, to=1, duration=0.3, play=true, easing=InCubic },
        { prop=AnimProp.scale, from=[4,4], to=[1,1], duration=0.4, play=true, easing=InCubic }
     ],
     key = zone.eid
   }
  )
}


function mkScanPointOfInterestMapMarkZones(marks, map_size) {
  return marks.map(@(data) mkScanPointOfInterestMapMarkZone(data, map_size))
}

let radarCircleId = {}
function mkRaradCircle(map_size) {
  let data = scanData.get()
  if (data == null)
    return null
  let sz = data.radius
  let timer = mkCountdownTimer(Watched(get_sync_time() + data.scanDur), radarCircleId)
  let dur = data.scanDur
  let minOpacity = 0.2

  return {
    size = static [ 1, 1 ]
    data = {
      worldPos = data.position,
      clampToBorder = false
      dirRotate = false
    }
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    transform = static {}
    children = function() {
      let factor = 1.0 - (timer.get() / dur)

      let realVisRadius = currentMapVisibleRadius.get()
      let canvasRadius = sz * factor * min(map_size.size[0], map_size.size[1]) / (2 * realVisRadius)

      return {
        transform = static {}
        watch = [ timer, currentMapVisibleRadius ]
        size = [ canvasRadius, canvasRadius ]
        rendObj = ROBJ_VECTOR_CANVAS
        opacity = max(minOpacity, 1.0 - factor)
        commands = static [
          [VECTOR_WIDTH, hdpx(1)],
          [VECTOR_FILL_COLOR, 0],
          [VECTOR_COLOR, Color(100, 100, 100, 50)],
          [VECTOR_ELLIPSE, 50, 50, 50, 50],
        ]
      }
    }
  }
}

return {
  scannedPoints = {
    watch = scanPointsOfInterestMapMarks
    ctor = @(p) mkScanPointOfInterestMapMarkZones(scanPointsOfInterestMapMarks.get().values(), p?.size)
  }
  radarCircle = {
    watch = scanData
    ctor = mkRaradCircle
  }
}