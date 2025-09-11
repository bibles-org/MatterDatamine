from "%ui/helpers/timers.nut" import mkCountdownTimerPerSec
from "%ui/helpers/time.nut" import secondsToStringLoc
from "%ui/components/commonComponents.nut" import mkText
from "%ui/fonts_style.nut" import body_txt

from "%ui/ui_library.nut" import *

let { nexusRoundModeRoundDrawAt } = require("%ui/hud/state/nexus_round_mode_state.nut")


let drawTipId = {}
let drawTip = function(){
  if (nexusRoundModeRoundDrawAt.get() <= 0){
    return { watch = [nexusRoundModeRoundDrawAt] }
  }

  let timer = mkCountdownTimerPerSec(nexusRoundModeRoundDrawAt, drawTipId)
  return {
    watch = nexusRoundModeRoundDrawAt
    children = @(){
      watch = timer
      children = mkText($"Draw in {secondsToStringLoc(timer.get().tointeger())}", body_txt)
    }
  }
}

return drawTip
