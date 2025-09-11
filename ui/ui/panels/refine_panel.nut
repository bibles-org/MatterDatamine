from "%ui/panels/console_common.nut" import mkStdPanel, textColor, waitingCursor, inviteText, consoleTitleFontSize
from "%ui/ui_library.nut" import *

let { refinesReady } = require("%ui/mainMenu/amProcessingSelectItem.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")

#allow-auto-freeze

return {
  mkRefinerNotifications = @() refinesReady
  mkRefinePanel = @(canvasSize, data, notifier=null) mkStdPanel(canvasSize, data, {
    children = [ @() {
      size = flex()
      watch = isOnboarding
      flow = FLOW_VERTICAL
      padding = static [8, 16]
      gap = 2
      children = isOnboarding.get() ? null : [
        static {rendObj = ROBJ_TEXT text = loc("amClean/start") fontSize = consoleTitleFontSize color = textColor }
        {size = flex()}
        inviteText
        waitingCursor
      ]
    }, notifier]
  })
}