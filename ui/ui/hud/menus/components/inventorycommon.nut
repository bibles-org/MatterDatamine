from "%ui/ui_library.nut" import *

let {body_txt} = require("%ui/fonts_style.nut")

let mkInventoryHeaderText = @(text, override = {}) {
  rendObj = ROBJ_TEXT
  text
  size = [ flex(), SIZE_TO_CONTENT ]
  color = Color(196,196,196,196)
  halign = ALIGN_CENTER
  fontFx = FFT_GLOW
  fontFxColor = Color(0, 0, 0, 255)
}.__update(body_txt, override)

let mkInventoryHeader = @(text, content) {
  flow = FLOW_VERTICAL
  valign = ALIGN_TOP
  size =  [ flex(), SIZE_TO_CONTENT ]
  cursorNavAnchor = [elemw(50), elemh(50)]
  children = [ text ? mkInventoryHeaderText(text) : null, content ]
}

return {
  mkInventoryHeader
  mkInventoryHeaderText
}