from "%ui/ui_library.nut" import *

let userInfo = require("%sqGlob/userInfo.nut")
let logPSC = require("%sqGlob/library_logs.nut").with_prefix("[leaderboard]")
let { object_to_json_string } = require("json")
let lowLeaderboardClient = require("leaderboard")
let { disableRemoteNetServices } = require("%sqGlob/offline_mode.nut")
let netErrorConverter = require("%sqGlob/netErrorConverter.nut")
let { get_app_id } = require("app")

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
  }
  else
    logPSC($"request {id}: {action} completed without error")

  if (cb)
    cb(result)
}

let next_request_id = persist("leaderboard_next_request_id", @() { value = 0})


function requestLeaderboard(action, params, cb = null) {
  let id = next_request_id.value++
  let reqData = {
    method = action
    id
    jsonrpc = "2.0"
  }

  if (params != null)
    reqData["params"] <- params
  let request = {
    headers = {
      token = userInfo.get()?.token ?? (disableRemoteNetServices ? 1 : null)
      appid = get_app_id()
    },
    action = action
    data = reqData
  }

  logPSC($"Sending request {id}, method: {action}")

  lowLeaderboardClient.request(request,
    @(result) netErrorConverter.error_response_converter(@(r) checkAndLogError(id, action, cb, r),
    result))
}

function updateLeaderboard() {
  let request = {
    projectid = "active_matter_pc"
    token = userInfo.get()?.token ?? (disableRemoteNetServices ? 1 : null)
    table = "season"
    gameMode = "default"
    category = "timestamp"
    resolveNick = 1
    count = 10
    start = 0
  }

  requestLeaderboard("GetLeaderboard", request, @(result) logPSC(result))
}

console_register_command(updateLeaderboard, "leaderboard.get_leaderboard")

return {
  lowLeaderboardClient
  requestLeaderboard = @(request, cb = null) requestLeaderboard("GetLeaderboard", request, cb)
}
