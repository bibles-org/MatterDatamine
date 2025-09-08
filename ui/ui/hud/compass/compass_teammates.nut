from "%ui/ui_library.nut" import *

let { teammatesSet, teammatesGetWatched } = require("%ui/hud/state/teammates_es.nut")
let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")
let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")
let { TeammateColor, TEAM0_TEXT_COLOR } = require("%ui/components/colors.nut")
let { orderedTeamNicks } = require("%ui/squad/squad_colors.nut")
let { nexusSelectedNames } = require("%ui/hud/state/nexus_mode_state.nut")

function mkCompassTeammate(eid) {
  let teammateWatched = teammatesGetWatched(eid)
  return function() {
    if (!teammateWatched.get().isAlive)
      return {watch = teammateWatched}

    let colorIdx = orderedTeamNicks.get().findindex(@(v)v == teammateWatched.get().name) ?? 0
    local color = teammateWatched.get().name in nexusSelectedNames.get() ? TEAM0_TEXT_COLOR : TeammateColor[colorIdx]

    return {
      watch = [teammateWatched, orderedTeamNicks, nexusSelectedNames]
      halign = ALIGN_CENTER
      valign = ALIGN_BOTTOM
      transform = {}
      data = {
        eid = eid
        clampToBorder = true
      }
      children = {
        rendObj = ROBJ_IMAGE
        image = Picture($"ui/skin#unit_arrow.svg:{hdpxi(24)}:{hdpxi(32)}:P")
        color = color
        size = [hdpxi(12), hdpxi(16)]
      }
    }
  }
}

return {
  watch = [teammatesSet, controlledHeroEid, watchedHeroEid]
  childrenCtor = @() teammatesSet.get()
    .keys()
    .filter(@(eid) eid != controlledHeroEid.get() && eid != watchedHeroEid.get())
    .map(mkCompassTeammate)
}
