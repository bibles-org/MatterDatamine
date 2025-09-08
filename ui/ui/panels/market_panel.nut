from "%ui/ui_library.nut" import *

let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { mkStdPanel, textColor, waitingCursor, inviteText, consoleTitleFontSize, consoleFontSize } = require("%ui/panels/console_common.nut")
let { creditsTextIcon, monolithTokensTextIcon } = require("%ui/mainMenu/currencyIcons.nut")
let { playerProfileCreditsCount, playerProfileMonolithTokensCount } = require("%ui/profile/profileState.nut")

return {
  mkMarketPanel = @(canvasSize, data) mkStdPanel(canvasSize, data, {
    children = @() {
      size = flex()
      watch = isOnboarding
      flow = FLOW_VERTICAL
      padding = const [8, 16]
      gap = 2
      children = isOnboarding.get() ? null : [
        {
          flow = FLOW_HORIZONTAL
          valign = ALIGN_CENTER
          size = [flex(), SIZE_TO_CONTENT]
          gap = 5
          children = [
            const {rendObj = ROBJ_TEXT text = loc("market/name") fontSize = consoleTitleFontSize color = textColor}
            const {size=[flex(), 0]}
            @() {rendObj = ROBJ_TEXT text = $"{creditsTextIcon} {playerProfileCreditsCount.get()}" fontSize = consoleFontSize color = textColor watch = playerProfileCreditsCount}
            @() {rendObj = ROBJ_TEXT text = $"{monolithTokensTextIcon} {playerProfileMonolithTokensCount.get()}" fontSize = consoleFontSize color = textColor watch = playerProfileMonolithTokensCount}
          ]
        }
        const {size = flex()}
        inviteText
        waitingCursor
      ]
    }
  })
}