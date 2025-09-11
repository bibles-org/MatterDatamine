from "%ui/hud/player_info/affects_widget.nut" import affectsWidget
from "%ui/hud/player_info/hand_stamina.nut" import mkHandStaminaComp
from "%ui/hud/player_info/breath.nut" import mkBreathUI
from "%ui/hud/player_info/heartrate.nut" import mkHeartbeatUI
from "%ui/hud/menus/components/damageModel.nut" import miniBodypartsPanel

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { levelLoaded } = require("%ui/state/appState.nut")
let { visibleHandStamina } = require("%ui/hud/player_info/hand_stamina.nut")
let { breathVisibleWatched } = require("%ui/hud/player_info/breath.nut")
let { isInMonsterState } = require("%ui/hud/state/hero_monster_state.nut")
let hideHud = require("%ui/hud/state/hide_hud.nut")

let watch = freeze([isInMonsterState, hideHud, levelLoaded])

let handStamina = mkHandStaminaComp()
let breath = mkBreathUI()

let indics = freeze({
  flow  = FLOW_HORIZONTAL
  halign = ALIGN_RIGHT
  rendObj  = ROBJ_WORLD_BLUR_PANEL
  gap = hdpx(10)
  children = [
    @() { watch = visibleHandStamina, children = visibleHandStamina.get() ? handStamina : null}
    @(){ watch = breathVisibleWatched children = breathVisibleWatched.get() ? breath : null}
    mkHeartbeatUI()
  ]
})

let bodyparts = miniBodypartsPanel()
let proxyDollBlock = function() {
  if (!isInMonsterState.get() || hideHud.get() || !levelLoaded.get())
    return { watch }
  return {
    watch
    flow = FLOW_VERTICAL
    children = [
      affectsWidget,
      bodyparts,
      indics
    ]
    valign = ALIGN_BOTTOM
    halign = ALIGN_RIGHT
  }
}

return {
  proxyDollBlock
}
