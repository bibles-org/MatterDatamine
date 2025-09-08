from "%ui/ui_library.nut" import *

let loginCb = require("%ui/login/login_cb.nut")
let ah = require("%ui/login/stages/auth_helpers.nut")
let auth = require("auth.psn")
let psnUser = require("sony.user")
let {sendPsPlusStatusToUserstatServer = null} = null 
let {voiceChatEnabled} = require("%ui/voiceChat/voiceChatGlobalState.nut")
let { eventbus_subscribe_onehit } = require("eventbus")
let {get_auth_data_async, check_age_restrictions, check_parental_control, is_new_package_available} = require("dng.sony")

function login_psn(state, cb) {
  eventbus_subscribe_onehit("login_psn", ah.status_cb(cb))
  auth.login_psn(state.stageResult.sony_auth_data, "login_psn")
}

function sony_auth_data_stage(cb) {
  let evtname = "dng.sony.auth_data_login"
  eventbus_subscribe_onehit(evtname, function(result_in) {
    let result = clone result_in
    if (result.error == true)
      result.error = "get_auth_data failed"
    else
      result.$rawdelete("error")
    cb(result)
  })
  get_auth_data_async(evtname)
}

function update_premium_permissions(_state, cb) {
  psnUser.requestPremiumStatusUpdate(@(_ignored) cb({}))
}

function check_age_restrictions_stage(cb) {
  eventbus_subscribe_onehit("dng.sony.age_restriction", function(data) {
    if (data.succeeded) {
      cb({})
    } else {
      let errorCode = is_new_package_available() ? "new_package_available" : "age_restriction_check_failed"
      cb({ error = errorCode, needShowError = data.messageNeeded })
    }
  })
  check_age_restrictions()
}

function check_parental_control_stage(cb) {
  eventbus_subscribe_onehit("dng.sony.parental_control", function(restrictions) {
    if (restrictions.chat) {
      log("VoiceChat disabled due to parental control restrictions")
      voiceChatEnabled(false)
    }
    cb({})
  })
  check_parental_control()
}

function send_ps_plus_status(state) {
  if (sendPsPlusStatusToUserstatServer==null)
    return
  let token = state.stageResult.auth_result.token
  let havePsPlus = auth.have_ps_plus_subscription()
  log($"[PLUS] user has active subscription: {havePsPlus}")
  sendPsPlusStatusToUserstatServer(havePsPlus, token)
}

function onSuccess(state) {
  loginCb.onSuccess(state)
  send_ps_plus_status(state)
}

return {
  stages = [
    { id = "check_age", action = @(_state, cb) check_age_restrictions_stage(cb), actionOnReload = @(_state, _cb) null },
    { id = "parental_control", action = @(_state, cb) check_parental_control_stage(cb), actionOnReload = @(_state, _cb) null },
    { id = "sony_auth_data", action = @(_state, cb) sony_auth_data_stage(cb), actionOnReload = @(_state, _cb) null },
    { id = "auth_psn", action = login_psn, actionOnReload = @(_state, _cb) null },
    { id = "check_plus", action = update_premium_permissions, actionOnReload = @(_state, _cb) null },
    require("%ui/login/stages/eula_before_login.nut"),
    require("%ui/login/stages/auth_result.nut"),
    require("%ui/login/stages/char.nut"),
    require("%ui/login/stages/online_settings.nut"),
    require("%ui/login/stages/eula.nut"),
    require("%ui/login/stages/matching.nut"),
  ]
  onSuccess = onSuccess
  onInterrupt = loginCb.onInterrupt
}
