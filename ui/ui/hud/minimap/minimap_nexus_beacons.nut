from "%ui/ui_library.nut" import *

let { nexusBeacons, nexusBeaconEids } = require("%ui/hud/state/nexus_mode_state.nut")
let minimapHoverableMarker = require("minimap_hover_hint.nut")
let { mkBeacon } = require("%ui/hud/tips/nexus_round_mode_header.nut")
let { mkText } = require("%ui/components/commonComponents.nut")
let { ModalBgTint } = require("%ui/components/colors.nut")

function mkNexusBeaconMarkers(eids, stateWatched) {
  if (eids == null || eids.len() <= 0)
    return null
  let sortedBeacons = eids.sort(@(a, b) a <=> b)
  let beaconsDataWatches = sortedBeacons.map(@(beaconId) Computed(@() stateWatched.get()?[beaconId] ?? []))
  return beaconsDataWatches.map(function(beaconData) {
    return minimapHoverableMarker(
      {worldPos = beaconData.get().pos, clampToBorder = true}
      {},
      loc("marker_tooltip/capturePoint"),
      @(sf) {
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        children = [
          mkBeacon(beaconData, sf)
          {
            padding = [0, hdpx(4), 0, hdpx(4)]
            pos = [0, hdpx(26)]
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
