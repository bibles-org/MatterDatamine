from "%ui/fonts_style.nut" import h2_txt
import "%ui/login/ui/background.nut" as background
from "%ui/components/button.nut" import buttonWithGamepadHotkey
from "%ui/components/commonComponents.nut" import mkText
from "%ui/login/ui/eulaUrlView.nut" import bottomEulaUrl
import "%ui/components/progressText.nut" as progressText
from "%ui/login/login_chain.nut" import startLogin

from "%ui/ui_library.nut" import *

let { safeAreaHorPadding, safeAreaVerPadding } = require("%ui/options/safeArea.nut")

let { currentStage } = require("%ui/login/login_chain.nut")
let loginDarkStripe = require("%ui/login/ui/loginDarkStripe.nut")


function loginBtnAction() {
  startLogin({})
}

let loginBtn = buttonWithGamepadHotkey(mkText(loc("Login"), { hplace = ALIGN_CENTER }.__merge(h2_txt)), loginBtnAction,
  { size = static [flex(), hdpx(70)], halign = ALIGN_CENTER, margin = 0
    hotkeys = [["^J:Y", { description = { skip = true }}]]
  }.__update(h2_txt)
)

let isFirstOpen = mkWatched(persist, "isFirstOpen", true)

function loginRoot() {
  let children = isFirstOpen.get()
    ? [progressText(loc("loggingInProcess"))]
    : currentStage.get() ? [progressText(loc("loggingInProcess"))] : [ loginBtn ]
  return {
    watch = [ currentStage, safeAreaVerPadding ]
    padding = [safeAreaVerPadding.get(), safeAreaHorPadding.get()]
    onAttach = function() {
      if (isFirstOpen.get() && currentStage.get() == null) {
        isFirstOpen.set(false)
        loginBtnAction()
      }
    }
    flow = FLOW_VERTICAL
    gap = hdpx(25)
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children
    size = static [fsh(40), fsh(55)]
    pos = [-sw(15), -sh(5)]
    hplace = ALIGN_RIGHT
    vplace = ALIGN_CENTER
  }
}

return @() {
  size = flex()
  children = [
    background
    loginDarkStripe
    loginRoot
    bottomEulaUrl
  ]
}
