from "%ui/ui_library.nut" import *

let { tipCmp } = require("%ui/hud/tips/tipComponent.nut")
let { isAiming } = require("%ui/hud/state/crosshair_state_es.nut")

function climbing_markers_ctor(eid, info){
  return tipCmp(@() isAiming.get() ? const {watch = isAiming} : {
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
    transform = const {}
  })
}

return {
  climbing_markers_ctor
}