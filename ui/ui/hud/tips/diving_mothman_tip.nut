from "%ui/hud/tips/tipComponent.nut" import tipCmp

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { mothmanDivingGrabAbilityPotentialTargetEid, mothmanDivingGrabAbilityTargetEid,
  isContolledHeroGrabbedByMothman, mothmanGrabbingReleaseProgress } = require("%ui/hud/state/monster_diving_mothman_state.nut")

let tipColor = Color(100, 140, 200, 110)


let mothmanDivingGrabAbilityPotentialTargetTipRequired = Computed(
  @() mothmanDivingGrabAbilityPotentialTargetEid.get() && !mothmanDivingGrabAbilityTargetEid.get())


let mothmanDivingGrabAbilityPotentialTargetTip = @() {
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  watch = mothmanDivingGrabAbilityPotentialTargetTipRequired
  children = mothmanDivingGrabAbilityPotentialTargetTipRequired.get() ? tipCmp({
    inputId = "MonsterMothman.GrabEnemy"
    text = loc("hint/mothman_diving_grab_ability")
    textStyle = { textColor = tipColor }
  }) : null
}


let mkReleaseProgress = function(progress) {
  let currentProgress = progress.tofloat() * 100
  return {
    rendObj = ROBJ_SOLID
    size = static [ flex(), hdpx(4) ]
    color = Color(0, 0, 0, 50)
    children = [
      {
        rendObj = ROBJ_SOLID
        color = Color(186, 186, 186, 255)
        size = [ pw(min(currentProgress, 100)), flex() ]
      }
    ]
  }
}


let mothmanDivingGrabAbilityReleaseTip = @() {
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  watch = [isContolledHeroGrabbedByMothman, mothmanGrabbingReleaseProgress]
  children = [
      isContolledHeroGrabbedByMothman.get() ? tipCmp({
      inputId = "Human.Jump"
      text = loc("hint/mothman_diving_grab_ability_release")
      textStyle = { textColor = tipColor }
    }) : null
    mkReleaseProgress(mothmanGrabbingReleaseProgress.get())
  ]
}

return {
  mothmanDivingGrabAbilityPotentialTargetTip
  mothmanDivingGrabAbilityReleaseTip
}