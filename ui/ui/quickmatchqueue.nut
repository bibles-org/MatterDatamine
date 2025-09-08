import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let queueState = require("%ui/state/queueState.nut")
let { STATUS, curQueueParam, queueStatus, isInQueue,
  timeInQueue, queueClusters, queueInfo, joiningQueueName } = queueState

let { revokeAllSquadInvites, dismissAllOfflineSquadmates, squadOnlineMembers,
  isInSquad, autoSquad, squadId, squadMembers, isInvitedToSquad, leaveSquad
} = require("%ui/squad/squadManager.nut")
let { remap_nick } = require("%ui/helpers/remap_nick.nut")
let msgbox = require("%ui/components/msgbox.nut")
let { matchingCall, netStateCall } = require("matchingClient.nut")
let {matching_listen_notify} = require("matching.api")
let matching_errors = require("matching.errors")
let { get_time_msec } = require("dagor.time")
let { get_app_id } = require("app")
let { checkMultiplayerPermissions } = require("permissions/permissions.nut")
let { EventUserMMQueueJoined } = require("gameevents")
let { isGroupAvailable, queueRaid } = require("gameModeState.nut")
let { crossnetworkPlay } = require("%ui/state/crossnetwork_state.nut")
let { eventbus_subscribe } = require("eventbus")
let { saveLastEquipmentPreset, AGENCY_PRESET_UID } = require("%ui/equipPresets/presetsState.nut")
let { selectedPreset } = require("%ui/equipPresets/presetsButton.nut")

let startQueueTime = Watched(0)
let private = {
  nextQPosUpdateTime  = 0
}

function onTimer(){
  if (queueStatus.value == STATUS.NOT_IN_QUEUE)
    return

  timeInQueue.update(get_time_msec() - startQueueTime.value)

  let now = get_time_msec()
  if (now > private.nextQPosUpdateTime) {
    private.nextQPosUpdateTime = now + 1000000

    matchingCall("enlmm.get_my_queue_postion",
      function(response) {
        private.nextQPosUpdateTime = now + 5000
        if (response.error == 0)
          queueInfo(response)
      }
    )
  }
}

local wasStatus = queueStatus.value
queueStatus.subscribe(function(s) {
  if (s == STATUS.NOT_IN_QUEUE) {
    timeInQueue(0)
    startQueueTime(get_time_msec())
    gui_scene.clearTimer(onTimer)
  } else if (s == STATUS.JOINING || (s == STATUS.IN_QUEUE && wasStatus == STATUS.NOT_IN_QUEUE)) {
    startQueueTime(get_time_msec())
    timeInQueue(0)
    gui_scene.clearTimer(onTimer)
    gui_scene.setInterval(1.0, onTimer)

    ecs.g_entity_mgr.broadcastEvent(EventUserMMQueueJoined())
  } else if (s == STATUS.WAITING_FOR_SERVER) {
    if (selectedPreset.get() != AGENCY_PRESET_UID) {
       saveLastEquipmentPreset()
    }
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
  let isOnlyNewbie = !isInSquad.value && (queue?.extraParams.isNewby ?? false)
  let params = {
    queueId = queue.id
    clusters = queueClusters.value.filter(@(has) has).keys()
    allowFillGroup = isGroupAvailable() && autoSquad.get()
    appId = get_app_id()
    crossplayType = crossnetworkPlay.value
    queueRaid = queueRaid.get()
  }.__update(queue_params)
  curQueueParam(params)
  if (isOnlyNewbie) {
    queueStatus(STATUS.JOINING)
    log("enlmm.join_quick_match_queue_newbie", params)
    return
  }
  netStateCall(function() {
    if (isGroupAvailable()) {
      if (isInSquad.value && squadOnlineMembers.value.len() > 1) {
        let smembers = []
        let appIds = {}
        foreach (uid, member in squadOnlineMembers.value) {
          smembers.append(uid)
          appIds[uid.tostring()] <- member.state?.appId ?? get_app_id()
        }
        let squad = {
          members = smembers
          leader = squadId.value
        }
        params.squad <- squad
        params.appIds <- appIds
      }
    }
    else if (isInSquad.get()){
      leaveSquad()
    }

    queueStatus(STATUS.JOINING)
    log("enlmm.join_quick_match_queue", params)

    matchingCall("enlmm.join_quick_match_queue", function(response) {
      if (response.error != 0){
        log(response)
        queueStatus(STATUS.NOT_IN_QUEUE)
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
  if (!isInSquad.value)
    return joinImpl(queue, queue_params)
  let { maxGroupSize = 1, minGroupSize = 1 } = queue
  local notReadyMembers = ""
  let squadOnlineMembersVal = squadOnlineMembers.value
  let squadOnlineMembersAmount = squadOnlineMembersVal.len()

  foreach (member in squadOnlineMembers.value) {
    if ((!member.isLeader && !member.state?.ready) || member.state?.inBattle)
      notReadyMembers += ((notReadyMembers != "") ? ", " : "") + remap_nick(member?.realnick)
  }

  if (notReadyMembers.len())
    return msgbox.showMsgbox({text=loc("squad/notReadyMembers" { notReadyMembers })})
  if (minGroupSize > squadOnlineMembersAmount)
    return msgbox.showMsgbox({text=loc("squad/tooFewMembers" { reqMembers = minGroupSize })})
  if (maxGroupSize < squadOnlineMembersAmount || (!isGroupAvailable() && squadOnlineMembers.get()>1))
    return msgbox.showMsgbox({text=loc("squad/tooMuchMembers" { maxMembers = maxGroupSize })})

  let offlineNum = squadMembers.value.len() - squadOnlineMembersAmount
  local msg = offlineNum ? loc("squad/hasOfflineMembers", { number = offlineNum }) : ""
  if (isInvitedToSquad.value.len())
    msg = (msg.len() ? "\n" : "").concat(msg, loc("squad/hasInvites", { number = isInvitedToSquad.value.len() }))
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
      queueStatus.value == STATUS.WAITING_FOR_SERVER ? "mrooms.leave_room" : "enlmm.leave_quick_match_queue",
      function(v) { cb?(v) })
  })
  queueStatus(STATUS.NOT_IN_QUEUE)
}




foreach (name, cb in {
  ["enlmm.on_quick_match_queue_leaved"] = function(request) {
    print("onQuickMatchQueueLeaved")
    log(request)
    queueStatus(STATUS.NOT_IN_QUEUE)
    joiningQueueName(null)
  },

  ["mrooms.on_host_notify"] = function(_request) {
    print("onConnectToServer")
    queueStatus(STATUS.NOT_IN_QUEUE)
  },

  ["enlmm.on_quick_match_queue_joined"] = function(request) {
    print("onQuickMatchQueueJoined")
    log(request)
    joiningQueueName(request.queue_id)
    queueStatus(STATUS.IN_QUEUE)
  },

  ["enlmm.on_room_invite"] = function(_request) {
    print("onRoomJoin")
    queueStatus(STATUS.WAITING_FOR_SERVER)
  },
}){
  matching_listen_notify(name)
  eventbus_subscribe(name,cb)
}

eventbus_subscribe("matching.logged_out", @(...) queueStatus(STATUS.NOT_IN_QUEUE))


eventbus_subscribe("squad.local_player_leaved", function(_) {
  leaveQueue()
})

isInSquad.subscribe(function(_) {
  if (isInQueue.value)
    leaveQueue()
})

let squadMembersGeneration = Watched(0)
local prevSquadMembers = {}
let changeGen = @() squadMembersGeneration(squadMembersGeneration.value+1)

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
squadMembers.subscribe(onSquadMembersChange)
onSquadMembersChange(squadMembers.value)


squadMembersGeneration.subscribe(function(_) {
  if (isInQueue.value)
    leaveQueue()
})

return queueState.__merge({
  joinQueue
  leaveQueue
})
