from "%ui/fonts_style.nut" import body_txt
from "%ui/components/colors.nut" import BtnTextHover, BtnTextNormal

from "%ui/ui_library.nut" import *



function optionLabel(opt, group, override = {}) {
  let stateFlags = Watched(0)

  return function() {
    let color = (stateFlags.get() & S_HOVER) ? BtnTextHover : BtnTextNormal
    let text = opt?.restart ? $"{opt.name}*" : opt.name
    return {
      size = FLEX_H
      group
      halign = ALIGN_LEFT
      
      watch = stateFlags
      onElemState = @(sf) stateFlags.set(sf)
      clipChildren = true
      rendObj = ROBJ_TEXT 

      
      text
      color
      sound = {
        hover = "ui_sounds/menu_highlight_settings"
      }
    }.__update(body_txt, override)
  }
}

return optionLabel
