from "%ui/ui_library.nut" import *

let {eventbus_subscribe} = require("eventbus")
let {userInfoUpdate, userInfo} = require("%sqGlob/userInfoState.nut")
let {hideAllModalWindows} = require("%ui/components/modalWindows.nut")
let steam = require("steam")
let { token_renew_event, YU2_OK } = require("auth")
let {nestWatched} = require("%dngscripts/globalState.nut")

let isSteamRunning = nestWatched("isSteamRunning", steam.is_running())
let isLoggedIn = keepref(Computed(@() userInfo.value != null))
let linkSteamAccount = nestWatched("linkSteamAccount", false)

function logOut() {
  log("logout")
  hideAllModalWindows()
  userInfoUpdate(null)
}

console_register_command(logOut, "app.logout")

eventbus_subscribe(token_renew_event, function(res) {
  if (res?.status == YU2_OK)
    return

  log($"logout due to auth token renew failure: {res?.status}")
  logOut()
})

return {
  logOut
  isLoggedIn
  isSteamRunning
  linkSteamAccount
}
