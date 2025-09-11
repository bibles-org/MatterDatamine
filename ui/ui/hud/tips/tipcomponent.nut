from "%ui/fonts_style.nut" import body_txt
from "%ui/components/controlHudHint.nut" import controlHudHint, mkHasBinding
from "%ui/components/colors.nut" import TextNormal, HudTipFillColor, TextHighlight
from "%ui/components/per_character_animation.nut" import mkAnimText
from "%ui/ui_library.nut" import *

let { isSpectator } = require("%ui/hud/state/spectator_state.nut")


let defaultTipTextStyle = {
  textColor = TextNormal
  font = body_txt.font
  fontSize = body_txt.fontSize
  textAnims = []
}

let hintCharAnim = @(delay) [
  { prop=AnimProp.color, from=TextNormal, to=TextHighlight, duration=1.0, easing=CosineFull, play=true, loop=true, delay, loopPause=1.0 }
]

function text_hint(text, params={}) {
  return mkAnimText(text, hintCharAnim, params)
}

function text_hint_no_anim(text, params={}) {
  let res = {
    rendObj = ROBJ_TEXTAREA
    behavior = Behaviors.TextArea
    margin = hdpx(2)
    text
    color = params.textColor
    font = params.font
    fontSize = params.fontSize
    transform = {pivot=[0.1,0.5]}
    animations = params.textAnims
    fontFx = FFT_GLOW
    fontFxColor = Color(0, 0, 0, 255)
  }
  if (text instanceof Watched)
    return @() res.__update({ watch = text, text = text.get() })
  return res
}

let defTipAnimations = freeze([
  { prop=AnimProp.scale, from=[0,1], to=[1,1], duration=0.25, play=true, easing=OutCubic }
  { prop=AnimProp.opacity, from=0, to=1, duration=0.15, play=true, easing=OutCubic }
  { prop=AnimProp.scale, from=[1,1], to=[0,1], duration=0.25, playFadeOut=true, easing=OutCubic }
  { prop=AnimProp.opacity, from=1, to=0, duration=0.25, playFadeOut=true, easing=OutCubic }
])

function mkInputHintBlock(inputId, addChild = null) {
  if (inputId == null)
    return null
  let hasBinding = mkHasBinding(inputId?.id ?? inputId)
  let inputHint = controlHudHint({ id = inputId })
  return @() {
    watch = hasBinding
    flow = FLOW_HORIZONTAL
    children = hasBinding.get() ? [inputHint, addChild] : null
  }
}

let padding = freeze({ size = [fsh(1), 0] })

let tipBack = freeze({
  rendObj = ROBJ_WORLD_BLUR
  borderRadius = hdpx(8)
  padding = static [hdpx(6), hdpx(10)]
  fillColor = HudTipFillColor
  transform = { pivot = [0.5, 0.5] }
})

function [pure] tipContents(params) {
  local {
    text = null, inputId = null, extraCmp = null,
    size = SIZE_TO_CONTENT, animations = defTipAnimations,
    needCharAnimation = true
    needBuiltinPadding = true
  } = params

  let textStyle = defaultTipTextStyle.__merge(params?.textStyle ?? {})

  if (text == null && inputId == null)
    return null
  animations = [].extend(animations).extend(params?.extraAnimations ?? [])
  let textCmp = text == null ? null :
    needCharAnimation ? text_hint(text, textStyle) : text_hint_no_anim(text, textStyle)
  let hintPadding = (needBuiltinPadding && textCmp) ? padding : null
  let inputHintBlock = isSpectator.get() ? null : mkInputHintBlock(inputId, hintPadding)
  return @() tipBack.__merge({
    watch = inputId != null ? isSpectator : null
    size
    animations
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    children = [
      inputHintBlock
      textCmp
      extraCmp ? padding : null
      extraCmp
    ]
  }).__update(params?.style ?? {})
}

function tipCmp(params) {
  let contents = tipContents(params)
  if (contents == null)
    return null
  return contents
}

return {
  tipCmp
  tipContents
  tipBack
  tipText = text_hint
  mkInputHintBlock
  defTipAnimations
}
