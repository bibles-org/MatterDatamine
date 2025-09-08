from "%ui/ui_library.nut" import *

from "%sqstd/underscore.nut" import chunk
let {textInput} = require("%ui/components/textInput.nut")
let {textButton} = require("%ui/components/button.nut")
let { addModalPopup, removeModalPopup } = require("%ui/components/modalPopupWnd.nut")
let { makeVertScroll } = require("%ui/components/scrollbar.nut")
let {dtext} = require("%ui/components/text.nut")
let {body_txt} = require("%ui/fonts_style.nut")
let {BtnBgHover, BtnBdHover, BtnBdSelected, BtnTextNormal, BtnTextHover} = require("%ui/components/colors.nut")
let JB = require("%ui/control/gui_buttons.nut")

function mkSelectBtn(name, opt, state, close=null, setValue=null) {
  function onClick() {
    let sel = opt?.item ?? opt
    if (setValue!=null)
      setValue(sel)
    else
      state.set(sel)
    close?()
  }
  let size = const [fsh(30), SIZE_TO_CONTENT]

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
      padding = const [hdpx(2), hdpx(10)]
      children = {
        group
        behavior = Behaviors.Marquee
        size = const [flex(), SIZE_TO_CONTENT]
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
  assert(state instanceof Watched)
  let titleComp = title!=null ? dtext(title, {hplace = ALIGN_CENTER}.__update(titleStyle ?? {})) : null
  let filter = filterState!=null ? textInput(filterState, {placeholder = filterPlaceHolder ?? loc("filter")}) : null
  let close = @() removeModalPopup(uid)
  let buttonCtor = @(opt) mkSelectBtn(mkTxt(opt), opt, state, close, setValue)
  let mkColumn = @(options) mkMkColumn(options, buttonCtor)

  let selectWindow = @() {
    size = const [sw(70), sh(80)]
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
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        children = chunk(optionsState?.get() ?? optionsState, (optionsState?.get() ?? optionsState).len()/columns + 1).map(mkColumn)
      })
    ]
    padding = hdpx(20)
  }
  return @() addModalPopup([0, 0],
    {
      size = const [sw(100), sh(100)]
      uid
      fillColor = Color(0,0,0)
      padding = 0
      popupFlow = FLOW_HORIZONTAL
      popupValign = ALIGN_TOP
      popupOffset = 0
      margin = 0
      pos = [0,0]
      children = selectWindow
      popupBg = { rendObj = ROBJ_WORLD_BLUR_PANEL, fillColor = Color(0,0,0,120) }
    }
  )
})

function mkOpenSelectWindowBtn(state, openMenu, mkTxt = @(v) v, title = null, tooltipText = null){
  return @() {
    watch = state
    flow = FLOW_HORIZONTAL
    size = flex()
    valign = ALIGN_CENTER
    children = [
      title!=null ? dtext(title, {color = Color(180,180,180), padding=0, margin=0}) : null,
      title!=null ? const {size = [flex(), 0]} : null,
      textButton(mkTxt(state.get()), openMenu, {size = flex() margin = 0, minWidth = hdpx(50), padding = const [hdpx(5), hdpx(8)], textMargin=0, halign = ALIGN_CENTER, tooltipText})
    ]
  }
}


return {
  mkSelectWindow
  mkOpenSelectWindowBtn
}