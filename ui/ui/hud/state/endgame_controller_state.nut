from "%sqGlob/dasenums.nut" import EndgameControllerState

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


let endgameControllerState = Watched(EndgameControllerState.NONE)
let endgameControllerDebriefingReason = Watched(0)
let endgameControllerDebriefingTeam = Watched(0)
let endgameControllerDebriefingAllowSpectate = Watched(false)
let endgameControllerAutoExit = Watched(false)


ecs.register_es("endgame_controller_ui",
  {
    [["onInit", "onChange"]] = function(_eid, comp) {
      endgameControllerAutoExit.set(comp.endgame_controller__debriefing__autoExit)
      endgameControllerState.set(comp.endgame_controller__state)
      endgameControllerDebriefingReason.set(comp.endgame_controller__debriefing__reason)
      endgameControllerDebriefingTeam.set(comp.endgame_controller__debriefing__team)
      endgameControllerDebriefingAllowSpectate.set(comp.endgame_controller__debriefing__allowSpectate)
    },
    onDestroy = function(...) {
      endgameControllerState.set(0)
      endgameControllerDebriefingReason.set(0)
      endgameControllerDebriefingTeam.set(0)
      endgameControllerDebriefingAllowSpectate.set(false)
    }
  },
  {
    comps_track=[
      ["endgame_controller__state", ecs.TYPE_INT],
      ["endgame_controller__debriefing__reason", ecs.TYPE_INT],
      ["endgame_controller__debriefing__team", ecs.TYPE_INT],
      ["endgame_controller__debriefing__allowSpectate", ecs.TYPE_BOOL],
      ["endgame_controller__debriefing__autoExit", ecs.TYPE_BOOL]
    ]
  }
)


return {
  endgameControllerState
  endgameControllerDebriefingReason
  endgameControllerDebriefingTeam
  endgameControllerDebriefingAllowSpectate
  endgameControllerAutoExit
}
