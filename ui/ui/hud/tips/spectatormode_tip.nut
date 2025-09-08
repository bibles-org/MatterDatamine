from "%ui/ui_library.nut" import *

let { spectatingPlayerName } = require("%ui/hud/state/spectator_state.nut")
let { showDebriefing } = require("%ui/mainMenu/debriefing/debriefingState.nut")
let { mkText } = require("%ui/components/commonComponents.nut")

let spectatingName = Computed(function() {
  if (!showDebriefing.get() && spectatingPlayerName.get() != null)
    return spectatingPlayerName.get()
  return null
})

function spectatorMode_tip() {
  let watch = spectatingName
  if (spectatingName.get() == null || spectatingName.get() == "")
    return { watch }
  return {
    watch
    margin = hdpx(20)
    children = mkText(loc("hud/spectator_target", {user = spectatingName.get()}))
  }
}

return spectatorMode_tip
