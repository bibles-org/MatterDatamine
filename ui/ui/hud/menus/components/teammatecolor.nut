from "%ui/ui_library.nut" import *
let { nexusModeTeamColors } = require("%ui/hud/state/nexus_mode_state.nut")

let TeammateColor = @() {
  watch = nexusModeTeamColors
  flow = FLOW_VERTICAL
  rendObj = ROBJ_BOX
  fillColor = Color(0, 0, 0)
  size = const [hdpx(50), flex()]
  gap = hdpx(1)
  padding = hdpx(1)
  children = [
    {
      rendObj = ROBJ_BOX
      fillColor = nexusModeTeamColors.get()[0]
      size = flex()
    },
    {
      rendObj = ROBJ_BOX
      fillColor = nexusModeTeamColors.get()[1]
      size = flex()
    }
  ]
}

return {
  TeammateColor
}
