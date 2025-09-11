from "%ui/fonts_style.nut" import sub_txt
from "%ui/mainMenu/eula/eula.nut" import showEula
import "%ui/components/urlText.nut" as urlText

from "%ui/ui_library.nut" import *

let { safeAreaHorPadding, safeAreaVerPadding } = require("%ui/options/safeArea.nut")

let eulaUrlView = {
    zOrder = 1
    size = SIZE_TO_CONTENT
    flow = FLOW_HORIZONTAL
    margin = fsh(0.5)
    children = urlText(loc("eula/urlViewText"), null, {
      onClick = @() showEula(null)
      skipDirPadNav = true
    }.__update(sub_txt))
}
let bottomEulaUrl = @(){
  size = flex()
  halign = ALIGN_LEFT
  valign = ALIGN_BOTTOM
  children = eulaUrlView
  padding = [safeAreaVerPadding.get()+fsh(5), safeAreaHorPadding.get()+sw(4)]
  watch=[safeAreaVerPadding]
}
return {
  eulaUrlView
  bottomEulaUrl
}
