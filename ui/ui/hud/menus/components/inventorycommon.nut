from "%ui/fonts_style.nut" import body_txt
from "%ui/ui_library.nut" import *

#allow-auto-freeze

let mkInventoryHeaderText = @[pure](text, override = {}) {
  rendObj = ROBJ_TEXT
  text
  size = FLEX_H
  color = Color(196,196,196,196)
  halign = ALIGN_CENTER
  fontFx = FFT_GLOW
  fontFxColor = Color(0, 0, 0, 255)
}.__update(body_txt, override)

let mkInventoryHeader = @[pure](text, content) {
  flow = FLOW_VERTICAL
  valign = ALIGN_TOP
  size =  FLEX_H
  cursorNavAnchor = [elemw(50), elemh(50)]
  children = [ text ? mkInventoryHeaderText(text) : null, content ]
}

return {
  mkInventoryHeader
  mkInventoryHeaderText
}