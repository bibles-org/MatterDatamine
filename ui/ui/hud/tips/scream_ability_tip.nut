import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let {tipCmp} = require("%ui/hud/tips/tipComponent.nut")
let {screamAbilitySpawnTime, screamAbilitylastFailedUseTime} = require("%ui/hud/state/scream_ability_state.nut")

let showSpawnTip = Watched(false)
let showFailedUseTip = Watched(false)

let spawnTipDurationSeconds = 15.0
let failedUseTipDurationSeconds = 5.0


let onSpawnTimeEnd = function() {
  showSpawnTip.set(false)
}

screamAbilitySpawnTime.subscribe(function(value){
  if (value != 0){
    showSpawnTip.set(true)
    gui_scene.resetTimeout(spawnTipDurationSeconds, onSpawnTimeEnd)
  }
})

let onFailedUseTimeEnd = function() {
  showFailedUseTip.set(false)
}

screamAbilitylastFailedUseTime.subscribe(function(value){
  if (value != 0){
    showFailedUseTip.set(true)
    showSpawnTip.set(false)
    gui_scene.resetTimeout(failedUseTipDurationSeconds, onFailedUseTimeEnd)
  }
})

let spawnTip = @() tipCmp({
  inputId = "MonsterChanged.SpawnMinion"
  text = loc("hint/on_spawn_with_scream_ability")
})

let failedUseTip = @() tipCmp({
  text = loc("hint/ability_on_cooldown")
})

return @() {
  watch = [showSpawnTip, showFailedUseTip]
  size = SIZE_TO_CONTENT
  children = showFailedUseTip.value ? failedUseTip() : (showSpawnTip.value ? spawnTip() : null)
}