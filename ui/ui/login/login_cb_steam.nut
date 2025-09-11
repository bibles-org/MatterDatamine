import "%ui/components/msgbox.nut" as msgbox

import "auth" as auth
import "%ui/login/login_cb.nut" as defLoginCb
from "%ui/login/login_chain.nut" import startLogin

from "%ui/ui_library.nut" import *

let { linkSteamAccount } = require("%ui/login/login_state.nut")


let isNewSteamAccount = mkWatched(persist, "isNewSteamAccount", false) 

function createSteamAccount() {
  linkSteamAccount.set(false)
  startLogin({ onlyKnown = false })
}

let steamNewAccountMsg = @() msgbox.showMsgbox({
  text = loc("msg/steam/loginByGaijinNet")
  buttons = [
    { text = loc("LoginViaGaijinNet"), isCurrent = true, action = @() linkSteamAccount.set(true) }
    { text = loc("CreateSteamAccount"), action = createSteamAccount }
  ]
})

function onSuccess(state) {
  state.userInfo.isNewSteamAccount <- isNewSteamAccount.get()
  defLoginCb.onSuccess(state)
  isNewSteamAccount.set(false)
}

function onInterrupt(state) {
  if (state?.status == auth.YU2_NOT_FOUND) {
    isNewSteamAccount.set(true)
    steamNewAccountMsg()
    return
  }

  defLoginCb.onInterrupt(state)
}

return {
  onSuccess = onSuccess
  onInterrupt = onInterrupt
}
