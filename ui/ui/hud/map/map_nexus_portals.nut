import "%dngscripts/ecs.nut" as ecs
import "%ui/hud/map/map_hover_hint.nut" as mapHoverableMarker

from "%ui/ui_library.nut" import *

let portalsEids = Watched({})

ecs.register_es("map_nexus_portals_es", {
  onInit = @(eid, _comp) portalsEids.mutate(@(v) v[eid] <- true)
  onDestroy = @(eid, _comp) portalsEids.mutate(@(v) v.$rawdelete(eid))
}, {
  comps_rq = ["teleportation_portal__groupId"]
})


function mkNexusPortals(eids) {
  let portalsList = eids.keys()
  return portalsList.map(function(eid) {
    return mapHoverableMarker(
      {eid, clampToBorder = false}
      {},
      loc("marker_tooltip/teleport"),
      @(sf) {
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        rendObj = ROBJ_IMAGE
        image = Picture($"ui/skin#portal.svg:{hdpxi(16)}:{hdpxi(16)}:P")
        size = hdpxi(16)
        color = sf.get() & S_HOVER ? Color(255, 255, 0) : Color(255, 255, 255)
      }
    )
  })
}

return {
  nexusPortals = {
    watch = portalsEids
    ctor = @(_) mkNexusPortals(portalsEids.get())
  }
}
