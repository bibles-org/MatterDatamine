from "%dngscripts/globalState.nut" import nestWatched

from "dagor.debug" import logerr
from "%ui/components/msgbox.nut" import showMsgbox
from "%ui/popup/popupsState.nut" import addPopup, removePopup
from "%ui/components/modalPopupWnd.nut" import removeModalPopup

from "%ui/ui_library.nut" import *

let MAILBOX_MODAL_UID = "mailbox_modal_wnd"
let isMailboxVisible  = nestWatched("isMailboxVisible", false)
let inbox = nestWatched("inbox", [])
let unreadNum = Computed(@() inbox.get().reduce(@(res, notify) notify.isRead ? res : res + 1, 0))
let counter = persist("counter", @() { last = 0 })
let hasUnread = Computed(@() unreadNum.get() > 0)

let getPopupId = @(notify) $"mailbox_{notify.id}"

let subscriptions = {}
function subscribeGroup(actionsGroup, actions) {
  if (actionsGroup in subscriptions || actionsGroup == "") {
    logerr($"Mailbox already has subscriptions on actionsGroup {actionsGroup}")
    return
  }
  subscriptions[actionsGroup] <- actions
}

function removeNotifyById(id) {
  let idx = inbox.get().findindex(@(n) n.id == id)
  if (idx != null) {
    removePopup(getPopupId(inbox.get()[idx]))
    inbox.mutate(@(value) value.remove(idx))
  }
}

function removeNotify(notify) {
  removePopup(getPopupId(notify))
  let idx = inbox.get().indexof(notify)
  if (idx != null)
    inbox.mutate(@(value) value.remove(idx))
  if (inbox.get().len() == 0)
    removeModalPopup(MAILBOX_MODAL_UID)
}

function onNotifyShow(notify) {
  if (!inbox.get().contains(notify))
    return
  let onShow = subscriptions?[notify.actionsGroup].onShow ?? removeNotify
  onShow(notify)
}

function onNotifyRemove(notify) {
  if (!inbox.get().contains(notify))
    return

  let onRemove = subscriptions?[notify.actionsGroup].onRemove
  onRemove?(notify)
  removeNotify(notify)
}

function clearAll() {
  let list = clone inbox.get()
  foreach (notify in list) {
    let onRemove = subscriptions?[notify.actionsGroup].onRemove
    onRemove?(notify)
  }
  inbox.set(inbox.get().filter(@(n) !list.contains(n)))
}

let showPopup = @(notify)
  addPopup({ id = getPopupId(notify), text = notify.text, onClick = @() onNotifyShow(notify) })

let NOTIFICATION_PARAMS = {
  id = null 
  text = ""
  actionsGroup = ""
  isRead = false
  needPopup = false
  styleId = ""
}
function pushNotification(notify = NOTIFICATION_PARAMS) {
  notify = NOTIFICATION_PARAMS.__merge(notify)

  if (notify.id != null)
    removeNotifyById(notify.id)
  else
    notify.id = "_{0}".subst(counter.last++)

  inbox.mutate(@(v) v.append(notify))
  if (notify.needPopup)
    showPopup(notify)
}

function markReadAll() {
  if (hasUnread.get())
    inbox.mutate(@(v) v.each(@(notify) notify.isRead = true))
}

console_register_command(
  function(text){
    counter.last++
    pushNotification({
      id = "m_{0}".subst(counter.last)
      text = text,
      onShow = @(...) showMsgbox({text=text, buttons = [ {text = loc("Yes"), action = @() removeNotifyById("m_{0}".subst(counter.last)) }]}),
    })
  },
  "mailbox.push"
)

return {
  inbox
  hasUnread
  unreadNum
  pushNotification
  removeNotifyById
  removeNotify
  markReadAll
  clearAll
  isMailboxVisible
  MAILBOX_MODAL_UID

  subscribeGroup
  onNotifyRemove
  onNotifyShow
}
