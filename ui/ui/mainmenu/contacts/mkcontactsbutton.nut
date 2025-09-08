from "%ui/ui_library.nut" import *

let { Alert } = require("%ui/components/colors.nut")
let { friendsOnlineUids, requestsToMeUids } = require("%ui/mainMenu/contacts/contactsWatchLists.nut")
let buildCounter = require("buildCounter.nut")
let { squareIconButton } = require("%ui/components/button.nut")
let { showCursor } = require("%ui/cursorState.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")

let counterText = @(count) count > 0 ? count : null

let onlineFriendsCounter = buildCounter(
  Computed(@() counterText(friendsOnlineUids.value.len()))
  {pos = [hdpx(5), -hdpx(4)], hplace = ALIGN_RIGHT})

let invitationsCounter = buildCounter(
  Computed(@() counterText(requestsToMeUids.value.len())),
  {
    pos = [hdpx(4), hdpx(2)]
    vplace = ALIGN_BOTTOM
    hplace = ALIGN_RIGHT
    color = Alert
  })

let contactsButton = @(onClick) @() {
  watch = isOnboarding
  children = !isOnboarding.get() ? [
    squareIconButton({
      onClick
      tooltipText = loc("tooltips/contactsButton")
      iconId = "users"
      isEnable = showCursor
    })
    onlineFriendsCounter
    invitationsCounter
  ] : null
}

return contactsButton
