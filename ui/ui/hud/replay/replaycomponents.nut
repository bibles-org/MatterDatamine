from "%dngscripts/sound_system.nut" import sound_play

from "%ui/helpers/time.nut" import secondsToString
from "%ui/fonts_style.nut" import sub_txt
import "%ui/components/faComp.nut" as faComp

from "%ui/ui_library.nut" import *

let cursors = require("%ui/components/cursors.nut")

  
let smallPadding = hdpxi(4)
let commonBorderRadius = hdpx(2)
  
let panelBgColor = 0xFF313C45
let hoverPanelBgColor = 0xFF59676E
let darkPanelBgColor = 0xFF13181F
let disabledBgColor = 0xFF292E33
let accentColor = 0xFFFAFAFA
  
let defBdColor    = 0xFFB3BDC1
let disabledBdColor = 0xFF4B575D
let hoverBdColor  = 0xFF132438
  
let disabledTxtColor = 0xFF4B575D
let defTxtColor = 0xFFB3BDC1
let hoverTxtColor = 0xFFD4D4D4
let titleTxtColor = 0xFFFAFAFA
let darkTxtColor = 0xFF313841

let knobSize = [hdpxi(14), hdpxi(14)]
let blockPadding = smallPadding
let blockSize = [hdpx(50), knobSize[1] + 2 * blockPadding]
let transitions = [ { prop = AnimProp.translate, duration = 0.15, easing = InOutCubic } ]
let disabledPos = { translate = [knobSize[0] / 2 + blockPadding, 0] }
let activePos = { translate = [blockSize[0] - knobSize[0] / 2 - blockPadding, 0] }


let mkLabel = @(label, size, isActive) {
  rendObj = ROBJ_TEXTAREA
  size
  behavior = Behaviors.TextArea
  text = label
  halign = ALIGN_RIGHT
}.__update(sub_txt, !isActive ? static { color = disabledTxtColor } : static {})


let checkBox = @(isChecked, isActive, isHovered) {
  size = hdpxi(18)
  rendObj = ROBJ_BOX
  borderWidth = isHovered ? hdpx(2) : hdpx(1)
  borderRadius = commonBorderRadius * 2
  borderColor = isActive ? accentColor : disabledBdColor
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  fillColor = isActive ? panelBgColor : disabledBgColor
  children = !isChecked ? null : static faComp("check", {
    color = accentColor
    fontSize = hdpxi(12)
  })
}


function mkCheckbox(isChecked, label, isActive = true, setValue = null) {
  let onClick = !isActive ? null : (setValue ? @() setValue(!isChecked.get()) :  @() isChecked.modify(@(v) !v))
  let stateFlags = Watched(0)
  return function() {
    let sf = stateFlags.get()
    return {
      watch = [stateFlags, isChecked]
      onElemState = @(s) stateFlags.set(s)
      size = FLEX_H
      behavior = Behaviors.Button
      onClick
      valign = ALIGN_CENTER
      flow = FLOW_HORIZONTAL
      gap = hdpxi(8)
      children = [
        checkBox(isChecked.get(), isActive, sf & S_HOVER)
        mkLabel(label, FLEX_H, isActive)
      ]
    }
  }
}


function mkTimeline(var, options={}) {
  let minval = options?.min ?? 0
  let maxval = options?.max ?? 1
  let group = ElemGroup()


  let setValue = options?.setValue ?? @(v) var.set(v)
  function onChange(factor){
    let value = factor.tofloat() * (maxval - minval) + minval
    if (!(options?.canChangeVal ?? true))
      return
    setValue(value)
  }

  return function() {
    let factor = ((maxval - minval) < 1e-6) ? 0.0 : clamp((var.get().tofloat() - minval) / (maxval - minval), 0, 1)
    return {
      watch = var
      size = static [flex(), hdpx(16)]
      behavior = Behaviors.Slider
      min = 0
      max = 1
      unit = 0.001
      group
      fValue = factor
      onChange
      onSliderMouseMove = @(val) cursors.setTooltip(val == null ? null : secondsToString(val.tofloat() * (maxval - minval) + minval))
      valign = ALIGN_CENTER
      children = [
        {
          flow = FLOW_HORIZONTAL
          size = flex()
          children = [
            {
              group
              rendObj = ROBJ_BOX
              size = [flex(factor), flex()]
              fillColor = titleTxtColor
              borderRadius = factor < 1.0
                ? [commonBorderRadius, 0, 0, commonBorderRadius]
                : commonBorderRadius
              borderColor = accentColor
            }
            {
              group
              rendObj = ROBJ_BOX
              fillColor = defBdColor
              borderRadius = factor > 0.0
                ? [0, commonBorderRadius, commonBorderRadius, 0]
                : commonBorderRadius
              size = [flex(1.0 - factor), flex()]
            }
          ]
        }
      ]
    }
  }
}

let calcEmptyFrameColor = @(sf, isEnabled) !isEnabled ? hoverPanelBgColor
  : sf & S_HOVER ? darkPanelBgColor
  : hoverPanelBgColor

let calcKnobFrameColor = @(sf, isEnabled) !isEnabled ? hoverPanelBgColor
  : sf & S_ACTIVE ? darkTxtColor
  : sf & S_HOVER ? hoverPanelBgColor
  : accentColor


let defLabelStyle = {
  color = defTxtColor
}.__update(sub_txt)


let hoverLabelStyle = {
  color = titleTxtColor
}.__update(sub_txt)


function mkSlider(var, label, options = {}) {
  let minval = options?.min ?? 0
  let maxval = options?.max ?? 1
  let setValue = options?.setValue ?? @(v) var.set(v)
  let rangeval = maxval - minval
  let step = options?.step ?? 0
  let unit = (options?.unit ?? step) ? step / rangeval : 0.01
  let isEnabled = options?.isEnabled ?? true
  let group = ElemGroup()

  let knobStateFlags = Watched(0)
  let knob = function() {
    let sf = knobStateFlags.get()
    return {
      watch = knobStateFlags
      onElemState = @(s) knobStateFlags.set(s)
      size = knobSize
      group
      rendObj = ROBJ_VECTOR_CANVAS
      commands = [[ VECTOR_ELLIPSE, 0, 50, 50, 50 ]]
      fillColor = !isEnabled ? darkTxtColor : accentColor
      color = calcKnobFrameColor(sf, isEnabled)
    }
  }

  let sliderText = @(text, sf) {
    rendObj = ROBJ_TEXT
    group
    text
  }.__update(isEnabled && (sf & S_HOVER) ? hoverLabelStyle : defLabelStyle)


  function onChange(factor){
    let value = factor.tofloat() * (maxval - minval) + minval
    if (!isEnabled)
      return
    setValue(value)
  }

  let stateFlags = Watched(0)
  return function() {
    let sf = stateFlags.get()
    let factor = clamp((var.get().tofloat() - minval) / (maxval - minval), 0, 1)
    let valueToShow = options?.valueToShow ?? var.get()
    return {
      watch = [stateFlags, var]
      onElemState = @(s) stateFlags.set(s)
      size = FLEX_H
      behavior = Behaviors.Slider
      min = 0
      max = 1
      unit
      ignoreWheel = true
      group
      fValue = factor
      onChange
      flow = FLOW_VERTICAL
      gap = smallPadding
      children = [
        {
          size = FLEX_H
          children = [
            sliderText(label, sf)
            sliderText(valueToShow, sf).__update({ hplace = ALIGN_RIGHT })
          ]
        }
        {
          size = FLEX_H
          valign = ALIGN_CENTER
          children = [
            {
              flow = FLOW_HORIZONTAL
              size = static [flex(), hdpx(6)]
              children = [
                {
                  group
                  rendObj = ROBJ_BOX
                  size = [flex(factor), flex()]
                  fillColor = isEnabled ? hoverPanelBgColor : accentColor
                  borderWidth = sf & S_HOVER ? hdpx(1) : hdpx(0)
                  borderRadius = factor < 100.0 ? [hdpx(2), 0, 0, hdpx(2)] : hdpx(2)
                  borderColor = accentColor
                }
                {
                  group
                  rendObj = ROBJ_BOX
                  fillColor = calcEmptyFrameColor(sf, isEnabled)
                  borderRadius = factor > 0.0 ? [0, hdpx(2), hdpx(2), 0] : hdpx(2)
                  size = [flex(1.0 - factor), flex()]
                }
              ]
            }
            {
              pos = [pw(factor * 100), 0]
              children = knob
            }
          ]
        }
      ]
    }
  }
}

function mkToggle(curValue, isEnabled = true, setValue = null){
  let group = ElemGroup()

  let knobStateFlags = Watched(0)
  let knob = function() {
    let sf = knobStateFlags.get()
    return {
      watch = [knobStateFlags, curValue]
      onElemState = @(s) knobStateFlags.set(s)
      size = knobSize
      transform = curValue.get() ? activePos : disabledPos
      transitions
      group
      rendObj = ROBJ_VECTOR_CANVAS
      commands = static [[ VECTOR_ELLIPSE, 0, 50, 50, 50 ]]
      fillColor = !isEnabled ? disabledTxtColor
        : sf & S_ACTIVE ? panelBgColor
        : sf & S_HOVER ? accentColor
        : hoverPanelBgColor
      color = !isEnabled ? disabledBgColor
        : sf & S_ACTIVE ? titleTxtColor
        : hoverTxtColor
    }
  }

  let stateFlags = Watched(0)
  return function() {
    let sf = stateFlags.get()
    return {
      watch = [stateFlags, curValue]
      onElemState = @(s) stateFlags.set(s)
      rendObj = ROBJ_BOX
      fillColor = curValue.get() ? darkPanelBgColor : panelBgColor
      borderRadius = blockSize[0] * 0.5
      borderColor = sf & S_HOVER ? hoverBdColor : defBdColor
      borderWidth = hdpx(1)
      group
      size = blockSize
      valign = ALIGN_CENTER
      behavior = Behaviors.Button
      onClick = function() {
        if (isEnabled) {
          if (setValue)
            setValue(!curValue.get())
          else
            curValue.modify(@(v) !v)
          sound_play(curValue.get() ? "ui_sounds/flag_set" : "ui_sounds/flag_unset")
        }
      }
      children = knob
    }
  }
}


return {
  mkCheckbox
  mkTimeline
  mkSlider
  mkToggle
  panelBgColor, defTxtColor, smallPadding, titleTxtColor, accentColor
}