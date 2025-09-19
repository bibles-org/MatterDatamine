from "%dngscripts/globalState.nut" import nestWatched

from "%ui/ui_library.nut" import *

let { isInSquad, isSquadLeader, squadSharedData } = require("%ui/squad/squadState.nut")
let squadClusters = squadSharedData.clusters
let { clusters } = require("%ui/clusterState.nut")
let { matchingQueues } = require("%ui/matchingQueues.nut")

let STATUS = static {
  NOT_IN_QUEUE = 0
  JOINING = 1
  IN_QUEUE = 2
  WAITING_FOR_SERVER = 3
}

let curQueueParam = nestWatched("curQueueParam", null)
let queueStatus = nestWatched("queueStatus", STATUS.NOT_IN_QUEUE)

let debugShowQueue = Watched(false)

let isInQueue = Computed(@() queueStatus.get() != STATUS.NOT_IN_QUEUE || debugShowQueue.get())

let timeInQueue = Watched(0)
let queueClusters = Computed(@()
  isInSquad.get() && !isSquadLeader.get() && squadClusters.get() != null
    ? clone squadClusters.get()
    : clone clusters.get()) 

let queueInfo = Watched(null)
let joiningQueueName = Watched(null)
let canChangeQueueParams = Computed(@() !isInQueue.get() && (!isInSquad.get() || isSquadLeader.get()))

let availableSquadMaxMembers = Computed(@() matchingQueues.get().reduce(@(res, gt) max(res, (gt?.maxGroupSize ?? 1)), 1))

function recalcSquadClusters(_) {
  if (!isSquadLeader.get())
    return
  squadClusters.set(clone clusters.get())
}

foreach (w in [isSquadLeader, clusters])
  w.subscribe_with_nasty_disregard_of_frp_update(recalcSquadClusters)

console_register_command(@() debugShowQueue.set(!debugShowQueue.get()), "ui.showQueueInfo")
console_register_command(@(statusId) queueStatus.set(statusId), "ui.setQueueStatus")

function getStatData(full_stat_name, op){
  let statNameValue = full_stat_name.split(op)
  if (statNameValue.len() != 2)
    return []
  let statName = (statNameValue[0]).split(".")
  if (statName.len() != 2)
    return []
  return [statName[0], statName[1], statNameValue[1].tointeger()]
}

function getStatTableName(reqStr) {
  let queueReqToStatTable = {
    STAT = "statsCurrentSeason"
    STATGLOBAL = "stats"
  }
  return queueReqToStatTable?[reqStr.split(".")[0]]
}

let statOperatorsMap = [ 
  ["!=",  @(a,b) a==b, @(a) a+1 ],
  ["==",  @(a,b) a!=b, @(a) a   ],
  [">=",  @(a,b) a<b,  @(a) a   ],
  ["<=",  @(a,b) a>b,  @(a) a   ],
  [">",   @(a,b) a<=b, @(a) a+1 ],
  ["<",   @(a,b) a>=b, @(a) a-1 ]
]

function doesZoneFitRequirements(zoneInfoRequirements, playerStatsVal) {
  if (zoneInfoRequirements==null)
    return true
  foreach(reqs in zoneInfoRequirements){
    let statTable = getStatTableName(reqs)
    if(statTable != null){
      let idx = reqs.indexof(".")
      let fullStatName = idx != null ? reqs.slice(idx + 1) : ""

      foreach(op in statOperatorsMap){
        let opData = getStatData(fullStatName, op[0])
        if (opData.len() == 3)
          if (op[1](playerStatsVal?[statTable][opData[0]][opData[1]] ?? 0, opData[2]))
            return false
          else
            break
      }
    }
    else{
      let inverse = reqs.startswith("!")
      if (inverse){
        if (playerStatsVal?.unlocks?.contains(reqs.slice(1)) ?? false)
          return false
      }
      else {
        if (!(playerStatsVal?.unlocks?.contains(reqs) ?? false))
          return false
      }
    }
  }
  return true
}


function getNeededZoneRequirements(zoneInfoRequirements, playerStatsVal) {
  if (zoneInfoRequirements==null)
    return [[], [], []]
  let neededStats = []
  let neededUnlocks = []
  let notNeededUnlocks = []
  foreach(reqs in zoneInfoRequirements){
    let statTable = getStatTableName(reqs)
    if(statTable != null){
      let idx = reqs.indexof(".")
      let fullStatName = idx != null ? reqs.slice(idx + 1) : ""
      foreach(op in statOperatorsMap){
        let opData = getStatData(fullStatName, op[0])
        if (opData.len() != 3)
          continue
        if (op[1](playerStatsVal?[statTable][opData[0]]?[opData[1]] ?? 0, opData[2]))
          neededStats.append([opData[0], opData[1], op[2](opData[2])])
        break
      }
    }
    else{
      let inverse = reqs.startswith("!")
      if (inverse){
        if (playerStatsVal?.unlocks?.contains(reqs.slice(1)) ?? false)
          notNeededUnlocks.append(reqs.slice(1))
      }
      else {
        if (!(playerStatsVal?.unlocks?.contains(reqs) ?? false))
          neededUnlocks.append(reqs)
      }
    }
  }
  return [neededStats, neededUnlocks, notNeededUnlocks]
}


function isQueueHiddenBySchedule(queue, time) {
  local nearestEnableTimeBefore = -1
  local nearestHideTimeBefore = -1
  if (queue?.enableSchedule != null) {
    foreach(enableTime in queue.enableSchedule) {
      if (enableTime.time < time && (nearestEnableTimeBefore == -1 || enableTime.time > nearestEnableTimeBefore))
        nearestEnableTimeBefore = enableTime.time
    }
  }
  if (queue?.disableSchedule != null) {
    foreach(disableTime in queue.disableSchedule) {
      let hideTime = disableTime.time - disableTime.overlap
      if (hideTime < time && (nearestHideTimeBefore == -1 || hideTime > nearestHideTimeBefore))
        nearestHideTimeBefore = hideTime
    }
  }
  return nearestHideTimeBefore != -1 && nearestHideTimeBefore > nearestEnableTimeBefore
}

function isZoneUnlocked(queue_params, player_stats, matchingUTCTime, inSquadState, isLeader, leaderRaid) {
  if (inSquadState && !isLeader)
    return leaderRaid?.extraParams.raidName != null
      && leaderRaid?.extraParams.raidName == queue_params?.extraParams.raidName
  return doesZoneFitRequirements(queue_params?.extraParams.requiresToSelect, player_stats)
    && queue_params?.enabled && !isQueueHiddenBySchedule(queue_params, matchingUTCTime?.get() ?? matchingUTCTime)
}



return freeze({
  STATUS
  curQueueParam
  queueStatus
  isInQueue
  joiningQueueName

  timeInQueue
  queueClusters

  queueInfo
  canChangeQueueParams

  availableSquadMaxMembers
  doesZoneFitRequirements
  getNeededZoneRequirements
  isZoneUnlocked
  isQueueHiddenBySchedule
})