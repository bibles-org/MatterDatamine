import "utf8" as utf8

from "%ui/ui_library.nut" import *

#allow-auto-freeze

function mkAnim(ch, i, total, anim, params = {}){
  let l = total.len()
  let delay = i * max(0.1, min(2.0/l, 0.3))
  return {
    rendObj = ROBJ_TEXT
    text = ch
    key = {}
    animations = anim(delay)
    transform = {}
    fontFx = FFT_GLOW
    fontFxColor = Color(0, 0, 0, 255)
  }.__update(params)
}

function mkAnimText(txt, anim, params = {}) {
  #forbid-auto-freeze
  let ut = utf8(txt)
  let chars = []
  for(local i=1; i <= ut.charCount(); i++){
    chars.append(ut.slice(i-1, i))
  }
  return {
    flow  = FLOW_HORIZONTAL
    hplace = ALIGN_CENTER
    children = chars.map(@(ch, i, total) mkAnim(ch, i, total, anim, params))
  }
}

return {
  mkAnimText
}