from "%dngscripts/sound_system.nut" import sound_play
from "%ui/components/colors.nut" import BtnBgFocused, BtnBdHover, BtnBgHover, BtnBdNormal, ControlBgOpaque
from "%ui/components/sounds.nut" import buttonSound
from "%ui/components/cursors.nut" import setTooltip
from "%ui/cursorState.nut" import showCursor
from "%ui/ui_library.nut" import *
import "math" as math

#allow-auto-freeze

let calcFrameColor = @(sf) (sf & S_KB_FOCUS)
    ? BtnBgFocused
    : (sf & S_HOVER) ? BtnBdHover : BtnBdNormal

let knobActiveColor = mul_color(BtnBdHover, 0.6)
let knobNormalColor = mul_color(BtnBdHover, 0.3)
let knobHoverColor = BtnBdHover
let calcKnobColor =  @(sf) (sf & S_KB_FOCUS)
  ? knobActiveColor
  : (sf & S_HOVER)
    ? knobHoverColor
    : knobNormalColor

let logarithmic_scale = {
  to = @(value, minv, maxv) value == 0 ? 0 : math.log(value.tofloat() / minv) / math.log(maxv / minv)
  from = @(factor, minv, maxv) minv * math.pow(maxv / minv, factor)
}

let scales = freeze({
  logarithmic = logarithmic_scale
  linear = {
    to = @(value, minv, maxv) (value.tofloat() - minv) / (maxv - minv)
    from = @(factor, minv, maxv) factor.tofloat() * (maxv - minv) + minv
  }
  logarithmicWithZero = {
    to = @(value, minv, maxv) logarithmic_scale.to(value.tofloat(), minv, maxv)
    from = @(factor, minv, maxv) factor == 0 ? 0 : logarithmic_scale.from(factor, minv, maxv)
  }
})

let sliderLeftLoc = loc("slider/reduce", "Reduce value")
let sliderRightLoc = loc("slider/increase", "Increase value")

function slider(orient, var, options={}) {
  let minval = options?.min ?? 0
  let maxval = options?.max ?? 1
  let group = options?.group ?? ElemGroup()
  let rangeval = maxval-minval
  let scaling = options?.scaling ?? scales.linear
  let step = options?.step
  let unit = options?.unit && options?.scaling!=scales.linear
    ? options?.unit
    : step ? step/rangeval : 0.01
  let pageScroll = options?.pageScroll ?? step ?? 0.05
  let ignoreWheel = options?.ignoreWheel ?? true
  let bgColor = options?.bgColor ?? ControlBgOpaque
  let hint = options?.hint
  let sliderStateFlags = Watched(0)

  function knob() {
    let sf = sliderStateFlags.get()
    return {
      rendObj = ROBJ_BOX
      size  = static [fsh(1), fsh(2)]
      fillColor = calcKnobColor(sf)
      borderWidth = hdpx(1)
      borderColor = sf & S_HOVER ? BtnBgHover : BtnBdNormal
      watch = sliderStateFlags
      group
      
    }
  }

  let setValue = options?.setValue ?? @(v) var.set(v)
  function onChange(factor){
    let value = orient == O_HORIZONTAL
      ? scaling.from(factor, minval, maxval)
      : scaling.from(factor, maxval, minval)
    let oldValue = var.get()
    setValue(value)
    if (oldValue != var.get())
      sound_play("ui_sounds/slider")
  }

  let hotkeysElem = {
    key = "hotkeys"
    hotkeys = [
      ["Left | J:D.Left", sliderLeftLoc, function() {
        let delta = maxval > minval ? -pageScroll : pageScroll
        onChange(clamp(scaling.to(var.get() + delta, minval, maxval), 0, 1))
      }],
      ["Right | J:D.Right", sliderRightLoc, function() {
        let delta = maxval > minval ? pageScroll : -pageScroll
        onChange(clamp(scaling.to(var.get() + delta, minval, maxval), 0, 1))
      }],
    ]
  }
  #forbid-auto-freeze
  return function() {
    let factor = clamp(scaling.to(var.get(), minval, maxval), 0, 1)
    return {
      watch = [var, sliderStateFlags, showCursor]
      size = flex()
      behavior = showCursor.get() ? Behaviors.Slider : null
      sound = buttonSound
      orientation = orient

      min = 0
      max = 1
      unit
      pageScroll
      ignoreWheel

      fValue = factor
      knob

      onChange
      onElemState = @(sf) sliderStateFlags.set(sf)
      onHover = hint ? @(on) setTooltip(on ? hint : null) : null
      valign = ALIGN_CENTER
      flow = orient == O_HORIZONTAL ? FLOW_HORIZONTAL : FLOW_VERTICAL

      xmbNode = options?.xmbNode

      children = [
        {
          group
          rendObj = ROBJ_SOLID
          color = orient == O_HORIZONTAL
            ? (sliderStateFlags.get() & S_HOVER) ? BtnBgHover : BtnBdNormal
            : bgColor
          size = orient == O_HORIZONTAL ? [flex(factor), fsh(1)] : [fsh(1), flex(1.0 - factor)]

          children = {
            rendObj = ROBJ_FRAME
            color = calcFrameColor(sliderStateFlags.get())
            borderWidth = orient == O_HORIZONTAL ? [hdpx(1),0,hdpx(1),hdpx(1)] : 0
            size = flex()
          }
        }
        knob
        {
          group
          rendObj = ROBJ_SOLID
          color = bgColor
          size =  orient == O_HORIZONTAL ? [flex(1.0 - factor), fsh(1)] : [fsh(1), flex(factor)]

          children = {
            rendObj = ROBJ_FRAME
            color = calcFrameColor(sliderStateFlags.get())
            borderWidth = orient == O_HORIZONTAL ? [1,1,1,0] : 0
            size = flex()
          }
        }
        sliderStateFlags.get() & S_HOVER ? hotkeysElem  : null
      ]
    }
  }
}


return freeze({
  Horiz = @(var, options={}) slider(O_HORIZONTAL, var, options)
  Vert  = @(var, options={}) slider(O_VERTICAL, var, options)
  scales
})
