from "%ui/components/colors.nut" import DropBdActive, DropBdDisabled, DropBdNormal, DropBgDisabled,
  DropBgNormal, RedWarningColor

from "%ui/fonts_style.nut" import body_txt
from "%ui/components/commonComponents.nut" import mkTextArea

from "%ui/ui_library.nut" import *

#allow-auto-freeze

function dropMarker(stateFlags=0, overwhelmed = false, txt=null) {
  let textToDraw = txt ?? (overwhelmed ? loc("inventory/overwhelmed") : null)
  return {
    rendObj = ROBJ_BOX
    size = flex()
    borderWidth = hdpx(1.5)
    borderColor = overwhelmed ? DropBdDisabled : (stateFlags & S_ACTIVE) ? DropBdActive : DropBdNormal
    fillColor = DropBgNormal
    key = stateFlags
    animations = (stateFlags & S_ACTIVE) && !overwhelmed ? [] : [
      { prop=AnimProp.fillColor, from=Color(0,0,0,0), to=overwhelmed ? DropBgDisabled : DropBgNormal, duration=1.2, play=true, loop=true, easing=CosineFull }
    ]
    children = textToDraw && textToDraw != "" ? {
      rendObj = ROBJ_SOLID
      size = FLEX_H
      color = RedWarningColor
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      children = mkTextArea(textToDraw, { halign = ALIGN_CENTER }.__update(body_txt))
    } : null
  }
}

return dropMarker