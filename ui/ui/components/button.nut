from "%ui/components/colors.nut" import BtnBdActive, BtnBdDisabled, BtnBdFocused, BtnBdHover,
  BtnBdNormal, BtnBdSelected, BtnBgActive, BtnBgDisabled,
  BtnBgFocused, BtnBgHover, BtnBgNormal, BtnBgSelected,
  SelBgNormal, TextDisabled, TextHighlight, TextHover,
  TextActive, TextNormal,
  BtnTextHover, Active, Inactive
import "%ui/components/gamepadImgByKey.nut" as gamepadImgByKey
from "%ui/fonts_style.nut" import body_txt, sub_txt
import "%ui/components/faComp.nut" as faComp
from "%ui/components/sounds.nut" import buttonSound
import "%ui/components/getGamepadHotkeys.nut" as getGamepadHotkeys
from "%ui/components/cursors.nut" import setTooltip
import "%ui/components/tooltipBox.nut" as tooltipBox
from "%ui/ui_library.nut" import *
from "math" import min

let { isGamepad } = require("%ui/control/active_controls.nut")

#allow-auto-freeze

let defButtonStyle = freeze({
  BtnBdActive,
  BtnBdDisabled,
  BtnBdFocused,
  BtnBdHover,
  BtnBdNormal,
  BtnBdSelected,

  BtnBgActive,
  BtnBgDisabled,
  BtnBgFocused,
  BtnBgHover,
  BtnBgNormal,
  BtnBgSelected,

  TextActive,
  TextDisabled,
  TextHighlight,
  TextHover,
  TextNormal,
  SelBgNormal,

  textMargin = [fsh(1), fsh(3)],
  sound = buttonSound
})

function borderColor(sf, style=null, isEnabled = true) {
  let styling = defButtonStyle.__merge(style ?? {})
  isEnabled = typeof(isEnabled) == "function" ? isEnabled() : !!isEnabled
  if (!isEnabled)       return styling.BtnBdDisabled
  if (sf & S_ACTIVE)    return styling.BtnBdActive
  if (sf & S_HOVER)     return styling.BtnBdHover
  if (sf & S_KB_FOCUS)  return styling.BtnBdFocused
  return styling.BtnBdNormal
}

function fillColor(sf, style=null, isEnabled = true) {
  let styling = defButtonStyle.__merge(style ?? {})
  isEnabled = typeof(isEnabled) == "function" ? isEnabled() : !!isEnabled
  if (!isEnabled)       return styling.BtnBgDisabled
  if (sf & S_ACTIVE)    return styling.BtnBgActive
  if (sf & S_HOVER)     return styling.BtnBgHover
  if (sf & S_KB_FOCUS)  return styling.BtnBgFocused
  return styling.BtnBgNormal
}

function textColor(sf, style=null, isEnabled = true) {
  let styling = defButtonStyle.__merge(style ?? {})
  isEnabled = typeof(isEnabled) == "function" ? isEnabled() : !!isEnabled
  if (!isEnabled) return styling.TextDisabled
  if (sf & S_ACTIVE)    return styling.TextActive
  if (sf & S_HOVER)     return styling.TextHover
  if (sf & S_KB_FOCUS)  return styling.TextFocused
  return styling.TextNormal
}

function iconBtnColor(sf, style=null, isEnabled = true) {
  let styling = defButtonStyle.__merge(style ?? {})
  isEnabled = typeof(isEnabled) == "function" ? isEnabled() : !!isEnabled
  if (!isEnabled)       return styling.BtnBdDisabled
  if (sf & S_ACTIVE)    return styling.BtnBgHover
  if (sf & S_HOVER)     return styling.BtnBgActive
  if (sf & S_KB_FOCUS)  return styling.BtnBdFocused
  return styling.BtnBdNormal
}

function tooltipTextArea(text) {
  return tooltipBox({
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      maxWidth = hdpx(500)
      color = Color(180, 180, 180, 120)
      text
    }
  )
}

let headupTooltip = @(tooltip) tooltipTextArea(type(tooltip) == "string" ? loc(tooltip) : tooltip())

function button(content, handler, params=null, group=null) {
  let { isEnabled = true, stateFlags = Watched(0), style = defButtonStyle,
        tooltipText = null, isInteractive = true } = params
  let sound = style?.sound ?? defButtonStyle.sound
  let onHover = (tooltipText==null || !isEnabled) ? null : @(on) setTooltip(on ? headupTooltip(tooltipText) : null)

  return @() {
    rendObj = ROBJ_BOX
    behavior = (isEnabled && isInteractive) ? Behaviors.Button : null
    onHover
    watch = stateFlags
    onElemState = @(v) stateFlags.set(v)
    margin = 0
    key = params?.key
    group
    fillColor = fillColor(stateFlags.get(), style, isEnabled)
    borderColor = borderColor(stateFlags.get(), style, isEnabled)
    borderWidth = 1
    borderRadius = hdpx(1)
    valign = ALIGN_CENTER
    clipChildren = true
    onDetach = @() stateFlags.set(0)

    children = [
      params?.bgChild,
      content,
      isEnabled ? params?.fgChild : null
    ]

    sound = isEnabled ? sound : null
    onClick = isEnabled ? handler : null
  }.__update(params ?? {})
}

function getGamepadHotkeyIcon(hotkeys) {
  if (hotkeys == null || !isGamepad.get())
    return null
  let gamepadHotkey = getGamepadHotkeys(hotkeys, true)
  let hotkeyIcon = (gamepadHotkey == "") ? null : gamepadImgByKey.mkImageCompByDargKey(gamepadHotkey)
  return hotkeyIcon
}

function buttonWithGamepadHotkey(content, handler, params=null, group=null) {
  let newContent = function() {
    let hotkeyIcon = getGamepadHotkeyIcon(params?.hotkeys)
    return {
      watch = isGamepad
      size = params?.size ?? SIZE_TO_CONTENT
      valign = ALIGN_CENTER
      minHeight = static hdpxi(40)
      padding = [0, hdpx(4)]
      children = [
        isGamepad.get() ? hotkeyIcon : null
        content
      ]
    }
  }
  return button(newContent, handler, params, group)
}

function textButton(text, handler, params=null) {
  let { font = body_txt.font,
        fontSize = body_txt.fontSize,
        textMargin = defButtonStyle.textMargin,
        style = defButtonStyle,
        isEnabled = true,
        additionalWatched = [],
        stateFlags = Watched(0)
      } = params
  let group = ElemGroup()

  let textComp = @(){
    watch = [stateFlags].extend(additionalWatched)
    rendObj = ROBJ_TEXT
    text = (type(text)=="function") ? text() : text
    scrollOnHover=true
    onElemState = @(v) stateFlags.set(v)
    delay = 0.5
    speed = static [hdpx(100), hdpx(700)]
    maxWidth = pw(100)
    margin = textMargin
    font
    fontSize
    group
    behavior = Behaviors.Marquee
    color = textColor(stateFlags.get(), style, isEnabled)
  }.__update(params?.textParams ?? {})

  return button(textComp, handler, params, group)
}

let soundActive = freeze(buttonSound.__merge({  active = "ui_sounds/button_action" }))

let override = {
  halign = ALIGN_CENTER
  sound = soundActive

}.__update(body_txt)

let smallStyle = static {
  textMargin = [hdpx(3), hdpx(5)]

}.__update(sub_txt)

let btnFontIconFontSize = hdpxi(20)
let btnFontSize = static [hdpxi(31),hdpxi(31)]
let defParams = freeze({})
let isNumeric = function(v) {
  let t = typeof(v)
  return (t == "float" || t=="integer")
}

function fontIconButton(icon, callback, params = defParams) {
  let stateFlags = Watched(0)
  let gamepadHotkey = getGamepadHotkeys(params?.hotkeys, true)
  let { skipDirPadNav = (gamepadHotkey ?? "") != "", selected=null, watch=null, style=null, isEnabled=true, fontSize = btnFontIconFontSize, iconSize = null
      size = btnFontSize, tooltipText=null} = params
  let resFontSize = type(size) == "array" && isNumeric(size?[1])
    ? min(isNumeric(fontSize) ? fontSize : btnFontIconFontSize, size[1])
    : isNumeric(size) && isNumeric(fontSize)
      ? min(fontSize, size)
      : isNumeric(size)
        ? size
        : fontSize
  let btnIconHeight = iconSize ?? (resFontSize*0.8).tointeger()
  let img = (gamepadHotkey == "") ? null : gamepadImgByKey.mkImageCompByDargKey(gamepadHotkey)
  let result_watch = [stateFlags, isGamepad, selected].extend(typeof watch == "array" ? watch : [watch])

  return function() {
    let gamepadImg = isGamepad.get() && img!=null
    let sf = stateFlags.get()
    let color = iconBtnColor(sf, style, isEnabled)
    return {
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      behavior = Behaviors.Button
      rendObj = ROBJ_BOX
      onClick = callback
      borderRadius = hdpx(1)
      borderWidth = 1
      borderColor = borderColor(sf, style, isEnabled)
      fillColor = fillColor(sf, style, isEnabled)
      size
      onElemState = function(s) {
        stateFlags.set(s)
        if (tooltipText == null || !isEnabled)
          return
        setTooltip(s & S_HOVER ? headupTooltip(tooltipText) : null)
      }
      children = gamepadImg ? img : icon.endswith(".svg")
        ? {rendObj = ROBJ_IMAGE image = Picture($"!ui/skin#{icon}:{btnIconHeight}:{btnIconHeight}:K") color size = [btnIconHeight, btnIconHeight] keepAspect = KEEP_ASPECT_FIT}
        : faComp(icon, {fontSize=resFontSize, color})

      sound = buttonSound
    }.__update(params ?? {}, { watch=result_watch, skipDirPadNav })
  }
}





let buttonIcon = @(iconId, iconOverride = {}) faComp(iconId,{
  size = flex()
  valign = ALIGN_CENTER
  halign = ALIGN_CENTER
  margin = static [hdpx(1), 0, 0, hdpx(2)]
  color = Inactive
}.__update(iconOverride))

let DEFAULT_BUTTON_PARAMS = {
  onClick = null
  selected = null
  iconId = "question"
  key = null
  animations = null
  tooltipText = null
  needBlink = false
  blinkAnimationId = ""
  hotkeys=null
  isEnable = Watched(true)
}

let btnHgt = calc_comp_size({size=SIZE_TO_CONTENT children={text = "A" margin = hdpx(1) rendObj=ROBJ_TEXT}.__update(body_txt)})[1]

function squareIconButton(params = DEFAULT_BUTTON_PARAMS, iconOverride = {}) {
  params = DEFAULT_BUTTON_PARAMS.__merge(params)
  let {blinkAnimationId, onClick, needBlink, tooltipText, hotkeys, iconId, animations, key, selected, isEnable} = params

  let stateFlags = Watched(0)
  return function() {
    let sf = stateFlags.get()
    return {
      rendObj = ROBJ_SOLID
      size = [btnHgt, btnHgt]
      watch = [stateFlags, isEnable]
      onElemState = @(s) stateFlags.set(s)
      behavior = isEnable?.get() ? Behaviors.Button : null
      onClick
      onHover = tooltipText!=null
                  ? @(on) setTooltip(on ? headupTooltip(tooltipText) : null)
                  : null
  
      color = (sf & S_HOVER) ? BtnBgHover : 0
      sound = buttonSound
      hotkeys
      children = @() {
        size = flex()
        watch = selected
        key
        animations
        transform = { pivot=[0.5, 0.5] }
        valign = ALIGN_CENTER
        children = [
          buttonIcon(iconId, selected?.get()
            ? { color = Active, fontFx = FFT_GLOW }.__update(iconOverride)
            : { color = (sf & S_HOVER) ? BtnTextHover : Inactive }.__update(iconOverride)
          )
          needBlink
            ? {
                size = flex()
                rendObj = ROBJ_SOLID
                transform = {}
                opacity = 0
                animations = [
                  { trigger = blinkAnimationId
                    prop = AnimProp.opacity, from = 0, to = 0.35, duration = 1.2,
                    play = true, loop = true, easing = Blink
                  }
                ]
              }
            : null
        ]
      }
    }
  }
}

return freeze({
  button
  textButton
  textButtonSmall = @(text, handler, params = null) textButton(text, handler, override.__merge(smallStyle, params ?? {}))
  textButtonSmallStyle = smallStyle
  defButtonStyle
  squareIconButton 
  fontIconButton
  buttonWithGamepadHotkey
  getGamepadHotkeyIcon
})
