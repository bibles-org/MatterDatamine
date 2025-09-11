from "%sqGlob/dasenums.nut" import EndgameControllerState

from "%ui/helpers/remap_nick.nut" import remap_nick

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")
let { watchedHeroPlayerEid } = require("%ui/hud/state/watched_hero.nut")
let { localPlayerSpecTarget } = require("%ui/hud/state/local_player.nut")
let { endgameControllerState } = require("%ui/hud/state/endgame_controller_state.nut")

let isSpectator = Computed(@() endgameControllerState.get() == EndgameControllerState.SPECTATING
  && localPlayerSpecTarget.get() != ecs.INVALID_ENTITY_ID
  && localPlayerSpecTarget.get() != controlledHeroEid.get())



let spectatingPlayerName = Computed(@() !isSpectator.get() ? null
  : remap_nick(ecs.obsolete_dbg_get_comp_val(watchedHeroPlayerEid.get(), "name", null)))


return {
  isSpectator
  spectatingPlayerName
  localPlayerSpecTarget
}