import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let {tipCmp}        = require("%ui/hud/tips/tipComponent.nut")
let {dashAbilitySpawnTime, dashAbilitylastFailedUseTime, dashAbilityAmCost}       = require("%ui/hud/state/dash_ability_state.nut")
let { heroAmValue } = require("%ui/hud/state/am_storage_state.nut")

let showSpawnTip = Watched(false)
let showFailedUseTip = Watched(false)

let spawnTipDurationSeconds = 15.0
let failedUseTipDurationSeconds = 3.0


let onSpawnTimeEnd = function() {
  showSpawnTip.set(false)
}

dashAbilitySpawnTime.subscribe(function(value){
  if (value != 0){
    showSpawnTip.set(true)
    gui_scene.resetTimeout(spawnTipDurationSeconds, onSpawnTimeEnd)
  }
})

let onFailedUseTimeEnd = function() {
  showFailedUseTip.set(false)
}

dashAbilitylastFailedUseTime.subscribe(function(value){
  if (value != 0){
    showFailedUseTip.set(true)
    showSpawnTip.set(false)
    gui_scene.resetTimeout(failedUseTipDurationSeconds, onFailedUseTimeEnd)
  }
})

let spawnTip = @() tipCmp({
  inputId = "MonsterChanged.Dash"
  text = dashAbilityAmCost.value > 0 ? loc("hint/on_spawn_with_dash_ability", {ability_am_cost=dashAbilityAmCost.value}) :
      loc("hint/on_spawn_with_free_dash_ability")
})

let failedUseTip = @() tipCmp({
  text = loc("hint/dash_ability_not_enough_am", {am=heroAmValue.value, ability_am_cost=dashAbilityAmCost.value})
})

return @() {
  watch = [showSpawnTip, showFailedUseTip, dashAbilityAmCost]
  size = SIZE_TO_CONTENT
  children = showFailedUseTip.value ? failedUseTip() : (showSpawnTip.value ? spawnTip() : null)
}