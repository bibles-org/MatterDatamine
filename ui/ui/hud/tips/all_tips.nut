from "%ui/hud/tips/diving_mothman_tip.nut" import mothmanDivingGrabAbilityPotentialTargetTip, mothmanDivingGrabAbilityReleaseTip
import "%ui/hud/tips/downed_tip.nut" as downed_tip
import "%ui/hud/tips/extraction_tip.nut" as extraction_tip
import "%ui/hud/tips/robodog_extraction_tip.nut" as robodog_extraction_tip
import "%ui/hud/tips/flashlight_tip.nut" as flashlight_tip
import "%ui/hud/tips/bipod_tip.nut" as bipod_tip
import "%ui/hud/tips/gun_jam_tip.nut" as gun_jam_tip
import "%ui/hud/tips/game_trigger_screen_tip.nut" as game_trigger_screen_tip
import "%ui/hud/tips/burning_tip.nut" as burning_tip
import "%ui/hud/tips/healing_tip.nut" as healing_tip
import "%ui/hud/tips/status_tip.nut" as status_tip
import "%ui/hud/tips/objective_tips.nut" as objective_tips
import "%ui/hud/tips/binoculars_tip.nut" as binoculars_tip
import "%ui/hud/tips/hold_breath_tip.nut" as hold_brief_tip
import "%ui/hud/tips/dash_dash_ability_tip.nut" as dash_dash_ability_tip
import "%ui/hud/tips/echolocation_ability_tip.nut" as echolocationTip
from "%ui/ui_library.nut" import *

require("%ui/hud/tips/dash_ability_tip.nut")
require("%ui/hud/tips/scream_ability_tip.nut")
let { showroomActive } = require("%ui/hud/state/showroom_state.nut")

let commonTips = [
  {
    pos = [-sh(30), sh(25)]
    gap = hdpx(2)
    children = [
      status_tip,
      burning_tip,
      flashlight_tip,
      bipod_tip,
      gun_jam_tip,
      healing_tip,
      echolocationTip,
      
      
      dash_dash_ability_tip
    ]
  }
  {
    pos = [fsh(30), fsh(25)]
    gap = hdpx(2)
    children = [
      hold_brief_tip
    ]
  }
  {
    pos = [-sh(30), sh(35)]
    gap = hdpx(2)
    children = [
      objective_tips,
      binoculars_tip,
      mothmanDivingGrabAbilityPotentialTargetTip,
      mothmanDivingGrabAbilityReleaseTip,
    ]
  }
  {
    pos = [sh(0), -sh(25)]
    children = [
      extraction_tip,
      robodog_extraction_tip,
    ]
  }
  {
    pos = [sh(0), sh(10)]
    gap = hdpx(2)
    children = [
      downed_tip,
      game_trigger_screen_tip,
    ]
  }
]


let tipsBlock = {
  gap = fsh(1)
  flow = FLOW_VERTICAL
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
}

return @() {
  watch = showroomActive
  size = flex()
  children = showroomActive.get() ? null : commonTips.map(@(tipGroup) tipsBlock.__merge(tipGroup))
}
