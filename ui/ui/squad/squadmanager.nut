from "%ui/ui_library.nut" import *

from "%ui/mainMenu/raid_preparation_window_state.nut" import currentPrimaryContractIds
from "%ui/profile/profileState.nut" import playerProfileCurrentContracts

let {checkMultiplayerPermissions} = require("%ui/permissions/permissions.nut")
let { debounce } = require("%sqstd/timers.nut")
let {nestWatched} = require("%dngscripts/globalState.nut")
let { fabs } = require("math")
let { pushNotification, removeNotifyById, removeNotify, subscribeGroup } = require("%ui/mainMenu/mailboxState.nut")
let popupsState = require("%ui/popup/popupsState.nut")    
let { blockedUids } = require("%ui/mainMenu/contacts/contactsWatchLists.nut")
let userInfo = require("%sqGlob/userInfo.nut")
let { getContactRealnick, getContact, validateNickNames,
      getContactNick, updateContact, contacts } = require("%ui/mainMenu/contacts/contact.nut")
let { onlineStatus, isContactOnline, updateSquadPresences } = require("%ui/mainMenu/contacts/contactPresence.nut")
let MSquadAPI = require("squadAPI.nut")
let {matching_listen_notify} = require("matching.api")
let {showMsgbox} = require("%ui/components/msgbox.nut")
let {join_voice_chat, leave_voice_chat} = require("%ui/voiceChat/voiceState.nut")
let {leaveChat, createChat, joinChat} = require("%ui/mainMenu/chat/chatApi.nut")
let squadState = require("%ui/squad/squadState.nut")
let { squadId, isInSquad, isSquadLeader, isInvitedToSquad, selfUid,
  squadSharedData, squadServerSharedData, squadMembers,
  squadSelfMember, notifyMemberRemoved, notifyMemberAdded
} = squadState

let logSq = require("%sqGlob/library_logs.nut").with_prefix("[SQUAD] ")
let sessionManager = require("%ui/squad/consoleSessionManager.nut")
let { eventbus_send, eventbus_subscribe } = require("eventbus")
let { uid2console } = require("%ui/mainMenu/contacts/consoleUidsRemap.nut")
let { crossnetworkPlay, CrossPlayStateWeight, crossnetworkChat } = require("%ui/state/crossnetwork_state.nut")
let { consoleCompare, canInterractCrossPlatformByCrossplay } = require("%ui/helpers/platformUtils.nut")
let { queueInfo, curQueueParam, availableSquadMaxMembers, doesZoneFitRequirements
} = require("%ui/state/queueState.nut")
let { getFormalLeaderUid, reservedSquad, waitingInvite } = require("%ui/mainMenu/raidAutoSquadState.nut")
let { sound_play } = require("%dngscripts/sound_system.nut")
let { showSquadNotification } = require("%ui/hud/state/in_battle_squad_notification_state.nut")
let { isInBattleState } = require("%ui/state/appState.nut")
let { maxVersionStr } = require("%ui/client_version.nut")
let { get_app_id } = require("app")
let { selectedRaid } = require("%ui/gameModeState.nut")
let { playerStats } = require("%ui/profile/profileState.nut")
let { matchingQueuesMap } = require("%ui/matchingQueues.nut")

const INVITE_ACTION_ID = "squad_invite_action"
const SQUAD_OVERDRAFT = 0

let setOnlineBySquad = @(userId, online) updateSquadPresences({ [userId.tostring()] = online })

let SquadMember = function(userId)  {
  let realnick = getContactRealnick(userId.tostring())
  return {
    userId
    isLeader = squadId.value == userId
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

squadId.subscribe(function(_val) {
  isSquadDataInited(false)
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
  if (squadSelfMember.value == null)
    return 

  let needSend = myDataLocal.value.findindex(@(value, key) !isEqualWithFloat(myDataRemote.value?[key], value)) != null
  if (needSend) {
    logSq("update my data: ", myDataLocal.value)
    MSquadAPI.setMemberData(myDataLocal.value)
  }
}, 0.1)

foreach (w in [squadSelfMember, myDataLocal, myDataRemote])
  w.subscribe(@(_) updateMyData())

function linkVarToMsquad(name, var) {
  myDataLocal.mutate(@(v) v[name] <- var.value)
  var.subscribe(@(_val) myDataLocal.mutate(@(v) v[name] <- var.value))
}

linkVarToMsquad("name", keepref(Computed(@() userInfo.value?.name))) 

let appId = Watched(get_app_id())
let myExtData_ready = mkWatched(persist, "myExtData_ready", false)

let unlockedQueues = keepref(Computed(function() {
  let res = {}
  foreach (queue in matchingQueuesMap.get()) {
    if (queue.enabled && doesZoneFitRequirements(queue?.extraParams.requiresToSelect, playerStats.get()))
      res[queue.queueId] <- true
  }
  return res
}))

let visibleQueues = keepref(Computed(function() {
  let res = {}
  foreach (queue in matchingQueuesMap.get()) {
    if (doesZoneFitRequirements(queue?.extraParams.requiresToShow, playerStats.get()))
      res[queue.queueId] <- true
  }
  return res
}))

let myExtSquadData = {
  inBattle = isInBattleState
  crossnetworkPlay
  version = maxVersionStr
  appId
  selectedRaid
  curQueueParam
  queueInfo
  unlockedQueues
  visibleQueues
  ready = myExtData_ready
}
let myExtDataRW = {ready = myExtData_ready}

foreach(name, var in myExtSquadData) {
  linkVarToMsquad(name, var)
}

function setSelfRemoteData(member_data) {
  myDataRemote(clone member_data)
  foreach (k, v in member_data) {
    if (k in myExtDataRW) {
      myExtDataRW[k].update(v)
    }
  }
}

isInBattleState.subscribe(function(v) {
  if (!v)
    myExtSquadData.ready(false)
})

function reset() {
  squadId(null)
  isInvitedToSquad({})

  if (squadSharedData.squadChat.value != null) {
    squadChatJoined(false)
    let chat_id = squadSharedData.squadChat.value?.chatId
    leaveChat(chat_id, null)
    chatId.set(null)
    if (chat_id)
      leave_voice_chat(voiceChatId(chat_id))
  }

  foreach (w in squadSharedData)
    w.update(null)
  foreach (w in squadServerSharedData)
    w.update(null)

  foreach (member in squadMembers.value) {
    setOnlineBySquad(member.userId, null)
    sendEvent(notifyMemberRemoved, member.userId)
  }
  squadMembers.update({})
  delayedInvites(null)

  myExtSquadData.ready(false)
  myDataRemote({})
}

function setSquadLeader(squadIdVal){
  squadMembers.mutate(function(s){
    foreach (uid, member in s){
      s[uid].isLeader = member.userId == squadIdVal
    }
  })
}
squadId.subscribe(setSquadLeader)
setSquadLeader(squadId.value)

function removeInvitedSquadmate(user_id) {
  if (!(user_id in isInvitedToSquad.value))
    return false
  isInvitedToSquad.mutate(@(value) value.$rawdelete(user_id))
  return true
}

function addInvited(user_id) {
  if (user_id in isInvitedToSquad.value)
    return false
  isInvitedToSquad.mutate(@(value) value[user_id] <- true)
  validateNickNames([getContact(user_id.tostring(), contacts.get())])
  return true
}

function applySharedData(dataTable) {
  if (!isInSquad.value)
    return

  foreach (key, w in squadServerSharedData)
    if (key in dataTable)
      w.update(dataTable[key])

  if (!isSquadLeader.value)
    foreach (key, w in squadSharedData)
      w.update(squadServerSharedData[key].value)
}

function checkDisbandEmptySquad() {
  if (squadMembers.value.len() == 1 && !isInvitedToSquad.value.len())
    MSquadAPI.disbandSquad()
}

function revokeSquadInvite(user_id) {
  if (!removeInvitedSquadmate(user_id))
    return

  MSquadAPI.revokeInvite(user_id)
  checkDisbandEmptySquad()
}

function revokeAllSquadInvites() {
  foreach (uid, _ in isInvitedToSquad.value)
    revokeSquadInvite(uid)
}

function leaveSquadSilent(cb = null) {
  if (!isInSquad.value) {
    cb?()
    return
  }

  if (squadMembers.value.len() == 1)
    revokeAllSquadInvites()

  sessionManager.leave()
  MSquadAPI.leaveSquad({ onAnyResult = function(...) {
    reset()
    cb?()
  }})
}

let showSizePopup = @(text, isError = true)
    popupsState.addPopup({ id = "squadSizePopup", text = text, styleName = isError ? "error" : "" })


let requestMemberData = @(uid, isMe,  isNewMember, cb = @(_res) null)
  MSquadAPI.getMemberData(uid,
    { onSuccess = function(response) {
        let member = squadMembers.value?[uid]
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
  if (squadId.value != squad_info.id)
    return

  foreach (uid in squad_info.members) {
    local isNewMember = false
    let isMe = (uid == selfUid.value)
    if (uid not in squadMembers.value) {
      if (isMe && squad_info.members.len() > availableSquadMaxMembers.value) {
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

  isSquadDataInited(true)
}

local fetchSquadInfo = null

function acceptInviteImpl(invSquadId) {
  if (!checkMultiplayerPermissions()){
    logSq("accept squad invitation is not allowed because of multiplayer permissions")
    return
  }
  MSquadAPI.acceptInvite(invSquadId,
      { onSuccess = function(...) {
          squadId.update(invSquadId)
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
  if (!isInSquad.value)
    acceptInviteImpl(invSquadId)
  else
    leaveSquadSilent(@() acceptInviteImpl(invSquadId))
}

function processSquadInvite(contact) {
  
  if (isInSquad.value && squadId.value == contact.uid) {
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
  if (inviterSquadId == squadId.value)
    removeInvitedSquadmate(invitedMemberId)
  else
    removeNotifyById(getSquadInviteUid(inviterSquadId))
}

function addInviteByContact(inviter) {
  if (inviter.uid == selfUid.value) 
    return

  if (inviter.userId in blockedUids.value) {
    logSq("got squad invite from blacklisted user", inviter)
    MSquadAPI.rejectInvite(inviter.uid)
    return
  }

  if (!canInterractCrossPlatformByCrossplay(inviter.realnick, crossnetworkPlay.value)) {
    logSq($"got squad invite from crossplatform user, is crosschat available: {crossnetworkChat.value}", inviter)
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
  let autoSquadFormalLeader = getFormalLeaderUid(reservedSquad.get())
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

    if (invite_info.invite.id == selfUid.value) {
      if (inviter!=null)
        addInviteByContact(inviter)
    }
    else
      addInvited(invite_info.invite.id)
  }
  else if ("replaces" in invite_info) {
    onInviteRevoked(invite_info.replaces, selfUid.value)
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
          squadId.update(null)
        if (cb)
          cb(result)
        return
      }

      if ("squad" in result) {
        squadId.update(result.squad.id)
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
  let member = squadMembers.value?[user_id]
  if (member == null)
    return

  let data = applyRemoteDataToSquadMember(member, request)
  let isMe = (user_id == selfUid.value)
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

  if (squadMembers.value.len() == availableSquadMaxMembers.value && isInvitedToSquad.value.len() > 0 && isSquadLeader.value) {
    revokeAllSquadInvites()
    showSizePopup(loc("squad/squadIsReadyExtraInvitesRevoken"))
  }
}

function removeMember(member) {
  let userId = member.userId

  if (userId == selfUid.value) {
    if (isInBattleState.get()) {
      showSquadNotification(loc("squad/kickedMsgbox"))
    } else {
      showMsgbox({
          text = loc("squad/kickedMsgbox")
        })
    }
    reset()
  }
  else if (userId in squadMembers.value) {
    let m = squadMembers.value[userId]
    setOnlineBySquad(m.userId, null)
    if (userId in squadMembers.value) 
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
  let member = squadMembers.value?[user_id]
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
  if (!isSquadLeader.value)
    return
  foreach (member in squadMembers.value){
    if (!isContactOnline(member.userId.tostring(), onlineStatus.value))
      MSquadAPI.dismissMember(member.userId)
  }
}

function transferSquad(user_id) {
  let is_leader = isSquadLeader.value
  MSquadAPI.transferSquad(user_id,
  {
    onSuccess = function(_) {
      squadId.update(user_id)
      if (is_leader) {
        sessionManager.updateData(user_id)
      }
    }
  })
}

function createSquadAndDo(afterFunc = null) {
  if (isInSquad.value) {
    logSq($"CreateSquadAndDo: don't create squad, do action")
    afterFunc?()
    return
  }

  if (afterFunc)
    delayedInvites([afterFunc])

  let inviteDelayed = function() {
    if (delayedInvites.value == null)
      return
    foreach (f in delayedInvites.value)
      f()
    delayedInvites(null)
  }

  let cleanupDelayed = @() delayedInvites(null)

  MSquadAPI.createSquad({
    onSuccess = @(_)
      fetchSquadInfo(
        function(r) {
          if (r.error != 0) {
            cleanupDelayed()
            return
          }

          if (sessionManager.isAvailableConsoleSession)
            sessionManager.create(squadId.value, inviteDelayed)
          else
            inviteDelayed()

          createChat(function(chat_resp) {
            if (chat_resp.error == 0) {
              squadChatJoined(true)
              squadSharedData.squadChat({
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
  if (isInSquad.value) {
    if (user_id in squadMembers.value) {
      logSq($"Invite: member {user_id}: already in squad")
      return
    }

    if (squadMembers.value.len() >= availableSquadMaxMembers.value) {
      logSq($"Invite: member {user_id}: squad already full")
      return showSizePopup(loc("squad/popup/squadFull"))
    }

    if (squadMembers.value.len() + isInvitedToSquad.value.len() >= availableSquadMaxMembers.value + SQUAD_OVERDRAFT) {
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
  if (needConsoleInvite && sessionManager.isAvailableConsoleSession && uid2console.value?[user_id.tostring()] != null)
    doInvite = @() sessionManager.invite(user_id, _doInvite)

  if (delayedInvites.value != null) { 
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
      if (w.value != squadServerSharedData[key].value)
        return true
    return false
  }

  if (isSharedDataRequestInProgress || !isSquadLeader.value || !isSharedDataDifferent())
    return

  let thisFunc = callee()
  isSharedDataRequestInProgress = true
  let requestData = squadSharedData.map(@(w) w.value)
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
  if (syncSharedDataTimer || !isSquadLeader.value)
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
      squadId.update(userId)
      fetchSquadInfo()
    },
    onFailure = @(resp) logSq($"Failed to join squad {userId}", resp)
  })
}

function onAcceptMembership(newContact) {
  let { realnick, uid } = newContact
  logSq($"Squad application notification from {uid}/{realnick}")
  if ((consoleCompare.xbox.isFromPlatform(realnick)
      || consoleCompare.psn.isFromPlatform(realnick)) && isSquadLeader.value) {
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
  squadId.update(sid)
  fetchSquadInfo()
}

function onSquadCreated(params) {
  let sid = params?.requestBy?.userId
  logSq($"Squad created, requested by {sid}")
  squadId.update(sid)
  fetchSquadInfo()
}

let msubscribes = {
  ["msquad.notify_invite"] = onInviteNotify,
  ["msquad.notify_invite_revoked"] = function(params) {
    if (params?.squad?.id != null && params?.invite?.id != null)
      onInviteRevoked(params.squad.id, params.invite.id)
  },
  ["msquad.notify_invite_rejected"] = function(params) {
    if (isSquadLeader.value) {
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
    if (!isSquadLeader.value) {
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
    squadId.update(params.userId)
    if (isSquadLeader.value) {
      sessionManager.updateData(params.userId)
    }
  },
  ["msquad.notify_data_changed"] = function(_params){
    if (isInSquad.value)
      fetchSquadInfo()
  },
  ["msquad.notify_member_data_changed"] = function(params) {
    MSquadAPI.getMemberData(params.userId,
        { onSuccess = @(response) onMemberDataChanged(params.userId, response) })
  },
  ["msquad.notify_member_logout"] = function(params) {
    let {userId} = params
    if (userId not in squadMembers.value)
      return
    setOnlineBySquad(userId, false)
    squadMembers.mutate(function(s){
      s[userId].state.ready <- false
    })
  },
  ["msquad.notify_member_login"] = function(params) {
    let member = squadMembers.value?[params.userId]
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

squadSharedData.squadChat.subscribe(function(value) {
  if (value != null) {
    if (!squadChatJoined.value) {
      joinChat(value?.chatId, value?.chatKey,
      function (resp) {
        if (resp.error == 0)
          squadChatJoined(false)
      })
      chatId.set(value?.chatId)
    }
    if (value?.chatId)
      join_voice_chat(voiceChatId(value.chatId))
  }
})

let squadOnlineMembers = Computed(@() squadMembers.value.filter(@(m) isContactOnline(m.userId.tostring(), onlineStatus.value)))

let unsuitableCrossplayConditionMembers = Computed(function() {
  let myCPState = crossnetworkPlay.value
  let res = []
  foreach (m in squadOnlineMembers.value) {
    let curPlayerCPState = m.state?.crossnetworkPlay
    if (curPlayerCPState in CrossPlayStateWeight
        && userInfo.value?.name != m.state?.realnick
        && CrossPlayStateWeight[curPlayerCPState] != CrossPlayStateWeight[myCPState])
      res.append(m)
  }

  return res
})

squadOnlineMembers.subscribe(function(members) {
  if (members.len() == (availableSquadMaxMembers.get() + 1))  
    revokeAllSquadInvites()
})

return squadState.__merge({
  
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
})
