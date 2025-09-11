import "%ui/components/msgbox.nut" as msgbox

from "%ui/permissions/permissions.nut" import checkMultiplayerPermissions
from "%ui/matchingClient.nut" import matchingCall
from "%ui/state/roomState.nut" import joinRoom
from "app" import get_app_id

from "%ui/ui_library.nut" import *

let { allowReconnect, lastRoomResult } = require("%ui/state/roomState.nut")
let { isInBattleState } = require("%ui/state/appState.nut")
let isReconnectChecking = mkWatched(persist, "isReconnectChecking", false)
let loginState = require("%ui/login/login_state.nut")

function checkReconnect() {
  if (isInBattleState.get() || !allowReconnect.get() || isReconnectChecking.get())
    return
  if (!checkMultiplayerPermissions()) {
    log("no permissions to join lobby")
    return
  }

  isReconnectChecking.set(true)
  matchingCall("enlmm.check_reconnect",
    function(response) {
      isReconnectChecking.set(false)
      let roomId = response?.roomId
      if (roomId == null)
        return

      log("found reconnect for room", roomId)
      msgbox.showMsgbox({
        text = loc("do_you_want_to_reconnect"),
        buttons = [
          {
            text = loc("Yes")
            action = @() joinRoom({ roomId = roomId }, false, function(...) {})
            isCurrent = true
          },
          {
            text = loc("No")
            isCancel = true
          }
        ]

      })
    },
    {appId = get_app_id()})
}

lastRoomResult.subscribe_with_nasty_disregard_of_frp_update(function(result) {
  if (result?.isDisconnect ?? false)
    defer(checkReconnect) 
})

loginState.isLoggedIn.subscribe_with_nasty_disregard_of_frp_update(function (state) {
  if (state)
    checkReconnect()
})

return checkReconnect
