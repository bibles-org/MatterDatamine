from "%ui/ui_library.nut" import *

from "%ui/components/commonComponents.nut" import mkText
from "%ui/components/colors.nut" import NexusPlayerPointsColor

let nexusPointsIconSize = hdpx(18)
let iconSizeSmall = hdpx(12)
let nexusPointsIconSmall = Picture("!ui/skin#raid_info/pvp_domination.svg:{0}:{0}:K".subst(iconSizeSmall))
let nexusPointsIcon = Picture("!ui/skin#raid_info/pvp_domination.svg:{0}:{0}:K".subst(nexusPointsIconSize))

function nexusPointsCostComp(points) {
  if (!points)
    return null

  return {
    rendObj = ROBJ_BOX
    borderRadius = [0, 0, 0,  hdpx(5)]
    fillColor = NexusPlayerPointsColor
    hplace = ALIGN_RIGHT
    vplace = ALIGN_TOP
    padding = hdpx(3)
    flow = FLOW_HORIZONTAL
    gap = hdpx(2)
    children = [
      {
        vplace = ALIGN_CENTER
        size = iconSizeSmall
        rendObj = ROBJ_IMAGE
        image = nexusPointsIconSmall
      }
      mkText(points)
    ]
  }
}

return {
  nexusPointsCostComp
  nexusPointsIcon
  nexusPointsIconSmall
  nexusPointsIconSize
}