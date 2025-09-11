from "%ui/fonts_style.nut" import body_txt, h2_txt
from "%ui/components/colors.nut" import ControlBg, panelRowColor, OptionRowBgHover, OptionRowBdHover
from "%ui/components/cursors.nut" import setTooltip
import "%ui/mainMenu/menus/options/optionLabel.nut" as optionLabel
from "%ui/components/scrollbar.nut" import makeVertScrollExt
import "%ui/mainMenu/menus/settingsHeaderTabs.nut" as settingsHeaderTabs
from "%ui/components/textInput.nut" import textInput
from "%sqstd/string.nut" import utf8ToLower
from "%ui/components/commonComponents.nut" import fontIconButton, mkText
from "%ui/ui_library.nut" import *

let JB = require("%ui/control/gui_buttons.nut")
let active_controls = require("%ui/control/active_controls.nut")

let customSettingsFilter = Watched("")

function deleteInputTextBtn() {
  let watch = customSettingsFilter
  if (customSettingsFilter.get().len() <= 0)
    return { watch }
  return {
    watch
    hplace = ALIGN_RIGHT
    vplace = ALIGN_CENTER
    margin = static [0, hdpx(10),0,0]
    children = fontIconButton("icon_buttons/x_btn.svg", @() customSettingsFilter.set(""),
      { padding = hdpx(2) }
    )
  }
}

let searchInputBlock = {
  flow = FLOW_HORIZONTAL
  gap = static hdpx(4)
  margin = static [hdpx(10), hdpx(20)]
  children = [
    {
      size = static [hdpx(400), SIZE_TO_CONTENT]
      children = textInput(customSettingsFilter, {
        placeholder = loc("search by name")
        textmargin = static hdpx(5)
        margin = 0
        onChange = function(value) {
          customSettingsFilter.set(value)
        }
        onEscape = function() {
          if (customSettingsFilter.get() == "")
            set_kb_focus(null)
          customSettingsFilter.set("")
        }
      }.__update(body_txt))
    }
    deleteInputTextBtn
  ]
}

let windowButtons = @(buttons, cancelHandler=null) function() {
  return {
    size = FLEX_H
    vplace = ALIGN_BOTTOM
    hplace = ALIGN_RIGHT
    flow = FLOW_HORIZONTAL
    halign = ALIGN_RIGHT
    valign = ALIGN_CENTER
    rendObj = ROBJ_SOLID
    color = ControlBg

    padding = fsh(0.5)
    children = buttons

    eventHandlers = {
      [JB.B] = @(_event) cancelHandler?(),
    }
  }
}

function optionRowContainer(children, hint=null) {
  let stateFlags = Watched(0)
  return @() {
    watch = stateFlags
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    behavior = Behaviors.Button
    onHover = hint == null ? null : @(on) setTooltip(on ? hint : null)
    onElemState = @(sf) stateFlags.set(sf)
    skipDirPadNav = true
    children
    rendObj = ROBJ_BOX
    margin = static [0, fsh(8)]
    fillColor = stateFlags.get() & S_HOVER ? OptionRowBgHover : panelRowColor
    borderWidth = stateFlags.get() & S_HOVER ? [hdpx(2), 0] : 0
    borderColor = OptionRowBdHover
    gap = fsh(2)
  }
}

function makeOptionRow(opt) {
  let group = ElemGroup()
  let xmbNode = XmbNode()

  let widget = opt.widgetCtor(opt, group, xmbNode)
  if (!widget)
    return static {}

  let baseHeight = fsh(4.8)
  let height = baseHeight
  let label = optionLabel(opt, group)

  let row = {
    padding = static [0, hdpx(12)]
    size = static [flex(), height]
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    gap = fsh(2)
    children = [
      label
      widget
    ]
  }

  return optionRowContainer(row, opt?.hint)
}

let sepColor = Color(120,120,120)
let sepLine = freeze({size = static [flex(), hdpx(2)], rendObj = ROBJ_SOLID, color=sepColor})

function mkSeparator(opt){
  let hasName = "name" in opt
  return freeze({
    size = FLEX_H
    valign = ALIGN_CENTER
    flow = FLOW_VERTICAL
    padding = static [hdpx(20), hdpx(20), 0, hdpx(20)]
    gap = hdpx(10)
    children = hasName ? [
      {
        rendObj = ROBJ_TEXT text = opt?.name color = sepColor
        fontFxColor = Color(0, 0, 0, 90)
        fontFxFactor = min(hdpx(48), 64)
        fontFx = FFT_GLOW
        fontFxOffsX = hdpx(1)
        fontFxOffsY = hdpx(1)
      }.__update(body_txt)
      sepLine
    ] : sepLine
  })
}
let isSeparator = @(v) v?.isSeparator

let animations = freeze([
  { prop=AnimProp.opacity, from=0, to=1, duration=0.2, play=true, easing=InOutCubic}
  { prop=AnimProp.opacity, from=1, to=0, duration=0.2, playFadeOut=true, easing=InOutCubic}
])

let emptyBlockText = mkText(loc("controls/activeSearchEmpty"), {
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
}.__merge(h2_txt))

function optionsPage(options, currentTab) {
  let xmbNode = XmbContainer({
    wrap = true
    scrollSpeed = 5.0
  })
  return function() {
    let optionControls = options.filter(@(v) customSettingsFilter.get().len() <= 0
        ? v.tab == currentTab.get()
        : utf8ToLower(v?.name ?? "").contains(utf8ToLower(customSettingsFilter.get())))
      .filter(@(val, idx, arr) !isSeparator(val) || ((idx+1 < arr.len()) && !isSeparator(arr?[idx+1])))
      .map(@(v) isSeparator(v) ? mkSeparator(v) : makeOptionRow(v))
    return {
      size = flex()
      watch = [currentTab, customSettingsFilter]
      behavior = Behaviors.Button
      children = makeVertScrollExt({
        flow = FLOW_VERTICAL
        xmbNode
        key = currentTab.get()
        size = FLEX_H
        padding = static [fsh(1), 0]
        gap = hdpx(4)
        clipChildren = true
        animations
        children = optionControls.len() <= 0 ? emptyBlockText
          : optionControls
      },{ rootBase = static {
          behavior = [Behaviors.Pannable]
          wheelStep = 0.82
        }
      })
    }
  }
}


let settingsMenu = kwarg(function(sourceTabs, currentTab, buttons, options, cancelHandler=null, size=static [fsh(90), sh(80)], key=null) {
  let resTabs = sourceTabs.map(@(v) v.__merge({
    isAvailable = Computed(@() customSettingsFilter.get().len() <= 0)
    unavailableHoverHint = loc("controls/activeSearch")
  }))
  return @(){
    size = static [sw(100), sh(100)]
    watch = active_controls.isGamepad
    key
    children = {
      
      
      transform = static {}
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      size
      rendObj = ROBJ_WORLD_BLUR_PANEL
      fillColor = Color(20,20,20,255)
      flow = FLOW_VERTICAL
      
      stopMouse = true
      behavior = DngBhv.ActivateActionSet
      actionSet = "StopInput"

      children = [
        settingsHeaderTabs(currentTab, resTabs)
        searchInputBlock
        optionsPage(options, currentTab)
        windowButtons(buttons, cancelHandler)
      ]
    }
    onDetach = @() customSettingsFilter.set("")
    animations = [
      { prop=AnimProp.opacity, from=0, to=1, duration=0.2, play=true, easing=InOutCubic}
      { prop=AnimProp.opacity, from=1, to=0, duration=0.2, playFadeOut=true, easing=InOutCubic}
    ]
  }
})


return settingsMenu
