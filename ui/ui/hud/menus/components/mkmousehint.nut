from "%ui/components/gamepadImgByKey.nut" import keysImagesMap

from "%ui/fonts_style.nut" import sub_txt
from "%ui/components/gamepadImgByKey.nut" import mkImageComp
from "%ui/components/colors.nut" import HUD_TIPS_HOTKEY_FG
from "%ui/components/commonComponents.nut" import mkText
import "%ui/components/faComp.nut" as faComp

from "%ui/ui_library.nut" import *

let { isGamepad } = require("%ui/control/active_controls.nut")

#allow-auto-freeze

let iconHeight = hdpxi(20)
let mouseBtn = @(btn) @() mkImageComp(keysImagesMap.get()?[btn], { watch = keysImagesMap, height = iconHeight, color = HUD_TIPS_HOTKEY_FG})

let text = @(txt) mkText(txt, {
  color = HUD_TIPS_HOTKEY_FG
  localize=false
}.__update(sub_txt))
let gap = text(" +").__merge({vplace=ALIGN_CENTER})
let mkFaIcon = @(icon) faComp(icon, {
  fontSize = sub_txt.fontSize
  color = HUD_TIPS_HOTKEY_FG
})

function mkButtonHint(btn) {
  let isMouseButton = keysImagesMap.get()?[btn] != null
  if (isMouseButton)
    return mouseBtn(btn)

  return mkText(btn, {
    color = HUD_TIPS_HOTKEY_FG
    fontFxColor = Color(0, 0, 0, 0)
  })
}

function buttonsHint(btns) {
  if (type(btns) != "array")
    btns = [btns]
  return {
    size = [SIZE_TO_CONTENT, iconHeight]
    flow = FLOW_HORIZONTAL
    gap = gap
    valign = ALIGN_CENTER
    children = btns.map(mkButtonHint)
  }
}

function mkMouseButtonHint(btext, btns, facompIcon = null, additionalText = null){
  let clickText = text($": {btext}")
  return @() {
    watch = isGamepad
    rendObj = ROBJ_WORLD_BLUR_PANEL
    padding = static [0, hdpx(2)]
    flow = FLOW_HORIZONTAL
    children = (btext == null || isGamepad.get()) ? null : [
      additionalText == null ? null : mkText(additionalText, { color = HUD_TIPS_HOTKEY_FG })
      buttonsHint(btns)
      facompIcon == null ? null : mkFaIcon(facompIcon)
      clickText
    ]
  }
}

return mkMouseButtonHint