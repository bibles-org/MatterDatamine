from "%ui/ui_library.nut" import *

let {tipCmp} = require("tipComponent.nut")
let hasPainEffect = require("%ui/hud/state/pain_state.nut")
let {isAlive, isDowned} = require("%ui/hud/state/health_state.nut")
let {healingDesc} = require("%ui/hud/state/healing_state.nut")
let {bodyPartsIsDamaged, getMostDamagedPart} = require("%ui/hud/state/human_damage_model_state.nut")


let showHealingTipTime = 60 * 3
let maxDuration = 20
let minDuration = 5

let showHealingTip = Watched(false)
local showHealingTipCallback
local hideHealingTipCallback

function changeShowHealing(state){
  showHealingTip.set(state)
  if (state && !hasPainEffect.get()){
    if (isDowned.get()){
      
      
      gui_scene.resetTimeout(99999.0, hideHealingTipCallback)
      return
    }
    let mostDamagedPart = getMostDamagedPart()
    let hpRatio = mostDamagedPart.hp / mostDamagedPart.maxHp
    let duration = hpRatio > 0.5 ? minDuration : minDuration + ((maxDuration - minDuration) / -0.5 * (hpRatio - 0.5)) 
    gui_scene.resetTimeout(duration, hideHealingTipCallback)
  }
  else if (!state && bodyPartsIsDamaged.get())
    gui_scene.resetTimeout(showHealingTipTime, showHealingTipCallback)
}

hideHealingTipCallback = function(){
  if (hasPainEffect.get())
    return
  changeShowHealing(false)
}

showHealingTipCallback = @() changeShowHealing(true)

hasPainEffect.subscribe(function(state){
  if (isDowned.get())
    return
  if (state && !bodyPartsIsDamaged.get())
    return
  gui_scene.clearTimer(hideHealingTipCallback)
  changeShowHealing(state)
})

bodyPartsIsDamaged.subscribe(function(state){
  if (isDowned.get())
    return
  if (!state){
    gui_scene.clearTimer(hideHealingTipCallback)
    gui_scene.clearTimer(showHealingTipCallback)
    changeShowHealing(false)
  }
})

isDowned.subscribe(function(state){
  gui_scene.clearTimer(hideHealingTipCallback)
  changeShowHealing(state)
})

function mkHealingTip(){
  if (healingDesc.get() == null)
    return null
  return tipCmp({
    inputId = "Human.FastHeal"
    text = loc(healingDesc.get())
  })
}

return function(){
  return {
    watch = [healingDesc, showHealingTip, isAlive]
    size = SIZE_TO_CONTENT
    children = showHealingTip.get() && isAlive.get() ? mkHealingTip() : null
  }
}