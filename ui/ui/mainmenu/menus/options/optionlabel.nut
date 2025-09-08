from "%ui/ui_library.nut" import *

let {body_txt} = require("%ui/fonts_style.nut")
let {BtnTextHover, BtnTextNormal} = require("%ui/components/colors.nut")


function optionLabel(opt, group) {
  let stateFlags = Watched(0)

  return function() {
    let color = (stateFlags.get() & S_HOVER) ? BtnTextHover : BtnTextNormal
    let text = opt?.restart ? $"{opt.name}*" : opt.name
    return {
      size = [flex(), SIZE_TO_CONTENT]
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
    }.__update(body_txt)
  }
}

return optionLabel
