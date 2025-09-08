from "%ui/ui_library.nut" import *

let { nexusBeacons, nexusBeaconEids, isNexus } = require("%ui/hud/state/nexus_mode_state.nut")
let { mkBeacon } = require("%ui/hud/tips/nexus_round_mode_header.nut")

function mkCompassNexusBeacons(eids, stateWatched) {
  return eids.map(function(beaconEid) {
    let beaconData = Computed(@() stateWatched.get()?[beaconEid] ?? [])
    return {
      data = { worldPos = beaconData.get().pos, doNotRotate = true }
      transform = {}
      children = mkBeacon(beaconData)
    }
  })
}

return {
  watch = [nexusBeacons, isNexus]
  childrenCtor = @() !isNexus.get() ? null : mkCompassNexusBeacons(nexusBeaconEids.get(), nexusBeacons)
}
