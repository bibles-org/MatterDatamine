from "%ui/components/textInput.nut" import textInput
from "%ui/components/button.nut" import textButton
from "%ui/components/modalPopupWnd.nut" import addModalPopup, removeModalPopup
from "%ui/components/scrollbar.nut" import makeVertScroll
from "%ui/components/text.nut" import dtext
from "%ui/fonts_style.nut" import body_txt
from "%ui/components/colors.nut" import BtnBgHover, BtnBdHover, BtnBdSelected, BtnTextNormal, BtnTextHover
from "%ui/ui_library.nut" import *
from "%sqstd/underscore.nut" import chunk

let JB = require("%ui/control/gui_buttons.nut")


#allow-auto-freeze

function mkSelectBtn(name, opt, state, close=null, setValue=null) {
  function onClick() {
    let sel = opt?.item ?? opt
    if (setValue!=null)
      setValue(sel)
    else
      state.set(sel)
    close?()
  }
  let size = static [fsh(30), SIZE_TO_CONTENT]

  let group = ElemGroup()
  let stateFlags = Watched(0)
  return function() {
    let sf = stateFlags.get()
    let isCur = opt?.isCurrent() ?? opt?.isEqual(state.get()) ?? (opt==state.get())
    return {
      watch = [state, stateFlags]
      group
      behavior = Behaviors.Button
      clipChildren = true
      onElemState = @(s) stateFlags.set(s)
      padding = static [hdpx(2), hdpx(10)]
      children = {
        group
        behavior = Behaviors.Marquee
        size = FLEX_H
        scrollOnHover = true
        children = {
          rendObj = ROBJ_TEXT
          text = name
          color = sf & S_HOVER ? BtnTextHover : BtnTextNormal
        }.__update(body_txt)
      }
      rendObj = ROBJ_BOX
      fillColor = sf & S_HOVER ? BtnBgHover : 0
      borderWidth = isCur ? hdpx(1) : 0
      borderColor = sf & S_HOVER
        ? BtnBdHover
        : isCur ? BtnBdSelected : 0
      onClick
      size
    }
  }
}

let mkMkColumn = @(options, buttonCtor) {
  flow = FLOW_VERTICAL
  children = options.map(buttonCtor)
}

let mkSelectWindow = kwarg(function(
    uid, optionsState, state, filterState=null, title=null, filterPlaceHolder=null, columns=4, titleStyle=null, mkTxt = @(v) v,
    onAttach=null, setValue = null
  ) {
  assert(state instanceof Watched, "selwindow require state of Watched type")
  let titleComp = title!=null ? dtext(title, {hplace = ALIGN_CENTER}.__update(titleStyle ?? {})) : null
  let filter = filterState!=null ? textInput(filterState, {placeholder = filterPlaceHolder ?? loc("filter")}) : null
  let close = @() removeModalPopup(uid)
  let buttonCtor = @(opt) mkSelectBtn(mkTxt(opt), opt, state, close, setValue)
  let mkColumn = @(options) mkMkColumn(options, buttonCtor)

  let selectWindow = @() {
    size = static [sw(70), sh(80)]
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    stopMouse = true
    behavior = Behaviors.Button
    hotkeys = [[$"Esc | {JB.B}"]]
    onClick = close
    key = uid
    watch = optionsState instanceof Watched ? optionsState : null
    onAttach
    flow = FLOW_VERTICAL
    gap = hdpx(5)
    children = [
      titleComp
      filter
      makeVertScroll({
        size = FLEX_H
        flow = FLOW_HORIZONTAL
        children = chunk(optionsState?.get() ?? optionsState, (optionsState?.get() ?? optionsState).len()/columns + 1).map(mkColumn)
      })
    ]
    padding = hdpx(20)
  }
  #forbid-auto-freeze
  return @() addModalPopup([0, 0],
    {
      size = static [sw(100), sh(100)]
      uid
      fillColor = Color(0,0,0)
      padding = 0
      popupFlow = FLOW_HORIZONTAL
      popupValign = ALIGN_TOP
      popupOffset = 0
      margin = 0
      pos = static [0,0]
      children = selectWindow
      popupBg = { rendObj = ROBJ_WORLD_BLUR_PANEL, fillColor = Color(0,0,0,120) }
    }
  )
})

function mkOpenSelectWindowBtn(state, openMenu, mkTxt = @(v) v, title = null, tooltipText = null, xmbNode = null){
  return @() {
    watch = state
    flow = FLOW_HORIZONTAL
    size = flex()
    valign = ALIGN_CENTER
    children = [
      title!=null ? dtext(title, {color = Color(180,180,180), padding=0, margin=0}) : null,
      title!=null ? static {size = static [flex(), 0]} : null,
      textButton(mkTxt(state.get()),
        openMenu,
        {
          size = flex()
          margin = 0
          minWidth = static hdpx(50)
          padding = static [hdpx(5), hdpx(8)]
          textMargin = 0
          halign = ALIGN_CENTER
          tooltipText
          xmbNode
        })
    ]
  }
}


return {
  mkSelectWindow
  mkOpenSelectWindowBtn
}