from "%ui/ui_library.nut" import *

let { tipBack, tipText } = require("%ui/hud/tips/tipComponent.nut")

function check_weapon_marker_ctors(eid, info){
  return tipBack.__merge({
    data = {
      eid
      minDistance = 0.0
      maxDistance = 3
      clampToBorder = true
    }
    markerFlags = DngBhv.MARKER_SHOW_ONLY_IN_VIEWPORT
    transform = {}
    animations = [
      { prop=AnimProp.opacity, from=0.0, to=1.0, duration=0.75, play=true, easing=OutCubic }
      { prop=AnimProp.opacity, from=1.0, to=0.0, duration=0.25, playFadeOut=true, easing=OutCubic }
    ]
    children = tipText(loc(info.loc, info.locData?.map(@(v) type(v) == "string" ? loc(v) : v)))
  })
}

return {
  check_weapon_marker_ctors
}
