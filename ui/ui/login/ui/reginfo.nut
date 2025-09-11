from "%ui/fonts_style.nut" import body_txt
from "%ui/components/colors.nut" import Inactive
import "%ui/components/urlText.nut" as urlText
from "settings" import get_setting_by_blk_path

from "%ui/ui_library.nut" import *

let { registerUrl } = require("%ui/login/ui/loginUiParams.nut")

function text(str) {
  return {
    rendObj = ROBJ_TEXT
    text = str
    color = Inactive
  }.__update(body_txt)
}

let regInfo = {
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  children = [
    (get_setting_by_blk_path("gaijin_net_login") ?? true)
      ? text(loc("login with your id in Gaijin.net"))
      : null
    urlText(loc("or register here"), registerUrl)
  ]
}
let loginWarning = {
  size = FLEX_H
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  halign = ALIGN_CENTER
  text = loc("login/agreement")
}
let legalUrl = get_setting_by_blk_path("legalsUrl") ?? "https://legal.gaijin.net/"
let legalInfo = {
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  size = FLEX_H
  children = [
    loginWarning
    urlText(loc("Legals"), legalUrl)
  ]
}

return {
  flow = FLOW_VERTICAL
  hplace = ALIGN_CENTER
  vplace = ALIGN_BOTTOM
  halign = ALIGN_CENTER
  pos = [0, sh(20)]
  gap = hdpx(10)
  children = [
    legalInfo
    regInfo
  ]
}
