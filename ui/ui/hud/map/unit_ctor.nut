from "math" import ceil
from "%ui/hud/state/teammates_es.nut" import teammatesGetWatched
from "%ui/components/colors.nut" import TeammateColor, TEAM0_TEXT_COLOR

from "%ui/ui_library.nut" import *

let { teammatesSet, groupmatesSet } = require("%ui/hud/state/teammates_es.nut")
let { orderedTeamNicks } = require("%ui/squad/squad_colors.nut")
let { nexusSelectedNames } = require("%ui/hud/state/nexus_mode_state.nut")

let unitArrowSz = [ceil(fsh(0.93)), ceil(fsh(1.44))]
let unitDownedSz = [ceil(fsh(1.6)), ceil(fsh(1.6))]

let unit_arrow = Picture("ui/skin#unit_arrow.svg:{0}:{1}:P".subst(
  unitArrowSz[0], unitArrowSz[1]))
let unit_downed = Picture("ui/skin#distress.svg:{0}:{1}:P".subst(
  unitDownedSz[0], unitDownedSz[1]))

let disstressColor = Color(240, 100, 50, 255)

let mkUnitIcon = memoize(function(fillColor) {
  return {
    rendObj = ROBJ_IMAGE
    color = fillColor
    image = unit_arrow
    size = unitArrowSz
  }
})

let downedIcon = {
  rendObj = ROBJ_IMAGE
  color = disstressColor
  image = unit_downed
  size = unitDownedSz
}

function mkMapUnit(eid) {
  let teammateWatched = teammatesGetWatched(eid)
  return function() {
    if (!teammateWatched.get().isAlive)
      return {watch = teammateWatched}
    let colorIdx = orderedTeamNicks.get().findindex(@(v)v == teammateWatched.get().name) ?? 0
    local color = teammateWatched.get().name in nexusSelectedNames.get() ? TEAM0_TEXT_COLOR : TeammateColor[colorIdx]

    return {
      watch = [teammateWatched, orderedTeamNicks, groupmatesSet, nexusSelectedNames]
      key = eid
      data = {
        eid = eid
        dirRotate = true
      }
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      transform = {}
      children = teammateWatched.get().isDowned ? downedIcon : mkUnitIcon(color)
    }
  }
}

return{
  teammatesMarkers = {
    watch = teammatesSet
    ctor = @(_) teammatesSet.get()
      .keys()
      .map(mkMapUnit)
  }
}