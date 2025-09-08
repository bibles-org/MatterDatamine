from "%ui/ui_library.nut" import *

let barWidth = sw(7)
let barHeight = fsh(0.5)

let blurBack = {
  rendObj = ROBJ_WORLD_BLUR
  size = flex()
  color=Color(250,250,250,250)
}

return freeze({
  HUD_ITEMS_COLOR = Color(180,180,180,50)
  blurBack = blurBack
  barWidth = barWidth
  barHeight = barHeight
  notSelectedItemColor = Color(180,180,180,150)
  itemAppearing = [
    {prop=AnimProp.opacity, from=0, to=1, duration=0.5, play=true, easing=InOutCubic}
  ]
  indicatorsFontStyle = {
    font = Fonts.system
    rendObj = ROBJ_TEXT
    vplace = ALIGN_CENTER
    hplace = ALIGN_RIGHT
  }
  indicatorsFontSize = 14
  indicatorsIcoSize = 16
  indicatorsGap = 2
})