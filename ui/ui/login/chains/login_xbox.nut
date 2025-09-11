from "%ui/ui_library.nut" import *
import "auth" as auth

let loginCb = require("%ui/login/login_cb.nut")

let {init_default_user, init_user_with_ui, shutdown_user} = require("%gdkLib/impl/user.nut")
let { xbox_login } = require("%ui/gdk/login.nut")

let { is_xbox } = require("%dngscripts/platform.nut")



function init_user(state, cb) {
  let login_function =
    (state.params?.xuid != null)
    ? init_default_user
    : init_user_with_ui

  login_function(function(xuid) {
    if (xuid > 0)
      cb({ xuid = xuid })
    else
      cb({ stop = true })
  })
}

let error_cb = @(cb, failure_loc_key, show_error, errorStr = null) @(success)
  success ? cb({}) : cb({error = failure_loc_key, needShowError = show_error, errorStr})

function login_live(state, cb) {
  let platform_loc_prefix = is_xbox ? "xbox" : "pc"
  let failure_loc_key = $"{platform_loc_prefix}/live_login_failed" 
  let xuid = state.stageResult.init_user.xuid
  log($"login live for user {xuid}")
  state.userInfo.xuid <- xuid

  xbox_login(function(status, status_text) {
    let full_error = $"{loc(failure_loc_key)} ({status_text})"
    error_cb(cb, failure_loc_key, true, full_error)(status == auth.YU2_OK)
  })
}










function onSuccess(state) {
  loginCb.onSuccess(state)
  
}

function onInterrupt(state) {
  shutdown_user(function() {
    loginCb.onInterrupt(state)
  })
}

return freeze({
  stages = [
    { id = "init_user", action = init_user, actionOnReload = @(_state, _cb) null },
    { id = "auth_xbox", action = login_live, actionOnReload = @(_state, _cb) null },
    require("%ui/login/stages/eula_before_login.nut"),
    require("%ui/login/stages/auth_result.nut"),
    require("%ui/login/stages/char.nut"),
    require("%ui/login/stages/online_settings.nut"),
    require("%ui/login/stages/eula.nut"),
    require("%ui/login/stages/matching.nut")
  ]
  onSuccess = onSuccess
  onInterrupt = onInterrupt
})
