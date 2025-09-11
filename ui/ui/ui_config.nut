from "settings" import get_setting_by_blk_path
from "dagor.system" import DBGLEVEL
from "%ui/fonts_style.nut" import sub_txt

from "daRg" import gui_scene
from "%ui/components/colors.nut" import TextNormal
from "%ui/ui_library.nut" import *



if (sub_txt!=null) {
  gui_scene.setConfigProps({
    defaultFont = sub_txt?.font ?? gui_scene.config.defaultFont
    defaultFontSize = sub_txt?.fontSize ?? gui_scene.config.defaultFontSize
    defTextColor = TextNormal
  })
}

gui_scene.setConfigProps({
  moveClickThreshold = hdpx(20)
  reportNestedWatchedUpdate = (DBGLEVEL > 0) ? true : get_setting_by_blk_path("debug/reportNestedWatchedUpdate") ?? false
  kbCursorControl = true
  gamepadCursorSpeed = 1.85
  

  gamepadCursorNonLin = 0.5
  gamepadCursorHoverMinMul = 0.07
  gamepadCursorHoverMaxMul = 0.8
  gamepadCursorHoverMaxTime = 1.0
  
  

  
  
  clickRumbleLoFreq = 0
  clickRumbleHiFreq = 0.8
  clickRumbleDuration = 0.04
})
