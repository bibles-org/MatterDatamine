from "%ui/hud/tips/tipComponent.nut" import tipCmp
from "%ui/ui_library.nut" import *
from "net" import get_sync_time

let { isExtracting, timeEnd } = require("%ui/hud/state/extraction_state.nut")
let { isAlive } = require("%ui/hud/state/health_state.nut")
let { isInBattleState } = require("%ui/state/appState.nut")
let { haveRobodog, robodogNear } = require("%ui/hud/state/robodog_state.nut")

let robodogTip = function(showTip, quantityRobodogNear){
  if (!showTip)
    return null

  if (quantityRobodogNear == 0)
    return tipCmp({
        inputId = null
        text = loc("hud/allRobodogWilBeLost")
      })
  else
    return tipCmp({
        inputId = null
        text = loc("hud/extractRobodog", {quantity = quantityRobodogNear})
      })
}

return function() {
  if (!isInBattleState.get())
    return { watch = isInBattleState }
  let time = get_sync_time()
  return {
    watch = [isExtracting, timeEnd, isAlive, isInBattleState, haveRobodog, robodogNear]
    size = SIZE_TO_CONTENT
    children = [
      robodogTip((isExtracting.get() && timeEnd.get() > time && isAlive.get() && haveRobodog.get()), robodogNear.get())
    ]
  }
}