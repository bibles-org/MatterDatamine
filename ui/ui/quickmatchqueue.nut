import "%ui/components/msgbox.nut" as msgbox
from "%ui/squad/squadManager.nut" import revokeAllSquadInvites, dismissAllOfflineSquadmates, leaveSquad
from "%ui/helpers/remap_nick.nut" import remap_nick
from "%ui/matchingClient.nut" import matchingCall, netStateCall
from "matching.api" import matching_listen_notify
import "matching.errors" as matching_errors
from "dagor.time" import get_time_msec
from "app" import get_app_id
from "%ui/permissions/permissions.nut" import checkMultiplayerPermissions
from "gameevents" import EventUserMMQueueJoined
from "dasevents" import EventGameTrigger, broadcastNetEvent
from "%ui/gameModeState.nut" import isGroupAvailable
from "eventbus" import eventbus_subscribe
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
from "%ui/mainMenu/offline_raid_widget.nut" import wantOfflineRaid, isOfflineRaidSelected

let queueState = require("%ui/state/queueState.nut")
let { STATUS, curQueueParam, queueStatus, isInQueue,
  timeInQueue, queueClusters, queueInfo, joiningQueueName } = queueState

let { squadOnlineMembers, isInSquad, autoSquad, squadId, squadMembers, isInvitedToSquad } = require("%ui/squad/squadManager.nut")
let { queueRaid } = require("%ui/gameModeState.nut")
let { crossnetworkPlay } = require("%ui/state/crossnetwork_state.nut")
let { matchingQueuesMap } = require("%ui/matchingQueues.nut")

let startQueueTime = Watched(0)
let private = {
  nextQPosUpdateTime  = 0
}

let enter_search_queue_hash = ecs.calc_hash("enter_search_queue")
let exit_search_queue_hash = ecs.calc_hash("exit_search_queue")

isInQueue.subscribe_with_nasty_disregard_of_frp_update(function(is_in_queue) {
  let triggerHash = is_in_queue ? enter_search_queue_hash : exit_search_queue_hash
  broadcastNetEvent(EventGameTrigger({triggerHash}))
})

function onTimer(){
  if (queueStatus.get() == STATUS.NOT_IN_QUEUE)
    return

  timeInQueue.set(get_time_msec() - startQueueTime.get())

  let now = get_time_msec()
  if (now > private.nextQPosUpdateTime) {
    private.nextQPosUpdateTime = now + 1000000

    matchingCall("enlmm.get_my_queue_postion",
      function(response) {
        private.nextQPosUpdateTime = now + 5000
        if (response.error == 0)
          queueInfo.set(response)
      }
    )
  }
}

local wasStatus = queueStatus.get()
queueStatus.subscribe_with_nasty_disregard_of_frp_update(function(s) {
  if (s == STATUS.NOT_IN_QUEUE) {
    timeInQueue.set(0)
    startQueueTime.set(get_time_msec())
    gui_scene.clearTimer(onTimer)
  } else if (s == STATUS.JOINING || (s == STATUS.IN_QUEUE && wasStatus == STATUS.NOT_IN_QUEUE)) {
    startQueueTime.set(get_time_msec())
    timeInQueue.set(0)
    gui_scene.clearTimer(onTimer)
    gui_scene.setInterval(1.0, onTimer)

    ecs.g_entity_mgr.broadcastEvent(EventUserMMQueueJoined())
  } else if (s == STATUS.WAITING_FOR_SERVER) {
    queueInfo.modify(@(val) (val ?? {}).__merge({isWaitingForServer=true}))
    gui_scene.clearTimer(onTimer)
  }
  wasStatus = s
})

function errorText(response) {
  if (response.error == 0)
    return ""
  let errKey = response?.error_id ?? matching_errors.error_string(response.error)
  return loc($"error/{errKey}")
}

function joinImpl(queue, queue_params) {
  let isOffline = !isInSquad.get() && ((queue?.extraParams.isNewby ?? false) || isOfflineRaidSelected.get())
  let params = {
    queueId = queue.id
    clusters = queueClusters.get().filter(@(has) has).keys()
    allowFillGroup = isGroupAvailable() && autoSquad.get()
    appId = get_app_id()
    crossplayType = crossnetworkPlay.get()
    queueRaid = queueRaid.get()
  }.__update(queue_params)
  curQueueParam.set(params)
  if (isOffline) {
    queueStatus.set(STATUS.JOINING)
    log("Joining offline match \"queue\"", params)
    return
  }
  netStateCall(function() {
    if (isGroupAvailable()) {
      if (isInSquad.get() && squadOnlineMembers.get().len() > 1) {
        let smembers = []
        let appIds = {}
        foreach (uid, member in squadOnlineMembers.get()) {
          smembers.append(uid)
          appIds[uid.tostring()] <- member.state?.appId ?? get_app_id()
        }
        let squad = {
          members = smembers
          leader = squadId.get()
        }
        params.squad <- squad
        params.appIds <- appIds
      }
    }
    else if (isInSquad.get()){
      leaveSquad()
    }

    queueStatus.set(STATUS.JOINING)
    log("enlmm.join_quick_match_queue", params)

    matchingCall("enlmm.join_quick_match_queue", function(response) {
      if (response.error != 0){
        log(response)
        queueStatus.set(STATUS.NOT_IN_QUEUE)
        msgbox.showMsgbox({text = errorText(response) })
      }
    }, params)
  })
}

function joinQueue(queue, queue_params = {}) {
  if (!checkMultiplayerPermissions()) {
    log("no permissions to run multiplayer")
    return
  }
  if (!isInSquad.get())
    return joinImpl(queue, queue_params)
  let { maxGroupSize = 1, minGroupSize = 1 } = queue
  local notReadyMembers = ""
  local ticketlessMembers = ""
  let squadOnlineMembersVal = squadOnlineMembers.get()
  let squadOnlineMembersAmount = squadOnlineMembersVal.len()

  let needTickets = wantOfflineRaid.get()

  foreach (member in squadOnlineMembers.get()) {
    if (needTickets) {
      let memberHasTicket = (member?.state?.playersData?.hasIsolatedRaidTickets) ?? false
      if (!memberHasTicket) {
        ticketlessMembers += ((ticketlessMembers != "") ? ", " : "") + remap_nick(member?.realnick)
      }
    }
    if ((!member.isLeader && !member.state?.ready) || member.state?.inBattle)
      notReadyMembers += ((notReadyMembers != "") ? ", " : "") + remap_nick(member?.realnick)
  }

  if (notReadyMembers.len())
    return msgbox.showMsgbox({text=loc("squad/notReadyMembers" { notReadyMembers })})
  if (minGroupSize > squadOnlineMembersAmount)
    return msgbox.showMsgbox({text=loc("squad/tooFewMembers" { reqMembers = minGroupSize })})
  if (maxGroupSize < squadOnlineMembersAmount || (!isGroupAvailable() && squadOnlineMembers.get()>1))
    return msgbox.showMsgbox({text=loc("squad/tooMuchMembers" { maxMembers = maxGroupSize })})
  if (ticketlessMembers.len() > 0)
    return msgbox.showMsgbox({text=loc("squad/needIsolatedTickets", {members=ticketlessMembers})})

  if (needTickets) {
    let isolatedVersion = matchingQueuesMap.get().findvalue(@(v) (v?.extraParams?.isolatedVersionOfQueue ?? "") == queue.queueId)
    if (isolatedVersion == null) {
      return msgbox.showMsgbox({text=loc("queue/offline_raids/online_isolated_unavailable")})
    }
    queue = isolatedVersion
  }

  let offlineNum = squadMembers.get().len() - squadOnlineMembersAmount
  local msg = offlineNum ? loc("squad/hasOfflineMembers", { number = offlineNum }) : ""
  if (isInvitedToSquad.get().len())
    msg = (msg.len() ? "\n" : "").concat(msg, loc("squad/hasInvites", { number = isInvitedToSquad.get().len() }))
  if (msg.len()) {
    return msgbox.showMsgbox({
      text = "\n".concat(msg, loc("squad/theyWillNotGoToBattle"))
      buttons = [
        { text = loc("squad/removeAndGoToBattle")
          isCurrent = true
          action = function() {
            dismissAllOfflineSquadmates()
            revokeAllSquadInvites()
            joinImpl(queue, queue_params)
          }
        }
        { text = loc("Cancel"), isCancel = true }
      ]
    })
  }
  else
    joinImpl(queue, queue_params)
}

function leaveQueue(cb = null) {
  netStateCall(function() {
    matchingCall(
      queueStatus.get() == STATUS.WAITING_FOR_SERVER ? "mrooms.leave_room" : "enlmm.leave_quick_match_queue",
      function(v) { cb?(v) })
  })
  queueStatus.set(STATUS.NOT_IN_QUEUE)
}




foreach (name, cb in {
  ["enlmm.on_quick_match_queue_leaved"] = function(request) {
    print("onQuickMatchQueueLeaved")
    log(request)
    queueStatus.set(STATUS.NOT_IN_QUEUE)
    joiningQueueName.set(null)
  },

  ["mrooms.on_host_notify"] = function(_request) {
    print("onConnectToServer")
    queueStatus.set(STATUS.NOT_IN_QUEUE)
  },

  ["enlmm.on_quick_match_queue_joined"] = function(request) {
    print("onQuickMatchQueueJoined")
    log(request)
    joiningQueueName.set(request.queue_id)
    queueStatus.set(STATUS.IN_QUEUE)
  },

  ["enlmm.on_room_invite"] = function(_request) {
    print("onRoomJoin")
    queueStatus.set(STATUS.WAITING_FOR_SERVER)
  },
}){
  matching_listen_notify(name)
  eventbus_subscribe(name,cb)
}

eventbus_subscribe("matching.logged_out", @(...) queueStatus.set(STATUS.NOT_IN_QUEUE))


eventbus_subscribe("squad.local_player_leaved", function(_) {
  leaveQueue()
})

isInSquad.subscribe_with_nasty_disregard_of_frp_update(function(_) {
  if (isInQueue.get())
    leaveQueue()
})

let squadMembersGeneration = Watched(0)
local prevSquadMembers = {}
let changeGen = @() squadMembersGeneration.set(squadMembersGeneration.get()+1)

function onSquadMembersChange(v) {
  local changedGen = false
  foreach (uid, member in v) {
    if (uid in prevSquadMembers)
      continue
    let isLeader = member?.isLeader
    if (!member.state?.ready && isLeader) {
      changeGen()
      changedGen = true
      break
    }
  }
  prevSquadMembers = v
  if (!changedGen && (v.len() != prevSquadMembers.len() || !isEqual(v.keys(), prevSquadMembers.keys())))
    changeGen()
}
squadMembers.subscribe_with_nasty_disregard_of_frp_update(onSquadMembersChange)
onSquadMembersChange(squadMembers.get())


squadMembersGeneration.subscribe_with_nasty_disregard_of_frp_update(function(_) {
  if (isInQueue.get())
    leaveQueue()
})

return queueState.__merge({
  joinQueue
  leaveQueue
})
