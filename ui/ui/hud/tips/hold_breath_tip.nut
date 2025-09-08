from "%ui/ui_library.nut" import *

let {isHoldBreath} = require("%ui/hud/player_info/breath.nut")
let {isAiming} = require("%ui/hud/state/crosshair_state_es.nut")
let isMachinegunner = require("%ui/hud/state/machinegunner_state.nut")
let {tipCmp} = require("tipComponent.nut")
let {isSpectator} = require("%ui/hud/state/spectator_state.nut")

let tip = tipCmp({
  inputId = "Human.HoldBreath"
  text = loc("tips/hold_breath_to_aim")
  textColor = Color(100,140,200,110)
})

let showHoldBrief = Computed(@()
  isAiming.get()
  && !isMachinegunner.get()
  && !isHoldBreath.get()
  && !isSpectator.get()
)

return @() {
  watch = showHoldBrief
  size = SIZE_TO_CONTENT
  children = showHoldBrief.get() ? tip : null
}
