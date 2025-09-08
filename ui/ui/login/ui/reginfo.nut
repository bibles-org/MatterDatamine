from "%ui/ui_library.nut" import *

let { body_txt } = require("%ui/fonts_style.nut")
let {Inactive} = require("%ui/components/colors.nut")
let urlText = require("%ui/components/urlText.nut")
let {registerUrl} = require("loginUiParams.nut")
let { get_setting_by_blk_path } = require("settings")

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
  size = [flex(), SIZE_TO_CONTENT]
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  halign = ALIGN_CENTER
  text = loc("login/agreement")
}
let legalUrl = get_setting_by_blk_path("legalsUrl") ?? "https://legal.gaijin.net/"
let legalInfo = {
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  size = [ flex(), SIZE_TO_CONTENT ]
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
    urlText(loc("gameForum"), get_setting_by_blk_path("gaijinForumUrl") ?? "https://forum.activematter.game/")
  ]
}
