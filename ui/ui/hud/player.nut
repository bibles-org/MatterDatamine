from "%ui/hud/player_info/style.nut" import barWidth
import "%ui/hud/player_info/jetfuel.nut" as jetfuel

from "%ui/ui_library.nut" import *

let vehicleWeapons = require("%ui/hud/vehicle_weapons.nut")
let vitalPlayerInfo = require("%ui/hud/player_info/vital_player_info.ui.nut")
let { isInMonsterState } = require("%ui/hud/state/hero_monster_state.nut")


function playerBlock() {
  let watch = [isInMonsterState]
  if (isInMonsterState.get())
    return { watch }
  return {
    watch
    flow = FLOW_VERTICAL
    halign = ALIGN_RIGHT
    size = [barWidth, SIZE_TO_CONTENT]
    gap = fsh(0.5)
    children = [
      vitalPlayerInfo,
      vehicleWeapons,
      jetfuel
    ]
  }
}

return playerBlock