let { Watched, gui_scene } = require("%ui/ui_library.nut")


let notificationText = Watched(null)

let clearNotification = @() notificationText.set(null)

let showSquadNotification = function(notification_text) {
  notificationText.set(notification_text)
  gui_scene.resetTimeout(7, clearNotification)
}

return {
  notificationText,
  showSquadNotification
}
