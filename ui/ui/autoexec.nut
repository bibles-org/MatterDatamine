from "%ui/components/msgbox.nut" import removeAllMsgboxes
import "app" as app
from "gameevents" import EventUserLoggedIn, EventUserLoggedOut

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let loginState = require("%ui/login/login_state.nut")
let userInfo = require("%sqGlob/userInfo.nut")

require("%ui/unlogingHandler.nut")
require("%ui/state/customRooms.nut")
require("%ui/registerConsoleCmds.nut")

gui_scene.setShutdownHandler(function() {
  removeAllMsgboxes()
})

function on_login() {
  app.switch_scene("") 
  ecs.g_entity_mgr.broadcastEvent(EventUserLoggedIn(userInfo.get().userId, userInfo.get().name))
}

function on_logout() {
  app.switch_scene("gamedata/scenes/login.blk")
  ecs.g_entity_mgr.broadcastEvent(EventUserLoggedOut())
}

loginState.isLoggedIn.subscribe(function (state) {
  if (state)
    on_login()
  else
    on_logout()
})
