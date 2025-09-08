import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { tipCmp } = require("%ui/hud/tips/tipComponent.nut")

let { photographObjectiveTargetEid, photographObjectiveTraceRatio,
    photographObjectiveDetectedTargetEid } = require("%ui/hud/state/hud_objective_photograph_state.nut")
let { binocularsWatchingState } = require("%ui/hud/state/binoculars_state.nut")
let { BinocularsWatchingState } = require("%sqGlob/dasenums.nut")


let tipColor = Color(100, 140, 200, 110)
let warnColor = Color(170, 170, 100, 110)
let errColor = Color(200, 140, 100, 110)

let usePhotoCameraTip = tipCmp({
  inputId = "Human.Shoot"
  text = loc("hint/use_photocamera")
  textColor = tipColor
})

let targetObscuredTip = tipCmp({
  text = loc("hint/obscured_photo_target")
  textColor = errColor
})

let findBetterAngleaTip = tipCmp({
  text = loc("hint/find_better_angle")
  textColor = warnColor
})

let showUsePhotoCameraTip = Computed(@()
  photographObjectiveTargetEid.get() != ecs.INVALID_ENTITY_ID &&
  binocularsWatchingState.get() == BinocularsWatchingState.IDLE
)

let showBetterCameraAngleTip = Computed(@()
  photographObjectiveDetectedTargetEid.get() != ecs.INVALID_ENTITY_ID &&
  photographObjectiveTargetEid.get() == ecs.INVALID_ENTITY_ID &&
  photographObjectiveTraceRatio.get() > 0
)

let showCameraTargetObscuredTip = Computed(@()
  photographObjectiveDetectedTargetEid.get() != ecs.INVALID_ENTITY_ID &&
  photographObjectiveTargetEid.get() == ecs.INVALID_ENTITY_ID &&
  photographObjectiveTraceRatio.get() == 0
)

return @() {
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  watch = [showUsePhotoCameraTip, showBetterCameraAngleTip, showCameraTargetObscuredTip]
  children = (showUsePhotoCameraTip.value ? usePhotoCameraTip :
              (showCameraTargetObscuredTip.value ? targetObscuredTip :
              (showBetterCameraAngleTip.value ? findBetterAngleaTip : null)))
}