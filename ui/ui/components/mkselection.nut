from "%ui/fonts_style.nut" import sub_txt
import "%ui/components/faComp.nut" as faComp
from "%ui/components/modalPopupWnd.nut" import addModalPopup, removeModalPopup

from "%ui/ui_library.nut" import *
import "%ui/components/colors.nut" as colors

#allow-auto-freeze


let panelBgColor = colors.BtnBgNormal
let commonBtnHeight = hdpx(40)
let defTxtColor = colors.BtnTextNormal
let midPadding = hdpx(10)
let darkTxtColor = colors.BtnTextNormal
let accentColor = colors.BtnBgHover
let commonBorderRadius = hdpx(3)
let smallBtnHeight = hdpx(30)
let tinyBtnHeight = hdpx(20)
let disabledBgColor = colors.BtnBgDisabled

const WND_UID = "SELECTION_WND"

let calcLineBgColor = @(sf) sf & S_HOVER ? accentColor : panelBgColor

let defStyle = {
  color = defTxtColor
}.__update(sub_txt)

let hoverStyle = {
  color = darkTxtColor
}.__update(sub_txt)


let dropDownHead = @(label, onClick, isExpanded, sf, isEnabled, defTxtStyle, hoverTxtStyle) @(){
  watch = isExpanded
  rendObj = ROBJ_BOX
  borderRadius = commonBorderRadius
  fillColor = onClick == null || !isEnabled ? disabledBgColor
    : sf & S_HOVER ? accentColor
    : panelBgColor
  size = flex()
  flow = FLOW_HORIZONTAL
  gap = hdpx(4)
  padding = static [0, midPadding]
  valign = ALIGN_CENTER
  behavior = Behaviors.Button
  onClick
  children = [
    {
      rendObj = ROBJ_TEXT
      size = flex()
      valign = ALIGN_CENTER
      text = label
      behavior = Behaviors.Marquee
    }.__update(sf & S_HOVER ? hoverTxtStyle : defTxtStyle)
    isExpanded.get()
      ? faComp("chevron-down", {
        size = FLEX_V
        valign = ALIGN_CENTER
        fontSize = sf & S_HOVER ? hoverTxtStyle.fontSize : defTxtStyle.fontSize
        color = sf & S_HOVER ? hoverTxtStyle.color : defTxtStyle.color
      })
      : faComp("chevron-up", {
        size = FLEX_V
        valign = ALIGN_CENTER
        fontSize = sf & S_HOVER ? hoverTxtStyle.fontSize : defTxtStyle.fontSize
        color = sf & S_HOVER ? hoverTxtStyle.color : defTxtStyle.color
      })
  ]
}

let mkOptionItem = function(option, curValue, size, defTxtStyle, hoverTxtStyle, onClickCb) {
  let stateFlags = Watched(0)
  return function() {
    let sf = stateFlags.get()
    return {
      watch = stateFlags
      onElemState = @(s) stateFlags.set(s)
      rendObj = ROBJ_SOLID
      color = calcLineBgColor(sf)
      size = static [flex(), smallBtnHeight]
      padding = static [0, midPadding]
      valign = ALIGN_CENTER
      behavior = Behaviors.Button
      function onClick() {
        if ("setValue" in option)
          option.setValue(option)
        else
          curValue.set(option)
        onClickCb(option)
      }
      children = {
        behavior = Behaviors.Marquee
        rendObj = ROBJ_TEXT
        valign = ALIGN_CENTER
        size
        text = loc(option.locId)
      }.__update(sf & S_HOVER ? hoverTxtStyle : defTxtStyle)
    }
  }
}

#allow-auto-freeze

function mkSelection(options, curValue, params = {}){
  let group = ElemGroup()
  let isExpanded = Watched(false)
  let canBeExpanded = options.len() > 0
  let { header = null, isEnabled = true, onClickCb = null,
    size = [flex(), commonBtnHeight], defTxtStyle=defStyle, hoverTxtStyle=hoverStyle } = params

  let optionCallback = function(option) {
    isExpanded.set(false)
    removeModalPopup(WND_UID)
    onClickCb?(option)
  }

  function expandWnd(event) {
    if (!isEnabled)
      return

    #forbid-auto-freeze
    isExpanded.set(true)
    addModalPopup(event.targetRect, {
      rendObj = ROBJ_WORLD_BLUR_PANEL
      uid = WND_UID
      size = [event.targetRect.r - event.targetRect.l,  SIZE_TO_CONTENT]
      popupHalign = ALIGN_LEFT
      padding = hdpx(1)
      borderRadius = commonBorderRadius
      flow = FLOW_VERTICAL
      group
      children = options.map(@(option) mkOptionItem(option, curValue, size, defTxtStyle, hoverTxtStyle, optionCallback))
      onDetach = @() isExpanded.set(false)
    })
  }
  let stateFlags = Watched(0)
  return function() {
    let sf = stateFlags.get()
    return {
      watch = [stateFlags, curValue]
      onElemState = @(s) stateFlags.set(s)
      size
      behavior = Behaviors.Button
      children = dropDownHead(header ?? loc(curValue.get()?.locId ?? ""),
        canBeExpanded ? expandWnd : null, isExpanded, sf, isEnabled,
        defTxtStyle, hoverTxtStyle)
    }.__update(params)
  }
}

let mkSmallSelection = @(options, curValue, params = {})
  mkSelection(options, curValue, { size = static [flex(), smallBtnHeight] }.__update(params))

let mkTinySelection = @(options, curValue, params = {})
  mkSelection(options, curValue, { size = static [flex(), tinyBtnHeight] }.__update(params))


return {
  mkSelection
  mkSmallSelection
  mkTinySelection
  tinyBtnHeight
}
