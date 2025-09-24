import "%ui/components/msgbox.nut" as msgbox
import "%dngscripts/ecs.nut" as ecs

from "%ui/permissions/permissions.nut" import checkMultiplayerPermissions
from "%ui/matchingClient.nut" import matchingCall, matchingLogin
from "%ui/state/roomState.nut" import joinRoom
from "%sqGlob/userInfoState.nut" import userInfo
from "eventbus" import eventbus_subscribe_onehit
from "app" import get_app_id

from "%ui/ui_library.nut" import *

let { allowReconnect, isLastMatchDisconnect } = require("%ui/state/roomState.nut")
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

ecs.register_es("check_reconnect_on_loaded_profile_es", {
  [["onInit", "onChange"]] = function(_eid, comp){
    if (comp.player_profile__isLoaded && (isLastMatchDisconnect.get() ?? false) && (userInfo.get() != null)) {
      let { userId, name, chardToken, token } = userInfo.get()
      let loginInfo = {
        userId
        name
        chardToken
        authJwt = token 
      }
      matchingLogin(loginInfo)
      eventbus_subscribe_onehit("matching.logged_in", @(...) checkReconnect())
    }
  }
},
{ comps_track=[["player_profile__isLoaded", ecs.TYPE_BOOL]] },
{ tags="gameClient", after="load_profile_server_data_es" }
)

loginState.isLoggedIn.subscribe_with_nasty_disregard_of_frp_update(function (state) {
  if (state)
    checkReconnect()
})

return checkReconnect
