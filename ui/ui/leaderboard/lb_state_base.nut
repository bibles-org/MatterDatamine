from "%ui/ui_library.nut" import *

let { get_time_msec } = require("dagor.time")
let { requestLeaderboard } = require("%sqGlob/leaderboard.nut")
let userInfo = require("%sqGlob/userInfo.nut")
let { isLoggedIn } = require("%ui/login/login_state.nut")
let { nestWatched } = require("%dngscripts/globalState.nut")
let { isInBattleState } = require("%ui/state/appState.nut")

const LB_REQUEST_TIMEOUT = 45000
const LB_UPDATE_INTERVAL = 5000
const REFRESH_PERIOD = 120

let curLbData = nestWatched("curLbData", [])
let curLbSelfRow = nestWatched("curLbSelfRow", null)
let lastLBRequestData = nestWatched("lastLBRequestData", null)
let curLbPlayersCount = nestWatched("curLbPlayersCount", 0)
let curLbErrName = Watched(null)

local lastRequestTime = 0
local lastUpdateTime = 0

let isRequestInProgress = @() lastRequestTime > lastUpdateTime
  && lastRequestTime + LB_REQUEST_TIMEOUT > get_time_msec()

let canRefresh = @() !isRequestInProgress()
  && isLoggedIn.get()
  && (!curLbData.get() || (lastUpdateTime + LB_UPDATE_INTERVAL < get_time_msec()))

function parseLbData(result) {
  lastUpdateTime = get_time_msec()
  curLbErrName(result?.result.error)

  let isSuccess = result?.result.success ?? true
  if (!isSuccess || result?.result.users_data == null)
    return

  let data = result.result.users_data
  curLbSelfRow.set(data.findvalue(@(v) v?[2] == userInfo.get().name))
  curLbData.set(data)
  curLbPlayersCount.set(result?.result.info.total ?? 0)
}

function refreshLbData(requestData = null) {
  if (!canRefresh())
    return

  if (requestData == null) {
    curLbData.set([])
    curLbErrName.set(null)
    return
  }

  lastRequestTime = get_time_msec()
  if (isEqual(requestData, lastLBRequestData.get())) {
    lastLBRequestData.set(requestData)
    return
  }

  requestLeaderboard(requestData, parseLbData)
}

function refreshMonolithLb() {
  let request = {
    start = 0
    count = max(curLbPlayersCount.get(), 45)
    projectid = "active_matter_pc"
    token = userInfo.get()?.token
    table = "season"
    gameMode = "default"
    category = "timestamp"
    resolveNick = 1
  }
  refreshLbData(request)
}

foreach (v in [isLoggedIn, userInfo, isInBattleState])
  v.subscribe(function(_) {
    refreshMonolithLb()
  })

function updateRefreshTimer(needUpdate) {
  if (needUpdate) {
    gui_scene.setInterval(REFRESH_PERIOD, refreshMonolithLb)
  }
  else
    gui_scene.clearTimer(refreshMonolithLb)
}

return {
  curLbData
  curLbSelfRow
  refreshLbData
  curLbPlayersCount
  refreshMonolithLb
  updateRefreshTimer
}