from "%dngscripts/globalState.nut" import nestWatched

from "%ui/mainMenu/contacts/contactPresence.nut" import isContactOnline

from "%ui/ui_library.nut" import *

let { onlineStatus } = require("%ui/mainMenu/contacts/contactPresence.nut")
let { canCrossnetworkChatWithAll, canCrossnetworkChatWithFriends } = require("%ui/state/crossnetwork_state.nut")

let isInternalContactsAllowed = true

let predefinedContactsList = ["approved", "myRequests", "requestsToMe", "rejectedByMe", "myBlacklist", "meInBlacklist"]

let contactsLists = predefinedContactsList
  .reduce(function(res, name) {
    console_print($"registerList {name}")
    res[name] <- nestWatched($"contact_list_{name}", {})
    return res
  },
  {})

let approvedUids = isInternalContactsAllowed ? contactsLists.approved : Watched({})
let psnApprovedUids = Watched({})
let xboxApprovedUids = Watched({})
let myRequestsUids = contactsLists.myRequests
let requestsToMeUids = contactsLists.requestsToMe
let rejectedByMeUids = contactsLists.rejectedByMe
let myBlacklistUids = contactsLists.myBlacklist
let psnBlockedUids = Watched({})
let xboxBlockedUids = Watched({})
let xboxMutedUids = Watched({})
let meInBlacklistUids = contactsLists.meInBlacklist

let friendsUids = Computed(@() {}.__update(approvedUids.get(), psnApprovedUids.get(), xboxApprovedUids.get()))
let blockedUids = Computed(@() {}.__update(myBlacklistUids.get(), psnBlockedUids.get(), xboxBlockedUids.get()))

let friendsOnlineUids = Computed(@()
  friendsUids.get().filter(@(_, userId) isContactOnline(userId, onlineStatus.get())).keys()
)

let getCrossnetworkChatEnabled = function(userId) {
  let uid = userId.tostring()
  if (uid in friendsUids.get()){
    log($"user is friend, crosschat with friends {canCrossnetworkChatWithFriends.get()}")
    return canCrossnetworkChatWithFriends.get()
  }
  log($"canCrossnetworkChatWithAll {canCrossnetworkChatWithAll.get()}")
  return canCrossnetworkChatWithAll.get()
}


return freeze({
  contactsLists
  approvedUids
  psnApprovedUids
  xboxApprovedUids
  myRequestsUids
  requestsToMeUids
  rejectedByMeUids
  myBlacklistUids
  psnBlockedUids
  xboxBlockedUids
  xboxMutedUids
  meInBlacklistUids
  friendsUids
  blockedUids
  friendsOnlineUids
  getCrossnetworkChatEnabled
  isInternalContactsAllowed
})