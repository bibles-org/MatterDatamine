from "%ui/ui_library.nut" import *
from "%ui/fonts_style.nut" import body_txt, basic_text_shadow
let { DBGLEVEL } = require("dagor.system")


let screenLabelTxt = Watched("")

console_register_command(function(label) {
  screenLabelTxt.set(label)
}, "dbg.frame_label")

let frameLabel = @() {
  watch = screenLabelTxt
  hplace = ALIGN_RIGHT
  children = screenLabelTxt.get() != "" ? {
    rendObj = ROBJ_BOX
    fillColor = Color(255,255,255,255)
    size = SIZE_TO_CONTENT
    children = {
      padding = hdpx(5)
      rendObj = ROBJ_TEXT
      color = Color(20, 20, 20, 255)
      text = screenLabelTxt.get()
    }.__update(body_txt, basic_text_shadow)
  } : null
}

return { frameLabel = DBGLEVEL > 0 ? frameLabel : null }