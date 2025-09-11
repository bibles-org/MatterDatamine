from "%ui/hud/tips/tipComponent.nut" import tipCmp

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


let { binocularsUseRequest } = require("%ui/hud/state/binoculars_state.nut")

let tipColor = Color(100, 140, 200, 110)

let stopWatchingBinocularsTip = tipCmp({
  inputId = "Human.Aim1"
  text = loc("hint/stop_watching_binoculars")
  textStyle = { textColor = tipColor }
})

return @() {
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  watch = binocularsUseRequest
  children = [
    binocularsUseRequest.get() ? stopWatchingBinocularsTip : null
  ]
}