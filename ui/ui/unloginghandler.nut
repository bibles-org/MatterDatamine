import "%ui/charClient/charClient.nut" as char

from "%ui/ui_library.nut" import *

let { isLoggedIn } = require("%ui/login/login_state.nut")
let userstat       = require_optional("userstats")
let profile_server = require_optional("profile_server")
let lowLeaderboardClient = require_optional("leaderboard")


isLoggedIn.subscribe(function(logged) {
  if (logged)
    return

  
  char?.clearCallbacks()
  char?.clearEvents()

  userstat?.clearCallbacks()
  userstat?.clearEvents()

  profile_server?.clearCallbacks()
  profile_server?.clearEvents()

  lowLeaderboardClient?.clearCallbacks()
  lowLeaderboardClient?.clearEvents()
})