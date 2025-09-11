from "math" import round

from "%ui/ui_library.nut" import *

#allow-auto-freeze

let calcWidth = memoize(@(text, font, fontSize) calc_str_box({rendObj = ROBJ_TEXT, text=text.tostring(), font, fontSize})[0])
function animatedDigit(start, end, textParams, trigger, onFinish, height, digitAnimDuration) {
  #forbid-auto-freeze
  let children = []
  let endAt = start >= end ? end + 10 : end
  let width = calcWidth(end, textParams.font, textParams.fontSize)
  for (local i = start; i <= endAt; i++) {
    children.append({
      rendObj = ROBJ_TEXT
      text = i % 10
      size = [width, height]
    }.__update(textParams))
  }
  #allow-auto-freeze
  let startPos = static [0, 0]
  let endPos = [0, -(endAt - start) * height]
  let idleTrigger = $"{trigger}_stop"
  return {
    size = FLEX_V
    clipChildren = true
    key = endAt
    children = {
      flow = FLOW_VERTICAL
      halign = ALIGN_CENTER
      children
      transform = { translate = endPos }
      animations = [
        { prop = AnimProp.translate, from = startPos, to = startPos, play = true
          trigger = idleTrigger }
        { prop = AnimProp.translate, from = startPos, to = endPos, easing = InOutCubic
          trigger, onFinish
          onStart = @() anim_skip(idleTrigger)
          duration = digitAnimDuration }
      ]
    }
  }
}
function animateNumbers(value, textParams, animParams = {}) {
  let { fontSize, font } = textParams
  local {
    digitAnimDuration = 1.0, bigScale = null, scaleDuration = 0.0,
    onFinish = null, trigger = null, startValue = 0
  } = animParams

  let triggerScale = $"{trigger}_scale"
  let onDigitsFinish = @() anim_start(triggerScale)

  let metrics = get_font_metrics(font, fontSize)
  let { lowercaseHeight } = metrics
  #forbid-auto-freeze
  let digits = []
  while (value > 0) {
    let digit = value % 10
    let startDigit = startValue % 10

    digits.append(
      animatedDigit(startDigit, digit, textParams, trigger, onDigitsFinish,
        round(lowercaseHeight), digitAnimDuration))
    value = (value / 10).tointeger()
    startValue = (startValue / 10).tointeger()
  }
  #allow-auto-freeze
  return {
    size = [SIZE_TO_CONTENT, lowercaseHeight]
    transform = static {}
    flow = FLOW_HORIZONTAL
    animations = scaleDuration <= 0 ? null : [
      {
        prop = AnimProp.scale, from = static [1, 1], to = bigScale, easing = CosineFull
        duration = scaleDuration, trigger = triggerScale, onFinish
      }
    ]
    children = digits.reverse()
  }
}

return {
  animateNumbers
}