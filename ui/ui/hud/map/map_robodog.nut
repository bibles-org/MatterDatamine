import "%dngscripts/ecs.nut" as ecs
import "%ui/hud/map/map_hover_hint.nut" as mapHoverableMarker

from "%ui/helpers/remap_nick.nut" import remap_others
from "%ui/hud/state/robodog_state.nut" import robodogEids
from "%ui/ui_library.nut" import *


function mkRobodogMark(data) {
  let robodogList = data.keys()
  return robodogList.map(function(eid) {
    return mapHoverableMarker(
      {eid, clampToBorder = false}
      {},
      loc(data[eid].status, {nickname = remap_others(data[eid].ownerName)}),
      @(_) {
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        rendObj = ROBJ_IMAGE
        image = Picture($"ui/skin#robodog.svg:{hdpxi(16)}:{hdpxi(16)}:P")
        color = data[eid].color
        size = hdpxi(16)
      }
    )
  })
}

return {
  robodogMarks = {
    watch = robodogEids
    ctor = @(_) mkRobodogMark(robodogEids.get())
  }
}
