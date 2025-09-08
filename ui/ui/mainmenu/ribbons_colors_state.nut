import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { get_color_by_index } = require("das.ribbons_color")
let { teamColorIdxs } = require("%ui/profile/profileState.nut")
let { IPoint2, Point4 } = require("dagor.math")
let { EventLocalPlayerRibbonsChanged } = require("dasevents")
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")

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
  comps_rw = [["player_ribbons__curColors", ecs.TYPE_IPOINT2]],
  comps_ro = [["is_local", ecs.TYPE_BOOL]]
})

teamColorIdxs.subscribe(@(v) setSelectedColorsQuery.perform(function(_eid, comp) {
  if (comp.is_local)
    comp.player_ribbons__curColors = IPoint2(v.primary, v.secondary)
}))

ecs.register_es("set_selected_colors_on_local_hero",
  {
    [["onInit", "onChange"]] = function(_eid, comp) {
      if (!isOnPlayerBase.get())
        return

      if (comp.is_local)
        comp.player_ribbons__curColors = IPoint2(teamColorIdxs.get().primary, teamColorIdxs.get().secondary)
    }
  },
  {
    comps_rw = [["player_ribbons__curColors", ecs.TYPE_IPOINT2]],
    comps_track = [["is_local", ecs.TYPE_BOOL]]
  }
)

let ribbonsChanged = Watched(0)
ecs.register_es("ribbons_changed_es",
  {
    [EventLocalPlayerRibbonsChanged] = function(_evt, _eid, _comps) {
      ribbonsChanged.set(ribbonsChanged.get() + 1)
    }
  }
)

return {
  indexToColor
  arrayToColor
  ribbonsChanged
}
