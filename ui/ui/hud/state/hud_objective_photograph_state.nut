from "%dngscripts/sound_system.nut" import sound_play
from "%sqGlob/dasenums.nut" import BinocularsWatchingState
from "%ui/hud/state/binoculars_state.nut" import binocularsWatchingState
from "dasevents" import EventObjectivePhotographShot

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")

let photographObjectiveActive = Watched(false)
let photographObjectiveInPlace = Watched(false)
let photographObjectiveTargetEid = Watched(ecs.INVALID_ENTITY_ID)
let photographObjectiveDetectedTargetEid = Watched(ecs.INVALID_ENTITY_ID)
let photographObjectiveTargetInView = Watched(false)
let photographObjectiveTraceRatio = Watched(0.0)

let photographObjectiveTargetName = Watched("")

let photographUIActive = Computed(@()
  photographObjectiveActive.get() &&
  (binocularsWatchingState.get() == BinocularsWatchingState.IDLE || binocularsWatchingState.get() == BinocularsWatchingState.IN_FADEOUT)
)

let showUsePhotoCameraTip = Computed(@()
  photographObjectiveTargetEid.get() != ecs.INVALID_ENTITY_ID &&
  binocularsWatchingState.get() == BinocularsWatchingState.IDLE
)

let showBetterCameraAngleTip = Computed(@()
  photographObjectiveDetectedTargetEid.get() != ecs.INVALID_ENTITY_ID &&
  photographObjectiveTargetEid.get() == ecs.INVALID_ENTITY_ID &&
  photographObjectiveTraceRatio.get() == 0
)

let showCameraTargetObscuredTip = Computed(@()
  photographObjectiveDetectedTargetEid.get() != ecs.INVALID_ENTITY_ID &&
  photographObjectiveTargetEid.get() == ecs.INVALID_ENTITY_ID &&
  photographObjectiveTraceRatio.get() > 0
)



ecs.register_es("quest_camera_watching_affect_es",
  {
    [["onInit","onChange"]] = function(_eid, comp){
      if (comp.game_effect__attachedTo == watchedHeroEid.get()){
        photographObjectiveActive.set(true)
        photographObjectiveInPlace.set(comp.quest_camera_watching_affect__inPlace)
        photographObjectiveTargetEid.set(comp.quest_camera_watching_affect__targetEid)
        photographObjectiveDetectedTargetEid.set(comp.quest_camera_watching_affect__detectedTargetEid)
        photographObjectiveTargetInView.set(comp.quest_camera_watching_affect__targetInView)
        photographObjectiveTraceRatio.set(comp.quest_camera_watching_affect__traceRatio)
      }
    },
    function onDestroy(_eid, comp){
      if (comp.game_effect__attachedTo == watchedHeroEid.get()){
        photographObjectiveActive.set(false)
        photographObjectiveInPlace.set(false)
        photographObjectiveTargetEid.set(ecs.INVALID_ENTITY_ID)
        photographObjectiveDetectedTargetEid.set(ecs.INVALID_ENTITY_ID)
        photographObjectiveTargetInView.set(false)
        photographObjectiveTraceRatio.set(0.0)
      }
    }
  },
  {
    comps_ro = [
      ["game_effect__attachedTo", ecs.TYPE_EID],
    ]
    comps_track = [
      ["quest_camera_watching_affect__inPlace", ecs.TYPE_BOOL],
      ["quest_camera_watching_affect__targetEid", ecs.TYPE_EID],
      ["quest_camera_watching_affect__detectedTargetEid", ecs.TYPE_EID],
      ["quest_camera_watching_affect__targetInView", ecs.TYPE_BOOL],
      ["quest_camera_watching_affect__traceRatio", ecs.TYPE_FLOAT],
    ]
  }
  {
    after="quest_camera_watching_affect_update"
  }
)


let photographObjectiveTargetQuery = ecs.SqQuery("photographObjectiveTargetQuery", {
  comps_ro=[
    ["photographing_target__name", ecs.TYPE_STRING]
  ]
})


photographObjectiveTargetEid.subscribe_with_nasty_disregard_of_frp_update(
  function(target_eid) {
    let comp = photographObjectiveTargetQuery.perform(target_eid, @(_eid, comp) comp)
    if (comp != null) {
      photographObjectiveTargetName.set(comp.photographing_target__name)

      sound_play("ui_sounds/menu_enter")
    }
    else {
      photographObjectiveTargetName.set("")
    }
  }
)

ecs.register_es("quest_camera_shot_ui_es",
  {
    [EventObjectivePhotographShot] = function(_eid, _comp){
      anim_start("photograph_flash")
      sound_play("am/ui/camera_shot")
    }
  }
  {
    comps_rq = [["watchedByPlr", ecs.TYPE_EID]]
  }
)


return {
  photographObjectiveActive,
  photographObjectiveInPlace,
  photographObjectiveTargetEid,
  photographObjectiveTargetInView,
  photographObjectiveDetectedTargetEid,
  photographObjectiveTargetName,
  photographObjectiveTraceRatio
  photographUIActive
  showUsePhotoCameraTip
  showBetterCameraAngleTip
  showCameraTargetObscuredTip
}
