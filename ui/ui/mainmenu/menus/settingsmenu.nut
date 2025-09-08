from "%ui/ui_library.nut" import *

let {body_txt} = require("%ui/fonts_style.nut")
let {ControlBg, panelRowColor, OptionRowBgHover, OptionRowBdHover} = require("%ui/components/colors.nut")
let {setTooltip} = require("%ui/components/cursors.nut")
let JB = require("%ui/control/gui_buttons.nut")
let optionLabel = require("options/optionLabel.nut")
let {makeVertScrollExt} = require("%ui/components/scrollbar.nut")
let active_controls = require("%ui/control/active_controls.nut")
let settingsHeaderTabs = require("settingsHeaderTabs.nut")

let windowButtons = @(buttons, cancelHandler=null) function() {
  return {
    size = [flex(), SIZE_TO_CONTENT]
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
    size = const [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    behavior = Behaviors.Button
    onHover = hint == null ? null : @(on) setTooltip(on ? hint : null)
    onElemState = @(sf) stateFlags(sf)
    skipDirPadNav = true
    children
    rendObj = ROBJ_BOX
    margin = const [0, fsh(8)]
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
    return const {}

  let baseHeight = fsh(4.8)
  let height = baseHeight
  let label = optionLabel(opt, group)

  let row = {
    padding = const [0, hdpx(12)]
    size = const [flex(), height]
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
let sepLine = freeze({size = [flex(), hdpx(2)], rendObj = ROBJ_SOLID, color=sepColor})

function mkSeparator(opt){
  let hasName = "name" in opt
  return freeze({
    size = [flex(), SIZE_TO_CONTENT]
    valign = ALIGN_CENTER
    flow = FLOW_VERTICAL
    padding = [hdpx(20), hdpx(20), 0, hdpx(20)]
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

function optionsPage(options, currentTab) {
  let xmbNode = XmbContainer({wrap=true})
  return function() {
    let optionControls = options.filter(@(v) v.tab == currentTab.get())
      .filter(@(val, idx, arr) !isSeparator(val) || ((idx+1 < arr.len()) && !isSeparator(arr?[idx+1])))
      .map(@(v) isSeparator(v) ? mkSeparator(v) : makeOptionRow(v))
    return {
      size = flex()
      watch = currentTab
      behavior = Behaviors.Button

      children = makeVertScrollExt({
        flow = FLOW_VERTICAL
        xmbNode
        key = currentTab.get()
        size = [flex(), SIZE_TO_CONTENT]
        padding = [fsh(1), 0]
        gap = hdpx(4)
        clipChildren = true
        animations
        children = optionControls
      },{ rootBase = {
          behavior = [Behaviors.Pannable]
          wheelStep = 0.82
        }
      })
    }
  }
}


let settingsMenu = kwarg(function(sourceTabs, currentTab, buttons, options, cancelHandler=null, size=[fsh(90), sh(80)], key=null) {
  return @(){
    size = [sw(100), sh(100)]
    watch = active_controls.isGamepad
    key
    children = {
      
      
      transform = {}
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
        settingsHeaderTabs(currentTab, sourceTabs)
        optionsPage(options, currentTab)
        windowButtons(buttons, cancelHandler)
      ]
    }
    animations = [
      { prop=AnimProp.opacity, from=0, to=1, duration=0.2, play=true, easing=InOutCubic}
      { prop=AnimProp.opacity, from=1, to=0, duration=0.2, playFadeOut=true, easing=InOutCubic}
    ]
  }
})


return settingsMenu
