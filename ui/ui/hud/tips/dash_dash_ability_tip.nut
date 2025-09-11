from "%ui/hud/tips/tipComponent.nut" import tipCmp

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { dashAbilityActivationTime, dashAbilityDashTime } = require("%ui/hud/state/dash_ability_state.nut")

let showDashDashTip = Watched(false)

let dashTipDurationSeconds = 5.0

let onDashTimeEnd = function() {
  showDashDashTip.set(false)
}

dashAbilityActivationTime.subscribe_with_nasty_disregard_of_frp_update(function(value){
  if (value != 0){
    showDashDashTip.set(true)
    gui_scene.resetTimeout(dashTipDurationSeconds, onDashTimeEnd)
  }
})

dashAbilityDashTime.subscribe_with_nasty_disregard_of_frp_update(function(_){
   showDashDashTip.set(false)
})

let dashTip = @() tipCmp({
  inputId = "Human.Jump"
  text = loc("hint/dash_ability_jump_to_dash")
})

return @() {
  watch = [showDashDashTip]
  size = SIZE_TO_CONTENT
  children = showDashDashTip.get() ? dashTip() : null
}