from "%ui/fonts_style.nut" import body_txt, sub_txt
from "%ui/components/colors.nut" import InfoTextValueColor, BtnBgFocused
from "%ui/components/commonComponents.nut" import mkText, mkTooltiped
from "%ui/components/cursors.nut" import setTooltip


from "%ui/ui_library.nut" import *


function mkPlusComp(text, fontSize, visParams= static {}, facomp=null, tooltip=null) {
  let tp = tooltip ? @(v) mkTooltiped(v, tooltip) :
    @(v) v
  return tp({
    rendObj = ROBJ_BOX
    fillColor = BtnBgFocused
    borderRadius = hdpx(20)
    padding = static [ hdpx(2), hdpx(10), hdpx(2), hdpx(10) ]
    hplace = ALIGN_RIGHT
    vplace = ALIGN_TOP
    pos = static [ pw(10), ph(10) ]
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
        size = FLEX_H
        flow = FLOW_VERTICAL
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        gap = hdpx(5)
        children = [
          itemTypeLoc && isAdded ? mkText(itemTypeLoc, {color = infoTextColor}) : null
          nameLoc == null ? null : {
            rendObj = ROBJ_TEXTAREA
            size = FLEX_H
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