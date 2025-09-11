from "das.ribbons_color" import get_color_by_index
from "dagor.math" import IPoint2, Point4

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
from "%ui/hud/state/gametype_state.nut" import isOnPlayerBase

let { teamColorIdxs } = require("%ui/profile/profileState.nut")

function indexToColor(index) {
  let scaled = get_color_by_index(index) * 255
  return Color(scaled.x, scaled.y, scaled.z, scaled.w)
}

function arrayToColor(colorArray) {
  if (colorArray == null || colorArray.len() < 4)
    return Color(0, 0, 0, 0)

  let scaled = Point4(colorArray[0] * 255, colorArray[1] * 255, colorArray[2] * 255, colorArray[3] * 255)
  return Color(scaled.x, scaled.y, scaled.z, scaled.w)
}

let setSelectedColorsQuery = ecs.SqQuery("ribbonsColorQuery", {
  comps_rw = [["ribbon_colors__curColors", ecs.TYPE_IPOINT2]],
  comps_rq = ["watchedByPlr"]
})

teamColorIdxs.subscribe(@(v) setSelectedColorsQuery.perform(function(_eid, comp) {
  comp.ribbon_colors__curColors = IPoint2(v.primary, v.secondary)
}))

ecs.register_es("set_selected_colors_on_player_base",
  {
    onInit = function(_eid, comp) {
      if (!isOnPlayerBase.get())
        return
      comp.player_ribbons__curColors = IPoint2(teamColorIdxs.get().primary, teamColorIdxs.get().secondary)
    }
  },
  {
    comps_rw = [["player_ribbons__curColors", ecs.TYPE_IPOINT2]],
  }
)

let ribbonsChanged = Watched(0)
ecs.register_es("ribbons_changed_es",
  {
    [["onInit", "onChange"]] = function(_evt, _eid, _comps) {
      ribbonsChanged.set(ribbonsChanged.get() + 1)
    }
  },
  {
    comps_rq = ["watchedByPlr"],
    comps_track = [["ribbon_colors__curColors", ecs.TYPE_IPOINT2]]
  }
)

return {
  indexToColor
  arrayToColor
  ribbonsChanged
}
