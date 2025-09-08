from "%ui/ui_library.nut" import *

let go_login = require("go.nut")
let {login_steam=null}  = require_optional("auth.steam")
let ah = require("auth_helpers.nut")
let { linkSteamAccount } = require("%ui/login/login_state.nut")
let { eventbus_subscribe_onehit } = require("eventbus")

const AUTH_STEAM = "auth_steam"
const STEAM_LINK = "steam_link"

return [
  {
    id = AUTH_STEAM
    function action(state, cb) {
      if (!linkSteamAccount.value) {
        eventbus_subscribe_onehit(AUTH_STEAM, ah.status_cb(cb))
        login_steam?(state.params.onlyKnown, AUTH_STEAM)
      }
      else
        cb({})
    }
  }
  {
    id = go_login.id
    function action(params, cb){
      if (linkSteamAccount.value)
        go_login.action(params, cb)
      else
        cb({})
    }
    actionOnReload = @(_state, _cb) null
  }
  {
    id = STEAM_LINK
    function action(_params, cb) {
      if (linkSteamAccount.value) {
        eventbus_subscribe_onehit(STEAM_LINK, ah.status_cb(cb))
        login_steam?(false, STEAM_LINK)
      }
      else
        cb({})
    }
  }
]
