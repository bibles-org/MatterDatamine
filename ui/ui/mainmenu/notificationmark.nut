from "%ui/ui_library.nut" import *
let { NotificationBg }  = require("%ui/components/colors.nut")
let { tiny_txt } = require("%ui/fonts_style.nut")

let notificationCircleSize = hdpx(18)

let mkNotificationCircle = @(center=[47, 52]) {
  rendObj = ROBJ_VECTOR_CANVAS
  flow = FLOW_HORIZONTAL
  size = flex()
  commands = [
    [VECTOR_COLOR, Color(0, 0, 0, 0)],
    [VECTOR_WIDTH, 0],
    [VECTOR_FILL_COLOR, NotificationBg],
    [VECTOR_ELLIPSE, center[0], center[1], 50, 50]
  ]
}

function mkNotificationMark(notificationWatch, override = {}) {
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
      size = val > 0 ? [ notificationCircleSize, notificationCircleSize ] : [ 0, 0 ]
      children = val ? [
        mkNotificationCircle([47, 52])
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

return {
  mkNotificationMark
  mkNotificationCircle
  notificationCircleSize
}