from "net" import get_sync_time
from "math" import ceil
from "%ui/ui_library.nut" import *

let { levelLoaded } = require("%ui/state/appState.nut")

const defaultTimeStep = 0.016666
function mkCountdownTimer(endTimeWatch, curTimeFunc = get_sync_time, step = defaultTimeStep, timeProcess = @(v) v, id = null) {
  let countdownTimer = Watched(0)

  function updateTimer() {
    countdownTimer.set(curTimeFunc())
  }
  updateTimer()

  
  
  let endTimeComputed = Computed(@() endTimeWatch.get())
  
  
  let levelLoadedComputed = Computed(@() levelLoaded.get())

  endTimeComputed.subscribe_with_nasty_disregard_of_frp_update(@(_) updateTimer())
  levelLoadedComputed.subscribe_with_nasty_disregard_of_frp_update(@(_) updateTimer())

  return Computed(function() {
    let cTime = countdownTimer.get()
    let leftTime = max((endTimeComputed.get() ?? 0) - cTime, 0)
    if (leftTime > 0) {
      if (id != null)
        gui_scene.resetTimeout(step, updateTimer, id)
      else
        gui_scene.resetTimeout(step, updateTimer)
    }
    return timeProcess(leftTime)
  })
}

return {
  mkCountdownTimer = @(endTimeWatch, id = null) mkCountdownTimer(endTimeWatch, get_sync_time, defaultTimeStep, @(v) v, id)
  mkCountdownTimerPerSec = @(endTimeWatch, id = null) mkCountdownTimer(endTimeWatch, get_sync_time, 1.0, @(v) ceil(v).tointeger(), id)
}