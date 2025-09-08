from "%ui/ui_library.nut" import *
let { mainAction, altAction } = require("%ui/hud/actions.nut")
let { showInteraction } = require("%ui/hud/menus/interaction.nut")

function action_marker_ctors(eid, worldPos){
  let data = {
    eid
    minDistance = 0.0
    maxDistance = 10000
    clampToBorder = true
    worldPos
  }
  return @(){
    data
    markerFlags = DngBhv.MARKER_SHOW_ONLY_IN_VIEWPORT
    transform = {}
    flow = FLOW_VERTICAL
    gap = -fsh(0.6)
    watch = showInteraction
    children = showInteraction.get() ? null : [mainAction, altAction]
  }
}

return {
  action_marker_ctors
}
