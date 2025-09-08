from "%ui/ui_library.nut" import *

let { nexusRoundModeRoundDrawAt } = require("%ui/hud/state/nexus_round_mode_state.nut")
let { mkCountdownTimerPerSec } = require("%ui/helpers/timers.nut")
let { secondsToStringLoc } = require("%ui/helpers/time.nut")
let { mkText } = require("%ui/components/commonComponents.nut")
let { body_txt } = require("%ui/fonts_style.nut")


let drawTip = function(){
  if (nexusRoundModeRoundDrawAt.get() <= 0){
    return { watch = [nexusRoundModeRoundDrawAt] }
  }

  let timer = mkCountdownTimerPerSec(nexusRoundModeRoundDrawAt)
  return {
    watch = nexusRoundModeRoundDrawAt
    children = @(){
      watch = timer
      children = mkText($"Draw in {secondsToStringLoc(timer.get().tointeger())}", body_txt)
    }
  }
}

return drawTip
