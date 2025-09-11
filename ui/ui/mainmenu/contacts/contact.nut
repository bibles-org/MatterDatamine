from "%dngscripts/globalState.nut" import nestWatched

from "%ui/helpers/remap_nick.nut" import remap_others
from "%ui/netUtils.nut" import request_nick_by_uid_batch

from "%ui/ui_library.nut" import *

let invalidNickName = "????????"
let contacts = nestWatched("contacts", {})



function updateContact(userIdStr, name=invalidNickName) {
  let uidStr = userIdStr.tostring()
  if (uidStr not in contacts.get()) {
    let contact = { userId = uidStr, uid = userIdStr.tointeger(), realnick = name }
    contacts.mutate(@(v) v[uidStr] <- contact)
    return contact
  }
  let contact = contacts.get()[uidStr]
  if (name != invalidNickName && name != contact.realnick)
    contact.realnick = name
  contacts.mutate(@(v) v[uidStr] <- contact)
  return contact
}

let isValidContactNick = @(c) c.realnick != invalidNickName

let requestedUids = {}


function validateNickNames(contactsContainer, finish_cb = null) {
  let requestContacts = []
  foreach (c in contactsContainer) {
    if (!isValidContactNick(c) && !(c.uid in requestedUids)) {
      requestContacts.append(c)
      requestedUids[c.uid] <- true
    }
  }
  if (!requestContacts.len()) {
    if (finish_cb)
      finish_cb()
    return
  }

  request_nick_by_uid_batch(requestContacts.map(@(c) c.uid),
    function(result) {
      foreach (contact in requestContacts) {
        let { userId, uid } = contact
        let name = result?[userId]
        if (name)
          updateContact(userId, name)
        if (uid in requestedUids)
          requestedUids.$rawdelete(uid)
      }
      if (finish_cb)
        finish_cb()
    })
}

let nickContactsCache = persist("nickContactsCache", @() {})
function getContactNick(contact) {
  let uid = contact.uid ?? contact?.uid
  let nick = contact.realnick ?? contact?.realnick ?? invalidNickName

  if (uid == null)
    remap_others(nick)

  if (uid in nickContactsCache)
    return nickContactsCache[uid]

  if (nick != invalidNickName) {
    nickContactsCache[uid] <- remap_others(nick)
    return nickContactsCache[uid]
  }
  return invalidNickName
}

let getContact = @(userId, contactsVal) contactsVal?[userId] ?? updateContact(userId)

return {
  contacts
  getContactRealnick = @(userId) getContact(userId, contacts.get()).realnick
  getContact
  updateContact
  validateNickNames
  getContactNick
  isValidContactNick
}
