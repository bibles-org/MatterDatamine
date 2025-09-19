import "%ui/control/gui_buttons.nut" as JB
from "%ui/components/colors.nut" import InfoTextValueColor, ConsoleFillColor, ControlBg, RedFailColor
from "%ui/components/commonComponents.nut" import mkText, mkTextArea
from "%ui/mainMenu/stdPanel.nut" import mkCloseStyleBtn, screenSize
from "%ui/fonts_style.nut" import h2_txt, body_txt, sub_txt
from "%sqstd/string.nut" import clearBorderSymbols
from "%ui/components/modalWindows.nut" import addModalWindow, removeModalWindow
from "%ui/components/msgbox.nut" import showMsgbox
from "eventbus" import eventbus_send
from "matching.errors" import INVALID_USER_ID
from "%ui/state/clientState.nut" import gameLanguage
from "app" import get_app_id, get_session_id
from "%ui/components/commonComponents.nut" import textButton
import "%ui/components/colorize.nut" as colorize
import "%ui/components/combobox.nut" as comboBox
from "%ui/components/textInput.nut" import textInput
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

const WND_UID = "complain_window"
const MIN_COMPLAIN_SYMBOLS = 10
let headerHeight = hdpx(45)
let complainTypes = ["CHEAT", "OTHER"]
let defaultType = complainTypes[0]

let wndWidth = screenSize[0]
let lastOpenParams = persist("lastOpenParams", @() {})

function close() {
  removeModalWindow(WND_UID)
  lastOpenParams.clear()
}

let header = @(name) {
  size = [flex(), headerHeight]
  valign = ALIGN_CENTER
  halign = ALIGN_CENTER
  padding = hdpx(10)
  children = [
    mkTextArea(loc("complain/header", { name = colorize(InfoTextValueColor, name) }),
      { halign = ALIGN_CENTER }.__merge(h2_txt))
    mkCloseStyleBtn(close, { hplace = ALIGN_RIGHT })
  ]
}

let mkSubmitButton = @(cantSubmitReason, trySubmit, userId) @() {
  watch = cantSubmitReason
  size = FLEX_H
  flow = FLOW_VERTICAL
  gap = hdpx(10)
  halign = ALIGN_CENTER
  xmbNode = XmbNode()
  children = [
    mkTextArea(cantSubmitReason.get() ?? " ", { halign = ALIGN_CENTER, color = RedFailColor })
    textButton(loc("btn/send"), function() {
      if (userId == ecs.INVALID_ENTITY_ID || userId == null) {
        close()
        showMsgbox({ text = loc("msg/complain/complainSent") })
        return
      }
      trySubmit()
    }, { isEnabled = cantSubmitReason.get() == null})
  ]
}

function complainWnd(sessionId, userId, name) {
  let curType = Watched(defaultType)
  let complainText = Watched("")
  let cantSubmitReason = Computed(@()
    clearBorderSymbols(complainText.get()).len() < MIN_COMPLAIN_SYMBOLS
      ? loc("msg/complain/needDetailedComment")
      : null)

  let trySubmit = function() {
    set_kb_focus(null)

    if (cantSubmitReason.get() != null) {
      showMsgbox({ text = cantSubmitReason.get() })
      return
    }

    if (userId != INVALID_USER_ID)
      eventbus_send("penitentiary.complain", {
        userId
        sessionId
        appId = get_app_id()
        complainType = curType.get().replace("ban/reason/", "")
        lang = gameLanguage.tolower()
        user_comment = clearBorderSymbols(complainText.get())
      })
    else {
      log($"[COMPLAIN] Attempt to complain on bot {name}, {sessionId}")
      log(clearBorderSymbols(complainText.get()))
    }

    showMsgbox({ text = loc("msg/complain/complainSent") })
    close()
  }

  return {
    size = [wndWidth, SIZE_TO_CONTENT]
    rendObj = ROBJ_WORLD_BLUR_PANEL
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    color = ConsoleFillColor
    padding = hdpx(10)
    gap = hdpx(10)

    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    stopMouse = true
    xmbNode = XmbContainer()

    children = [
      header(name)
      @() {
        watch = curType
        size = [pw(30), hdpx(40)]
        children = comboBox(curType, complainTypes.map(@(t) loc($"ban/reason/{t}")), loc("ban/reasonTitle"),
          loc($"ban/reason/{curType.get()}") != loc($"ban/reason/{defaultType}") ? null : loc($"ban/reason/{defaultType}"), 4, {
            margin = static [0,0, hdpx(20),0]
            color = InfoTextValueColor
          }.__merge(h2_txt))
      }
      {
        size = [pw(70), SIZE_TO_CONTENT]
        hplace = ALIGN_CENTER
        children = textInput(complainText, {
          placeholder = loc("complain/inputTextPlaceholder")
          textmargin = hdpx(5)
          xmbNode = XmbNode()
          onChange = @(value) complainText.set(value)
          onReturn = trySubmit
          halign = ALIGN_CENTER
          onEscape = close
        }.__update(body_txt))
      }
      mkSubmitButton(cantSubmitReason, trySubmit, userId)
    ]
  }
}

function open(sessionId, userId, name) {
  lastOpenParams.sessionId <- sessionId
  lastOpenParams.userId <- userId
  lastOpenParams.name <- name
  addModalWindow({
    key = WND_UID
    size = [sw(100), sh(100)]
    rendObj = ROBJ_WORLD_BLUR_PANEL
    fillColor = ControlBg
    onClick = close
    children = complainWnd(sessionId, userId, name)
    hotkeys = [[$"^{JB.B} | Esc", { action = close, description = loc("Cancel") }]]
  })
}

if (lastOpenParams.len() > 0)
  open(lastOpenParams.sessionId, lastOpenParams.userId, lastOpenParams.name)

return open
