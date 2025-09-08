from "%ui/ui_library.nut" import *

return @(content, override = {}) {
  rendObj = ROBJ_WORLD_BLUR_PANEL
  fillColor = Color(30, 30, 30, 160)
  children = {
    rendObj = ROBJ_FRAME
    color =  Color(50, 50, 50, 20)
    borderWidth = hdpx(1)
    padding = fsh(1)
    children = content
  }.__update(override)
}