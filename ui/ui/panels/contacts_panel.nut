from "%ui/panels/console_common.nut" import mkStdPanel, textColor, waitingCursor, inviteText, consoleTitleFontSize, consoleFontSize

from "%ui/ui_library.nut" import *

let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { unreadNum } = require("%ui/mainMenu/mailboxState.nut")
let { friendsOnlineUids, requestsToMeUids } = require("%ui/mainMenu/contacts/contactsWatchLists.nut")

#allow-auto-freeze

return {
  mkContactsPanel = @(canvasSize, data, notifier=null) mkStdPanel(canvasSize, data, {
    children = [
      @() {
        size = flex()
        watch = isOnboarding
        flow = FLOW_VERTICAL
        padding = static [8, 16]
        gap = 2
        children = isOnboarding.get() ? null : [
          static {rendObj = ROBJ_TEXT text = loc("intercom/console/header") fontSize = consoleTitleFontSize color = textColor}
          @() {rendObj = ROBJ_TEXT text = loc("intercom/console/messages", {num = unreadNum.get()}) fontSize = consoleFontSize color = textColor watch = unreadNum}
          @() {rendObj = ROBJ_TEXT text = loc("intercom/console/online", {num = friendsOnlineUids.get().len()}) fontSize = consoleFontSize color = textColor watch = unreadNum}
          @() {rendObj = ROBJ_TEXT text = loc("intercom/console/requests", {num=requestsToMeUids.get().len()}) fontSize = consoleFontSize color = textColor watch = unreadNum}
          static {size = flex()}
          inviteText
          waitingCursor
        ]
      }
      notifier
    ]
  })
}