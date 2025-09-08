import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let {CONNECTIVITY_OK} = require("connectivity")
let {switch_to_menu_scene} = require("%sqGlob/app_control.nut")
let {showMsgbox, removeMsgboxByUid} = require("%ui/components/msgbox.nut")
let {isLoggedIn} = require("%ui/login/login_state.nut")

let disconnectTimeout = 15.0
let returnToMenuMsgBox = function() {
  let self = callee()
  gui_scene.clearTimer(self)
  showMsgbox({
    uid = "exit_on_disrupted_connection"
    text = loc("exit_on_disrupted_connection")
    buttons = [
      { text=loc("gamemenu/btnExitBattle"), action=switch_to_menu_scene}
      { text=loc("Wait"), isCurrent=true, action=@() gui_scene.setTimeout(disconnectTimeout, self)}
    ]
  })
}

let closeReturnToMenuMsgBox = function() {
  gui_scene.clearTimer(returnToMenuMsgBox)
  removeMsgboxByUid("exit_on_disrupted_connection")
}

isLoggedIn.subscribe(function(logged){
  if (logged)
    return
  closeReturnToMenuMsgBox()
})












let connectivity = mkWatched(persist, "connectivity", CONNECTIVITY_OK)

ecs.register_es("ui_network_ui_es", {
  [["onChange", "onInit"]] = function(_evt, _eid, comp) {
    if (isLoggedIn.get())
      if (connectivity.get() != CONNECTIVITY_OK &&
          comp.ui_state__connectivity == CONNECTIVITY_OK)
        closeReturnToMenuMsgBox()
      else if (connectivity.get() == CONNECTIVITY_OK &&
              comp.ui_state__connectivity != CONNECTIVITY_OK)
        gui_scene.setTimeout(disconnectTimeout, returnToMenuMsgBox)

    connectivity(comp.ui_state__connectivity)
  }
  onDestroy = @(_eid, _comp) connectivity(CONNECTIVITY_OK)
  },
  {
    comps_track = [["ui_state__connectivity", ecs.TYPE_INT]]
  }
)

return {
  connectivity
}
