from "%ui/ui_library.nut" import *

let {barWidth} = require("player_info/style.nut")
let vitalPlayerInfo = require("player_info/vital_player_info.ui.nut")
let jetfuel = require("player_info/jetfuel.nut")
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
      jetfuel
    ]
  }
}

return playerBlock