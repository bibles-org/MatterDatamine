let profile_server = require_optional("profile_server")
let { disableRemoteNetServices } = require("%sqGlob/offline_mode.nut")
let netErrorConverter = require("%sqGlob/netErrorConverter.nut")
let { mq_gen_transactid=@(...) null, put_to_mq_raw=@(...) null } = require_optional("message_queue")
let { get_app_id } = require("app")
let logPSC = require("%sqGlob/library_logs.nut")
  .with_prefix("[profileServerClient]")
let {object_to_json_string} = require("json")
let userInfo = require("%sqGlob/userInfo.nut")
let isDedicated = require_optional("dedicated") != null
let { logerr } = require("dagor.debug")
let { get_arg_value_by_name } = require("dagor.system")
let { get_setting_by_blk_path } = require("settings")


function checkAndLogError(id, action, cb, result) {
  if ("error" in result) {
    local err = result.error
    if (typeof err == "table") {
      if ("message" in err) {
        if ("code" in err)
          err = $"{err.message} (code: {err.code})"
        else
          err = err.message
      }
    }
    if (typeof err != "string")
      err = $"(full answer dump) {object_to_json_string(result)}"
    logPSC($"request {id}: {action} returned error: {err}")
  } else {
    logPSC($"request {id}: {action} completed without error")
  }
  if (cb)
    cb(result)
}

let next_request_id = persist("profile_server_next_request_id", @() {value=0})
let isLocalProfileServer = (get_setting_by_blk_path("debug")?.profile_server?.servers?.url ?? "") != ""

function requestProfileServer(action, params, args, cb, id = null, token = null) {
  id = id ?? next_request_id.value++
  token = token ?? userInfo.get()?.token ?? (disableRemoteNetServices ? 1 : null)

  if (disableRemoteNetServices && !isLocalProfileServer){
    logerr("Use local profile server with 'disableRemoteNetServices' feature!")
    return
  }

  if (!token) {
    logPSC($"Skip action {action}, no token")
    if (cb)
      cb({error="No token"})
    return
  }

  let actionEx = $"das.{action}"
  let reqData = {
    method = actionEx
    id = id
    jsonrpc = "2.0"
  }

  if (params != null)
    reqData["params"] <- params
  let request = args.__merge({
    headers = {
      token = token
      appid = get_app_id()
    },
    action = actionEx
    data = reqData
  })

  logPSC($"Sending request {id}, method: {action}")
  profile_server.request(request,
                         @(result) netErrorConverter.error_response_converter(
                              @(r) checkAndLogError(id, action, cb, r),
                              result))
}

let tubeName = get_arg_value_by_name("profile_tube") ?? ""

function requestDedicated(action, userid, params, id = null) {
  if (!(put_to_mq_raw != null && isDedicated) || get_app_id() < 0) {
    logerr($"Refusing to send job {action} to profile")
    return
  }

  id = id ?? next_request_id.value++

  let actionEx = $"das.{action}"

  let reqData = {
    method = actionEx
    id = id
    jsonrpc = "2.0"
  }

  if (params != null)
    reqData["params"] <- params

  if (tubeName != "") {
    logPSC($"Sending request {id}, method: {actionEx} via message_queue")
    let transactid = mq_gen_transactid()
    put_to_mq_raw(tubeName, {
        action = actionEx,
        headers = {
          appid = get_app_id()
          userid = userid
          transactid = transactid
        },
        body = reqData
      })
  } else {
    logPSC($"Sending request {id}, method: {actionEx} via http")
    profile_server.request({
        action = actionEx,
        headers = {
          appid = get_app_id()
          userid = userid
        },
        data = reqData
      },
      @(result) netErrorConverter.error_response_converter(
        @(r) checkAndLogError(id, actionEx, null, r),
        result))
  }
}

return {
  requestProfileServer
  requestDedicated
}
