from "%ui/ui_library.nut" import *

let { tipCmp } = require("%ui/hud/tips/tipComponent.nut")
let { mkCountdownTimerPerSec } = require("%ui/helpers/timers.nut")
let { secondsToStringLoc } = require("%ui/helpers/time.nut")
let { isExtracting, alreadyExtracted, timeEnd, extractionEnableTime } = require("%ui/hud/state/extraction_state.nut")
let { isAlive } = require("%ui/hud/state/health_state.nut")
let { isInBattleState } = require("%ui/state/appState.nut")

let extractionTimer = mkCountdownTimerPerSec(timeEnd)
let extractionEnableTimer = mkCountdownTimerPerSec(extractionEnableTime)

let tip = function(extracting, extracted, timer, alive, extraction_enable_timer){
  if (extracting && timer.tointeger() > 0 && alive)
    return tipCmp({
        inputId = null
        text = "{0}: {1}".subst(loc("tips/extraction", "Extraction in"), secondsToStringLoc(timer.tointeger()))
        needCharAnimation = false
      })
  else if (alive && extraction_enable_timer.tointeger() > 0 && !extracted){
    return tipCmp({
        inputId = null
        text = loc("tips/extraction_enable_time", {time = secondsToStringLoc(extraction_enable_timer.tointeger())})
        needCharAnimation = false
      })
  }
  return null
}

return function() {
  if (!isInBattleState.get())
    return { watch = isInBattleState }
  return {
    watch = [isExtracting, alreadyExtracted, extractionTimer, isAlive, extractionEnableTimer, isInBattleState]
    size = SIZE_TO_CONTENT
    children = tip(isExtracting.value, alreadyExtracted.value, extractionTimer.value, isAlive.value, extractionEnableTimer.get())
  }
}
