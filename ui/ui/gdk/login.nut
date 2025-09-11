from "%sqGlob/library_logs.nut" import with_prefix
from "%gdkLib/impl/user.nut" import retrieve_auth_token
from "auth" import status_string, YU2_WRONG_PARAMETER
from "auth.xbox" import get_xbox_login_url, login_live
from "eventbus" import eventbus_subscribe_onehit

let logX = with_prefix("[XBOX_LOGIN] ")


function xbox_login_impl(token, signature, callback) {
  let eventName = "login_live"
  eventbus_subscribe_onehit(eventName, function(result) {
    let status = result?.status
    let statusText = status_string(status)
    callback(status, statusText)
  })
  login_live(token, signature, eventName)
}


function xbox_login(callback) {
  retrieve_auth_token(get_xbox_login_url(), "POST", function(success, token, signature) {
    logX($"get_auth_token succeeeded: {success}")
    if (!success) {
      callback(YU2_WRONG_PARAMETER, "Failed to get user token/signature")
      return
    }
    xbox_login_impl(token, signature, callback)
  })
}


return {
  xbox_login
}