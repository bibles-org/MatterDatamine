from "%ui/hud/tips/tipComponent.nut" import tipCmp

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { isAlive } = require("%ui/hud/state/health_state.nut")
let { curWeapon } = require("%ui/hud/state/hero_weapons.nut")

let tip = tipCmp({
  inputId = "Human.Reload"
  text = loc("hint/unjam_weapon")
})

let showGunJammedFlashlight = Computed(@()
  isAlive.get() && (curWeapon.get()?.isJammed ?? false))

return @() {
  watch = showGunJammedFlashlight
  size = SIZE_TO_CONTENT
  children = showGunJammedFlashlight.get() ? tip : null
}