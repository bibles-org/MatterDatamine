from "%ui/ui_library.nut" import *

let {checkMultiplayerPermissions} = require("permissions/permissions.nut")
let { matchingCall } = require("matchingClient.nut")
let { joinRoom, allowReconnect, lastRoomResult } = require("state/roomState.nut")
let { isInBattleState } = require("%ui/state/appState.nut")
let msgbox = require("%ui/components/msgbox.nut")
let isReconnectChecking = mkWatched(persist, "isReconnectChecking", false)
let {get_app_id} = require("app")
let loginState = require("%ui/login/login_state.nut")

function checkReconnect() {
  if (isInBattleState.value || !allowReconnect.value || isReconnectChecking.value)
    return
  if (!checkMultiplayerPermissions()) {
    log("no permissions to join lobby")
    return
  }

  isReconnectChecking(true)
  matchingCall("enlmm.check_reconnect",
    function(response) {
      isReconnectChecking(false)
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

lastRoomResult.subscribe(function(result) {
  if (result?.isDisconnect ?? false)
    defer(checkReconnect) 
})

loginState.isLoggedIn.subscribe(function (state) {
  if (state)
    checkReconnect()
})

return checkReconnect
