from "%ui/fonts_style.nut" import body_txt
from "%ui/components/openUrl.nut" import openUrl
from "%ui/components/colors.nut" import TextNormal, BtnBgHover, BtnBgActive

from "%ui/ui_library.nut" import *

#allow-auto-freeze

function url(str, address, params = {}) {
  let group = ElemGroup()
  let stateFlags = Watched(0)

  return function() {
    let sf = stateFlags.get()
    let color = (sf & S_ACTIVE)
      ? BtnBgActive
      : (sf & S_HOVER) ? BtnBgHover: TextNormal

    return {
      watch = stateFlags
      rendObj = ROBJ_TEXT
      behavior = Behaviors.Button
      sound = {
        hover = "ui_sounds/button_highlight"
        click = "ui_sounds/button_click"
      }
      text = str
      color
      group
      children = {
        rendObj = ROBJ_FRAME
        borderWidth = static [0,0,2,0]
        color
        group
        size = flex()
        pos = [0, 2]
      }.__update(params?.childParams ?? {})
      onClick = function() { openUrl(address) }
      onElemState = @(newSF) stateFlags.set(newSF)
    }.__update(body_txt, params)
  }
}

return url
