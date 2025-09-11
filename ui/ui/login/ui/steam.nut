from "%ui/fonts_style.nut" import h2_txt, sub_txt
import "%ui/login/ui/background.nut" as background
from "%ui/components/button.nut" import fontIconButton, textButton
import "%ui/components/progressText.nut" as progressText
from "%ui/mainMsgBoxes.nut" import exitGameMsgBox
from "%ui/login/login_chain.nut" import startLogin

from "%ui/ui_library.nut" import *

let regInfo = require("%ui/login/ui/reginfo.nut")
let supportLink = require("%ui/login/ui/supportLink.nut")
let { safeAreaHorPadding, safeAreaVerPadding } = require("%ui/options/safeArea.nut")
let { currentStage } = require("%ui/login/login_chain.nut")
let { linkSteamAccount } = require("%ui/login/login_state.nut")

let isFirstOpen = mkWatched(persist, "isFirstOpen", true)


function createSteamAccount() {
  if (!linkSteamAccount.get()) 
    startLogin({onlyKnown = false})
}

function onOpen() {
  if (!isFirstOpen.get())
    return
  isFirstOpen.set(false)
  startLogin({onlyKnown = true})
}

let steamLoginBtn = textButton(loc("steam/loginWithoutGaijinNet"), createSteamAccount,
  sub_txt)

function createLoginForm() {
  return [
    {
      vplace = ALIGN_BOTTOM
      halign = ALIGN_CENTER
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap = hdpx(10)
      children = [
        steamLoginBtn
      ]
    }
    regInfo
  ]
}

let centralContainer = @(children = null, watch = null, size = null) {
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  size = size
  watch = watch
  children = children
}

function loginRoot() {
  onOpen()
  let size = fsh(40)
  let watch = [currentStage]

  if (currentStage.get())
    return centralContainer(
      progressText(loc("loggingInProcessSteam")), watch, size)

  return centralContainer(createLoginForm(), watch, size)
}

let headerHeight = calc_comp_size({size=SIZE_TO_CONTENT children={margin = static [fsh(1), 0] size=[0, fontH(100)] rendObj=ROBJ_TEXT}.__update(h2_txt)})[1]*0.75

return {
 size = flex()
 children = [
  background
  loginRoot
  supportLink
  {
      size = [headerHeight, headerHeight]
      hplace = ALIGN_RIGHT
      margin = [fsh(2)+safeAreaVerPadding.get(), safeAreaHorPadding.get()+fsh(2)]
      children = fontIconButton("power-off", exitGameMsgBox)
    }
 ]
}
