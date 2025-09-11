from "%ui/ui_library.nut" import *

from "eventbus" import eventbus_send

let { settings, onlineSettingUpdated } = require("%ui/options/onlineSettings.nut")

const refundTimerAlreadyExpiredKey = "refundTimerAlreadyExpired"
const refundTimerKey = "refundTimer"
const timerCallInterval = 60.0
let refundTimerMax = 60 * 60 * 2

function writeToStorage() {
  if (!onlineSettingUpdated.get())
    return
  let currentTime = settings.get()?[refundTimerKey] ?? 0.0
  if (currentTime > refundTimerMax) {
    gui_scene.clearTimer("refundTimerIntervalKey")
    if (!settings.get()?[refundTimerAlreadyExpiredKey]) {

      eventbus_send("profile_server.playedhours", 2)

      settings.mutate(@(v) v[refundTimerAlreadyExpiredKey] <- true)
    }

    return
  }
  settings.mutate(@(v) v[refundTimerKey] <- (currentTime + timerCallInterval))
}

gui_scene.setInterval(timerCallInterval, writeToStorage, "refundTimerIntervalKey")
