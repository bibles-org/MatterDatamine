from "%dngscripts/platform.nut" import isPlatformRelevant
from "%dngscripts/globalState.nut" import nestWatched

from "%ui/matchingClient.nut" import matchingCall
from "matching.api" import matching_listen_notify
from "app" import get_app_id
from "eventbus" import eventbus_subscribe
from "%ui/devInfo.nut" import addTabToDevInfo
from "%ui/helpers/levelUtils.nut" import patchMatchingQueuesWithLevelInfo
from "%ui/state/matchingUtils.nut" import get_matching_utc_time

from "%ui/ui_library.nut" import *
from "math" import min

let { isInBattleState } = require("%ui/state/appState.nut")
let connectHolder = require("%ui/connectHolderR.nut")

let matchingTime = Watched(get_matching_utc_time())
let matchingQueuesRaw = nestWatched("matchingQueuesRaw", [])
let matchingQueuesScheduleRaw = nestWatched("matchingQueuesScheduleRaw", [])

let getGroupSizes = function(queue) {
  local maxGroupSize
  local minGroupSize

  foreach(team in queue.teams) {
    if (maxGroupSize == null) {
      maxGroupSize = team.maxGroupSize
      minGroupSize = team.minGroupSize
    }
    else {
      maxGroupSize = max(maxGroupSize, team.maxGroupSize)
      minGroupSize = min(minGroupSize, team.minGroupSize)
    }
  }
  return {maxGroupSize, minGroupSize}
}

function isQueueDisabledBySchedule(queue, time) {
  local nearestEnableTimeBefore = -1
  local nearestDisableTimeBefore = -1
  if (queue?.enableSchedule != null) {
    foreach(enableTime in queue.enableSchedule) {
      if (enableTime.time < time && (nearestEnableTimeBefore == -1 || enableTime.time > nearestEnableTimeBefore))
        nearestEnableTimeBefore = enableTime.time
    }
  }
  if (queue?.disableSchedule != null) {
    foreach(disableTime in queue.disableSchedule) {
      if (disableTime.time < time && (nearestDisableTimeBefore == -1 || disableTime.time > nearestDisableTimeBefore))
        nearestDisableTimeBefore = disableTime.time
    }
  }
  return nearestDisableTimeBefore != -1 && nearestDisableTimeBefore > nearestEnableTimeBefore
}

function getNearestEnableTime(queue, time) {
  local nearestEnableTime = -1
  if (queue?.enableSchedule != null) {
    foreach(enableTime in queue.enableSchedule) {
      if (enableTime.time > time && (nearestEnableTime == -1 || enableTime.time < nearestEnableTime))
        nearestEnableTime = enableTime.time
    }
  }
  return nearestEnableTime
}

function getNearestDisableTime(queue, time) {
  local nearestDisableTime = -1
  if (queue?.disableSchedule != null) {
    foreach(disableTime in queue.disableSchedule) {
      if (disableTime.time > time && (nearestDisableTime == -1 || disableTime.time < nearestDisableTime))
        nearestDisableTime = disableTime.time
    }
  }
  return nearestDisableTime
}

function getNextEnableTime(queue, time) {
  local nextEnableTime = -1
  local nearestDisableTime = getNearestDisableTime(queue, time)
  if (queue?.enableSchedule != null) {
    foreach(enableTime in queue.enableSchedule) {
      if (enableTime.time > time && (nextEnableTime == -1 || enableTime.time < nextEnableTime) && (!queue.enabled || nearestDisableTime < enableTime.time))
        nextEnableTime = enableTime.time
    }
  }
  return nextEnableTime
}

function getScheduleEnableTime(schedule, id, matching_time) {
  local result = []
  if (schedule.len()==0)
    return result
  foreach(v in schedule) {
    if (v.queue_id == id && v.action == "enable_queue" && v.time > matching_time)
      result.append({time = v.time})
  }
  return result
}

function getScheduleDisableTime(schedule, id, matching_time) {
  local result = []
  if (schedule.len()==0)
    return result
  foreach(v in schedule) {
    if (v.queue_id == id && v.action == "disable_queue" && v.time > matching_time)
      result.append({time = v.time, overlap = v?.overlap ?? 0.0})
  }
  return result
}

function processQueues(queuesRaw, queuesScheduleRaw) {
  local queues = queuesRaw.filter(@(q) isPlatformRelevant(q?.allowedPlatforms ?? []))
  if (queues.len()==0)
    queues = queuesRaw
  queues = queues.map(function(queue) {
    let result = {
      id = queue.queueId
      locId = queue?.locId
      extraParams = queue?.extraParams ?? {}
      allowFillGroup = queue?.allowFillGroup ?? true
    }.__update(queue).__update(getGroupSizes(queue))

    let matching_time = get_matching_utc_time()
    let enableSchedule = getScheduleEnableTime(queuesScheduleRaw, queue.queueId, matching_time)
    let disableSchedule = getScheduleDisableTime(queuesScheduleRaw, queue.queueId, matching_time)

    if (enableSchedule.len() > 0)
      result.__update({enableSchedule})
    if (disableSchedule.len() > 0)
      result.__update({disableSchedule})
    return result
  })
  let queuesMap = queues.reduce(@(res, v) res.__update({[v.id] = v}), {})
  queues.sort(@(next, prev)
    (next?.extraParams.uiOrder ?? 1000) <=> (prev?.extraParams.uiOrder ?? 1000)
    || next.maxGroupSize <=> prev.maxGroupSize
  )
  log("processQueues", queues)
  return {queues, queuesMap}
}

let matchingQueuesInt = Computed(function(prev) {
  if (prev != FRP_INITIAL && isInBattleState.get())
    return prev
  else if (prev == FRP_INITIAL && isInBattleState.get())
    return {queues = [], queuesMap = {}}
  return processQueues(matchingQueuesRaw.get(), matchingQueuesScheduleRaw.get())
})

let matchingQueues = Computed(@() matchingQueuesInt.get().queues)
let matchingQueuesMap = Computed(@() matchingQueuesInt.get().queuesMap)

function fetch_matching_queues() {
  let fetchMatchingQueues = fetch_matching_queues
  matchingCall("enlmm.get_queues_list",
    function(response) {
      log("get_queues_list", response)
      if (!connectHolder.is_logged_in())
        return
      if (response.error != 0) {
        gui_scene.resetTimeout(5, fetchMatchingQueues)
        return
      }
      matchingQueuesRaw.set(patchMatchingQueuesWithLevelInfo(response?.queues ?? []))
      matchingTime.set(get_matching_utc_time())
    }, static {appId = get_app_id(), rulesVersion="1.0"})
}


function fetch_matching_queues_schedule() {
  let fetchMatchingQueuesSchedule = fetch_matching_queues_schedule
  matchingCall("enlmm.get_schedule_list",
    function(response) {
      log("get_schedule_list", response)
      if (!connectHolder.is_logged_in())
        return
      if (response.error != 0) {
        gui_scene.resetTimeout(5, fetchMatchingQueuesSchedule)
        return
      }
      matchingQueuesScheduleRaw.set(response?.list ?? [])
    }, {appId = get_app_id(), rulesVersion="1.0"})
}


eventbus_subscribe("matching.logged_in", function(...) {
  fetch_matching_queues()
  fetch_matching_queues_schedule()
})

const INITIAL_DELAY = 15
const MAX_DELAY = 180
local currentDelay = INITIAL_DELAY
local timerForEmptyQueues 

function checkEmptyQueues(){
  if (matchingQueuesRaw.get().len() != 0 || !connectHolder.is_logged_in()) {
    currentDelay = INITIAL_DELAY
    return
  }
  
  currentDelay = min(currentDelay * 2, MAX_DELAY)
  fetch_matching_queues()
  fetch_matching_queues_schedule()
  gui_scene.clearTimer(timerForEmptyQueues)
  gui_scene.resetTimeout(currentDelay, timerForEmptyQueues)
}

timerForEmptyQueues = function() {
  if (isInBattleState.get())
    return
  checkEmptyQueues()
}

gui_scene.setInterval(INITIAL_DELAY, timerForEmptyQueues)

matching_listen_notify("enlmm.notify_games_list_changed")
matching_listen_notify("enlmm.notify_schedule_list_changed")
eventbus_subscribe("enlmm.notify_games_list_changed", @(_notify) fetch_matching_queues())
eventbus_subscribe("enlmm.notify_schedule_list_changed", @(_notify) fetch_matching_queues_schedule())

addTabToDevInfo("matchingQueues", matchingQueues)

return {
  matchingQueues
  matchingTime
  matchingQueuesMap
  isQueueDisabledBySchedule
  getNearestEnableTime
  getNearestDisableTime
  getNextEnableTime
}
