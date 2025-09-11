from "%ui/fonts_style.nut" import h2_txt, sub_txt, body_txt
from "%ui/components/commonComponents.nut" import bluredPanel, mkText
import "%ui/components/mkQrCode.nut" as mkQrCode
from "%ui/components/openUrl.nut" import openUrl
from "%ui/components/modalWindows.nut" import addModalWindow, removeModalWindow
import "%ui/components/spinner.nut" as spinner

from "%ui/ui_library.nut" import *

let JB = require("%ui/control/gui_buttons.nut")


const WND_UID = "qr_window"
const URL_REFRESH_SEC = 300 
let waitingSpinner = spinner()

function close(onCloseCb = null) {
  onCloseCb?()
  removeModalWindow(WND_UID)
}

let waitInfo = {
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  children = [
    mkText(loc("xbox/waitingMessage"))
    waitingSpinner
  ]
}

let qrWindow = kwarg(function (url, header = "", desc = "", needShowRealUrl = true) {
  let realUrl = Watched(null)
  function receiveRealUrl() {
    openUrl(url)
    gui_scene.setTimeout(URL_REFRESH_SEC, receiveRealUrl)
  }

  return @() {
    watch = realUrl
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    rendObj = ROBJ_WORLD_BLUR_PANEL
    padding = 2 * hdpx(20)
    gap = hdpx(20)

    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER

    onAttach = receiveRealUrl
    onDetach = @() gui_scene.clearTimer(receiveRealUrl)

    children = [
      { rendObj = ROBJ_TEXT, text = header }.__update(h2_txt)
      desc == "" ? null : {
        rendObj = ROBJ_TEXTAREA,
        behavior = Behaviors.TextArea,
        halign = ALIGN_CENTER
        text = desc,
        maxWidth = hdpx(600)
      }.__update(body_txt)
      needShowRealUrl ? { rendObj = ROBJ_TEXT, text = url }.__update(sub_txt) : null
      realUrl.get() ? mkQrCode({ data = realUrl.get() }) : waitInfo
    ]
  }
})

return @(params, onCloseCb = null) addModalWindow({
  key = WND_UID
  size = static [sw(100), sh(100)]
  onClick = @() close(onCloseCb)
  children = qrWindow(params)
  hotkeys = [[$"^{JB.B} | Esc", { action = @() close(onCloseCb), description = loc("Cancel") }]]
}.__update(bluredPanel))