from "%sqstd/json.nut" import object_to_json_string

import "%ui/components/msgbox.nut" as msgbox

from "dasevents" import MatchingRoomExtraParams, CmdStartMenuExtractionSequence, CmdConnectToHost, CmdHideAllUiMenus

from "net" import DC_CONNECTION_CLOSED, EventOnNetworkDestroyed, EventOnConnectedToServer, EventOnDisconnectedFromServer
from "dagor.system" import DBGLEVEL
from "dagor.debug" import logerr
from "app" import get_circuit
from "base64" import encodeString
from "%ui/matchingClient.nut" import matchingCall, netStateCall
from "%ui/gameLauncher.nut" import startGame
from "matching.api" import matching_listen_rpc, matching_listen_notify, matching_send_response
from "%ui/mainMenu/chat/chatApi.nut" import leaveChat, createChat, joinChat
from "%ui/mainMenu/chat/chatState.nut" import clearChatState
import "%ui/voiceChat/voiceState.nut" as voiceState
from "%ui/permissions/permissions.nut" import checkMultiplayerPermissions
from "eventbus" import eventbus_send, eventbus_subscribe
from "matching.errors" import OK, error_string
from "%ui/mainMenu/mailboxState.nut" import pushNotification, removeNotify, subscribeGroup

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

from "%ui/squad/squadState.nut" import isInSquad, isSquadLeader, squadId, squadLeaderState
from "%ui/mainMenu/raid_preparation_window_state.nut" import currentPrimaryContractIds

let { system = null } = require_optional("system")
let userInfo = require("%sqGlob/userInfo.nut")
let { oneOfSelectedClusters } = require("%ui/clusterState.nut")
let { isInBattleState } = require("%ui/state/appState.nut")
let { isInQueue, curQueueParam } = require("%ui/quickMatchQueue.nut")
let loginChain = require("%ui/login/login_chain.nut")
let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")
let { useAgencyPreset, previewPreset } = require("%ui/equipPresets/presetsState.nut")
let { alterMints } = require("%ui/profile/profileState.nut")

const INVITE_ACTION_ID = "room_invite_action"
let LobbyStatus = {
  ReadyToStart = "ready_to_launch"
  NotEnoughPlayers = "not_enough_players"
  CreatingGame = "creating_game"
  WaitingBeforeLauch = "waiting_before_launch"
  GameInProgress = "game_in_progress"
  GameInProgressNoLaunched = "game_in_progress_no_launched"
  WaitForDedicatedStart = "wait_for_dedicated_start"
  TeamsDisbalanced = "teams_disbalanced"
}

let ServerLauncherState = {
  Launching = "launching"
  Launched = "launched"
  WaitingForHost = "waiting_for_host"
  HostNotFound = "host_not_found"
  NoSession = "no_session"
}

let room = mkWatched(persist, "room", null)
let roomInvites = mkWatched(persist, "roomInvites", [])
let roomMembers = mkWatched(persist, "roomMembers", [])
let roomIsLobby = mkWatched(persist, "roomIsLobby", false)
let connectAllowed = mkWatched(persist, "connectAllowed", null)
let hostId  = mkWatched(persist, "hostId", null)
let chatId = mkWatched(persist, "chatId", null)
let squadVoiceChatId = mkWatched(persist, "squadVoiceChatId", null)
let doConnectToHostOnHostNotfy = mkWatched(persist, "doConnectToHostOnHostNotfy", true)
let lobbyLauncherState = Computed(@() room.get()?.public.launcherState ?? "no_session")
let myInfoUpdateInProgress = Watched(false)
let playersWaitingResponseFor = Watched({})
let joinedRoomWithInvite = Watched(false)

let canStartWithLocalDedicated = DBGLEVEL > 0 && system != null
  ? Computed(@() roomIsLobby.get() && room.get()?.public != null)
  : WatchedRo(false)

let lastRoomResult = mkWatched(persist, "lastRoomResult", null)
let lastSessionStartData = mkWatched(persist, "lastSessionStartData", null)
let isWaitForDedicatedStart = Watched(false)
let lobbyStatus = Computed(function() {
  if (isWaitForDedicatedStart.get())
    return LobbyStatus.WaitForDedicatedStart
  let launcherState = lobbyLauncherState.get()
  if(launcherState == LobbyStatus.NotEnoughPlayers)
    return LobbyStatus.NotEnoughPlayers
  if(launcherState == LobbyStatus.WaitingBeforeLauch)
    return LobbyStatus.WaitingBeforeLauch
  if(launcherState == LobbyStatus.TeamsDisbalanced)
    return LobbyStatus.TeamsDisbalanced
  if (launcherState == ServerLauncherState.Launching
      || launcherState == ServerLauncherState.WaitingForHost)
    return LobbyStatus.CreatingGame
  if (launcherState == ServerLauncherState.Launched)
    return isInBattleState.get() ? LobbyStatus.GameInProgress
      : !connectAllowed.get() ? LobbyStatus.CreatingGame
      : LobbyStatus.GameInProgressNoLaunched
  return LobbyStatus.ReadyToStart
})

roomIsLobby.subscribe(@(val) log($"roomIsLobby {val}"))

let myMemberInfo = Computed(function() {
  let { userId = null } = userInfo.get()
  return roomMembers.get().findvalue(@(m) m.userId == userId)
})
let canOperateRoom = Computed(@() myMemberInfo.get()?.public.operator ?? false)

let getRoomMember =  @(user_id) roomMembers.get().findvalue(@(member) member.userId == user_id)
let hasSquadMates =  @(squad_id) roomMembers.get().findvalue(@(member) member.public?.squadId == squad_id) != null

function cleanupRoomState() {
  log("cleanupRoomState")
  room.set(null)
  playersWaitingResponseFor.set({})
  roomInvites.set([])
  roomMembers.set([])
  roomIsLobby.set(false)
  hostId.set(null)
  connectAllowed.set(null)
  isWaitForDedicatedStart.set(false)
  if (chatId.get() != null) {
    leaveChat(chatId.get(), null)
    clearChatState(chatId.get())
    chatId.set(null)
  }

  if (squadVoiceChatId.get() != null) {
    voiceState.leave_voice_chat(squadVoiceChatId.get())
    squadVoiceChatId.set(null)
  }
}

function addRoomMember(member) {
  if (member.public?.host) {
    log("found host ", member.name,"(", member.userId,")")
    hostId.set(member.userId)
  }
  roomMembers.mutate(@(value) value.append(member))
  return member
}

function removeRoomMember(user_id) {
  roomMembers.set(roomMembers.get().filter(@(member) member.userId != user_id))

  if (user_id == hostId.get()) {
    log("host leaved from room")
    hostId.set(null)
    connectAllowed.set(null)
  }

  if (user_id == userInfo.get()?.userId)
    cleanupRoomState()
}

function makeCreateRoomCb(user_cb) {
  return function(response) {
    if (response.error != 0) {
      log("failed to create room:", error_string(response.error))
    } else {
      roomIsLobby.set(true)
      room.set(response)
      log("you have created the room", response.roomId)
      foreach (member in response.members)
        addRoomMember(member)
    }

    if (squadId.get() != null) {
      matchingCall("mrooms.set_member_attributes", null, {
                        public = {
                          squadId = squadId.get()
                        }
                      })
    }

    if (user_cb)
      user_cb(response)
  }
}

function createRoom(params, user_cb) {
  createChat(function(chat_resp) {
    if (chat_resp.error == 0) {
      params.public.chatId <- chat_resp.chatId
      params.public.chatKey <- chat_resp.chatKey
      chatId.set(chat_resp.chatId)
    }
    matchingCall("mrooms.create_room", makeCreateRoomCb(user_cb), params)
  })
}
function changeAttributesRoom(params, user_cb) {
  matchingCall("mrooms.set_attributes", user_cb, params)
}

let delayedMyAttribs = mkWatched(persist, "delayedMyAttribs", null)
function setMemberAttributes(params) {
  if (myInfoUpdateInProgress.get()) {
    delayedMyAttribs.set(params)
    return
  }
  myInfoUpdateInProgress.set(true)
  delayedMyAttribs.set(null)
  let self = callee()
  matchingCall("mrooms.set_member_attributes",
    function(_res) {
      myInfoUpdateInProgress.set(false)
      if (delayedMyAttribs.get() != null)
        self(delayedMyAttribs.get())
    },
    params)
}

function makeLeaveRoomCb(user_cb) {
  return function(response) {
    if (response.error != 0) {
      log("failed to leave room:", error_string(response.error))
      response.error = 0
      cleanupRoomState()
    }

    if (room.get()) {
      log("you left the room", room.get().roomId)
    }

    if (user_cb)
      user_cb(response)
  }
}

function leaveRoom(user_cb = null) {
  if (isInBattleState.get()) {
    if (user_cb != null)
      user_cb({error = "Can't do that while game is running"})
    return
  }

  matchingCall("mrooms.leave_room", makeLeaveRoomCb(user_cb))
}

function forceLeaveRoom() {
  matchingCall("mrooms.leave_room", makeLeaveRoomCb(null))
}

function destroyRoom(user_cb) {
  if (isInBattleState.get()) {
    if (user_cb != null)
      user_cb({error = "Can't do that while game is running"})
    return
  }

  matchingCall("mrooms.destroy_room", makeLeaveRoomCb(user_cb))
}

function makeJoinRoomCb(lobby, user_cb) {
  return function(response) {

    if (response.error != 0) {
      log("failed to join room:", error_string(response.error))
    }
    else {
      roomIsLobby.set(lobby)

      room.set(response)
      let roomId = response.roomId
      log("you joined room", roomId)
      foreach (member in response.members)
        addRoomMember(member)

      let newChatId = room.get()?.public.chatId
      if (newChatId) {
        joinChat(newChatId, room.get().public.chatKey,
        function(chat_resp) {
          if (chat_resp.error == 0)
            chatId.set(newChatId)
        })
      }
      let squadSelfMember = getRoomMember(userInfo.get()?.userId)
      let selfSquadId = squadSelfMember?.public?.squadId
      if (selfSquadId != null && hasSquadMates(selfSquadId)) {
        squadVoiceChatId.set($"__squad_${selfSquadId}_room_${roomId}")
        voiceState.join_voice_chat(squadVoiceChatId.get())
      }
    }

    if (user_cb)
      user_cb(response)
  }
}

function joinRoom(params, lobby, user_cb) {
  if (!checkMultiplayerPermissions()) {
    log("no permissions to join lobby")
    return
  }
  netStateCall(function() {
    matchingCall("mrooms.join_room", makeJoinRoomCb(lobby, user_cb), params)
  })

}

function makeStartSessionCb(user_cb) {
  return function(response) {
    if (user_cb)
      user_cb(response)
  }
}

function startSession(user_cb) {
  let params = {
    cluster = oneOfSelectedClusters.get()
  }
  matchingCall("mrooms.start_session", makeStartSessionCb(user_cb), params)
}

function startSessionWithLocalDedicated(user_cb, loadTimeout = 30.0) {
  if (!canStartWithLocalDedicated.get()) {
    logerr("Try to start local dedicated when it not allowed")
    return
  }
  let { scene = null } = room.get()?.public
  if (scene == null) {
    logerr("Try to start local dedicated when scene not set for the current room")
    return
  }

  let cmdText = "@start win64/active_matter-ded-dev --listen -config:circuit:t={circuit} -config:scene:t={scene} -invite_data={inviteData} -noeac -nonetenc"
    .subst({
      circuit = get_circuit()
      scene
      inviteData = encodeString(object_to_json_string({ mode_info = room.get().public }, false))
    })
  log("Start local dedicated: ", cmdText)
  system(cmdText)
  isWaitForDedicatedStart.set(true)
  gui_scene.setTimeout(loadTimeout, function() {
    if (!isWaitForDedicatedStart.get())
      return
    isWaitForDedicatedStart.set(false)
    matchingCall("mrooms.start_session", makeStartSessionCb(user_cb), { cluster = "debug" })
  })
}

function onRoomDestroyed(_notify) {
  cleanupRoomState()
}

function signBattleLoadout() {
  
  ecs.g_entity_mgr.broadcastEvent(CmdHideAllUiMenus())
  let queueParam = isInSquad.get() && !isSquadLeader.get() ? squadLeaderState.get()?.curQueueParam : curQueueParam.get()

  if (room.get().public?.extraParams.nexus ?? false)
    eventbus_send("profile_server.get_nexus_loadout", {
      session_id = (room.get().public?.sessionId ?? 0).tostring(),
      raid_name = room.get().public?.extraParams?.raidName ?? "",
      selected_mints=alterMints.get().map(@(v) v.id),
      primary_contract_ids = currentPrimaryContractIds.get()
    })
  else
    eventbus_send("profile_server.get_battle_loadout", {
      session_id = (room.get().public?.sessionId ?? 0).tostring(),
      raid_name = room.get().public?.extraParams?.raidName ?? "",
      queue_id = queueParam?.queueId ?? "",
      is_rented_equipment = useAgencyPreset.get(),
      primary_contract_ids = currentPrimaryContractIds.get(),
      is_offline = false
    })

  previewPreset.set(null)
}

function startConnectToHostSequence(...) {
  if (hostId.get() == null)
    return

  if (!room.get()) {
    log("ConnectToHost error: room leaved while wait for callback")
    return
  }

  ecs.g_entity_mgr.sendEvent(watchedHeroEid.get(), CmdStartMenuExtractionSequence({isOffline=false}))
}

eventbus_subscribe("battle_loadout_sign_success", startConnectToHostSequence)
eventbus_subscribe("battle_loadout_sign_failed", @(...) forceLeaveRoom())

function finishConnectingToHost() {

  local selfMember = getRoomMember(userInfo.get()?.userId)
  let launchParams = {
    host_urls = getRoomMember(hostId.get())?.public?.host_urls
    sessionId = room.get().public?.sessionId
    game = room.get().public?.gameName
    authKey = selfMember?.private?.id_hmac
    encKey = selfMember?.private?.enc_key
    modManifestUrl = room.get().public?.modManifestUrl ?? ""
    modHashes = room.get().public?.modHashes ?? ""
    baseModsFilesUrl = room.get().public?.baseModsFilesUrl ?? ""
  }

  launchParams.each(function(val, key) {
    if (val == null){
      log("ConnectToHost error: some room params are null:",key)
    }
  })

  lastSessionStartData.set({
    sessionId = launchParams.sessionId
    loginTime = loginChain.loginTime.get()
  })
  room.mutate(@(v) v.gameStarted <- true)
  lastRoomResult.set(null)
  ecs.g_entity_mgr.broadcastEvent(CmdHideAllUiMenus())
  startGame(launchParams)
}

ecs.register_es("enlist_connect_to_host_es", {
  [CmdConnectToHost] = @(...) finishConnectingToHost()
}, {comps_rq=["eid"]})

function onDisconnectedFromServer(evt, _eid, _comp) {
  if (!roomIsLobby.get())
    forceLeaveRoom()
  if (lastSessionStartData.get() == null)
    return

  local connLost = true
  if (evt[0] == DC_CONNECTION_CLOSED) {
    connLost = false
  }

  let { sessionId, loginTime } = lastSessionStartData.get()
  lastSessionStartData.set(null)
  let wasRelogin = loginTime != loginChain.loginTime.get()
  if (!wasRelogin && !connLost && !roomIsLobby.get()) {
    matchingCall("enlmm.remove_from_match", null, { sessionId })
    lastRoomResult.set({ connLost, sessionId })
  }
}

function onConnectedToServer() {
  if (room.get()?.public?.extraParams == null) {
    return
  }
  let extraParams = room.get()?.public?.extraParams
  ecs.g_entity_mgr.broadcastEvent(MatchingRoomExtraParams({
      routeEvaluationChance = extraParams?.routeEvaluationChance ?? 0.0,
      ddosSimulationChance = extraParams?.ddosSimulationChance ?? 0.0,
      ddosSimulationAddRtt = extraParams?.ddosSimulationAddRtt ?? 0,
  }));
}

ecs.register_es("enlist_disconnected_from_server_es", {
  [EventOnDisconnectedFromServer] = onDisconnectedFromServer,
  [EventOnNetworkDestroyed] = onDisconnectedFromServer,
})
ecs.register_es("enlist_connected_to_server_es", {
  [EventOnConnectedToServer] = onConnectedToServer,
})

function onHostNotify(notify) {
  log("onHostNotify", notify)
  if (notify.hostId != hostId.get()) {
    log($"warning: got host notify from host that is not in current room {notify.hostId} != {hostId.get()}")
    return
  }

  if (notify.roomId != room.get()?.roomId) {
    log("warning: got host notify for wrong room")
    return
  }

  if (notify.message == "connect-allowed")
    connectAllowed.set(true)
  else {
    msgbox.showMsgbox({text=loc("msgboxtext/connectNotAllowed")})
    forceLeaveRoom()
    return
  }

  if (!checkMultiplayerPermissions()) {
    forceLeaveRoom()
    log("no permissions to join network game")
    return
  }

  if (doConnectToHostOnHostNotfy.get() || isWaitForDedicatedStart.get()) {
    isWaitForDedicatedStart.set(false)
    signBattleLoadout()
  }
}

function onRoomMemberJoined(notify) {
  if (notify.roomId != room.get()?.roomId)
    return
  log("{0} ({1}) joined room".subst(notify.name, notify.userId))
  if (notify.userId != userInfo.get()?.userId) {
    let newmember = addRoomMember(notify)
    if (squadVoiceChatId.get() == null) {
      let squadSelfMember = getRoomMember(userInfo.get()?.userId)
      let selfSquadId = squadSelfMember?.public?.squadId
      if (selfSquadId != null && selfSquadId == newmember?.squadId) {
        let roomId = room.get().roomId
        squadVoiceChatId.set($"__squad_${selfSquadId}_room_${roomId}")
        voiceState.join_voice_chat(squadVoiceChatId.get())
      }
    }
  }
}

function onRoomMemberLeft(notify) {
  if (notify.roomId != room.get()?.roomId)
    return
  log("{0} ({1}) left from room".subst(notify.name, notify.userId))
  removeRoomMember(notify.userId)
}

function onRoomMemberKicked(notify) {
  removeRoomMember(notify.userId)
}

function merge_attribs(upd_data, attribs) {
  foreach (key, value in upd_data) {
    if (value == null) {
      if (key in attribs)
        attribs.$rawdelete(key)
    }
    else
      attribs[key] <- value
  }
  return attribs
}

function onRoomAttrChanged(notify) {
  if (!room.get())
    return

  room.mutate(function(roomVal){
    let pub = notify?.public
    let priv = notify?.private
    if (typeof pub == "table")
      merge_attribs(pub, roomVal.public)
    if (typeof priv == "table")
      merge_attribs(priv, roomVal.private)
    return roomVal
  })
}

function onRoomMemberAttrChanged(notify) {
  if (!roomMembers.get())
    return

  roomMembers.mutate(function(membs) {
    let idx = membs.findindex(@(m) m.userId == notify?.userId)
    if (idx == null)
      return membs
    let member = clone membs[idx]
    let pub = notify?["public"]
    let priv =notify?["private"]
    if (typeof pub == "table")
      member.public <- merge_attribs(pub, clone member.public)
    if (typeof priv == "table")
      member.private <- merge_attribs(priv, clone member.private)
    membs[idx] = member
    return membs
  })
}

let canInviteToRoom = Computed(@() room.get() != null
  && (room.get()?.public.slotsCnt ?? 0) < (room.get()?.public.maxPlayers ?? 0))

function isInMyRoom(newMemberId){
  return roomMembers.get().findvalue(@(member) member.userId == newMemberId) != null
}

function joinCb(response) {
  let err = response.error
  if (err != OK) {
    let errStr = error_string(err)
    msgbox.showMsgbox({ text = loc("msgbox/failedJoinRoom", {
      error = loc($"error/{errStr}", errStr)
    }) })
  }
}

subscribeGroup(INVITE_ACTION_ID, {
  onShow = @(notify) msgbox.showMsgbox({
    text = loc("squad/acceptInviteQst")
    buttons = [
      { text = loc("Yes"), isCurrent = true,
        function action() {
          let { userId = null } = userInfo.get()
          let params = { roomId = notify.roomId.tointeger() }
          joinRoom(params, true, joinCb)
          notify.send_resp({ accept = true, user_id = userId })
          joinedRoomWithInvite.set(true)
          removeNotify(notify)
        }
      }
      { text = loc("No"), isCancel = true,
        function action() {
          let { userId = null } = userInfo.get()
          removeNotify(notify)
          notify.send_resp({ accept = false, user_id = userId })
        }
      }
    ]
  })
  onRemove = @(notify) notify.send_resp({ accept = false })
})

room.subscribe_with_nasty_disregard_of_frp_update(function(v){
  if(v == null)
    joinedRoomWithInvite.set(false)
})

function onRoomInvite(reqctx) {
  let request = reqctx.request
  roomInvites.mutate(@(i) i.append({
    roomId = request.roomId
    senderId = request.invite_data.senderId
    senderName = request.invite_data.senderName
    send_resp = @(resp) matching_send_response(reqctx, resp)
  }))

  log("got room invite from", request.invite_data.senderName)

  pushNotification({
    roomId = request.roomId
    inviterUid = request.invite_data.senderId
    styleId = "toBattle"
    text = loc("room/invite", {playername = request.invite_data.senderName})
    actionsGroup = INVITE_ACTION_ID
    needPopup = true
    send_resp = @(resp) matching_send_response(reqctx, resp)
  })
}


function inviteToRoom(user_id){
  if(isInMyRoom(user_id) || !canInviteToRoom.get()){
    log("Player can not be invited to lobby")
    return
  }
  playersWaitingResponseFor.mutate(@(v) v[user_id] <- true)
  matchingCall("mrooms.invite_player",
    function(player){
      playersWaitingResponseFor.mutate(@(v) player?.user_id in v
        ? v.$rawdelete(player.user_id)
        : null)
    },
    { userId = user_id })
}

function onMatchInvite(reqctx) {
  log("got match invite from server")
  matching_send_response(reqctx, {})
  joinRoom(reqctx.request, false, function(_cb) {})
}

function list_invites(){
  foreach (i, invite in roomInvites.get()){
    log(
      "{0} from {1} ({2}), roomId {3}".subst(
        i, invite.senderName, invite.senderId, invite.roomId))
  }
}

let gameIsLaunching = Computed(@() !((roomIsLobby.get() || !room.get()) && !isInQueue.get()))

console_register_command(list_invites, "mrooms.list_invites")

foreach (name, cb in {
  ["mrooms.on_room_member_joined"] = onRoomMemberJoined,
  ["mrooms.on_room_member_leaved"] = onRoomMemberLeft,
  ["mrooms.on_room_attributes_changed"] = onRoomAttrChanged,
  ["mrooms.on_room_member_attributes_changed"] = onRoomMemberAttrChanged,
  ["mrooms.on_room_destroyed"] = onRoomDestroyed,
  ["mrooms.on_room_member_kicked"] = onRoomMemberKicked,
  ["mrooms.on_host_notify"] = onHostNotify
}){
  matching_listen_notify(name)
  eventbus_subscribe(name, cb)
}

foreach (name, cb in {
  ["mrooms.on_room_invite"] = onRoomInvite,
  ["enlmm.on_room_invite"] = onMatchInvite,
}){
  matching_listen_rpc(name)
  eventbus_subscribe(name, cb)
}

eventbus_subscribe("matching.on_disconnect", @(...) cleanupRoomState())

let allowReconnect = mkWatched(persist, "allowReconnect", true)


return {
  room
  isInRoom = Computed(@() room.get() != null)
  roomInvites
  roomMembers
  roomIsLobby
  lobbyStatus
  lastRoomResult
  chatId

  setMemberAttributes
  myInfoUpdateInProgress
  createRoom
  changeAttributesRoom
  joinRoom
  leaveRoom
  startSession
  canStartWithLocalDedicated
  startSessionWithLocalDedicated
  destroyRoom
  canOperateRoom
  myMemberInfo
  gameIsLaunching

  connectToHost = signBattleLoadout
  connectAllowed
  allowReconnect
  doConnectToHostOnHostNotfy
  LobbyStatus

  canInviteToRoom
  isInMyRoom
  inviteToRoom
  playersWaitingResponseFor
  joinedRoomWithInvite
}
