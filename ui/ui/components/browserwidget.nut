from "%ui/ui_library.nut" import *
let {Browser = null} = require_optional("browser.behaviors")

let {
  TextNormal, ModalBgTint
} = require("%ui/components/colors.nut")
let { showMsgbox } = require("%ui/components/msgbox.nut")
let {addModalWindow, removeModalWindow} = require("%ui/components/modalWindows.nut")
let { fontIconButton } = require("%ui/components/button.nut")
let { eventbus_subscribe } = require("eventbus")
let { browser_go_back = @() null,
        browser_reload_page = @() null,
        can_use_embeded_browser = @() false } = require_optional("browser")

let windowTitle = Watched(null)
let canGoBack = Watched(false)

const WND_UID = "webbrowser_window"

function handleBrowserEvent(val) {
  if ("canGoBack" in val)
    canGoBack(!!val.canGoBack)
  if ("title" in val)
    windowTitle(val.title ?? "")
}

eventbus_subscribe("browser_event", handleBrowserEvent)

let windowTitleHeader = @() {
  rendObj = ROBJ_TEXT
  vplace = ALIGN_CENTER
  watch = windowTitle
  text = windowTitle.value
  color = TextNormal
  size = [flex(), SIZE_TO_CONTENT]
  padding = [hdpx(5), hdpx(20)]
}

let btnstyle = freeze({padding = hdpx(5)})
let controlPanel = @(onClose) {
  size = [flex(), hdpx(35)]
  flow = FLOW_HORIZONTAL
  gap = hdpx(5)
  children = [
    fontIconButton("arrow-left", browser_go_back, {watch = canGoBack, isEnabled = @() canGoBack.get()}.__update(btnstyle))
    fontIconButton("refresh", browser_reload_page, btnstyle)
    windowTitleHeader
    fontIconButton("icon_buttons/x_btn.svg", function(){
        removeModalWindow(WND_UID)
        onClose?()
      }, btnstyle)
  ]
}

function showBrowser(url = "", onClose = @() null) {
  if (can_use_embeded_browser()) {
    addModalWindow({
      key = WND_UID
      rendObj = ROBJ_WORLD_BLUR_PANEL
      fillColor = ModalBgTint
      onClick = @() null
      children = {
        clipChildren = true
        flow = FLOW_VERTICAL
        
        
        size = [hdpx(1200), hdpx(768)]
        rendObj = ROBJ_SOLID
        color = Color(20,20,20,255)
        hplace = ALIGN_CENTER
        vplace = ALIGN_CENTER
        children = [
          controlPanel(onClose)
          {
            size = flex()
            rendObj = ROBJ_BROWSER
            behavior = Browser
            defaultUrl = url != "" ? url : null
          }
        ]
      }
    })
  } else {
    showMsgbox({text = loc("error/CANNOT_DISPLAY_WEBBROWSER")})
  }
}

return {
  showBrowser
}