from "%dngscripts/globalState.nut" import nestWatched
from "%dngscripts/sound_system.nut" import sound_play

from "%sqstd/string.nut" import hexStringToInt

from "app" import exit_game
from "eventbus" import eventbus_subscribe, eventbus_send
from "%ui/notifications/matchingNotifications.nut" import subscribe
from "%ui/state/matchingUtils.nut" import get_matching_utc_time
from "%ui/components/msgbox.nut" import showMsgbox, removeMsgboxByUid
from "%ui/hud/state/chat.nut" import pushSystemMsg
from "%ui/components/colors.nut" import RedWarningColor
import "%ui/components/colorize.nut" as colorize

from "%ui/ui_library.nut" import *


const DEF_LIFE_TIME = 300

let shown = nestWatched("shown", {})
let serviceNotificationsList = nestWatched("serviceNotificationsList", [])
serviceNotificationsList.subscribe(@(_v) sound_play("ui_sounds/notification"))

function filterOldAndStartTimer() {
  let curTime = get_matching_utc_time()
  let newList = serviceNotificationsList.get().filter(@(n) n.till_timestamp > curTime)
  if (newList.len() != serviceNotificationsList.get().len())
    serviceNotificationsList.set(newList)

  let nextNotifyTime = newList.reduce(@(res, n) res <= 0 ? n.till_timestamp : min(res, n.till_timestamp), 0)
  if (nextNotifyTime > 0)
    gui_scene.resetTimeout(nextNotifyTime - curTime, filterOldAndStartTimer)
}
filterOldAndStartTimer()

let pushNewNotifications = @(notifications)
  notifications.each(function(notify) {
    let { message, uid } = notify
    if (uid in shown)
      return
    shown.mutate(@(v) v[uid] <- true)
    pushSystemMsg(message)
  })

pushNewNotifications(serviceNotificationsList.get())
serviceNotificationsList.subscribe(pushNewNotifications)

let handlers = {
  function show_message_box(_ev, params) {
    local { message = null, logout_on_close = false } = params
    if (message == null)
      return
    showMsgbox({
      uid = message
      text = message
      onClose = logout_on_close ? exit_game
        : @() eventbus_send("webHandlers.removeMsg", { message })
    })
  }
  function show_chat_message(_ev, params) {
    local { message = null, till_timestamp = 0, color = 0 } = params
    if (message == null || (till_timestamp > 0 && till_timestamp <= get_matching_utc_time()))
      return

    if (type(color) == "string")
      color = hexStringToInt(color)
    message = colorize(color == 0 ? RedWarningColor : color | 0xFF000000, message)
    if (till_timestamp <= 0)
      till_timestamp = get_matching_utc_time() + DEF_LIFE_TIME
    serviceNotificationsList.mutate(@(v) v.append({ message, till_timestamp, uid = $"{message}_{till_timestamp}"}))
    filterOldAndStartTimer()
  }
}

subscribe("web-service", @(ev) handlers?[ev?.func](ev, ev?.params ?? {}))
eventbus_subscribe("webHandlers.removeMsg", @(msg) removeMsgboxByUid(msg.message))
