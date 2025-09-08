
from "%ui/ui_library.nut" import *

let { body_txt, sub_txt } = require("%ui/fonts_style.nut")
let { InfoTextValueColor, BtnBgFocused } = require("%ui/components/colors.nut")
let { mkText, mkTooltiped } = require("%ui/components/commonComponents.nut")
let { setTooltip } = require("%ui/components/cursors.nut")

function mkPlusComp(text, fontSize, visParams= const {}, facomp=null, tooltip=null) {
  let tp = tooltip ? @(v) mkTooltiped(v, tooltip) :
    @(v) v
  return tp({
    rendObj = ROBJ_BOX
    fillColor = BtnBgFocused
    borderRadius = hdpx(20)
    padding = const [ hdpx(2), hdpx(10), hdpx(2), hdpx(10) ]
    hplace = ALIGN_RIGHT
    vplace = ALIGN_TOP
    pos = const [ pw(10), ph(10) ]
    flow = FLOW_HORIZONTAL
    gap = hdpx(5)

    children = [
      facomp
      {
        rendObj = ROBJ_TEXT
        text
        fontFx = FFT_GLOW
        fontFxColor = Color(0, 0, 0, 255)
        font = Fonts.system
        fontSize
      }
    ]
  }.__merge(visParams))
}

function mkIcon(icon, itemCount, iconBlockSize, fontSize, isAdded) {
  return {
    size = iconBlockSize
    children = [
      icon,
      itemCount > 0 ? mkPlusComp(isAdded ? $"+{itemCount}" : itemCount, fontSize) : null
    ]
  }
}

function mkItemPanel(icon, nameLoc, itemTypeLoc, count, tooltip, iconBlockSize, fontSize, infoTextColor, isAdded) {
  return {
    size = [iconBlockSize[0], SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    vplace = ALIGN_TOP
    valign = ALIGN_TOP
    gap = hdpx(10)
    behavior = Behaviors.Button
    onHover = @(on) setTooltip(on && tooltip != "" ? tooltip : null)
    children = [
      mkIcon(icon, count, iconBlockSize, fontSize, isAdded)
      {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        gap = hdpx(5)
        children = [
          itemTypeLoc && isAdded ? mkText(itemTypeLoc, {color = infoTextColor}) : null
          nameLoc == null ? null : {
            rendObj = ROBJ_TEXTAREA
            size = [flex(), SIZE_TO_CONTENT]
            behavior = Behaviors.TextArea
            halign = ALIGN_CENTER
            text = nameLoc
          }.__update(isAdded ? body_txt : sub_txt)
        ]
      }
    ]
  }
}

let mkReceivedPanel = @(icon, nameLoc, itemTypeLoc, count, tooltip = "" )
    mkItemPanel(icon, nameLoc, itemTypeLoc, count, tooltip,
      [hdpx(200), hdpx(200)], fsh(2.037), InfoTextValueColor, true)

let mkInitialItemPanel = @(icon, nameLoc, itemTypeLoc, count, tooltip = "")
    mkItemPanel(icon, nameLoc, itemTypeLoc, count, tooltip,
      [hdpx(100), hdpx(100)], sub_txt.fontSize, InfoTextValueColor, false)


return {
  mkPlusComp
  mkReceivedPanel
  mkInitialItemPanel
}