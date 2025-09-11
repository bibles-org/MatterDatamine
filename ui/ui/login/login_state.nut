from "%sqGlob/userInfoState.nut" import userInfoUpdate
from "%dngscripts/globalState.nut" import nestWatched

from "eventbus" import eventbus_subscribe
from "%ui/components/modalWindows.nut" import hideAllModalWindows
import "steam" as steam
from "auth" import token_renew_event, YU2_OK
from "das.profile" import update_authorization_token

from "%ui/ui_library.nut" import *

let { userInfo } = require("%sqGlob/userInfoState.nut")

let isSteamRunning = nestWatched("isSteamRunning", steam.is_running())
let isLoggedIn = keepref(Computed(@() userInfo.get() != null))
let linkSteamAccount = nestWatched("linkSteamAccount", false)

function logOut() {
  log("logout")
  hideAllModalWindows()
  userInfoUpdate(null)
  update_authorization_token("")
}

console_register_command(logOut, "app.logout")

eventbus_subscribe(token_renew_event, function(res) {
  if (res?.status == YU2_OK)
    return

  log($"logout due to auth token renew failure: {res?.status}")
  logOut()
})

return freeze({
  logOut
  isLoggedIn
  isSteamRunning
  linkSteamAccount
})
