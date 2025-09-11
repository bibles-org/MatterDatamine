from "%ui/fonts_style.nut" import h2_txt, body_txt
from "%ui/components/button.nut" import fontIconButton, textButton, button

from "%ui/ui_library.nut" import *
from "%ui/components/colors.nut" import WindowBd, InfoTextValueColor, DangerTextValueColor
from "%ui/components/tagsTable.style.nut" import defaultTagsTable
import "%ui/control/gui_buttons.nut" as JB
import "%ui/components/colorize.nut" as colorize

let { isGamepad } = require("%ui/control/active_controls.nut")

#allow-auto-freeze

let eventHandlersStopper = {
  ["HUD.ChatInput"] = @(_event) EVENT_BREAK 
}

let defStyling = freeze({
  Root = {
    behavior = DngBhv.ActivateActionSet
    actionSet = "StopInput"
    rendObj = ROBJ_WORLD_BLUR_PANEL
    stopMouse = true
    stopHotkeys = true
    fillColor = Color(0,0,0,120)
    borderColor = WindowBd
    borderWidth = static [hdpx(1),0,hdpx(1),0]
    padding = static [0, 0, hdpx(20), 0]
    vplace = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = static [sw(100), SIZE_TO_CONTENT]
    minHeight = fsh(40)
    transform = static {pivot =[0.5,0.5]}
    animations = static [
      { prop=AnimProp.opacity, from=0, to=1, duration=0.25, play=true, easing=OutCubic }
      { prop=AnimProp.scale,  from=[1, 0], to=[1,1], duration=0.2, play=true, easing=OutQuintic }
    ]
  }
  moveMouseCursor = isGamepad
  closeKeys = "Esc | {0}".subst(JB.B)
  leftKeys = "L.Shift Tab | R.Shift Tab"
  rightKeys = "Tab"
  activateKeys = "Space | Enter"

  closeTxt = loc("mainmenu/btnClose")
  BgOverlay = static {
    size = static [sw(100), sh(100)]
    color = Color(0,0,0,220)
    rendObj = ROBJ_SOLID
    stopMouse = true
    zOrder = Layers.MsgBox
    sound = {
      hover  = "ui_sounds/menu_highlight"
      click  = "ui_sounds/button_click_inactive"
    }
    eventHandlers = eventHandlersStopper
    animations = [
      { prop=AnimProp.opacity, from=1, to=0, duration=0.15, playFadeout=true, easing=OutCubic }
      { prop=AnimProp.opacity, from=0, to=1, duration=0.15, play=true, easing=OutCubic }
    ]
  }

  button = function(desc, on_click) {
    let addKey = {key = desc?.key ?? desc}
    if (desc?.customButton)
      return button(desc.customButton, on_click, (desc?.customStyle!=null) ? desc.customStyle.__merge(addKey) : addKey)
    return textButton(desc?.text ?? "???", on_click, (desc?.customStyle!=null) ? desc.customStyle.__merge(addKey) : addKey)
  }

  messageText = function(params) {
    local text = params?.text
    if (text instanceof Watched)
      text = text.get()
    return {
      size = FLEX_H
      minHeight = fsh(50)
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      flow = FLOW_VERTICAL
      padding = static [fsh(2), 0]
      children = [
        {
          size = FLEX_H
          rendObj = ROBJ_TEXTAREA
          behavior = Behaviors.TextArea
          halign = ALIGN_CENTER
          text
          tagsTable = params?.tagsTable ?? defaultTagsTable
        }.__update(params?.fontStyle ?? h2_txt)
        params?.children
      ]
    }
  }
})
#forbid-auto-freeze
let widgets = persist("msgbox_widgets", @() [])
#allow-auto-freeze
let msgboxGeneration = persist("msgbox_msgboxGeneration", @() Watched(0))
let hasMsgBoxes = Computed(@() msgboxGeneration.get() >= 0 && widgets.len() > 0)

function getCurMsgbox(){
  if (widgets.len()==0)
    return null
  return widgets.top()
}



function addWidget(w) {
  widgets.append(w)
  defer(@() msgboxGeneration.modify(@(v) v+1))
}

function removeWidget(w, uid=null) {
  let idx = widgets.indexof(w) ?? (uid!=null ? widgets.findindex(@(v) v?.uid == uid) : null)
  if (idx == null)
    return
  widgets.remove(idx)
  msgboxGeneration.modify(@(v) v+1)
}

function removeAllMsgboxes() {
  widgets.clear()
  msgboxGeneration.modify(@(v) v+1)
}

function updateWidget(w, uid){
  let idx = widgets.findindex(@(wd) wd.uid == uid)
  if (idx == null)
    addWidget(w)
  else {
    widgets.remove(idx)
    addWidget(w)
  }
}

function removeMsgboxByUid(uid) {
  let idx = widgets.findindex(@(w) w.uid == uid)
  if (idx == null)
    return false
  widgets.remove(idx)
  msgboxGeneration.modify(@(v) v+1)
  return true
}

function isMsgboxInList(uid) {
  return widgets.findindex(@(w) w.uid == uid) != null
}
















let skip = {skip=true}
let skpdescr = {description = skip}
let defaultButtons = [{text="OK" customStyle={hotkeys=[["^Esc | Enter", skpdescr]]}}]


function showMsgbox(params, styling=defStyling) {
  #forbid-auto-freeze
  log($"[MSGBOX] show: text = '{params?.text}'")
  let self = {v = null}
  let uid = params?.uid ?? {}

  function doClose() {
    removeWidget(self.v, uid)
    if ("onClose" in params && params.onClose)
      params.onClose()

    log($"[MSGBOX] closed: text = '{params?.text}'")
  }

  function handleButton(button_action) {
    if (button_action) {
      if (button_action?.getfuncinfos?().parameters.len()==2) {
        
        button_action({doClose})
        return 
      }

      button_action()
    }

    doClose()
  }

  local btnsDesc = params?.buttons ?? defaultButtons
  if (!(btnsDesc instanceof Watched))
    btnsDesc = Watched(btnsDesc, FRP_DONT_CHECK_NESTED)

  local defCancel = null
  local initialBtnIdx = 0

  foreach (idx, bd in btnsDesc.get()) {
    if (bd?.isCurrent)
      initialBtnIdx = idx
    if (bd?.isCancel)
      defCancel = bd
  }

  let curBtnIdx = Watched(initialBtnIdx)

  function moveBtnFocus(dir) {
    curBtnIdx.set((curBtnIdx.get() + dir + btnsDesc.get().len()) % btnsDesc.get().len())
  }

  function activateCurBtn() {
    log($"[MSGBOX] handling active '{btnsDesc.get()[curBtnIdx.get()]?.text}' button: text = '{params?.text}'")
    handleButton(btnsDesc.get()[curBtnIdx.get()]?.action)
  }

  let buttonsBlockKey = {}

  function buttonsBlock() {
    return @() {
      watch = [curBtnIdx, btnsDesc]
      key = buttonsBlockKey
      size = SIZE_TO_CONTENT
      flow = FLOW_HORIZONTAL
      gap = hdpx(40)

      children = btnsDesc.get().map(function(desc, idx) {
        let conHover = desc?.onHover
        function onHover(on){
          if (!on)
            return
          curBtnIdx.set(idx)
          conHover?()
        }
        let onAttach = (initialBtnIdx==idx && styling?.moveMouseCursor.get())
          ? @(elem) move_mouse_cursor(elem)
          : null
        local behavior = desc?.customStyle?.behavior ?? desc?.customStyle?.behavior
        behavior = type(behavior) == "array" ? behavior : [behavior]
        behavior.append(Behaviors.Button)
        let customStyle = (desc?.customStyle ?? {}).__merge({
          onHover
          behavior
          onAttach
        })
        function onClick() {
          log($"[MSGBOX] clicked '{desc?.text}' button: text = '{params?.text}'")
          handleButton(desc?.action)
        }
        return styling.button(desc.__merge({customStyle = customStyle, key=desc}), onClick)
      })

      hotkeys = [
        [styling?.closeKeys ?? "Esc", {action= @() handleButton(params?.onCancel ?? defCancel?.action), description = styling?.closeTxt}],
        [styling?.rightKeys ?? "Right | Tab", {action = @() moveBtnFocus(1) description = skip}],
        [styling?.leftKeys ?? "Left", {action = @() moveBtnFocus(-1) description = skip}],
        [styling?.activateKeys ?? "Space | Enter", {action= activateCurBtn, description= skip}],
        [styling?.maskKeys ?? "", {action = @() null, description = skip}]
      ]
    }
  }

  let root = styling.Root.__merge({
    key = uid
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    children = [
      styling.messageText(params.__merge({ handleButton }))
      buttonsBlock()
    ]
  })

  self.v = styling.BgOverlay.__merge({
    uid
    stopMouse = true
    children = [styling.BgOverlay?.children, root]
  })

  updateWidget(self.v, uid)

  return self
}
let msgboxComponent = @(){watch=msgboxGeneration children = getCurMsgbox()}

let addDefOkButton = @(p) ("buttons" in p) ? p : p.__merge({
  buttons = static [
    {
      text = loc("Ok")
      isCancel = true
      sound = {
        click  = "ui_sounds/button_ok"
        hover  = "ui_sounds/button_highlight"
      }
    }
  ]
})

let msgWithStyleTxt = function(s) {
  return {
    halign = ALIGN_CENTER
    padding = static [fsh(2), 0]
    minHeight = fsh(50)
    valign = ALIGN_CENTER
    children = s.content
  }
}
function showMessageWithStyle(p, msgStyle) {
  msgStyle = msgStyle.__merge({messageText = msgWithStyleTxt})
  showMsgbox(addDefOkButton(p), msgStyle)
}

function showContentOnPictureBg(p) {
  let msgStyle = clone defStyling
  msgStyle.Root = defStyling.Root.__merge({ rendObj = null })
  msgStyle.BgOverlay = defStyling.BgOverlay.__merge({
    size = static [sw(100), sh(100)]
    rendObj = ROBJ_SOLID
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    children = {
      size = static [SIZE_TO_CONTENT, sh(100)]
      rendObj = ROBJ_IMAGE
      hplace = ALIGN_CENTER
      color = null
      keepAspect = true
      image = p?.bgImage
    }
  })
  showMessageWithStyle(p, msgStyle)
}

function showMessageWithContent(p, customStyle = null) {
  showMessageWithStyle(p, customStyle ?? defStyling)
}


function showWithCloseButton(params) {
  let originalMessageText = defStyling.messageText
  let style = defStyling.__merge({
    messageText = @(textParams) {
      size = FLEX_H
      children = [
        {
          flow = FLOW_HORIZONTAL
          vplace = ALIGN_TOP
          hplace = ALIGN_RIGHT
          children = [
            params?.topPanel
            fontIconButton("icon_buttons/x_btn.svg", @() textParams?.handleButton(params?.onButtonCloseCb), {
              size = fsh(5)
              hotkeys = [[JB.B, { description = { skip = true } }]]
            })
          ]
        }
        originalMessageText(textParams)
      ]
    }
  })
  showMsgbox(addDefOkButton(params), style)
}

return freeze({
  getCurMsgbox
  msgboxGeneration
  removeAllMsgboxes
  isMsgboxInList
  removeMsgboxByUid
  msgboxComponent
  hasMsgBoxes
  showMsgbox = @(params, style=defStyling) showMsgbox(addDefOkButton(params), style)
  showMessageWithContent
  showContentOnPictureBg
  showWithCloseButton
  styling = defStyling
  msgboxDefStyle = defStyling
})
