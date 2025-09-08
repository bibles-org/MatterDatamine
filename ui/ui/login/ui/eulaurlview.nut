from "%ui/ui_library.nut" import *

let { sub_txt } = require("%ui/fonts_style.nut")
let {showEula} = require("%ui/mainMenu/eula/eula.nut")
let urlText = require("%ui/components/urlText.nut")
let {safeAreaHorPadding, safeAreaVerPadding} = require("%ui/options/safeArea.nut")

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
  padding = [safeAreaVerPadding.value+fsh(5), safeAreaHorPadding.value+sw(4)]
  watch=[safeAreaVerPadding]
}
return {
  eulaUrlView
  bottomEulaUrl
}
