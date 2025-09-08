from "%ui/ui_library.nut" import *

let { get_sync_time } = require("net")
let { ceil } = require("math")
let { levelLoaded } = require("%ui/state/appState.nut")

const defaultTimeStep = 0.016666
function mkCountdownTimer(endTimeWatch, curTimeFunc = get_sync_time, step = defaultTimeStep, timeProcess = @(v) v) {
  let countdownTimer = Watched(0)

  function updateTimer() {
    countdownTimer.set(curTimeFunc())
  }
  updateTimer()

  
  
  let endTimeComputed = Computed(@() endTimeWatch.get())
  
  
  let levelLoadedComputed = Computed(@() levelLoaded.get())

  endTimeComputed.subscribe(@(_) updateTimer())
  levelLoadedComputed.subscribe(@(_) updateTimer())

  return Computed(function() {
    let cTime = countdownTimer.get()
    let leftTime = max((endTimeComputed.get() ?? 0) - cTime, 0)
    if (leftTime > 0)
      gui_scene.resetTimeout(step, updateTimer)
    return timeProcess(leftTime)
  })
}

return {
  mkCountdownTimer
  mkCountdownTimerPerSec = @(endTimeWatch) mkCountdownTimer(endTimeWatch, get_sync_time, 1.0, @(v) ceil(v).tointeger())
}