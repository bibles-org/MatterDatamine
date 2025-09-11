from "%ui/panels/console_common.nut" import mkStdPanel, textColor, waitingCursor, inviteText, consoleTitleFontSize, consoleFontSize

from "%ui/ui_library.nut" import *

let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { creditsTextIcon, monolithTokensTextIcon } = require("%ui/mainMenu/currencyIcons.nut")
let { playerProfileCreditsCount, playerProfileMonolithTokensCount } = require("%ui/profile/profileState.nut")

#allow-auto-freeze

return {
  mkMarketPanel = @(canvasSize, data, notifier=null) mkStdPanel(canvasSize, data, {
    children = [
      @() {
        size = flex()
        watch = isOnboarding
        flow = FLOW_VERTICAL
        padding = static [8, 16]
        gap = 2
        children = isOnboarding.get() ? null : [
          {
            flow = FLOW_HORIZONTAL
            valign = ALIGN_CENTER
            size = FLEX_H
            gap = 5
            children = [
              static {rendObj = ROBJ_TEXT text = loc("market/name") fontSize = consoleTitleFontSize color = textColor}
              static {size=static [flex(), 0]}
              @() {rendObj = ROBJ_TEXT text = $"{creditsTextIcon} {playerProfileCreditsCount.get()}" fontSize = consoleFontSize color = textColor watch = playerProfileCreditsCount}
              @() {rendObj = ROBJ_TEXT text = $"{monolithTokensTextIcon} {playerProfileMonolithTokensCount.get()}" fontSize = consoleFontSize color = textColor watch = playerProfileMonolithTokensCount}
            ]
          }
          static {size = flex()}
          inviteText
          waitingCursor
        ]
      }, notifier
    ]
  })
}