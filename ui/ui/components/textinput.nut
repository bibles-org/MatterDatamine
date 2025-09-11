from "%ui/components/colors.nut" import ControlBg, Active, BtnBgHover, BtnBgSelected,
  TextInputBdNormal

from "%darg/ui_imports.nut" import *
from "string" import regexp, split_by_chars


#allow-auto-freeze
let placeHolderColor = Color(80,80,80,80)
let textColor = Active
let backGroundColor = ControlBg
let highlightFailure = Color(255,60,70)








let rexInt = regexp(@"[\+\-]?[0-9]+")
function isStringInt(str){
  return rexInt.match(str) 
}

let rexFloat = regexp(@"(\+|-)?([0-9]+\.?[0-9]*|\.[0-9]+)([eE](\+|-)?[0-9]+)?")
function isStringFloat(str){
  return rexFloat.match(str) 
}

let rexEng = regexp(@"[a-z,A-Z]*")
function isStringEng(str){
  return rexEng.match(str)
}
function isStringLikelyEmail(str, _verbose=true) {




  if (type(str)!="string")
    return false
  let splitted = split_by_chars(str,"@")
  if (splitted.len()<2)
    return false
  local locpart = splitted[0]
  if (splitted.len()>2)
    locpart = "@".join(splitted.slice(0,-1))
  if (locpart.len()>64)
    return false
  let dompart = splitted[splitted.len()-1]
  if (dompart.len()>253 || dompart.len()<4) 
    return false
  let quotes = locpart.indexof("\"")
  if (quotes && quotes!=0)
    return false 
  if (quotes==null && locpart.indexof("@")!=null)
    return false 
  if (dompart.indexof(".")==null || dompart.indexof(".")>dompart.len()-3) 
    return false  
  return true
}

function defaultFrame(inputObj, group, sf) {
  return {
    rendObj = ROBJ_FRAME
    borderWidth = static [hdpx(1), hdpx(1), 0, hdpx(1)]
    size = FLEX_H
    color = (sf & S_KB_FOCUS) ? Color(180, 180, 180) : Color(120, 120, 120)
    group = group

    children = {
      rendObj = ROBJ_FRAME
      borderWidth = static [0, 0, hdpx(1), 0]
      size = FLEX_H
      color = (sf & S_KB_FOCUS) ? Color(250, 250, 250) : Color(180, 180, 180)
      group = group

      children = inputObj
    }
  }
}

function isValidStrByType(str, inputType) {
  if (str=="")
    return true
  if (inputType=="mail")
     return isStringLikelyEmail(str)
  if (inputType=="num")
     return isStringInt(str) || isStringFloat(str)
  if (inputType=="integer")
     return isStringInt(str)
  if (inputType=="float")
     return isStringFloat(str)
  if (inputType=="lat")
     return isStringEng(str)
  return true
}

let failAnim = @(trigger) {
  prop = AnimProp.color
  from = highlightFailure
  easing = OutCubic
  duration = 1.0
  trigger = trigger
}

let interactiveValidTypes = ["num","lat","integer","float"]

function textInput(text_state, options={}, frameCtor=defaultFrame) {
  let group = ElemGroup()
  let {
    setValue = @(v) text_state.set(v), inputType = null,
    placeholder = null, showPlaceHolderOnFocus = false, password = null, maxChars = null,
    title = null, font = null, fontSize = null, hotkeys = null,
    size = [flex(), fontH(100)], textmargin = static [sh(1), sh(0.5)], valignText = ALIGN_BOTTOM,
    margin = static [sh(1), 0], padding = 0, borderRadius = hdpx(3), valign = ALIGN_CENTER,
    xmbNode = null, imeOpenJoyBtn = null, charMask = null,

    
    onBlur = null, onReturn = null,
    onEscape = @() set_kb_focus(null), onChange = null, onFocus = null, onAttach = null,
    onHover = null, onImeFinish = null
  } = options

  local {
    isValidResult = null, isValidChange = null
  } = options

  isValidResult = isValidResult ?? @(new_value) isValidStrByType(new_value, inputType)
  isValidChange = isValidChange
    ?? @(new_value) interactiveValidTypes.indexof(inputType) == null
      || isValidStrByType(new_value, inputType)

  let stateFlags = Watched(0)

  function onBlurExt() {
    if (!isValidResult(text_state.get()))
      anim_start(text_state)
    onBlur?()
  }

  function onReturnExt(){
    if (!isValidResult(text_state.get()))
      anim_start(text_state)
    onReturn?()
  }

  function onEscapeExt(){
    if (!isValidResult(text_state.get()))
      anim_start(text_state)
    onEscape()
  }

  function onChangeExt(new_val) {
    onChange?(new_val)
    if (!isValidChange(new_val))
      anim_start(text_state)
    else
      setValue(new_val)
  }

  local placeholderObj = null
  if (placeholder != null) {
    let phBase = {
      text = placeholder
      rendObj = ROBJ_TEXT
      font
      fontSize
      color = placeHolderColor
      animations = [failAnim(text_state)]
      margin = static [0, sh(0.5)]
    }
    placeholderObj = placeholder instanceof Watched
      ? @() phBase.__update({ watch = placeholder, text = placeholder.get() })
      : phBase
  }

  let inputObj = @() {
    watch = [text_state, stateFlags]
    rendObj = ROBJ_TEXT
    behavior = Behaviors.TextInput

    size
    font
    fontSize
    color = textColor
    group
    margin = textmargin
    valign = valignText

    animations = [failAnim(text_state)]

    text = text_state.get()
    title
    inputType = inputType
    password = password
    key = text_state

    maxChars
    hotkeys
    charMask

    onChange = onChangeExt

    onFocus
    onBlur   = onBlurExt
    onAttach
    onReturn = onReturnExt
    onEscape = onEscapeExt
    onHover
    onImeFinish
    xmbNode
    imeOpenJoyBtn

    children = (text_state.get()?.len() ?? 0)== 0
        && (showPlaceHolderOnFocus || !(stateFlags.get() & S_KB_FOCUS))
      ? placeholderObj
      : null
  }

  return @() {
    watch = [stateFlags]
    onElemState = @(sf) stateFlags.set(sf)
    margin
    padding

    rendObj = ROBJ_BOX
    fillColor = backGroundColor
    borderWidth = 0
    borderRadius
    clipChildren = true
    size = FLEX_H
    group
    animations = [failAnim(text_state)]
    valign

    children = frameCtor(inputObj, group, stateFlags.get())
  }
}


function makeFrame(inputObj, group, sf) {
  let isHover = sf & S_HOVER
  let isKbdFocus = sf & S_KB_FOCUS
  return {
    rendObj = ROBJ_BOX
    borderWidth = hdpx(1)
    fillColor = 0
    size = FLEX_H
    borderColor = isHover
        ? BtnBgHover
        : isKbdFocus ? BtnBgSelected : TextInputBdNormal
    group
    children = inputObj
    padding = static [0, hdpx(1)]
  }
}


function makeUnderline(inputObj, group, sf) {
  let isHover = sf & S_HOVER
  let isKbdFocus = sf & S_KB_FOCUS
  return {
    rendObj = ROBJ_BOX
    borderWidth = static [0, 0, hdpx(1), 0]
    fillColor = 0
    size = FLEX_H
    group = group
    borderColor = isHover
        ? BtnBgHover
        : isKbdFocus ? BtnBgSelected : TextInputBdNormal
    children = inputObj
  }
}

return {
  textInputUnderlined = @(text_state, options={}) textInput(text_state, options, makeUnderline)
  textInput = @(text_state, options={}) textInput(text_state, options, makeFrame)
}
