import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let {tipCmp} = require("%ui/hud/tips/tipComponent.nut")
let {dashAbilityActivationTime, dashAbilityDashTime} = require("%ui/hud/state/dash_ability_state.nut")

let showDashDashTip = Watched(false)

let dashTipDurationSeconds = 5.0

let onDashTimeEnd = function() {
  showDashDashTip.set(false)
}

dashAbilityActivationTime.subscribe(function(value){
  if (value != 0){
    showDashDashTip.set(true)
    gui_scene.resetTimeout(dashTipDurationSeconds, onDashTimeEnd)
  }
})

dashAbilityDashTime.subscribe(function(_){
   showDashDashTip.set(false)
})

let dashTip = @() tipCmp({
  inputId = "Human.Jump"
  text = loc("hint/dash_ability_jump_to_dash")
})

return @() {
  watch = [showDashDashTip]
  size = SIZE_TO_CONTENT
  children = showDashDashTip.value ? dashTip() : null
}