import "%ui/hud/map/map_hover_hint.nut" as mapHoverableMarker
from "%ui/hud/tips/nexus_header_components.nut" import mkBeacon
from "%ui/components/commonComponents.nut" import mkText
from "%ui/components/colors.nut" import ModalBgTint

from "%ui/ui_library.nut" import *

let { nexusBeacons, nexusBeaconEids } = require("%ui/hud/state/nexus_mode_state.nut")

function mkNexusBeaconMarkers(eids, stateWatched) {
  if (eids == null || eids.len() <= 0)
    return null
  let sortedBeacons = eids.sort(@(a, b) a <=> b)
  let beaconsDataWatches = sortedBeacons.map(@(beaconId) Computed(@() stateWatched.get()?[beaconId] ?? []))
  return beaconsDataWatches.map(function(beaconData) {
    return mapHoverableMarker(
      {worldPos = beaconData.get().pos, clampToBorder = true}
      {},
      loc("marker_tooltip/capturePoint"),
      @(sf) {
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        children = [
          mkBeacon(beaconData, sf)
          {
            padding = static [0, hdpx(4), 0, hdpx(4)]
            pos = static [0, hdpx(26)]
            halign = ALIGN_CENTER
            children = mkText(loc(beaconData.get().name))
            rendObj = ROBJ_SOLID
            color = ModalBgTint
          }
        ]
      }
    )
  })
}

return {
  mkNexusBeaconMarkers,
  nexusBeacons = {
    watch = nexusBeaconEids
    ctor = @(_) mkNexusBeaconMarkers(nexusBeaconEids.get(), nexusBeacons)
  }
}
