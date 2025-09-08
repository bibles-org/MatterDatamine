from "%ui/ui_library.nut" import *

let {body_txt} = require("%ui/fonts_style.nut")

function dtext(val, params={}) {
  if (val == null)
    return null
  if (type(val)=="table") {
    params = val.__merge(params)
    val = params?.text
  }
  local children = params?.children
  if (children && type(children) !="array")
    children = [children]

  let watch = params?.watch
  local watchedtext = false
  local txt = ""
  if (type(val) == "string")  {
    txt = val
  }
  if (type(val) == "instance" && val instanceof Watched) {
    txt = val.value
    watchedtext = true
  }
  let ret = {
    rendObj = ROBJ_TEXT
    size = SIZE_TO_CONTENT
    halign = ALIGN_LEFT
  }.__update(body_txt, params, {text = txt, children})
  if (watch || watchedtext)
    return @() ret
  else
    return ret
}

return {dtext}