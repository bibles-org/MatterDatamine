from "%ui/ui_library.nut" import *

let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { unreadNum } = require("%ui/mainMenu/mailboxState.nut")
let { mkStdPanel, textColor, waitingCursor, inviteText, consoleTitleFontSize, consoleFontSize } = require("%ui/panels/console_common.nut")
let { friendsOnlineUids, requestsToMeUids } = require("%ui/mainMenu/contacts/contactsWatchLists.nut")

return {
  mkContactsPanel = @(canvasSize, data) mkStdPanel(canvasSize, data, {
    children = @() {
      size = flex()
      watch = isOnboarding
      flow = FLOW_VERTICAL
      padding = const [8, 16]
      gap = 2
      children = isOnboarding.get() ? null : [
        const {rendObj = ROBJ_TEXT text = "Intercom" fontSize = consoleTitleFontSize color = textColor}
        @() {rendObj = ROBJ_TEXT text = $"Messages: {unreadNum.get()}" fontSize = consoleFontSize color = textColor watch = unreadNum}
        @() {rendObj = ROBJ_TEXT text = $"Friends Online: {friendsOnlineUids.get().len()}" fontSize = consoleFontSize color = textColor watch = unreadNum}
        @() {rendObj = ROBJ_TEXT text = $"Waiting Requests: {requestsToMeUids.get().len()}" fontSize = consoleFontSize color = textColor watch = unreadNum}
        const {size = flex()}
        inviteText
        waitingCursor
      ]
    }
  })
}