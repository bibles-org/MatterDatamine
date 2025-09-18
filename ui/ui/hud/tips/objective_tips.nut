from "%ui/hud/tips/tipComponent.nut" import tipCmp

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


let { showUsePhotoCameraTip, showBetterCameraAngleTip, showCameraTargetObscuredTip } = require("%ui/hud/state/hud_objective_photograph_state.nut")


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
  needCharAnimation = false
  textStyle = {
    textColor = errColor
  }

})

let findBetterAngleaTip = tipCmp({
  text = loc("hint/find_better_angle")
  needCharAnimation = false
  textStyle = {
    textColor = warnColor
  }
})


return @() {
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  watch = [showUsePhotoCameraTip, showBetterCameraAngleTip, showCameraTargetObscuredTip]
  children = (showUsePhotoCameraTip.get() ? usePhotoCameraTip :
              (showCameraTargetObscuredTip.get() ? targetObscuredTip :
              (showBetterCameraAngleTip.get() ? findBetterAngleaTip : null)))
}
