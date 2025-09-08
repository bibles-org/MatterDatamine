import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { remap_nick } = require("%ui/helpers/remap_nick.nut")
let {controlledHeroEid} = require("%ui/hud/state/controlled_hero.nut")
let {watchedHeroPlayerEid} = require("%ui/hud/state/watched_hero.nut")
let {localPlayerSpecTarget} = require("%ui/hud/state/local_player.nut")
let { endgameControllerState } = require("%ui/hud/state/endgame_controller_state.nut")
let { EndgameControllerState } = require("%sqGlob/dasenums.nut")

let isSpectator = Computed(@() endgameControllerState.get() == EndgameControllerState.SPECTATING
  && localPlayerSpecTarget.value != ecs.INVALID_ENTITY_ID
  && localPlayerSpecTarget.value != controlledHeroEid.value)



let spectatingPlayerName = Computed(@() !isSpectator.get() ? null
  : remap_nick(ecs.obsolete_dbg_get_comp_val(watchedHeroPlayerEid.get(), "name", null)))


return {
  isSpectator
  spectatingPlayerName
  localPlayerSpecTarget
}