from "%ui/components/colors.nut" import TeammateColor, TEAM0_TEXT_COLOR
from "%ui/components/commonComponents.nut" import mkText
from "%ui/fonts_style.nut" import tiny_txt
from "%ui/hud/map/map_user_points.nut" import user_points_icons, markSz
from "%ui/hud/state/user_points.nut" import user_points, teammatesPointsOpacity, playerPointsOpacity

from "%ui/ui_library.nut" import *

let { orderedTeamNicks } = require("%ui/squad/squad_colors.nut")
let { nexusSelectedNames } = require("%ui/hud/state/nexus_mode_state.nut")

#allow-auto-freeze

let animations = static [
  { prop=AnimProp.scale, from=[0, 0], to=[1, 1], duration=0.1, play=true, easing=InCubic }
  { prop=AnimProp.scale, from=[1, 1], to=[1.25, 1.25], duration=1, play=true, delay=0.1, easing=DoubleBlink }
]

let function makeUserPoint(eid, data, color) {
  let iconDesc = user_points_icons?[data.userPointType]
  let iconName = iconDesc?.icon ?? user_points_icons.pin_1
  let pin = {
      size = markSz
      rendObj = ROBJ_IMAGE
      color
      pos = [0, -markSz[1]]
      image = Picture($"{iconName}:{markSz[0]}:{markSz[1]}:P")
      halign = ALIGN_CENTER
      children = iconDesc?.text ? mkText(iconDesc?.text, {
        color
        valign = ALIGN_CENTER
        halign = ALIGN_CENTER
        size = flex()
        pos = iconDesc?.textPos
      }) : null

  }

  return @() {
    watch = data?.byLocalPlayer ? playerPointsOpacity : teammatesPointsOpacity
    size = markSz
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    transform = static {}
    animations
    opacity = data?.byLocalPlayer ? playerPointsOpacity.get() : teammatesPointsOpacity.get()

    data = {
      eid = eid
      clampToBorder = true
    }

    children = pin
  }
}

let userPoints = Computed(function(){
  #forbid-auto-freeze
  let components = []
  foreach (eid, data in user_points.get()) {
    let { playerNick = "" } = data
    let colorIdx = orderedTeamNicks.get().findindex(@(v) v == playerNick) ?? 0
    let color = playerNick in nexusSelectedNames.get() ? TEAM0_TEXT_COLOR : TeammateColor[colorIdx]
    components.append(makeUserPoint(eid, data, color))
  }

  return components
})

return userPoints
