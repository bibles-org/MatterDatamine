from "%ui/hud/state/cortical_vaults_es.nut" import corticalVaultsGetWatched
import "%ui/hud/map/map_hover_hint.nut" as mapHoverableMarker

from "%ui/ui_library.nut" import *

let { corticalVaultsSet } = require("%ui/hud/state/cortical_vaults_es.nut")


let mkTeammateCorticalVaultMarker = function(transform, eid) {
  let cvWatched = corticalVaultsGetWatched(eid)
  return mapHoverableMarker(
    @(){worldPos = cvWatched.get().pos, clampToBorder = true},
    transform,
    loc("hint/corticalVaultMinimapMarker"),
    @(stateWatched) @(){
      watch = stateWatched
      rendObj = ROBJ_IMAGE
      image = Picture($"ui/skin#microchip.svg:{hdpxi(16)}:{hdpxi(16)}:P")
      color = stateWatched.get() & S_HOVER ? Color(255, 255, 0) : Color(255, 255, 255)
      size = hdpxi(16)
    },
    {watch = cvWatched}
  )
}

return {
  watch = corticalVaultsSet
  ctor = @(p) corticalVaultsSet.get().keys().map(@(eid) mkTeammateCorticalVaultMarker(p?.transform ?? {}, eid))
}