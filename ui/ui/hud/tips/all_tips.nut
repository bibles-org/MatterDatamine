from "%ui/ui_library.nut" import *

let downed_tip              = require("%ui/hud/tips/downed_tip.nut")
let extraction_tip          = require("%ui/hud/tips/extraction_tip.nut")
let flashlight_tip          = require("%ui/hud/tips/flashlight_tip.nut")
let gun_jam_tip          = require("%ui/hud/tips/gun_jam_tip.nut")
let onboarding_custom_action_tip  = require("%ui/hud/tips/onboarding_custom_action_tip.nut")
let game_trigger_screen_tip = require("%ui/hud/tips/game_trigger_screen_tip.nut")
let burning_tip             = require("%ui/hud/tips/burning_tip.nut")
let healing_tip             = require("%ui/hud/tips/healing_tip.nut")
let status_tip             = require("%ui/hud/tips/status_tip.nut")
let objective_tips          = require("%ui/hud/tips/objective_tips.nut")
let binoculars_tip          = require("%ui/hud/tips/binoculars_tip.nut")
let hold_brief_tip              = require("%ui/hud/tips/hold_breath_tip.nut")

let { mothmanDivingGrabAbilityPotentialTargetTip,
  mothmanDivingGrabAbilityReleaseTip } = require("%ui/hud/tips/diving_mothman_tip.nut")
require("%ui/hud/tips/dash_ability_tip.nut")
let dash_dash_ability_tip        = require("%ui/hud/tips/dash_dash_ability_tip.nut")
require("%ui/hud/tips/scream_ability_tip.nut")
let { showroomActive } = require("%ui/hud/state/showroom_state.nut")
let echolocationTip = require("%ui/hud/tips/echolocation_ability_tip.nut")

let commonTips = [
  {
    pos = [-sh(30), sh(25)]
    gap = hdpx(2)
    children = [
      status_tip,
      burning_tip,
      flashlight_tip,
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
    ]
  }
  {
    pos = [sh(0), sh(10)]
    gap = hdpx(2)
    children = [
      downed_tip,
      onboarding_custom_action_tip,
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
