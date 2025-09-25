from "%dngscripts/globalState.nut" import nestWatched

from "dagor.time" import get_time_msec

from "%ui/ui_library.nut" import *

let { requestLeaderboard } = require("%sqGlob/leaderboard.nut")
let userInfo = require("%sqGlob/userInfo.nut")
let { isLoggedIn } = require("%ui/login/login_state.nut")
let { isInBattleState } = require("%ui/state/appState.nut")

const LB_REQUEST_TIMEOUT = 45000
const LB_MONOLITH_UPDATE_INTERVAL = 5000
const LB_FACTION_UPDATE_INTERVAL = 1000
const REFRESH_PERIOD = 120

let curMonolithLbData = nestWatched("curMonolithLbData", [])
let curFactionLbData = nestWatched("curFactionLbData", [])

let lastMonolithLbRequestData = nestWatched("lastMonolithLbRequestData", null)
let lastFactionLBRequestData = nestWatched("lastFactionLBRequestData", null)

let curMonolithLbPlayersCount = nestWatched("curMonolithLbPlayersCount", 0)
let curMonolithLbVotesCount = nestWatched("curMonolithLbVotesCount", 0)
let curFactionLbPlayersCount = nestWatched("curFactionLbPlayersCount", 0)

let curMonolithLbErrName = Watched(null)
let curFactionLbErrName = Watched(null)

local lastMonolithRequestTime = 0
local lastMonolithUpdateTime = 0

local lastFactionRequestTime = 0
local lastFactionUpdateTime = 0

let isMonolithRequestInProgress = @() lastMonolithRequestTime > lastMonolithUpdateTime
  && lastMonolithRequestTime + LB_REQUEST_TIMEOUT > get_time_msec()

let canRefreshMonolithLb = @() !isMonolithRequestInProgress()
  && isLoggedIn.get()
  && (!curMonolithLbData.get() || (lastMonolithUpdateTime + LB_MONOLITH_UPDATE_INTERVAL < get_time_msec()))

function parseMonolithLbData(result) {
  lastMonolithUpdateTime = get_time_msec()
  curMonolithLbErrName.set(result?.result.error)

  let isSuccess = result?.result.success ?? true
  if (!isSuccess || result?.result.users_data == null)
    return

  let data = result.result.users_data
  curMonolithLbData.set(data)
  curMonolithLbPlayersCount.set(max((result?.result.info.total ?? 0) - 1, 0))
  let aggregator = data?[0] 
  curMonolithLbVotesCount.set((aggregator?[1] ?? 0) == 208876377 ? (aggregator?[4] ?? 0) : curMonolithLbPlayersCount.get())
}

function refreshMonolithLbData(requestData = null) {
  if (!canRefreshMonolithLb())
    return

  if (requestData == null) {
    curMonolithLbData.set([])
    curMonolithLbErrName.set(null)
    return
  }

  lastMonolithRequestTime = get_time_msec()
  if (isEqual(requestData, lastMonolithLbRequestData.get())) {
    lastMonolithLbRequestData.set(requestData)
    return
  }

  requestLeaderboard(requestData, parseMonolithLbData)
}

function refreshMonolithLb() {
  let request = {
    start = 0
    count = max(curMonolithLbPlayersCount.get(), 45)
    projectid = "active_matter_pc"
    token = userInfo.get()?.token
    table = "season"
    gameMode = "future_makers"
    category = "timestamp"
    resolveNick = 1
  }
  refreshMonolithLbData(request)
}

function parseFactionLbData(result) {
  lastFactionUpdateTime = get_time_msec()
  curFactionLbErrName.set(result?.result.error)

  let isSuccess = result?.result.success ?? true
  if (!isSuccess || result?.result.users_data == null)
    return

  let data = result.result.users_data
  curFactionLbData.modify(@(_v) data)
  curFactionLbPlayersCount.set(result?.result.info.total ?? 0)
}

let isFactionRequestInProgress = @() lastFactionRequestTime > lastFactionUpdateTime
  && lastFactionRequestTime + LB_REQUEST_TIMEOUT > get_time_msec()

let canRefreshFactionLb = @() !isFactionRequestInProgress()
  && isLoggedIn.get()
  && (!curFactionLbData.get() || (lastFactionUpdateTime + LB_FACTION_UPDATE_INTERVAL < get_time_msec()))

function refreshFactionLbData(requestData = null) {
  if (!canRefreshFactionLb())
    return

  if (requestData == null) {
    curFactionLbData.set([])
    curFactionLbErrName.set(null)
    return
  }

  lastFactionRequestTime = get_time_msec()
  if (isEqual(requestData, lastFactionLBRequestData.get())) {
    lastFactionLBRequestData.set(requestData)
    return
  }

  requestLeaderboard(requestData, parseFactionLbData)
}

function refreshFactionLb(faction) {
  let request = {
    start = 0
    count = max(curFactionLbPlayersCount.get(), 50)
    projectid = "active_matter_pc"
    token = userInfo.get()?.token
    table = "nexus_season"
    gameMode = "nexus"
    category = $"faction_{faction}_scores_count"
    resolveNick = 1
  }
  refreshFactionLbData(request)
}

foreach (v in [isLoggedIn, userInfo, isInBattleState])
  v.subscribe(function(_) {
    refreshMonolithLb()
  })

function updateRefreshTimer(needUpdate, cb, timerId = null) {
  if (timerId != null) {
    if (needUpdate)
      gui_scene.setInterval(REFRESH_PERIOD, cb, timerId)
    else
      gui_scene.clearTimer(timerId)
    return
  }
  if (needUpdate)
    gui_scene.setInterval(REFRESH_PERIOD, cb)
  else
    gui_scene.clearTimer(cb)
}

return {
  curMonolithLbData
  curMonolithLbPlayersCount
  curMonolithLbVotesCount
  refreshMonolithLb
  curFactionLbData
  curFactionLbPlayersCount
  refreshFactionLb
  updateRefreshTimer
}