from "%ui/ui_library.nut" import *

let { corticalVaultsSet, corticalVaultsGetWatched } = require("%ui/hud/state/cortical_vaults_es.nut")
let minimapHoverableMarker = require("minimap_hover_hint.nut")


let mkTeammateCorticalVaultMarker = function(transform, eid) {
  let cvWatched = corticalVaultsGetWatched(eid)
  return minimapHoverableMarker(
    @(){worldPos = cvWatched.get().pos, clampToBorder = true},
    transform,
    loc("hint/corticalVaultMinimapMarker"),
    @(stateWatched) @(){
      watch = stateWatched
      rendObj = ROBJ_IMAGE
      image = Picture($"ui/skin#microchip.svg:{hdpxi(16)}:{hdpxi(16)}:P")
      color = stateWatched.value & S_HOVER ? Color(255, 255, 0) : Color(255, 255, 255)
      size = [hdpxi(16), hdpxi(16)]
    },
    cvWatched
  )
}

return {
  watch = corticalVaultsSet
  ctor = @(p) corticalVaultsSet.get().keys().map(@(eid) mkTeammateCorticalVaultMarker(p?.transform ?? {}, eid))
}