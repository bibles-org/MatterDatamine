from "%ui/fonts_style.nut" import h2_txt, sub_txt
from "%ui/components/colors.nut" import TextNormal

from "%ui/ui_library.nut" import *

#allow-auto-freeze

function textarea(txt, params={}) {
  if (type(txt)=="table") {
    params = txt
    txt = params?.text
  }
  return {
    size = FLEX_H
    color = TextNormal
    text = txt
  }.__update(h2_txt, params, {
    rendObj=ROBJ_TEXTAREA
    behavior = Behaviors.TextArea
  })
}

function smallTextarea(txt, params={}) {
  if (type(txt)=="table")
    txt = params?.text ?? ""
  return {
    size = FLEX_H
    halign = ALIGN_LEFT
    rendObj=ROBJ_TEXTAREA
    behavior = Behaviors.TextArea
    text=txt
  }.__update(sub_txt, params)
}


return {
  textarea
  smallTextarea
}