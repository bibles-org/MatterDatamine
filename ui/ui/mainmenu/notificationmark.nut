from "%ui/components/colors.nut" import NotificationBg
from "%ui/fonts_style.nut" import tiny_txt

from "%ui/ui_library.nut" import *

let notificationCircleSize = hdpx(18)

let mkNotificationCircle = @[pure](center=static [47, 52], fillColor=NotificationBg ) {
  rendObj = ROBJ_VECTOR_CANVAS
  flow = FLOW_HORIZONTAL
  size = flex()
  commands = [
    static [VECTOR_COLOR, Color(0, 0, 0, 0)],
    static [VECTOR_WIDTH, 0],
    [VECTOR_FILL_COLOR, fillColor],
    [VECTOR_ELLIPSE, center[0], center[1], 50, 50]
  ]
}

function [pure] mkNotificationMark(notificationWatch, override = {}) {
  return function() {
    let val = notificationWatch.get()?.notificationsCount != null ? notificationWatch.get().notificationsCount : notificationWatch.get()
    let notificationsType = notificationWatch.get()?.notificationsType ?? "reward"
    let isReward = notificationsType == "reward"
    return {
      margin = val > 0 ? hdpx(2) : 0
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      vplace = ALIGN_CENTER
      hplace = ALIGN_CENTER
      watch = notificationWatch
      size = val > 0 ? notificationCircleSize : 0
      children = val ? [
        static mkNotificationCircle([47, 52])
        isReward ? {
          vplace = ALIGN_CENTER
          hplace = ALIGN_CENTER
          rendObj = ROBJ_TEXT
          text = val
          color = Color(0,0,0)
        }.__update(tiny_txt) : null
      ] : null
    }.__update(override)
  }
}

return freeze({
  mkNotificationMark
  mkNotificationCircle
  notificationCircleSize
})