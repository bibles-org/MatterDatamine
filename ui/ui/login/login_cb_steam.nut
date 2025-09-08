from "%ui/ui_library.nut" import *

let auth = require("auth")
let defLoginCb = require("%ui/login/login_cb.nut")
let {startLogin} = require("%ui/login/login_chain.nut")
let {linkSteamAccount} = require("%ui/login/login_state.nut")
let msgbox = require("%ui/components/msgbox.nut")


let isNewSteamAccount = mkWatched(persist, "isNewSteamAccount", false) 

function createSteamAccount() {
  linkSteamAccount(false)
  startLogin({ onlyKnown = false })
}

let steamNewAccountMsg = @() msgbox.showMsgbox({
  text = loc("msg/steam/loginByGaijinNet")
  buttons = [
    { text = loc("LoginViaGaijinNet"), isCurrent = true, action = @() linkSteamAccount(true) }
    { text = loc("CreateSteamAccount"), action = createSteamAccount }
  ]
})

function onSuccess(state) {
  state.userInfo.isNewSteamAccount <- isNewSteamAccount.value
  defLoginCb.onSuccess(state)
  isNewSteamAccount(false)
}

function onInterrupt(state) {
  if (state?.status == auth.YU2_NOT_FOUND) {
    isNewSteamAccount(true)
    steamNewAccountMsg()
    return
  }

  defLoginCb.onInterrupt(state)
}

return {
  onSuccess = onSuccess
  onInterrupt = onInterrupt
}
