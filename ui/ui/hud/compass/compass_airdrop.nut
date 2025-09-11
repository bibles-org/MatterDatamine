from "%ui/ui_library.nut" import *

let { airdropPredictedPositions } = require("%ui/hud/state/airdrop_state.nut")

#allow-auto-freeze

function mkCompassAirdrop(airdropInfo) {
  return function() {
    return {
      transform = {}
      data = {
        worldPos = airdropInfo.center
      }
      children = {
        pos = [0, -13]
        rendObj = ROBJ_IMAGE
        image = Picture("!ui/skin#{0}:{1}:{2}}:P".subst(airdropInfo.icon, hdpxi(18), hdpxi(32)))
        color = Color(255, 255, 255)
        size = static [hdpxi(18), hdpxi(32)]
      }
      size = static [hdpxi(18), hdpxi(32)]
    }
  }
}

return {
  watch = [airdropPredictedPositions]
  childrenCtor = @() airdropPredictedPositions.get().values().map(mkCompassAirdrop)
}