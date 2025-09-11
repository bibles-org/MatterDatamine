from "%ui/mainMenu/raidAutoSquadState.nut" import getFormalLeaderUid
from "%ui/fonts_style.nut" import sub_txt
from "%ui/components/commonComponents.nut" import mkText
from "%ui/matchingClient.nut" import matchingCall
from "matching.errors" import error_string, OPERATION_COMPLETE
from "eventbus" import eventbus_subscribe
from "matching.api" import matching_listen_notify
from "%ui/squad/squadManager.nut" import inviteToSquad
from "dagor.debug" import logerr
from "%ui/components/button.nut" import textButton
from "%ui/helpers/timers.nut" import mkCountdownTimerPerSec
from "net" import get_sync_time
from "%ui/helpers/time.nut" import secondsToStringLoc
from "%ui/components/cursors.nut" import setTooltip
from "%ui/ui_library.nut" import *

let { isInSquad } = require("%ui/squad/squadState.nut")
let { selectedRaid } = require("%ui/gameModeState.nut")
let { matchingQueuesMap } = require("%ui/matchingQueues.nut")
let { autoSquadGatheringState, autosquadPlayers, reservedSquad, waitingInvite, waitingInviteFromLeaderNumber } = require("%ui/mainMenu/raidAutoSquadState.nut")
let { isInQueue } = require("%ui/quickMatchQueue.nut")
let userInfo = require("%sqGlob/userInfo.nut")

local searchTime = -1
let squadSize = 3
let joinTimerTime = Watched(-1.0)
let joinTimer = mkCountdownTimerPerSec(joinTimerTime, "squadSearch")

function setTimer(time) {
  joinTimerTime.set(get_sync_time() + time)
}

function makeSquad() {
  let squad = reservedSquad.get()
  let formalLeaderUid = getFormalLeaderUid(squad)
  log($"[Autosquad] Squad gathering. Is leader: {formalLeaderUid == userInfo.get()?.userId}")
  log($"[Autosquad] Squad arr:", squad)
  if (formalLeaderUid == userInfo.get()?.userId) {
    gui_scene.resetTimeout(1, function() {
      foreach (member in squad) {
        if (member.userId != formalLeaderUid) {
          log($"[Autosquad] Squad invite player {member.userId}")
          inviteToSquad(member.userId)
        }
      }
      reservedSquad.set([])
      autoSquadGatheringState.set(false)
    })
  }
  else {
    
    
    
    waitingInvite.set(true)
    waitingInviteFromLeaderNumber.set(formalLeaderUid)
    let waitForInvite = 5
    gui_scene.resetTimeout(waitForInvite, function() {
      waitingInvite.set(false)
      autoSquadGatheringState.set(false)
      waitingInviteFromLeaderNumber.set(0)
    }, "resetAutoquadWaiting")
  }
}

joinTimer.subscribe_with_nasty_disregard_of_frp_update(function(v) {
  if (v == 0 && autoSquadGatheringState.get()) {
    makeSquad()
  }
})

function addPlayer(member) {
  log($"[Autosquad] adding player {member.userId} to room")
  autosquadPlayers.mutate(@(v)
    v.append({
      name = member.name,
      userId = member.userId
      memberId = member.memberId
    })
  )
  reservedSquad.set(autosquadPlayers.get())
  if (autosquadPlayers.get().len() == squadSize) {
    makeSquad()
    autoSquadGatheringState.set(false)
  }
}

function removePlayer(member) {
  log($"[Autosquad] removing player {member.userId} from room")
  let idx = autosquadPlayers.get().findindex(@(v2) v2.userId == member.userId)
  if (idx != null) {
    autosquadPlayers.mutate(@(v)
      v.remove(idx))
  }
}

foreach (name, cb in {
  ["mrooms.on_room_member_joined"] = function(v) {
    if (autoSquadGatheringState.get() && v.userId != userInfo.get()?.userId) {
      addPlayer(v)
      if (searchTime > 0)
        setTimer(searchTime)
    }
  },
  ["mrooms.on_room_member_leaved"] = function(v) {
    if (autoSquadGatheringState.get() && v != null && v.userId != userInfo.get()?.userId)
      removePlayer(v)
  }
}){
  matching_listen_notify(name)
  eventbus_subscribe(name, cb)
}

function callbackJoinRoom(response) {
  if (response?.error != OPERATION_COMPLETE) {
    log($"[Autosquad] Error creating room: {error_string(response.error)}")
    autoSquadGatheringState.set(false)
    setTimer(-1)
    return
  }
  let roomTimeWait = response?.public?.waitTimeSec ?? -1
  foreach (member in response.members) {
    addPlayer(member)
  }
  setTimer(roomTimeWait)
  searchTime = roomTimeWait
}

function callbackCreateRoom(response) {
  if (response?.error != OPERATION_COMPLETE) {
    log($"[Autosquad] Error creating room: {error_string(response.error)}")
    autoSquadGatheringState.set(false)
    setTimer(-1)
    return
  }
  let roomTimeWait = response?.public?.waitTimeSec ?? -1
  addPlayer(response.members[0])
  setTimer(roomTimeWait)
  searchTime = roomTimeWait
}

function createNewAutosquadRoom() {
  let params = {
    public = {
      autosquadQueueId = selectedRaid.get().id
    }
    lobby_template = "autosquad"
  }
  matchingCall("mrooms.create_room", callbackCreateRoom, params)
}

local digestToJoin = []
local digestIter = 0
function joinAutosquadRoom(response) {
  if (response.error == 0) {
    callbackJoinRoom(response)
    return
  }
  if (digestToJoin.len() == digestIter) {
    createNewAutosquadRoom()
    return
  }
  matchingCall("mrooms.join_room", joinAutosquadRoom, { roomId = digestToJoin[digestIter].roomId.tointeger() })
  digestIter = digestIter + 1
}

function listRoomsCb(response) {
  if (response.error) {
    logerr($"[Autosquad] Digest getting error: {error_string(response.error)}")
    return
  }

  if (response.digest.len() == 0) {
    log("[Autosquad] : no rooms found, creating...")
    createNewAutosquadRoom()
  }
  else {
    log($"[Autosquad] : Joining to {response.digest[0].roomId}")
    digestToJoin = response.digest
    digestIter = 1
    matchingCall("mrooms.join_room", joinAutosquadRoom, { roomId = response.digest[0].roomId.tointeger() })
  }
}

autoSquadGatheringState.subscribe_with_nasty_disregard_of_frp_update(function(v) {
  if (v == false) {
    if (autosquadPlayers.get().len() <= 1)
      matchingCall("mrooms.destroy_room", @(_) null)
    else
      matchingCall("mrooms.leave_room", @(_) null)
    autosquadPlayers.set([])
    return
  }
  gui_scene.clearTimer("resetAutoquadWaiting")

  let queueId = selectedRaid.get().id

  let params = {
    group = "custom-lobby"
    cursor = 0
    count = 100
    filter = {}
  }
  params.filter["autosquadQueueId"] <- {
    test = "eq"
    value = queueId
  }

  matchingCall("mrooms.fetch_rooms_digest2", listRoomsCb, params)
})

isInQueue.subscribe_with_nasty_disregard_of_frp_update(function(v) {
  if (v)
    autoSquadGatheringState.set(false)
})

eventbus_subscribe("autosquad.invite_accepted", function(_) {
  reservedSquad.set([])
  autoSquadGatheringState.set(false)
})

function squadGatheringData() {
  let watch = autoSquadGatheringState
  let timerMaxSize = calc_comp_size(mkText(loc("autosquad/timeRemaining", { time = secondsToStringLoc(58) })))
  let textBlock = mkText(loc("autosquad/playersFound", { num = max(0, autosquadPlayers.get().len() - 1) }))
  let textBlockHeight = calc_comp_size(textBlock)[1]
  if (!autoSquadGatheringState.get())
    return {
      watch
      size = [flex(), textBlockHeight]
    }
  return {
    watch
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    gap = hdpx(5)
    halign = ALIGN_RIGHT
    children = [
      @() {
        watch = autosquadPlayers
        children = mkText(loc("autosquad/playersFound", { num = max(0, autosquadPlayers.get().len() - 1) }))
      }
      @() {
        watch = joinTimer
        size = [timerMaxSize[0], SIZE_TO_CONTENT]
        children = mkText(loc("autosquad/timeRemaining", { time = secondsToStringLoc(joinTimer.get()) }))
      }
    ]
  }
}

let btnParams = @(searchState) {
  size = static [flex(), hdpx(30)],
  halign = ALIGN_LEFT,
  margin = 0,
  textMargin = [0, 0, 0, fsh(1)],
  clipChildren = true
  textParams = sub_txt.__merge({ behavior = Behaviors.Marquee })
  onHover = @(on) setTooltip(!on ? null
    : searchState ? loc("autosquad/stopSearchTooltip") : loc("autosquad/startSearchTooltip"))
}

function autosquadWidget() {
  if (isInQueue.get())
    return { watch = isInQueue }
  let queue = matchingQueuesMap.get()?[selectedRaid.get()?.id]
  let status = autoSquadGatheringState.get() ? loc("autosquad/searchInProgress") : loc("autosquad/findTeamIn")
  let queueName = loc(queue?.locId)
  let autosquadButton = textButton(" ".join([status, queueName]),
    function() {
      setTooltip(null)
      autoSquadGatheringState.set(!autoSquadGatheringState.get())
    },
    btnParams(autoSquadGatheringState.get()))
  return {
    watch = [autoSquadGatheringState, selectedRaid, isInSquad, isInQueue]
    size = FLEX_H
    flow = FLOW_VERTICAL
    children = [
      squadGatheringData
      isInSquad.get() ? null : autosquadButton
    ]
  }
}


return {
  autosquadWidget
}
