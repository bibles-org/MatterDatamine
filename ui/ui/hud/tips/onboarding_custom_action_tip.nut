import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let {tipCmp} = require("%ui/hud/tips/tipComponent.nut")

local hintDelay = 1.0
let isLookingAroundInOnboarding = Watched(false)
let lookAroundContinueInputId = Watched(null)
let lookAroundContinueHintText = Watched(null)

let doShowTip = Watched(false)

let enableTip = @() doShowTip.set(true)

isLookingAroundInOnboarding.subscribe(function(value){
  if (!value) {
    doShowTip.set(false)
    gui_scene.clearTimer(enableTip)
    return
  }

  gui_scene.resetTimeout(hintDelay, enableTip)
})

let tip = @() tipCmp({
  inputId = lookAroundContinueInputId.get(),
  text = loc(lookAroundContinueHintText.get())
})

function resetHintState() {
  isLookingAroundInOnboarding.set(false)
  lookAroundContinueInputId.set(null)
  lookAroundContinueHintText.set(null)
}

function setHintState(comp) {
  if (!comp.onboarding_custom_action__showHint) {
    resetHintState()
    return
  }
  hintDelay = comp.onboarding_custom_action__hintDelay
  isLookingAroundInOnboarding.set(true)
  lookAroundContinueInputId.set(comp.onboarding_custom_action__name)
  lookAroundContinueHintText.set(comp.onboarding_custom_action__hintText)
}

ecs.register_es("track_onboarding_look_around",
  {
    [["onInit", "onChange"]] = @(_evt, _eid, comp) setHintState(comp)
    onDestroy = @(...) resetHintState()
  }
  {
    comps_ro = [
      ["onboarding_custom_action__name", ecs.TYPE_STRING],
      ["onboarding_custom_action__hintText", ecs.TYPE_STRING],
      ["onboarding_custom_action__hintDelay", ecs.TYPE_FLOAT]
    ]
    comps_track = [["onboarding_custom_action__showHint", ecs.TYPE_BOOL]]
  },
  { tags = "gameClient", after="onboarding_show_action_hint_init" }
)

return @() {
  watch = doShowTip
  size = SIZE_TO_CONTENT
  children = doShowTip.get() ? tip() : null
}
