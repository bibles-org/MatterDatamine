from "%ui/ui_library.nut" import *

let {body_txt} = require("%ui/fonts_style.nut")
let {TextNormal} = require("%ui/components/colors.nut")
let slider = require("%ui/components/slider.nut")

let slider_value_width = calc_str_box("200%", body_txt)[0]

return function(opt, _group, xmbNode, morphText = @(val) val) {
  let valWatch = opt.var
  return {
    size = flex()
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    gap = fsh(1)

    children = [
      slider.Horiz(valWatch, opt.__merge({xmbNode}))
      @() {
        watch = valWatch
        size = [slider_value_width, SIZE_TO_CONTENT]
        rendObj = ROBJ_TEXT
        color = TextNormal
        text = morphText(valWatch.value)
      }.__update(body_txt)
    ]
  }
}