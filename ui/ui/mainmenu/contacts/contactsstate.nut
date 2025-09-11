from "%ui/mainMenu/mailboxState.nut" import pushNotification, removeNotify, subscribeGroup, removeNotifyById
import "%ui/charClient/charClient.nut" as charClient
from "%ui/mainMenu/contacts/contactsWatchLists.nut" import getCrossnetworkChatEnabled
from "%ui/mainMenu/contacts/contact.nut" import updateContact, validateNickNames, getContactNick
from "%ui/matchingClient.nut" import matchingCall
from "matching.api" import matching_listen_notify
from "eventbus" import eventbus_subscribe
from "%ui/components/msgbox.nut" import showMsgbox
from "%ui/mainMenu/contacts/contactPresence.nut" import updatePresences
from "%ui/helpers/platformUtils.nut" import canInterractCrossPlatform
from "%ui/getAppIdsList.nut" import getAppIdsList
from "%ui/restrictionWarnings.nut" import showCrossnetworkChatRestrictionMsgBox
from "matching.errors" import INVALID_USER_ID
from "dagor.time" import get_time_msec
from "%ui/ui_library.nut" import *

let logC = require("%sqGlob/library_logs.nut").with_prefix("[CONTACTS STATE] ")
let { contactsLists } = require("%ui/mainMenu/contacts/contactsWatchLists.nut")
let userInfo = require("%sqGlob/userInfo.nut")
let platform = require("%dngscripts/platform.nut")
let isContactsVisible = mkWatched(persist, "isContactsVisible", false)
let { presences } = require("%ui/mainMenu/contacts/contactPresence.nut")
let { crossnetworkChat, canCrossnetworkChatWithAll, canCrossnetworkChatWithFriends } = require("%ui/state/crossnetwork_state.nut")
let { isInBattleState } = require("%ui/state/appState.nut")


isInBattleState.subscribe_with_nasty_disregard_of_frp_update(function(isInBattle){
  matchingCall("mpresence.set_presence", logC, {isInBattle})
})

const ADD_MODE = "add"
const DEL_MODE = "del"
const APPROVED_MAIL = "approved_mail"
const REQUESTS_TO_ME_MAIL = "requests_to_me_mail"
let getContactsInviteId = @(uid) $"contacts_invite_{uid}"

userInfo.subscribe_with_nasty_disregard_of_frp_update(function(uInfo) {
  if (uInfo?.userIdStr)
    updateContact(uInfo.userIdStr, uInfo.name)
})

const GAME_GROUP_NAME = "Enlisted" 

let searchContactsResults = Watched({})


local fetchContacts = null

function execContactsCharAction(userId, charAction) {
  if (userId == INVALID_USER_ID) {
    logC($"trying to do {charAction} with invalid contact")
    return
  }
  charClient[charAction](userId.tointeger(), GAME_GROUP_NAME, {
    success = function () {
      fetchContacts(null)
    }

    failure = function (err) {
      showMsgbox({
        text = loc(err)
      })
    }
  })
}


let buildFullListName = @(name) $"#{GAME_GROUP_NAME}#{name}"
let markRead = @(mail_id) matchingCall("postbox.notify_read", null, { mail_id })

subscribeGroup(APPROVED_MAIL, {
  function onShow(notify) {
    removeNotify(notify)
    markRead(notify.mailId)
  }
  onRemove = @(notify) markRead(notify.mailId)
})

subscribeGroup(REQUESTS_TO_ME_MAIL, {
  function onShow(notify) {
    removeNotify(notify)
    markRead(notify.mailId)
    let contact = updateContact(notify.fromUid)
    let user = getContactNick(contact)
    if (!canInterractCrossPlatform(user, getCrossnetworkChatEnabled(contact.uid))) {
      showCrossnetworkChatRestrictionMsgBox()
      return
    }

    showMsgbox({
      text = loc("contact/mbox_add_to_friends", { user })
      buttons = [
        { text = loc("Yes")
          action = @() execContactsCharAction(notify.fromUid, "contacts_approve_request")
          isCurrent = true
        }
        { text = loc("No")
          action = @() execContactsCharAction(notify.fromUid, "contacts_reject_request")
          isCancel = true
        }
      ]
    })
  }
  onRemove = @(notify) markRead(notify.mailId)
})

function onNotifyListChanged(body, mailId) {
  let changed = body?.changed
  if (type(changed) != "table")
    return

  let perUidList = {}
  function handleList(changedListObj, mode, listName) {
    if (mode not in changedListObj)
      return
    foreach (uid in changedListObj[mode]) {
      if (!(uid in perUidList))
        perUidList[uid] <- {}
      perUidList[uid][mode] <- { listName }
    }
  }

  foreach (name, _ in contactsLists) {
    let changedListObj = changed?[buildFullListName(name)]
    if (changedListObj == null)
      continue
    console_print(changedListObj)
    handleList(changedListObj, ADD_MODE, name)
    handleList(changedListObj, DEL_MODE, name)
  }

  foreach (uidInt, data in perUidList) {
    let uid = uidInt.tostring()
    let contact = updateContact(uid)
    if (data?[ADD_MODE].listName == "requestsToMe") {
      validateNickNames([contact],
        function() {
          let nick = getContactNick(contact)
          if (canInterractCrossPlatform(nick, canCrossnetworkChatWithAll.get()))
            pushNotification({
              id = getContactsInviteId(uid)
              mailId
              fromUid = uid
              styleId = "primary"
              text = loc("contact/incomingInvitation", { user = nick })
              actionsGroup = REQUESTS_TO_ME_MAIL
            })
        })
    }
    else if (data?[DEL_MODE].listName == "requestsToMe")
      removeNotifyById(getContactsInviteId(uid))
    else if (data?[DEL_MODE].listName == "approved")
      validateNickNames([contact],
        @() pushNotification({
          mailId
          text = loc("contact/removedYouFromFriends", { user = getContactNick(contact) })
          isRead = true
          actionsGroup = APPROVED_MAIL
        }))
  }
}

function updatePresencesByList(new_presences) {
  logC("Update presences by list: new presences:", new_presences)
  let curPresences = presences.get()
  logC("Update presences by list: old presences:", curPresences)
  let updPresences = curPresences
  foreach (p in new_presences)
    updPresences[p.userId] <- p?.update ? (curPresences?[p.userId] ?? {}).__merge(p.presences)
      : p.presences

  logC("Update presences by list: set finale states:", updPresences)
  updatePresences(updPresences)
}

function updateGroup(new_contacts, uids, groupName) {
  let members = new_contacts?[groupName] ?? []
  local hasChanges = false
  let newUids = {}
  let cnChatWatchVal = groupName == buildFullListName("approved")
    ? canCrossnetworkChatWithFriends.get()
    : canCrossnetworkChatWithAll.get()

  foreach (member in members) {
    local { userId, nick } = member
    if (!canInterractCrossPlatform(nick, cnChatWatchVal))
      continue

    userId = userId.tostring()
    hasChanges = hasChanges || userId not in uids.get()
    updateContact(userId, nick) 
    newUids[userId] <- true
  }

  if (hasChanges || uids.get().len() != newUids.len())
    uids.set(newUids)
}

function updateAllLists(new_contacts) {
  foreach (name, uids in contactsLists)
    updateGroup(new_contacts, uids, buildFullListName(name))
}

function onUpdateContactsCb(result) {
  if ("groups" in result) {
    updateAllLists(result.groups)
  }

  if ("presences" in result)
    updatePresencesByList(result.presences)
}

fetchContacts = function (postFetchCb=null) {
  matchingCall("mpresence.reload_contact_list", function(result) {
    onUpdateContactsCb(result)
    if (postFetchCb != null)
      postFetchCb()
  })
}

function searchContactsOnline(nick, callback = null) {
  let request = {
    nick = nick
    maxCount = 100
    ignoreCase = true
    specificAppId = ";".join(getAppIdsList())
  }
  logC(request)
  charClient?.char_request(
    "cln_find_users_by_nick_prefix_json",
    request,
    function (result) {
      if (!(result?.result?.success ?? true)) {
        searchContactsResults.set({})
        if (callback)
          callback()
        return
      }

      let myUserId = userInfo.get()?.userIdStr ?? ""
      let resContacts = {}
      foreach (uidStr, name in result)
        if ((typeof name == "string")
            && uidStr != myUserId
            && uidStr != "") {
          local a
          try {
            a = uidStr.tointeger()
          } catch(e){
            print($"uid is not an integer, uid: {uidStr}")
          }
          if (a == null)
            continue
          updateContact(uidStr, name) 
          resContacts[uidStr] <- true
        }

      searchContactsResults.set(resContacts)
      if (callback)
        callback()
    }
  )
}

matching_listen_notify("mpresence.notify_presence_update")
matching_listen_notify("postbox.notify_mail")

eventbus_subscribe("mpresence.notify_presence_update", onUpdateContactsCb)
eventbus_subscribe("postbox.notify_mail",
  function(mail_obj) {
    if (mail_obj.mail?.subj == "notify_contacts_update") {
      function handleMail() {
        console_print(mail_obj.mail.body)
        onNotifyListChanged(mail_obj.mail.body, mail_obj.mail_id)
      }
      fetchContacts(handleMail)
    }
  })

if (platform.is_sony)
  eventbus_subscribe("playerProfileDialogClosed", @(res) res?.result.wasCanceled ? null : fetchContacts())

crossnetworkChat.subscribe(@(_) fetchContacts())


let { chooseRandom } = require("%sqstd/rand.nut")

let fakeList = Watched([])
fakeList.subscribe(function(f) {
  updatePresencesByList(f)
  updateAllLists({ ["#Enlisted#approved"] = f })
})
function genFake(count) {
  let fake = array(count)
    .map(@(_, i) {
      nick = $"stranger{i}",
      userId = (2000000000 + i).tostring(),
      presences = { online = (i % 2) == 0 }
    })
  let startTime = get_time_msec()
  fakeList.set(fake)
  logC($"Friends update time: {get_time_msec() - startTime}")
}
console_register_command(genFake, "contacts.generate_fake")

function changeFakePresence(count) {
  if (fakeList.get().len() == 0) {
    logC("No fake contacts yet. Generate them first")
    return
  }
  let startTime = get_time_msec()
  for(local i = 0; i < count; i++) {
    let f = chooseRandom(fakeList.get())
    f.presences.online = !f.presences.online
    updatePresences({ [f.userId] = f.presences })
  }
  logC($"{count} friends presence update by separate events time: {get_time_msec() - startTime}")
}
console_register_command(changeFakePresence, "contacts.change_fake_presence")

return {
  searchContactsOnline
  searchContactsResults
  searchContacts = searchContactsOnline
  execContactsCharAction
  isContactsVisible
  contactBlockExtensionCtr = Watched({})
  getContactsInviteId
}