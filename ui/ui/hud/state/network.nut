from "%sqGlob/app_control.nut" import switch_to_menu_scene
from "connectivity" import CONNECTIVITY_OK
from "%ui/components/msgbox.nut" import showMsgbox, removeMsgboxByUid
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *













let connectivity = mkWatched(persist, "connectivity", CONNECTIVITY_OK)

ecs.register_es("ui_network_ui_es", {
  [["onChange", "onInit"]] = function(_evt, _eid, comp) {
    connectivity.set(comp.ui_state__connectivity)
  }
  onDestroy = @(_eid, _comp) connectivity.set(CONNECTIVITY_OK)
  },
  {
    comps_track = [["ui_state__connectivity", ecs.TYPE_INT]]
  }
)

return {
  connectivity
}
