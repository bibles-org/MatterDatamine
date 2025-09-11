from "%dngscripts/globalState.nut" import nestWatched
from "%dngscripts/sound_system.nut" import sound_play
from "%sqstd/timers.nut" import debounce
from "%ui/mainMenu/contacts/contact.nut" import getContactRealnick, getContact, validateNickNames, getContactNick, updateContact
from "%ui/permissions/permissions.nut" import checkMultiplayerPermissions
from "math" import fabs
from "%ui/mainMenu/mailboxState.nut" import pushNotification, removeNotifyById, removeNotify, subscribeGroup
from "%ui/mainMenu/contacts/contactPresence.nut" import isContactOnline, updateSquadPresences
import "%ui/squad/squadAPI.nut" as MSquadAPI
from "matching.api" import matching_listen_notify
from "%ui/components/msgbox.nut" import showMsgbox
from "%ui/voiceChat/voiceState.nut" import join_voice_chat, leave_voice_chat
from "%ui/mainMenu/chat/chatApi.nut" import leaveChat, createChat, joinChat
import "%ui/squad/consoleSessionManager.nut" as sessionManager
from "eventbus" import eventbus_send, eventbus_subscribe
from "%ui/helpers/platformUtils.nut" import canInterractCrossPlatformByCrossplay
from "%ui/mainMenu/raidAutoSquadState.nut" import getFormalLeaderUid
from "%ui/hud/state/in_battle_squad_notification_state.nut" import showSquadNotification
from "app" import get_app_id
from "%ui/ui_library.nut" import *
from "%ui/mainMenu/raid_preparation_window_state.nut" import currentPrimaryContractIds
from "%ui/profile/profileState.nut" import playerProfileCurrentContracts

let logSq = require("%sqGlob/library_logs.nut").with_prefix("[SQUAD] ")
let popupsState = require("%ui/popup/popupsState.nut")    
let { blockedUids } = require("%ui/mainMenu/contacts/contactsWatchLists.nut")
let userInfo = require("%sqGlob/userInfo.nut")
let { contacts } = require("%ui/mainMenu/contacts/contact.nut")
let { onlineStatus } = require("%ui/mainMenu/contacts/contactPresence.nut")
let squadState = require("%ui/squad/squadState.nut")
let { squadId, isInSquad, isSquadLeader, isInvitedToSquad, selfUid, squadSharedData,
  squadServerSharedData, squadMembers, squadSelfMember, notifyMemberRemoved, notifyMemberAdded
} = squadState

let { uid2console } = require("%ui/mainMenu/contacts/consoleUidsRemap.nut")
let { crossnetworkPlay, CrossPlayStateWeight, crossnetworkChat } = require("%ui/state/crossnetwork_state.nut")
let { consoleCompare } = require("%ui/helpers/platformUtils.nut")
let { queueInfo, curQueueParam, availableSquadMaxMembers } = require("%ui/state/queueState.nut")
let { waitingInvite, waitingInviteFromLeaderNumber } = require("%ui/mainMenu/raidAutoSquadState.nut")
let { isInBattleState } = require("%ui/state/appState.nut")
let { maxVersionStr } = require("%ui/client_version.nut")
let { selectedRaid, leaderSelectedRaid } = require("%ui/gameModeState.nut")
let { playersData } = require("%ui/squad/players_share_data.nut")

const INVITE_ACTION_ID = "squad_invite_action"
const SQUAD_OVERDRAFT = 0

let setOnlineBySquad = @(userId, online) updateSquadPresences({ [userId.tostring()] = online })

let SquadMember = function(userId)  {
  let realnick = getContactRealnick(userId.tostring())
  return {
    userId
    isLeader = squadId.get() == userId
    state = {}
    realnick
  }
}

function applyRemoteDataToSquadMember(member, msquad_data) {
  logSq($"[SQUAD] applyRemoteData for {member.userId} from msquad")
  logSq(msquad_data)

  let newOnline = msquad_data?.online
  if (newOnline != null)
    setOnlineBySquad(member.userId, newOnline)

  let data = msquad_data?.data
  if (typeof(data) != "table")
    return {}

  let oldVal = member.state
  foreach (k,v in data){
    if (k in oldVal && oldVal[k] == v)
      continue
    member.state = oldVal.__merge(data)
    break
  }

  return data
}


let delayedInvites = mkWatched(persist, "delayedInvites", null)
let isSquadDataInited = nestWatched("isSquadDataInited", false)
let squadChatJoined = nestWatched("squadChatJoined", false)

let myDataRemote = nestWatched("myDataRemoteWatch", {})
let myDataLocal = Watched({})

let voiceChatId          = @(s) $"squad-channel-{s}"
let chatId = nestWatched("nestWatched", null)

squadId.subscribe_with_nasty_disregard_of_frp_update(function(_val) {
  isSquadDataInited.set(false)
})
squadMembers.subscribe(@(list)
  validateNickNames(list.map(@(m) getContact(m.userId.tostring(), contacts.get()))))

let getSquadInviteUid = @(inviterSquadId) $"squad_invite_{inviterSquadId}"

function sendEvent(handlers, val) {
  foreach (h in handlers)
    h(val)
}

function isFloatEqual(a, b, eps = 1e-6) {
  let absSum = fabs(a) + fabs(b)
  return absSum < eps ? true : fabs(a - b) < eps * absSum
}

let isEqualWithFloat = @(v1, v2) isEqual(v1, v2, { float = isFloatEqual })

let updateMyData = debounce(function() {
  if (squadSelfMember.get() == null)
    return 

  let needSend = myDataLocal.get().findindex(@(value, key) !isEqualWithFloat(myDataRemote.get()?[key], value)) != null
  if (needSend) {
    logSq("update my data: ", myDataLocal.get())
    MSquadAPI.setMemberData(myDataLocal.get())
  }
}, 0.1)

foreach (w in [squadSelfMember, myDataLocal, myDataRemote])
  w.subscribe(@(_) updateMyData())

function linkVarToMsquad(name, var) {
  myDataLocal.mutate(@(v) v[name] <- var.get())
  var.subscribe_with_nasty_disregard_of_frp_update(@(_val) myDataLocal.mutate(@(v) v[name] <- var.get()))
}

linkVarToMsquad("name", keepref(Computed(@() userInfo.get()?.name))) 

let appId = Watched(get_app_id())
let myExtData_ready = mkWatched(persist, "myExtData_ready", false)

let myExtSquadData = freeze({
  inBattle = isInBattleState
  crossnetworkPlay
  version = maxVersionStr
  appId
  selectedRaid
  curQueueParam
  queueInfo
  ready = myExtData_ready
  leaderRaid = leaderSelectedRaid
  playersData
})

let myExtDataRW = freeze({ready = myExtData_ready})

foreach(name, var in myExtSquadData) {
  linkVarToMsquad(name, var)
}

function setSelfRemoteData(member_data) {
  myDataRemote.set(clone member_data)
  foreach (k, v in member_data) {
    if (k in myExtDataRW) {
      myExtDataRW[k].set(v)
    }
  }
}

isInBattleState.subscribe_with_nasty_disregard_of_frp_update(function(v) {
  if (!v) {
    myExtSquadData.ready.set(false)
    myExtSquadData.leaderRaid.set(null)
  }
})

function reset() {
  squadId.set(null)
  isInvitedToSquad.set({})

  if (squadSharedData.squadChat.get() != null) {
    squadChatJoined.set(false)
    let chat_id = squadSharedData.squadChat.get()?.chatId
    leaveChat(chat_id, null)
    chatId.set(null)
    if (chat_id)
      leave_voice_chat(voiceChatId(chat_id))
  }

  foreach (w in squadSharedData)
    w.set(null)
  foreach (w in squadServerSharedData)
    w.set(null)

  foreach (member in squadMembers.get()) {
    setOnlineBySquad(member.userId, null)
    sendEvent(notifyMemberRemoved, member.userId)
  }
  squadMembers.set({})
  delayedInvites.set(null)
  myExtSquadData.ready.set(false)
  myExtSquadData.leaderRaid.set(null)
  myDataRemote.set({})
}

function setSquadLeader(squadIdVal){
  squadMembers.mutate(function(s) {
    foreach (uid, member in s){
      s[uid].isLeader = member.userId == squadIdVal
    }
  })
}
squadId.subscribe_with_nasty_disregard_of_frp_update(setSquadLeader)
setSquadLeader(squadId.get())

function removeInvitedSquadmate(user_id) {
  if (!(user_id in isInvitedToSquad.get()))
    return false
  isInvitedToSquad.mutate(@(value) value.$rawdelete(user_id))
  return true
}

function addInvited(user_id) {
  if (user_id in isInvitedToSquad.get())
    return false
  isInvitedToSquad.mutate(@(value) value[user_id] <- true)
  validateNickNames([getContact(user_id.tostring(), contacts.get())])
  return true
}

function applySharedData(dataTable) {
  if (!isInSquad.get())
    return

  foreach (key, w in squadServerSharedData)
    if (key in dataTable)
      w.set(dataTable[key])

  if (!isSquadLeader.get())
    foreach (key, w in squadSharedData)
      w.set(squadServerSharedData[key].get())
}

function checkDisbandEmptySquad() {
  if (squadMembers.get().len() == 1 && !isInvitedToSquad.get().len())
    MSquadAPI.disbandSquad()
}

function revokeSquadInvite(user_id) {
  if (!removeInvitedSquadmate(user_id))
    return

  MSquadAPI.revokeInvite(user_id)
  checkDisbandEmptySquad()
}

function revokeAllSquadInvites() {
  foreach (uid, _ in isInvitedToSquad.get())
    revokeSquadInvite(uid)
}

function leaveSquadSilent(cb = null) {
  if (!isInSquad.get()) {
    cb?()
    return
  }

  if (squadMembers.get().len() == 1)
    revokeAllSquadInvites()

  sessionManager.leave()
  MSquadAPI.leaveSquad({ onAnyResult = function(...) {
    reset()
    cb?()
  }})
}

let showSizePopup = @(text, isError = true)
    popupsState.addPopup({ id = "squadSizePopup", text = text, styleName = isError ? "error" : "" })


let requestMemberData = @(uid, isMe, isNewMember, cb = @(_res) null)
  MSquadAPI.getMemberData(uid,
    { onSuccess = function(response) {
        let member = squadMembers.get()?[uid]
        if (member) {
          let data = applyRemoteDataToSquadMember(member, response)
          if (isMe && data)
            setSelfRemoteData(data)
          if (isNewMember) {
            sendEvent(notifyMemberAdded, uid)
          }
        }
        squadMembers.trigger()
        cb(response)
      }
    })

function updateSquadInfo(squad_info) {
  if (squadId.get() != squad_info.id)
    return

  foreach (uid in squad_info.members) {
    local isNewMember = false
    let isMe = (uid == selfUid.get())
    if (uid not in squadMembers.get()) {
      if (isMe && squad_info.members.len() > availableSquadMaxMembers.get()) {
        logSq("Leave from squad, right after join. Squad was already full.")
        leaveSquadSilent(@() showSizePopup(loc("squad/popup/squadFull")))
        continue
      }

      let sMember = SquadMember(uid)
      squadMembers.mutate(@(m) m[uid] <- sMember)

      sound_play("ui_sounds/teammate_appear")
      removeInvitedSquadmate(uid)
      isNewMember = true
      if (isMe) {
        requestMemberData(uid, isMe, isNewMember)
        continue
      }
    }

    requestMemberData(uid, isMe, isNewMember)
  }
  squadMembers.trigger()

  foreach (uid in squad_info?.invites ?? [])
    addInvited(uid)

  if (squad_info?.data)
    applySharedData(squad_info.data)

  isSquadDataInited.set(true)
}

local fetchSquadInfo = null

function acceptInviteImpl(invSquadId) {
  if (!checkMultiplayerPermissions()){
    logSq("accept squad invitation is not allowed because of multiplayer permissions")
    return
  }
  MSquadAPI.acceptInvite(invSquadId,
      { onSuccess = function(...) {
          squadId.set(invSquadId)
          fetchSquadInfo()
        }
        onFailure = function(resp) {
          let errId = resp?.error_id ?? ""
          showMsgbox({
            text = loc($"squad/nonAccepted/{errId}",
              ": ".concat(loc("squad/inviteError"), errId)) })
          eventbus_send("ipc.squadIsFull", null)
          logSq("sessionManager.leave on mpi.acceptinvite failure")
          sessionManager.leave()
        }
      })
}

function acceptSquadInvite(invSquadId) {
  if (!isInSquad.get())
    acceptInviteImpl(invSquadId)
  else
    leaveSquadSilent(@() acceptInviteImpl(invSquadId))
}

function processSquadInvite(contact) {
  
  if (isInSquad.get() && squadId.get() == contact.uid) {
    return
  }

  pushNotification({
    id = getSquadInviteUid(contact.uid)
    inviterUid = contact.uid
    styleId = "toBattle"
    text = loc("squad/invite", {playername=getContactNick(contact)})
    actionsGroup = INVITE_ACTION_ID
    needPopup = true
  })
}

function onInviteRevoked(inviterSquadId, invitedMemberId) {
  if (inviterSquadId == squadId.get())
    removeInvitedSquadmate(invitedMemberId)
  else
    removeNotifyById(getSquadInviteUid(inviterSquadId))
}

function addInviteByContact(inviter) {
  if (inviter.uid == selfUid.get()) 
    return

  if (inviter.userId in blockedUids.get()) {
    logSq("got squad invite from blacklisted user", inviter)
    MSquadAPI.rejectInvite(inviter.uid)
    return
  }

  if (!canInterractCrossPlatformByCrossplay(inviter.realnick, crossnetworkPlay.get())) {
    logSq($"got squad invite from crossplatform user, is crosschat available: {crossnetworkChat.get()}", inviter)
    MSquadAPI.rejectInvite(inviter.uid)
    return
  }

  if (consoleCompare.xbox.isPlatform && consoleCompare.xbox.isFromPlatform(inviter.realnick)) {
    logSq("got squad invite from xbox player. It will be silently accepted or hidden", inviter)
    return
  }

  processSquadInvite(inviter)
}

function onInviteNotify(invite_info) {
  let autoSquadFormalLeader = waitingInviteFromLeaderNumber.get()
  log("[Autosquad] Check is autosquad inite:")
  log($"[Autosquad] waitingInvite: {waitingInvite.get()}")
  log($"[Autosquad] autoSquadFormalLeader: {autoSquadFormalLeader}")
  log($"[Autosquad] selfUid: {selfUid.get()}")
  log($"[Autosquad] invite_info.leader.id: {invite_info?.leader.id}")
  if (waitingInvite.get() &&
      autoSquadFormalLeader &&
      autoSquadFormalLeader != selfUid.get() &&
      autoSquadFormalLeader == invite_info?.leader.id) {
    acceptSquadInvite(invite_info.leader.id)
    eventbus_send("autosquad.invite_accepted", null)
    return
  }

  if (contacts.get()?[invite_info?.leader.id.tostring()] == null) {
    
    
    log("[SQUAD] Skip invite from non-friend user")
    return
  }

  if ("invite" in invite_info) {
    let uid = invite_info?.leader.id
    let inviter = uid != null ? updateContact(invite_info.leader.id.tostring(), invite_info?.leader.name) : null

    if (invite_info.invite.id == selfUid.get()) {
      if (inviter!=null)
        addInviteByContact(inviter)
    }
    else
      addInvited(invite_info.invite.id)
  }
  else if ("replaces" in invite_info) {
    onInviteRevoked(invite_info.replaces, selfUid.get())
    let uid = invite_info?.leader.id.tostring()
    if (uid != null)
      addInviteByContact(getContact(uid, contacts.get()))
  }
}


fetchSquadInfo = function(cb = null) {
  MSquadAPI.getSquadInfo({
    onAnyResult = function (result) {
      if (result.error != 0) {
        if (result?.error_id == "NOT_SQUAD_MEMBER")
          squadId.set(null)
        if (cb)
          cb(result)
        return
      }

      if ("squad" in result) {
        squadId.set(result.squad.id)
        updateSquadInfo(result.squad)
        if (cb)
          cb(result)
      }

      let validateList = (result?.invites ?? []).map(@(id) getContact(id.tostring(), contacts.get()))

      validateNickNames(validateList, function() {
        foreach (sender in validateList)
          addInviteByContact(sender)
      })
    }
  })
}

function onMemberDataChanged(user_id, request) {
  let member = squadMembers.get()?[user_id]
  if (member == null)
    return

  let data = applyRemoteDataToSquadMember(member, request)
  let isMe = (user_id == selfUid.get())
  if (isMe && data)
    setSelfRemoteData(data)
  squadMembers.trigger()
}

function addMember(member) {
  let userId = member.userId
  logSq("addMember", userId, member.name)

  let squadMember = SquadMember(member.userId)
  let realnick = getContactRealnick(member.userId.tostring())
  squadMember.realnick = realnick
  setOnlineBySquad(squadMember.userId, true)
  removeInvitedSquadmate(member.userId)

  squadMembers.mutate(@(val) val[userId] <- squadMember)
  sendEvent(notifyMemberAdded, userId)

  if (squadMembers.get().len() == availableSquadMaxMembers.get() && isInvitedToSquad.get().len() > 0 && isSquadLeader.get()) {
    revokeAllSquadInvites()
    showSizePopup(loc("squad/squadIsReadyExtraInvitesRevoken"))
  }
}

function removeMember(member) {
  let userId = member.userId

  if (userId == selfUid.get()) {
    if (isInBattleState.get()) {
      showSquadNotification(loc("squad/kickedMsgbox"))
    } else {
      showMsgbox({
          text = loc("squad/kickedMsgbox")
        })
    }
    reset()
  }
  else if (userId in squadMembers.get()) {
    let m = squadMembers.get()[userId]
    setOnlineBySquad(m.userId, null)
    if (userId in squadMembers.get()) 
      squadMembers.mutate(@(v) v.$rawdelete(userId))
    sendEvent(notifyMemberRemoved, userId)
    checkDisbandEmptySquad()
  }
  sound_play("ui_sounds/teammate_leave")
}

  
function leaveSquad(cb = null) {
  showMsgbox({
    text = loc("squad/leaveSquadQst")
    buttons = [
      { text = loc("Yes"), action = function() {
        leaveSquadSilent(cb)
        eventbus_send("squad.local_player_leaved", null)
      }}
      { text = loc("No") }
    ]
  })
}

function dismissSquadMember(user_id) {
  let member = squadMembers.get()?[user_id]
  if (!member)
    return
  showMsgbox({
    text = loc("squad/kickPlayerQst",
      { name = getContactNick(getContact(member.userId.tostring(), contacts.get())) })
    buttons = [
      { text = loc("Yes"), action = @() MSquadAPI.dismissMember(user_id) }
      { text = loc("No"), isCancel = true, isCurrent = true }
    ]
  })
}

function dismissAllOfflineSquadmates() {
  if (!isSquadLeader.get())
    return
  foreach (member in squadMembers.get()){
    if (!isContactOnline(member.userId.tostring(), onlineStatus.get()))
      MSquadAPI.dismissMember(member.userId)
  }
}

function transferSquad(user_id) {
  let is_leader = isSquadLeader.get()
  MSquadAPI.transferSquad(user_id,
  {
    onSuccess = function(_) {
      squadId.set(user_id)
      if (is_leader) {
        sessionManager.updateData(user_id)
      }
      myExtSquadData.leaderRaid.set(null)
    }
  })
}

function createSquadAndDo(afterFunc = null) {
  if (isInSquad.get()) {
    logSq($"CreateSquadAndDo: don't create squad, do action")
    afterFunc?()
    return
  }

  if (afterFunc)
    delayedInvites.set([afterFunc])

  let inviteDelayed = function() {
    if (delayedInvites.get() == null)
      return
    foreach (f in delayedInvites.get())
      f()
    delayedInvites.set(null)
  }

  let cleanupDelayed = @() delayedInvites.set(null)

  MSquadAPI.createSquad({
    onSuccess = @(_)
      fetchSquadInfo(
        function(r) {
          if (r.error != 0) {
            cleanupDelayed()
            return
          }

          if (sessionManager.isAvailableConsoleSession)
            sessionManager.create(squadId.get(), inviteDelayed)
          else
            inviteDelayed()

          createChat(function(chat_resp) {
            if (chat_resp.error == 0) {
              squadChatJoined.set(true)
              squadSharedData.squadChat.set({
                chatId = chat_resp.chatId
                chatKey = chat_resp.chatKey
              })
              chatId.set(chat_resp.chatId)
            }
          })
        }
      )
    onFailure = @(_) cleanupDelayed()
  })
}

function inviteToSquad(user_id, needConsoleInvite = true) {
  if (!checkMultiplayerPermissions()){
    logSq("invite to squad is not allowed because of multiplayer permissions")
    return
  }
  if (isInSquad.get()) {
    if (user_id in squadMembers.get()) {
      logSq($"Invite: member {user_id}: already in squad")
      return
    }

    if (squadMembers.get().len() >= availableSquadMaxMembers.get()) {
      logSq($"Invite: member {user_id}: squad already full")
      return showSizePopup(loc("squad/popup/squadFull"))
    }

    if (squadMembers.get().len() + isInvitedToSquad.get().len() >= availableSquadMaxMembers.get() + SQUAD_OVERDRAFT) {
      logSq($"Invite: member {user_id}: too many invites")
      return showSizePopup(loc("squad/popup/tooManyInvited"))
    }
  }

  let _doInvite = function() {
    MSquadAPI.invitePlayer(user_id, {
      onFailure = function(resp) {
        let errId = resp?.error_id ?? ""
        showSizePopup(loc($"error/{errId}"), false)
      }
    })
  }

  local doInvite = _doInvite
  if (needConsoleInvite && sessionManager.isAvailableConsoleSession && uid2console.get()?[user_id.tostring()] != null)
    doInvite = @() sessionManager.invite(user_id, _doInvite)

  if (delayedInvites.get() != null) { 
    delayedInvites.mutate(@(inv) inv.append(doInvite))
    logSq($"Invite: member {user_id}: saved to delayed. Postpone")
    return
  }

  createSquadAndDo(doInvite)
}

local isSharedDataRequestInProgress = false
function syncSharedDataImpl() {
  function isSharedDataDifferent() {
    foreach (key, w in squadSharedData)
      if (w.get() != squadServerSharedData[key].get())
        return true
    return false
  }

  if (isSharedDataRequestInProgress || !isSquadLeader.get() || !isSharedDataDifferent())
    return

  let thisFunc = callee()
  isSharedDataRequestInProgress = true
  let requestData = squadSharedData.map(@(w) w.get())
  MSquadAPI.setSquadData(requestData,
    { onSuccess = function(_res) {
        isSharedDataRequestInProgress = false
        applySharedData(requestData)
        thisFunc()
      }
      onFailure = function(_res) {
        isSharedDataRequestInProgress = false
      }
    })
}

local syncSharedDataTimer = null
function syncSharedData(...) {
  if (syncSharedDataTimer || !isSquadLeader.get())
    return
  
  syncSharedDataTimer = function() {
    gui_scene.clearTimer(syncSharedDataTimer)
    syncSharedDataTimer = null
    syncSharedDataImpl()
  }
  gui_scene.setInterval(0.1, syncSharedDataTimer)
}

foreach (w in squadSharedData)
  w.subscribe(syncSharedData)

subscribeGroup(INVITE_ACTION_ID, {
  onShow = @(notify) showMsgbox({
    text = loc("squad/acceptInviteQst")
    buttons = [
      { text = loc("Yes"), isCurrent = true,
        function action() {
          removeNotify(notify)
          acceptSquadInvite(notify.inviterUid)
        }
      }
      { text = loc("No"), isCancel = true,
        function action() {
          removeNotify(notify)
          MSquadAPI.rejectInvite(notify.inviterUid)
        }
      }
    ]
  })

  onRemove = @(notify) MSquadAPI.rejectInvite(notify.inviterUid)
})

function requestJoinSquad(userId) {
  MSquadAPI.requestJoin(userId, {
    onSuccess = function(...) {
      squadId.set(userId)
      fetchSquadInfo()
    },
    onFailure = @(resp) logSq($"Failed to join squad {userId}", resp)
  })
}

function onAcceptMembership(newContact) {
  let { realnick, uid } = newContact
  logSq($"Squad application notification from {uid}/{realnick}")
  if ((consoleCompare.xbox.isFromPlatform(realnick)
      || consoleCompare.psn.isFromPlatform(realnick)) && isSquadLeader.get()) {
    logSq($"Accepting squad membership from {uid}")
    MSquadAPI.acceptMembership(uid)
  } else {
    logSq($"Not squad leader or request was performed from {realnick} non-(xbox or psn) platform. Skipping.")
  }
}

function onApplicationNotify(params) {
  let applicant = params?.applicant
  let uid = applicant?.id
  let contactUid = uid?.tostring()
  if (uid) {
    let newContact = getContact(contactUid, contacts.get())
    validateNickNames([newContact], @() onAcceptMembership(newContact))
  }
  else
    println($"incorrect uid on contact creation, {uid}")
}


function onApplicationAccept(params) {
  let sid = params?.squad?.id
  logSq($"Squad membership application accepted for squad {sid}")
  squadId.set(sid)
  fetchSquadInfo()
}

function onSquadCreated(params) {
  let sid = params?.requestBy?.userId
  logSq($"Squad created, requested by {sid}")
  squadId.set(sid)
  fetchSquadInfo()
}

let msubscribes = {
  ["msquad.notify_invite"] = onInviteNotify,
  ["msquad.notify_invite_revoked"] = function(params) {
    if (params?.squad?.id != null && params?.invite?.id != null)
      onInviteRevoked(params.squad.id, params.invite.id)
  },
  ["msquad.notify_invite_rejected"] = function(params) {
    if (isSquadLeader.get()) {
      let contact = getContact(params.invite.id.tostring(), contacts.get())
      removeInvitedSquadmate(contact.uid)
      pushNotification({ text = loc("squad/mail/reject", {playername = getContactNick(contact) })})
      checkDisbandEmptySquad()
    }
  },
  ["msquad.notify_invite_expired"] = function(params) {
    removeInvitedSquadmate(params.invite.id)
    checkDisbandEmptySquad()
  },
  ["msquad.notify_disbanded"] = function(_params) {
    sessionManager.leave()
    if (!isSquadLeader.get()) {
      if (isInBattleState.get()) {
        showSquadNotification(loc("squad/msgbox_disbanded"))
      } else {
        showMsgbox({text = loc("squad/msgbox_disbanded")})
      }
    }
    sound_play("ui_sounds/teammate_leave")
    reset()
  },
  ["msquad.notify_member_joined"] = addMember,
  ["msquad.notify_member_leaved"] = removeMember,
  ["msquad.notify_leader_changed"] = function(params) {
    squadId.set(params.userId)
    if (isSquadLeader.get()) {
      sessionManager.updateData(params.userId)
    }
  },
  ["msquad.notify_data_changed"] = function(_params){
    if (isInSquad.get())
      fetchSquadInfo()
  },
  ["msquad.notify_member_data_changed"] = function(params) {
    MSquadAPI.getMemberData(params.userId,
        { onSuccess = @(response) onMemberDataChanged(params.userId, response) })
  },
  ["msquad.notify_member_logout"] = function(params) {
    let {userId} = params
    if (userId not in squadMembers.get())
      return
    setOnlineBySquad(userId, false)
    squadMembers.mutate(function(s){
      s[userId].state.ready <- false
    })
  },
  ["msquad.notify_member_login"] = function(params) {
    let member = squadMembers.get()?[params.userId]
    if (member){
      logSq("member", params.userId, "going to online")
      setOnlineBySquad(member.userId, true)
    }
  },
  ["msquad.notify_squad_created"] = onSquadCreated,
  ["msquad.notify_application"] = onApplicationNotify,
  ["msquad.notify_application_accepted"] = onApplicationAccept,
  ["msquad.notify_application_revoked"] = function(...) {},
  ["msquad.notify_application_denied"] = function(...) {}
}

foreach (k, v in msubscribes) {
  matching_listen_notify(k)
  eventbus_subscribe(k, v)
}

eventbus_subscribe("matching.logged_out", @(...) reset())
eventbus_subscribe("matching.logged_in", function(...) {
  reset()
  fetchSquadInfo(@(val) logSq(val))
})

squadSharedData.squadChat.subscribe_with_nasty_disregard_of_frp_update(function(value) {
  if (value != null) {
    if (!squadChatJoined.get()) {
      joinChat(value?.chatId, value?.chatKey,
      function (resp) {
        if (resp.error == 0)
          squadChatJoined.set(false)
      })
      chatId.set(value?.chatId)
    }
    if (value?.chatId)
      join_voice_chat(voiceChatId(value.chatId))
  }
})

let squadOnlineMembers = Computed(@() squadMembers.get().filter(@(m) isContactOnline(m.userId.tostring(), onlineStatus.get())))

let unsuitableCrossplayConditionMembers = Computed(function() {
  let myCPState = crossnetworkPlay.get()
  let res = []
  foreach (m in squadOnlineMembers.get()) {
    let curPlayerCPState = m.state?.crossnetworkPlay
    if (curPlayerCPState in CrossPlayStateWeight
        && userInfo.get()?.name != m.state?.realnick
        && CrossPlayStateWeight[curPlayerCPState] != CrossPlayStateWeight[myCPState])
      res.append(m)
  }

  return res
})

squadOnlineMembers.subscribe(function(members) {
  if (members.len() == (availableSquadMaxMembers.get() + 1))  
    revokeAllSquadInvites()
})

return freeze(squadState.__merge({
  
  squadOnlineMembers
  unsuitableCrossplayConditionMembers
  chatId
  myExtSquadData

  
  inviteToSquad
  dismissAllOfflineSquadmates
  revokeAllSquadInvites
  leaveSquad
  leaveSquadSilent
  transferSquad
  dismissSquadMember

  removeInvitedSquadmate
  revokeSquadInvite
  acceptSquadInvite
  requestJoinSquad

  
  subsMemberAddedEvent = @(func) notifyMemberAdded.append(func)
  subsMemberRemovedEvent = @(func) notifyMemberRemoved.append(func)
}))
