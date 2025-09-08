from "%ui/ui_library.nut" import *

import "%ui/components/fontawesome.map.nut" as fa
let { body_txt, fontawesome } = require("%ui/fonts_style.nut")
let { TextNormal, RedWarningColor } = require("%ui/components/colors.nut")
let { notificationText } = require("%ui/hud/state/in_battle_squad_notification_state.nut")
let { sound_play } = require("%dngscripts/sound_system.nut")
let { sideNotificationStyle } = require("%ui/components/commonComponents.nut")


let icon = {
  rendObj = ROBJ_TEXT
  font = fontawesome.font
  fontSize = fontawesome.fontSize
  text = fa["exclamation"]
}

let titleText = @() body_txt.__merge({
  watch = notificationText
  rendObj = ROBJ_TEXT
  color = TextNormal
  text = notificationText.get()
})

let title = {
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  gap = hdpx(5)
  children = [
    icon
    titleText
  ]
}

let notification = sideNotificationStyle.__merge({
  borderColor = RedWarningColor
  flow = FLOW_VERTICAL
  children = title
  onAttach = @() sound_play("ui_sounds/teammate_leave")
})

return @() {
  watch = notificationText
  children = notificationText.get() != null ? notification : null
}
