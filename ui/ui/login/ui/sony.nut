from "%ui/ui_library.nut" import *

let { h2_txt } = require("%ui/fonts_style.nut")
let background = require("background.nut")
let { textButton } = require("%ui/components/button.nut")
let {bottomEulaUrl} = require("eulaUrlView.nut")
let progressText = require("%ui/components/progressText.nut")
let { safeAreaHorPadding, safeAreaVerPadding } = require("%ui/options/safeArea.nut")

let {startLogin, currentStage} = require("%ui/login/login_chain.nut")
let loginDarkStripe = require("loginDarkStripe.nut")


function loginBtnAction() {
  startLogin({})
}

let loginBtn = textButton(loc("Login"), loginBtnAction,
  { size = [flex(), hdpx(70)], halign = ALIGN_CENTER, margin = 0
    hotkeys = [["^J:Y", { description = { skip = true }}]]
  }.__update(h2_txt)
)

let isFirstOpen = mkWatched(persist, "isFirstOpen", true)

function loginRoot() {
  let children = isFirstOpen.value
    ? [progressText(loc("loggingInProcess"))]
    : currentStage.value ? [progressText(loc("loggingInProcess"))] : [ loginBtn ]
  return {
    watch = [ currentStage, safeAreaVerPadding ]
    padding = [safeAreaVerPadding.get(), safeAreaHorPadding.get()]
    onAttach = function() {
      if (isFirstOpen.value && currentStage.value == null) {
        isFirstOpen(false)
        loginBtnAction()
      }
    }
    flow = FLOW_VERTICAL
    gap = hdpx(25)
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children
    size = [fsh(40), fsh(55)]
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
