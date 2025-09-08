import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { isInMonsterState } = require("%ui/hud/state/hero_monster_state.nut")
let mkStraightCompassStrip = require("%ui/hud/compass/mk_straight_compass_strip.nut")
let hideHud = require("%ui/hud/state/hide_hud.nut")


let proxyCompass = mkStraightCompassStrip([])

function proxyCompassStrip() {
  let watch = [isInMonsterState, hideHud]
  if (!isInMonsterState.get() || hideHud.get())
    return { watch }
  return {
    watch
    rendObj = ROBJ_WORLD_BLUR_PANEL
    margin = hdpx(20)
    children = proxyCompass
  }
}

return {
  proxyCompassStrip
}