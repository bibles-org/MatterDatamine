from "%ui/ui_library.nut" import *

let { sub_txt } = require("%ui/fonts_style.nut")

let faComp = require("%ui/components/faComp.nut")
let { addModalPopup, removeModalPopup } = require("%ui/components/modalPopupWnd.nut")
let colors = require("%ui/components/colors.nut")

let panelBgColor = colors.BtnBgNormal
let commonBtnHeight = hdpx(40)
let defTxtColor = colors.BtnTextNormal
let midPadding = hdpx(10)
let darkTxtColor = colors.BtnTextNormal
let accentColor = colors.BtnBgHover
let commonBorderRadius = hdpx(3)
let smallBtnHeight = hdpx(30)
let disabledBgColor = colors.BtnBgDisabled

let isExpanded = Watched(false)
const WND_UID = "SELECTION_WND"

let calcLineBgColor = @(sf) sf & S_HOVER ? accentColor : panelBgColor

let defTxtStyle = {
  color = defTxtColor
}.__update(sub_txt)

let hoverTxtStyle = {
  color = darkTxtColor
}.__update(sub_txt)


let dropDownHead = @(label, onClick, sf, isEnabled) {
  rendObj = ROBJ_BOX
  borderRadius = commonBorderRadius
  fillColor = onClick == null || !isEnabled ? disabledBgColor
    : sf & S_HOVER ? accentColor
    : panelBgColor
  size = flex()
  flow = FLOW_HORIZONTAL
  gap = { size = flex() }
  padding = [0, midPadding]
  valign = ALIGN_CENTER
  behavior = Behaviors.Button
  onClick
  children = [
    {
      rendObj = ROBJ_TEXT
      text = label
    }.__update(sf & S_HOVER ? hoverTxtStyle : defTxtStyle)
    isExpanded.get()
      ? faComp("chevron-down", {
        fontSize = sub_txt.fontSize
        color = sf & S_HOVER ? hoverTxtStyle.color : defTxtStyle.color
      })
      : faComp("chevron-up", {
        fontSize = sub_txt.fontSize
        color = sf & S_HOVER ? hoverTxtStyle.color : defTxtStyle.color
      })
  ]
}


isExpanded.subscribe(@(v) v ? null : removeModalPopup(WND_UID))

function mkSelection(options, curValue, params = {}){
  let group = ElemGroup()
  let canBeExpanded = options.len() > 0
  let { header = null, isEnabled = true, onClickCb = null } = params

  let mkOptionItem = @(option) watchElemState(@(sf){
    rendObj = ROBJ_SOLID
    color = calcLineBgColor(sf)
    size = [flex(), smallBtnHeight]
    padding = [0, midPadding]
    valign = ALIGN_CENTER
    behavior = Behaviors.Button
    function onClick() {
      curValue.set(option)
      isExpanded(false)
      onClickCb?(option)
    }
    children = {
      rendObj = ROBJ_TEXT
      text = loc(option.locId)
    }.__update(sf & S_HOVER ? hoverTxtStyle : defTxtStyle)
  })

  function expandWnd(event) {
    if (!isEnabled)
      return
    isExpanded(true)
    addModalPopup(event.targetRect, {
      rendObj = ROBJ_WORLD_BLUR_PANEL
      uid = WND_UID
      size = [event.targetRect.r - event.targetRect.l,  SIZE_TO_CONTENT]
      popupHalign = ALIGN_LEFT
      padding = hdpx(1)
      borderRadius = commonBorderRadius
      flow = FLOW_VERTICAL
      group
      children = options.map(mkOptionItem)
    })
  }
  return watchElemState(@(sf) {
    watch = curValue
    size = [flex(), commonBtnHeight]
    behavior = Behaviors.Button
    children = dropDownHead(header ?? loc(curValue.get()?.locId ?? ""),
      canBeExpanded ? expandWnd : null, sf, isEnabled)
  }.__update(params))
}

let mkSmallSelection = @(options, curValue, params = {})
  mkSelection(options, curValue, { size = [flex(), smallBtnHeight] }.__update(params))


return {
  mkSelection
  mkSmallSelection
}