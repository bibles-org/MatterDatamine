from "%ui/sony/psn_state.nut" import psn_friendsUpdate, psn_blocked_usersUpdate
from "settings" import get_setting_by_blk_path
import "%ui/sony/auth_friends.nut" as auth_friends
from "%ui/mainMenu/contacts/contactPresence.nut" import updatePresences
from "%ui/mainMenu/contacts/contact.nut" import updateContact, isValidContactNick
from "eventbus" import eventbus_send
import "voiceApi" as voiceApi
import "%ui/sony/profile.nut" as profile
from "%ui/mainMenu/contacts/externalIdsManager.nut" import searchContactByExternalId
from "%ui/mainMenu/contacts/consoleUidsRemap.nut" import updateUids
from "%ui/ui_library.nut" import *

let logpsn = require("%sqGlob/library_logs.nut").with_prefix("[PSN CONTACTS] ")
let pswa = require("%sonyLib/webApi.nut")
let { psn_blocked_users } = require("%ui/sony/psn_state.nut")
let { isLoggedIn } = require("%ui/login/login_state.nut")
let { presences } = require("%ui/mainMenu/contacts/contactPresence.nut")
let { psnApprovedUids, psnBlockedUids } = require("%ui/mainMenu/contacts/contactsWatchLists.nut")
let { console2uid } = require("%ui/mainMenu/contacts/consoleUidsRemap.nut")
let { isInBattleState } = require("%ui/state/appState.nut")



let gameAppId = get_setting_by_blk_path("authGameId") ?? "cr"

function psnConstructFriendsList(psn_friends, contacts) {
  let result = []
  let updPresences = {}
  let afriends = contacts?.friends ?? {}
  let uidsList = {}
  let psn2uid = {}

  foreach (f in psn_friends) {
    let friend = f
    if (friend.accountId in afriends) {
      let currentUid = afriends[friend.accountId]
      if (currentUid == null) {
        logpsn($"Friends mapping error: {friend.accountId} -> {currentUid}")
        continue
      }

      updateContact(currentUid, $"{friend.nick}@psn")
      result.append(currentUid)
      updPresences[currentUid] <- { online = friend.online }
      psn2uid[friend.accountId] <- currentUid
      uidsList[currentUid] <- true
    }
  }

  updateUids(psn2uid)
  updatePresences(updPresences)
  psn_friendsUpdate(result)
  psnApprovedUids.set(uidsList)

  eventbus_send("PSNAuthContactsReceived", null)
}

function psnConstructBlocksList(profile_blocked, psn_contacts, callback) {
  logpsn("psnConstructBlocksList: ", psn_contacts)
  let authBlocked = psn_contacts?.blocklist ?? {}
  let authFriends = psn_contacts?.friends ?? {}
  let users2 = []
  foreach (user in profile_blocked) {
    let accountId = user.accountId
    let userId = authBlocked?[accountId] ?? authFriends?[accountId]
    if (userId != null) {
      user.userId <- userId
      users2.append(user)
    }
  }
  callback(users2)
}

function onGetPsnFriends(pfriends) {
  logpsn("onGetPsnFriends: AUTH_GAME_ID:", gameAppId)
  auth_friends.request_auth_contacts(gameAppId, false, @(contacts) psnConstructFriendsList(pfriends, contacts))
}

function onGetBlockedUsers(users) {
  let unblockedList = psn_blocked_users.get().filter(@(u) users.findvalue(@(u2) u.userId == u2.userId) == null)
  let blockedList = users.filter(@(u) psn_blocked_users.get().findvalue(@(u2) u.userId == u2.userId) == null)

  foreach (u in unblockedList)
    voiceApi.unmute_player_by_uid(u.userId.tointeger())

  foreach (u in blockedList)
    voiceApi.mute_player_by_uid(u.userId.tointeger())

  psn_blocked_usersUpdate(users)

  let unknownPsnUids = []
  let knownUids = []
  let updPresences = {}
  let psn2uid = {}

  let contactsList = []
  foreach (user in users) {
    let u = user
    let c = updateContact(u.userId)
    if (!isValidContactNick(c)) {
      contactsList.append(c)
      unknownPsnUids.append(u.accountId)
    }
    else
      knownUids.append(u.userId)

    updPresences[u.userId] <- { online = false }
    psn2uid[u.accountId] <- u.userId
  }

  updateUids(psn2uid)
  updatePresences(updPresences)

  searchContactByExternalId(unknownPsnUids, function(res) {
    
    if (unknownPsnUids.len() != res.len())
      logpsn("Requested external ids info not full", unknownPsnUids, res)

    let bl = {}
    foreach (uid in knownUids)
      bl[uid] <- true

    foreach (uidStr, _ in res)
      bl[uidStr] <- true

    psnBlockedUids.set(bl)
  })
}

function onPresenceUpdate(data) {
  let accountId = data?.accountId
  if (accountId) {
    let userId = console2uid.get()?[accountId.tostring()]
    if (userId != null && userId in presences.get())
      updatePresences({ [userId] = { online = !(presences.get()[userId]?.online ?? false) }})
  }
}

function onFriendsUpdate(_) {
  profile.request_psn_friends(onGetPsnFriends)
}

function request_blocked_users(callback) {
  profile.request_blocked_users(function(users) {
    auth_friends.request_auth_contacts(gameAppId, false, @(contacts) psnConstructBlocksList(users, contacts, callback))
  })
}

function onBlocklistUpdate(_) {
  request_blocked_users(onGetBlockedUsers)
}

function request_psn_contacts() {
  logpsn("request_psn_contacts: AUTH_GAME_ID: ", gameAppId)
  auth_friends.request_auth_contacts(gameAppId, false, function(contacts) {
    profile.request_blocked_users(@(profile_blocked) psnConstructBlocksList(profile_blocked, contacts, onGetBlockedUsers))
    profile.request_psn_friends(@(psn_friends) psnConstructFriendsList(psn_friends, contacts))
  })
}

function eventSubscribeOutOfBattle(v) {
  if (v) {
    pswa.subscribeToPresenceUpdates(onPresenceUpdate)
    request_psn_contacts()
  }
  else {
    pswa.unsubscribeFromPresenceUpdates(onPresenceUpdate)
  }
}
let needRequestContacts = keepref(Computed(@() !isInBattleState.get() && isLoggedIn.get()))
eventSubscribeOutOfBattle(needRequestContacts.get())
needRequestContacts.subscribe(eventSubscribeOutOfBattle)

function initHandlers() {
  pswa.subscribeToPresenceUpdates(onPresenceUpdate)
  pswa.subscribe.friendslist(onFriendsUpdate)
  pswa.subscribe.blocklist(onBlocklistUpdate)
  request_psn_contacts()
}

function disposeHandlers() {
  pswa.unsubscribeFromPresenceUpdates(onPresenceUpdate)
  pswa.unsubscribe.friendslist(onFriendsUpdate)
  pswa.unsubscribe.blocklist(onBlocklistUpdate)
}

if (isLoggedIn.get())
  initHandlers()

isLoggedIn.subscribe(@(v) v
  ? initHandlers()
  : disposeHandlers())
