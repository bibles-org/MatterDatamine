from "%ui/hud/state/entity_use_state.nut" import calcItemUseProgress

from "%ui/hud/tips/continuous_action_tip.nut" import mkContinuousActionTip

from "%ui/ui_library.nut" import *

let { curTime } = require("%ui/hud/state/time_state.nut")
let { entityUseEnd, entityUseStart, entityToUseTemplate, entityToUseOverrideLongUseHint } = require("%ui/hud/state/entity_use_state.nut")
let { isAlive } = require("%ui/hud/state/health_state.nut")

let mkProgressLine = function() {
  let timeLeft = Computed(@() entityUseEnd.get() - curTime.get())
  let progressProportion = Computed(@() calcItemUseProgress(curTime.get()) / 100.0)

  return mkContinuousActionTip(progressProportion, timeLeft, entityToUseTemplate, entityToUseOverrideLongUseHint)
}

let showEntityUsage = Computed(function() {
  return entityUseEnd.get() > 0
         && isAlive.get()
         && (entityUseEnd.get() - entityUseStart.get() < 100000.0)
         && (entityUseEnd.get() - curTime.get() > 0)
})

return function() {
  return {
    watch = showEntityUsage
    margin = static [0, 0, hdpx(30), 0]
   children = showEntityUsage.get() ? mkProgressLine() : null
  }
}
