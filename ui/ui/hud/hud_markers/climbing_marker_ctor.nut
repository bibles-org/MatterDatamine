from "%ui/hud/tips/tipComponent.nut" import tipCmp

from "%ui/ui_library.nut" import *

let { isAiming } = require("%ui/hud/state/crosshair_state_es.nut")

#allow-auto-freeze

function climbing_markers_ctor(eid, info){
  return tipCmp(@() isAiming.get() ? static {watch = isAiming} : {
    watch = isAiming
    inputId = "Human.Jump"
    text = loc(info.text)
    data = {
      eid
      minDistance = 0
      maxDistance = 5
      clampToBorder = true
      worldPos = info.pos
    }
    markerFlags = DngBhv.MARKER_SHOW_ONLY_IN_VIEWPORT
    transform = static {}
  })
}

return {
  climbing_markers_ctor
}