import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let loginState = require("%ui/login/login_state.nut")
let userInfo = require("%sqGlob/userInfo.nut")
let {removeAllMsgboxes} = require("%ui/components/msgbox.nut")
let app = require("app")
let {EventUserLoggedIn, EventUserLoggedOut} = require("gameevents")

require("unlogingHandler.nut")
require("state/customRooms.nut")
require("registerConsoleCmds.nut")

gui_scene.setShutdownHandler(function() {
  removeAllMsgboxes()
})

function on_login() {
  app.switch_scene("") 
  ecs.g_entity_mgr.broadcastEvent(EventUserLoggedIn(userInfo.value.userId, userInfo.value.name))
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
