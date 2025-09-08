from "%ui/ui_library.nut" import *
from "%ui/components/colors.nut" import HUD_TIPS_HOTKEY_FG

let {sub_txt} = require("%ui/fonts_style.nut")
let {buildElems, textListFromAction} = require("%ui/control/formatInputBinding.nut")
let parseDargHotkeys =  require("%ui/components/parseDargHotkeys.nut")
let {isGamepad} = require("%ui/control/active_controls.nut")

function container(children, params={}){
  return {
    children = {
      speed = [60,800]
      delay = 0.3
      children = children
      flow = FLOW_HORIZONTAL
      behavior = [Behaviors.Marquee]
      scrollOnHover = true
      maxWidth = pw(100)
      size = SIZE_TO_CONTENT
      halign = ALIGN_LEFT
      valign = ALIGN_CENTER
    }
    clipChildren = true
    size = SIZE_TO_CONTENT
    padding = [hdpx(4), hdpx(6)]
  }.__update(params)
}

function makeHintRow(hotkeys, params={}) {
  let frame = params?.frame ?? true
  let font = params?.text_params?.font ?? sub_txt?.font
  let fontSize = params?.text_params?.fontSize ?? sub_txt.fontSize
  let color = params?.color ?? HUD_TIPS_HOTKEY_FG
  let width = params?.width ?? SIZE_TO_CONTENT
  let height = params?.height ?? SIZE_TO_CONTENT

  function makeControlText(text) {
    return {
      text, fontSize, font, color, rendObj = ROBJ_TEXT
    }
  }

  let noWatchGamepad = params?.column != null
  return function(){
    let isGamepadV = noWatchGamepad ? params.column == 1 : isGamepad.get()
    let parsed = parseDargHotkeys(hotkeys)
    let rowTexts = parsed?[isGamepadV ? "gamepad" : "kbd"] ?? []
    let dainputs = (parsed?["dainput"] ?? []).map(@(v) v.slice(1))
    let column = isGamepad.get() ? 1 : 0
    let disableFrame = isGamepadV
    if (rowTexts.len() == 0 && dainputs.len()==0)
      return null
    let elems = buildElems(
      dainputs.len() > 0
        ? textListFromAction(dainputs[0], column)
        : rowTexts, {textFunc = (params?.textFunc ?? makeControlText), compact = true}
      )
    return {
      watch = noWatchGamepad ? null : isGamepad
      size = [width, height]
      halign = ALIGN_CENTER,
      valign = ALIGN_CENTER,
      children = [
        container(elems, params?.text_params ?? {}),
        frame && !disableFrame ? { rendObj = ROBJ_FRAME, color = HUD_TIPS_HOTKEY_FG, size = flex(), opacity = 0.3 } : null
      ]
    }
  }
}
function mkHotkey(hotkey, action=null, params={}){
  return {
    children = makeHintRow(hotkey, params)
    size = SIZE_TO_CONTENT
    hotkeys = [[hotkey, {action, description={skip=true}}]]
  }.__merge(params)
}

return {
  mkHintRow = makeHintRow
  mkHotkey
}