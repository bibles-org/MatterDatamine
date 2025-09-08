from "%ui/ui_library.nut" import *

let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { mkStdPanel, textColor, waitingCursor, inviteText, consoleTitleFontSize } = require("%ui/panels/console_common.nut")

return {
  mkRefinePanel = @(canvasSize, data) mkStdPanel(canvasSize, data, {
    children = @() {
      size = flex()
      watch = isOnboarding
      flow = FLOW_VERTICAL
      padding = [8, 16]
      gap = 2
      children = isOnboarding.get() ? null : [
        const {rendObj = ROBJ_TEXT text = loc("amClean/start") fontSize = consoleTitleFontSize color = textColor }
        {size = flex()}
        inviteText
        waitingCursor
      ]
    }
  })
}