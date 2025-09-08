from "%ui/ui_library.nut" import *

from "%ui/hud/minimap/map_state.nut" import currentMapVisibleRadius
let { colorblindPalette } = require("%ui/components/colors.nut")
let { Point3 } = require("dagor.math")
let { mkObjectiveIdxMark, color_common } = require("%ui/hud/objectives/objective_components.nut")

let minimapHoverableMarker = require("minimap_hover_hint.nut")

let zeroPos = Point3(0,0,0)

function makeZone(zone, transform, map_size, objectivesValue) {
  let idx = objectivesValue.findindex(function(objective) {
    return (objective?.params?.staticTargetTag.indexof(zone?.objectiveTag) != null ||
            objective?.params?.dynamicTargetTag.indexof(zone?.objectiveTag) != null)
  })

  if (idx == null)
    return

  let { name = "unknown", requiredValue=1, currentValue=1, colorIdx=null } = objectivesValue?[idx]
  let objectiveColor = colorblindPalette?[colorIdx] ?? color_common
  let progress = (requiredValue??1.0) > 0 ? (currentValue ?? 1.0).tofloat()/(requiredValue ?? 1.0) : 1.0
  function objectiveIdxMark() {
    let realVisRadius = currentMapVisibleRadius.get()
    let canvasRadius = zone.radius * min(map_size[0], map_size[1]) / (2 * realVisRadius)
    let needTextMark = zone?.needIdxMark ?? true

    return {
      watch = currentMapVisibleRadius
      children = mkObjectiveIdxMark(needTextMark ? $"{idx+1}" : "", [2 * canvasRadius, 2 * canvasRadius], objectiveColor, progress)
    }
  }

  return minimapHoverableMarker(
    {
      worldPos = zone?["pos"] ?? zeroPos
      clampToBorder = false
      dirRotate = false
    },
    transform,
    loc($"contract/{name}"),
    @(_) objectiveIdxMark
  )
}

function zones(transform, map_size, zonesWatched, objectivesWatched){
  let zonesArr = zonesWatched.get().values()
    .map(@(zone) zone.__merge({radius = zone.radius * 0.9}))
  
  
  let objectivesValue = objectivesWatched.get()

  zonesArr.sort(@(a, b) -(a.radius <=> b.radius))
  return zonesArr.map(@(zone) makeZone(zone, transform, map_size, objectivesValue))
}

return @(zonesWatched, objectivesWatched) {
  watch = [zonesWatched, objectivesWatched]
  ctor = @(p) zones(p?.transform ?? {}, p.size, zonesWatched, objectivesWatched)
}
