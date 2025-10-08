from "%ui/hud/tips/tipComponent.nut" import tipCmp

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


const HINT_DURATION = 5
let showEcholocationTip = Watched(false)

ecs.register_es("echolocation_tip_es", {
  onInit = @(_eid, _comp) showEcholocationTip.set(true),
  onDestroy = @(_eid, _comp) showEcholocationTip.set(false)
}, {
  comps_rq=["hero", "active_matter_echolocation_ability"]
})

let echolocationTip = @() tipCmp({
  inputId = "Human.Flashlight"
  text = loc("hint/echolocation_ability")
})

return function() {
  let watch = showEcholocationTip
  if (!showEcholocationTip.get())
    return { watch }
  gui_scene.resetTimeout(HINT_DURATION, @() showEcholocationTip.set(false))
  return {
    watch = showEcholocationTip
    children = echolocationTip()
  }
}