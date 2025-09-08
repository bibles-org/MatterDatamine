from "%ui/ui_library.nut" import *
let {ItemDelayedMove} = require("%ui/components/colors.nut")

function moveMarker(stateFlags=0, opacity=1.0) {
  return {
    rendObj = ROBJ_BOX
    size=flex()
    key = stateFlags
    opacity = opacity == 1.0 ? 0.8 : opacity
    animations = (stateFlags & S_ACTIVE) ? [] : [
      { prop=AnimProp.fillColor, from=Color(0,0,0,0), to=ItemDelayedMove, duration=1.2, play=true, loop=true, easing=CosineFull }
    ]
  }
}

function moveMarkerWithTrigger(stateFlags=0, opacity=1.0, trigger="") {
  return {
    rendObj = ROBJ_BOX
    size=flex()
    key = stateFlags
    opacity = opacity == 1.0 ? 0.8 : opacity
    fillColor = Color(0,0,0,0)
    animations = (stateFlags & S_ACTIVE) ? [] : [
      { prop=AnimProp.fillColor, from=Color(0,0,0,0), to=ItemDelayedMove, duration=1.2, play=false, loop=true, trigger, easing=CosineFull }
    ]
  }
}

return {
  moveMarker
  moveMarkerWithTrigger
}
