import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { get_controlled_hero } = require("%dngscripts/common_queries.nut")


let mothmanDivingGrabAbilityPotentialTargetEid = Watched(0)
let mothmanDivingGrabAbilityTargetEid = Watched(0)

let isContolledHeroGrabbedByMothman = Watched(false)
let mothmanGrabbingReleaseProgress = Watched(0.0)


ecs.register_es("mothman_diving_grab_ability_ui_es",
  {
    [["onChange", "onInit"]] = function(_eid, comp) {
      mothmanDivingGrabAbilityPotentialTargetEid.set(comp["mothman_diving_grab_ability__potentialTargetEid"])
      mothmanDivingGrabAbilityTargetEid.set(comp["mothman_diving_grab_ability__targetEid"])
    }
    onDestroy = function(...) {
      mothmanDivingGrabAbilityPotentialTargetEid.set(0)
      mothmanDivingGrabAbilityTargetEid.set(0)
    }
  },
  {
    comps_track = [
      ["mothman_diving_grab_ability__potentialTargetEid", ecs.TYPE_EID],
      ["mothman_diving_grab_ability__targetEid", ecs.TYPE_EID],
    ]
    comps_rq=["watchedByPlr"]
  }
)


ecs.register_es("mothman_diving_grab_ability_target_affect_ui_es",
  {
    [["onChange", "onInit"]] = function(_eid, comp) {
      if (comp.game_effect__attachedTo == get_controlled_hero()) {
        isContolledHeroGrabbedByMothman.set(true)
        mothmanGrabbingReleaseProgress.set(comp.mothman_diving_grab_ability_target_affect__releaseProgress)
      }
    }
    onDestroy = function(_eid, comp) {
      if (comp.game_effect__attachedTo == get_controlled_hero()) {
        isContolledHeroGrabbedByMothman.set(false)
        mothmanGrabbingReleaseProgress.set(0.0)
      }
    }
  },
  {
    comps_track = [
      ["mothman_diving_grab_ability_target_affect__releaseProgress", ecs.TYPE_FLOAT]
    ]
    comps_ro=[
      ["game_effect__attachedTo", ecs.TYPE_EID]
    ]
    comps_rq=[
      ["mothman_diving_grab_ability_target_affect", ecs.TYPE_TAG]
    ]
  }
)


return {
  mothmanDivingGrabAbilityPotentialTargetEid
  mothmanDivingGrabAbilityTargetEid
  isContolledHeroGrabbedByMothman
  mothmanGrabbingReleaseProgress
}
