from "%ui/ui_library.nut" import *

let { corticalVaultsSet, corticalVaultsGetWatched } = require("%ui/hud/state/cortical_vaults_es.nut")
let { isNexus } = require("%ui/hud/state/nexus_mode_state.nut")
let img = @() {
  rendObj = ROBJ_IMAGE
  image = Picture($"ui/skin#microchip.svg:{hdpxi(16)}:{hdpxi(16)}:P")
  color = Color(255, 255, 255)
  size = [hdpxi(16), hdpxi(16)]
}

function mkCompassCorticalVault(eid) {
  let cvWatched = corticalVaultsGetWatched(eid)
  return function() {
    return {
      watch = cvWatched
      transform = {}
      data = {
        worldPos = cvWatched.get().pos
      }
      children = img
      size = [hdpxi(16), hdpxi(16)]
    }
  }
}

return {
  watch = [corticalVaultsSet, isNexus]
  childrenCtor = @() isNexus.get() ? null :
    corticalVaultsSet.get()
      .keys()
      .map(mkCompassCorticalVault)
}