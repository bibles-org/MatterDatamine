from "%ui/hud/tips/tipComponent.nut" import tipCmp

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { isAlive } = require("%ui/hud/state/health_state.nut")
let { isIndoor } = require("%ui/hud/state/indoor_state_es.nut")
let { hasFlashlight } = require("%ui/hud/state/equipment.nut")
let { get_controlled_hero } = require("%dngscripts/common_queries.nut")
let { isFlashlightTipEnabled } = require("%ui/mainMenu/menus/options/flashlight_tip_option.nut")

let isFlashlighting = Watched(false)

let isFlashLightTipOnCooldown = Watched(false)
let blockFlashlightHintUntilOutdoors = Watched(false)
let forceShowFlashlighTip = Watched(false)

let flashlightTipDurationSeconds = 5.0
let flashlightTipCooldownAfterShowSeconds = 15.0


let onFlashlightTipCooldown = function() {
  isFlashLightTipOnCooldown.set(false)
}

let onShowSwitchOnFlashlightTimeout = function() {
  forceShowFlashlighTip.set(false)
  isFlashLightTipOnCooldown.set(true)
  blockFlashlightHintUntilOutdoors.set(true)
  gui_scene.resetTimeout(flashlightTipCooldownAfterShowSeconds, onFlashlightTipCooldown)
}

isIndoor.subscribe_with_nasty_disregard_of_frp_update(function(value){
  if (!value && blockFlashlightHintUntilOutdoors.get())
    blockFlashlightHintUntilOutdoors.set(false)
})

ecs.register_es("catch_hero_switch_on_flashlight_es", {
  [["onInit", "onDestroy", "onChange"]] = function(_evt,_eid,comp){
      if (get_controlled_hero() == comp["flashlight_spot_light__actorEid"])
        isFlashlighting.set(comp["flashlight_spot_light__isOn"])
    }
  },
  {
    comps_ro = [["flashlight_spot_light__actorEid", ecs.TYPE_EID]]
    comps_track = [["flashlight_spot_light__isOn", ecs.TYPE_BOOL]]
  },
  {tags = "gameClient"}
)

let tip = tipCmp({
  inputId = "Human.Flashlight"
  text = loc("hint/use_flashlight")
})

let showSwitchOnFlashlight = Computed(function() {
  if (!isFlashlightTipEnabled.get())
    return false
  return (isAlive.get()
    && isIndoor.get()
    && !isFlashlighting.get()
    && hasFlashlight.get()
    && !isFlashLightTipOnCooldown.get()
    && !blockFlashlightHintUntilOutdoors.get())
    || forceShowFlashlighTip.get()
})

showSwitchOnFlashlight.subscribe_with_nasty_disregard_of_frp_update(function(value){
  if (value) {
    gui_scene.resetTimeout(flashlightTipDurationSeconds, onShowSwitchOnFlashlightTimeout)
    forceShowFlashlighTip.set(true)
  }
})

return @() {
  watch = showSwitchOnFlashlight
  children = showSwitchOnFlashlight.get() ? tip : null
}