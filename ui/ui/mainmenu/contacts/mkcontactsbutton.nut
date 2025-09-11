from "%ui/components/colors.nut" import Alert
import "%ui/mainMenu/contacts/buildCounter.nut" as buildCounter
from "%ui/components/button.nut" import squareIconButton

from "%ui/ui_library.nut" import *

let { friendsOnlineUids, requestsToMeUids } = require("%ui/mainMenu/contacts/contactsWatchLists.nut")
let { showCursor } = require("%ui/cursorState.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")

let counterText = @(count) count > 0 ? count : null

let onlineFriendsCounter = buildCounter(
  Computed(@() counterText(friendsOnlineUids.get().len()))
  {pos = [hdpx(5), -hdpx(4)], hplace = ALIGN_RIGHT})

let invitationsCounter = buildCounter(
  Computed(@() counterText(requestsToMeUids.get().len())),
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
