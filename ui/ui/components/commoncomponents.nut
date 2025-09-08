from "%ui/ui_library.nut" import *
from "dagor.debug" import logerr
from "colors.nut" import ConsoleFillColor, ConsoleBorderColor,
  BtnBgNormal, BtnBgHover, BtnBgSelected, BtnBgDisabled, BtnBdSelected, BtnBdTransparent, BtnBdHover, BtnTextHover, BtnTextActive, BtnTextHighlight, BtnTextNormal, BtnTextVisualDisabled,
  SelBdSelected, SelBdNormal, SelBdDisabled, SelBdHover,
  panelRowColor, InfoTextDescColor, InfoTextValueColor, TooltipBackground, ControlBgOpaque, DangerTextValueColor

let { h2_txt, body_txt, sub_txt, fontawesome } = require("%ui/fonts_style.nut")
let { getRomanNumeral } = require("%sqstd/math.nut")
let fa = require("%ui/components/fontawesome.map.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let { button, textButton, defButtonStyle, fontIconButton } = require("%ui/components/button.nut")
let { secondsToTime } = require("%sqstd/time.nut")
let { format } = require("string")
let { locTable } = require("%ui/helpers/time.nut")
let { showMsgbox } = require("%ui/components/msgbox.nut")

function selectFillColor(sf, is_selected, style=null, disabled = false) {
  let styling = style != null ? defButtonStyle.__merge(style) : defButtonStyle
  if (disabled) return styling.BtnBgDisabled
  if (sf & S_ACTIVE) return styling.BtnBgActive
  if (sf & S_HOVER) return styling.BtnBgHover
  if (sf & S_KB_FOCUS) return styling.BtnBgFocused
  return is_selected ? styling.BtnBgSelected : styling.SelBgNormal
}

let defSound = freeze({
  click  = "ui_sounds/button_click"
  hover  = "ui_sounds/button_highlight"
  active = "ui_sounds/button_action"
})

let VertSelectPanelGap = freeze({size=[flex(), hdpx(2)] color = BtnBgNormal opacity = 0.7 rendObj = ROBJ_SOLID})
let VertSmallSelectPanelGap = freeze({size=[flex(), hdpx(1)] color = BtnBgNormal opacity = 0.8 rendObj = ROBJ_SOLID})
let not_set_state = {}

const BD_TOP = 0
const BD_RIGHT = 1
const BD_BOTTOM = 2
const BD_LEFT = 3
const BD_CENTER = 4
const BD_LEFT_RIGHT = 5
const BD_TOP_BOTTOM = 6
const BD_NONE = 6

let descriptionStyle = freeze({ fontFx = FFT_GLOW fontFxColor = Color(0, 0, 0, 255)
  tagsTable={
    accented = {color = InfoTextValueColor }
    danger = {color = DangerTextValueColor }
  }
})

let selBorders = freeze({
  [BD_TOP] =    [hdpx(2), 0, 0, 0],
  [BD_RIGHT] =  [0, hdpx(2), 0, 0],
  [BD_BOTTOM] = [0, 0, hdpx(2), 0],
  [BD_LEFT] =   [0, 0, 0, hdpx(2)],
  [BD_CENTER] = hdpx(2),
  [BD_TOP_BOTTOM] = [hdpx(2), 0, hdpx(2), 0],
  [BD_LEFT_RIGHT] = [0, hdpx(2), 0, hdpx(2)],
  [BD_NONE] = 0,
})

let getTextColorForSelectedPanelText = @(isSelected, isHover, disabled=false) disabled
  ? BtnTextVisualDisabled
    : isSelected
      ? (isHover ? BtnTextHover : BtnTextActive)
      : (isHover ? BtnTextHighlight : BtnTextNormal)

function mkSelectPanelTextCtor(text, textStyle = null) {
  return kwarg(@(stateFlags, watch, isSelected, disabled, group=null) function() {
    let isHover = (stateFlags.get() & S_HOVER)
    return {
      rendObj = ROBJ_TEXT
      watch
      text
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      group
      fontFx = isSelected() ? null : FFT_GLOW
      fontFxColor = Color(0, 0, 0, 55)
      behavior = Behaviors.Marquee
      speed = hdpx(50)
      scrollOnHover=true
      color = getTextColorForSelectedPanelText(isSelected(), isHover, disabled)
    }.__update(textStyle ?? const {})
  })
}
let mkSelectPanelTextWithFaIconCtor = @(fa_icon, text=null, font_style=body_txt) kwarg(@(stateFlags, watch, isSelected, disabled, group)
  function() {
    let isHover = (stateFlags.get() & S_HOVER)
    let color = disabled ? BtnTextVisualDisabled :
         isSelected()
           ? (isHover ? BtnTextHover : BtnTextActive)
           : (isHover ? BtnTextHighlight : BtnTextNormal)
    return {
      flow = FLOW_HORIZONTAL
      gap = hdpx(5)
      valign = ALIGN_CENTER
      watch
      group
      children = [
        {
          rendObj = ROBJ_TEXT
          font = fontawesome.font
          text = fa[fa_icon]
          fontSize = (font_style.fontSize*0.91).tointeger()
          color
        }
        body_txt.__merge({
          rendObj = ROBJ_TEXT
          text
          color
        })
      ]
    }
  }
)
let getBorderColor = @(sf, selected) sf & S_HOVER ? SelBdHover : (selected ? SelBdSelected : SelBdNormal)

let mkSelectPanelItem = kwarg(function(children, idx, state=null, onSelect=null, visual_params = null, onHover=null,
  sound = null, tooltip_text = null, multi=false, optional=false, default_state=not_set_state,
  border_align=BD_BOTTOM, disabled=false, cb = @(...) null, onDoubleClick = null, onlySelectedBd=false, onElemState=null, stateFlags=null, watch=null, group=null
){
  assert(state instanceof Watched, @() $"state={type(state)}")
  assert(stateFlags==null || onElemState!=null, "with provided stateFlags, onElemState is also required")
  default_state = default_state==not_set_state ? state.get() : default_state
  stateFlags = stateFlags ?? Watched(0)
  group = group ?? ElemGroup()
  let isSelected = multi
    ? @() (state.get() & (1 << idx)) > 0
    : @() isEqual(state.get(), idx)
  let onClick = function(event) {
    let action = multi
      ? ( onSelect!=null ? function() {
          state.set(state.get() ^ (1 << idx))
          onSelect((state.get() & (1 << idx)) > 0)
        } : @() state.set(state.get() ^ (1 << idx)) )
      : optional
        ? @() onSelect!=null ? onSelect(idx) : state.set(state.get() == idx ? default_state : idx)
        : @() onSelect!=null ? onSelect(idx) : state.set(idx)
    action()
    cb(event)
  }
  watch = watch == null
    ? [stateFlags, state]
    : [stateFlags, state].extend(type(watch)=="array" ? watch : [watch])

  if (type(children)=="function") {
    let paramsNum = children.getfuncinfos().parameters.len()
    if (paramsNum>1) {
      children = children({stateFlags, watch, isSelected, disabled, group})
    }
  }

  let bdw = selBorders[border_align]
  let merged_sound = defSound.__merge(sound ?? {})
  let onHoverRes = function(on) {
    onHover?(on)
    setTooltip(on ? tooltip_text : null)
  }
  let resOnElemState = onElemState==null ? @(v) stateFlags.set(v) : function(v){onElemState(v); stateFlags.set(v);}

  return function(){
    let selected = isSelected()
    let sf = stateFlags.get()
    return {
      rendObj = ROBJ_BOX
      watch
      group
      fillColor =  selectFillColor(sf, selected, visual_params?.style, disabled)
      size = const flex()
      onHover = onHoverRes
      onElemState = resOnElemState
      behavior = Behaviors.Button
      borderWidth = !disabled && (!onlySelectedBd || ((sf & S_HOVER) || selected)) ? bdw : 0
      borderColor = getBorderColor(sf, selected)
      onClick = disabled ? null : onClick
      onDoubleClick = disabled ? null : onDoubleClick
      padding = const hdpx(15)
      sound = merged_sound
      children
    }.__update(visual_params ?? const {})
  }
})

let panelParams = freeze({
  rendObj = ROBJ_BOX
  fillColor = panelRowColor
  padding = hdpx(15)
})

let bluredPanel = freeze({
  rendObj = ROBJ_WORLD_BLUR_PANEL
  fillColor = ConsoleFillColor
})

let bluredPanelWindow = freeze({
  rendObj = ROBJ_WORLD_BLUR_PANEL
  fillColor = ConsoleFillColor
  borderWidth = const [hdpx(1), 0]
  borderColor = ConsoleBorderColor
})

let defParams = freeze({})
function mkPanel(children, visual_params = null){
  return freeze({
    size = flex()
    children
  }.__update(panelParams, visual_params ?? defParams))
}

let mkTitleString = @(text) {
  rendObj = ROBJ_TEXT
  margin = hdpx(10)
  text = text
  fontFx = FFT_GLOW
  fontFxColor = Color(0, 0, 0, 255)
}.__update(h2_txt)

let mkPaddingString = @(text){
  size = [flex(), SIZE_TO_CONTENT]
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  text = text
  margin = [0, hdpx(10)]
}

let mkTextWithFAIcon = @(fa_icon, text, font_style=body_txt) freeze({
  flow = FLOW_HORIZONTAL
  gap = hdpx(5)
  valign = ALIGN_CENTER
  children = [
    {
      rendObj = ROBJ_TEXT
      font = fontawesome.font
      text = fa[fa_icon]
      fontSize = (font_style.fontSize*0.91).tointeger()
    }
    {
      rendObj = ROBJ_TEXT
      text
    }.__update(font_style)
  ]
})

function mkConsoleScreen(children){
  return {
    
    
    
    
    
    size = flex()
    padding = hdpx(10)
    children
  }
}

let mkText = @(text, override = sub_txt) {
  rendObj = ROBJ_TEXT
  fontFx = FFT_GLOW
  fontFxColor = Color(0, 0, 0, 255)
  text
}.__update(override)

let mkTextArea = @(text, override = {}) {
  rendObj = ROBJ_TEXTAREA
  size = [flex(), SIZE_TO_CONTENT]
  behavior = Behaviors.TextArea
  fontFx = FFT_GLOW
  fontFxColor = Color(0, 0, 0, 255)
  text
}.__update(override)

let mkDescTextarea = @(text, override=null ) mkTextArea(text, descriptionStyle.__merge(override ?? {}))

let NBSP = " " 

function helpComponents(components){
  if (components == null)
    return null
  let children = components.map(@(x, idx){
    rendObj = ROBJ_TEXTAREA
    behavior = Behaviors.TextArea
    text = $"{getRomanNumeral(idx+1)} {loc(x)}"
    fontFx = FFT_GLOW
    fontFxColor = Color(0, 0, 0, 255)
  }.__update(body_txt))
  return {
    flow = FLOW_VERTICAL
    size = [flex(), SIZE_TO_CONTENT]
    children
  }
}

function helpFootnotes(footnotes){
  if (footnotes == null)
    return null
  let text = "; ".join(footnotes.map(@(x, idx) $"{idx+1}.{NBSP}{loc(x)}"))
  return {
    rendObj = ROBJ_TEXTAREA
    behavior = Behaviors.TextArea
    text = text
    size = [flex(), SIZE_TO_CONTENT]
    fontFx = FFT_GLOW
    fontFxColor = Color(0, 0, 0, 255)
  }.__update(sub_txt)
}

function mkHelpConsoleScreen(device_image, help_data){
  return {
    rendObj = ROBJ_WORLD_BLUR_PANEL
    fillColor = ConsoleFillColor
    borderColor = ConsoleBorderColor
    borderWidth = [0, 0, hdpx(1), 0]
    size = flex()
    padding = hdpx(15)
    flow = FLOW_HORIZONTAL
    gap = hdpx(5)
    children = [
      {
        rendObj = ROBJ_SOLID
        size = flex(1)
        halign = ALIGN_CENTER
        color = TooltipBackground
        padding = hdpx(20)
        children = {
          rendObj = ROBJ_TEXTAREA
          behavior = Behaviors.TextArea
          size = [flex(), SIZE_TO_CONTENT]
          text = loc(help_data.content)
          fontFx = FFT_GLOW
          fontFxColor = Color(0, 0, 0, 255)
        }.__update(body_txt)
      },
      {
        rendObj = ROBJ_SOLID
        size = flex(3)
        flow = FLOW_HORIZONTAL
        color = TooltipBackground
        padding = hdpx(20)
        children = [
          {
            rendObj = ROBJ_IMAGE
            size = flex(4)
            image = device_image
            hplace = ALIGN_CENTER
            keepAspect = KEEP_ASPECT_FIT
          },
          {
            flow = FLOW_VERTICAL
            vplace  = ALIGN_CENTER
            gap = hdpx(20)
            size = [flex(3),SIZE_TO_CONTENT]
            children = [
              helpComponents(help_data?.components)
              helpFootnotes(help_data?.footnotes)
            ]
          }
        ]
      }
    ]
  }
}


function mkInfoTxt(title, val, textParam = {}){
  return {
    flow = FLOW_HORIZONTAL gap = hdpx(10)
    children = [
      mkText(title, { color = InfoTextDescColor }.__update(textParam))
      mkText(val, { color = InfoTextValueColor }.__update(textParam))
    ]
  }
}

function underlineComp(children) {
  return {
    rendObj = ROBJ_BOX
    borderColor = BtnBdTransparent
    borderWidth = [0,0,hdpx(1),0]
    size = [flex(), SIZE_TO_CONTENT]
    children
  }
}

function mkFlexInfoTxt(title, val, textParam = null){
  return underlineComp({
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    gap = hdpx(6)
    children = [
      mkTextArea(title, {
        size = [flex(), SIZE_TO_CONTENT]
        color = InfoTextDescColor
        minWidth = SIZE_TO_CONTENT
        maxWidth = hdpx(250)
        hplace = ALIGN_LEFT
      }.__update(body_txt, textParam ?? {}))
      mkTextArea(val, {
        size = [flex(), SIZE_TO_CONTENT]
        color = InfoTextValueColor
        halign = ALIGN_RIGHT
      }.__update(body_txt, textParam ?? {}))
    ]
  })
}

function mkInfoTxtArea(title, val, textParam = null){
  return {
    rendObj = ROBJ_TEXTAREA
    behavior = Behaviors.TextArea
    color = InfoTextValueColor
    size = [flex(), SIZE_TO_CONTENT]
    text = $"<color={InfoTextDescColor}>{title}</color> {val}"
  }.__update(textParam ?? {})
}

function mkFATextWithTextButton(sym, text, callback, params = null) {
  let children = mkTextWithFAIcon(sym, text)
  return button(children, callback, {
    isEnabled = params?.isEnabled ?? true,
    size = flex(),
    style = { BtnBgDisabled = BtnBgDisabled, BtnBgNormal = Color(60, 60, 60, 120) }
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
  }.__update(params ?? {}))
}

function mkTooltiped(content, tooltip, override = {}) {
  return {
    behavior = Behaviors.Button
    onHover = @(on) setTooltip(on ? tooltip : null)
    skipDirPadNav = true
    children = content
    eventPassThrough = true
  }.__update(override)
}

let sideNotificationStyle = freeze({
  padding = hdpx(8)
  rendObj = ROBJ_WORLD_BLUR_PANEL
  fillColor = Color(10, 10, 10, 40)
  borderColor = BtnBdSelected
  borderWidth = [0, 0, 0, hdpx(2)]

  transform = {}
  animations = [
    { prop=AnimProp.opacity, from=0, to=1, duration=0.3, play=true, easing=OutCubic }
    { prop=AnimProp.opacity, from=1, to=0, duration=0.3, playFadeOut=true, easing=OutCubic }
  ]
})
let mkTimeTxtStyle = memoize(@(fontStyle) {vplace = ALIGN_BOTTOM}.__merge(fontStyle))
let mkTimeMonoTxtStyle = memoize(function(fontStyle) {
  let bs = mkTimeTxtStyle(fontStyle)
  let monoWidth = calc_str_box({text="0"}.__update(bs))[0]
  return bs.__merge({monoWidth})
})

function mkMonospaceTimeComp(time, fontStyle = sub_txt, color = InfoTextValueColor) {
  let { days=0, hours=0, minutes=0, seconds=0 } = secondsToTime(time)
  let txtStyle = mkTimeTxtStyle(fontStyle).__merge({color})
  let monoStyle = mkTimeMonoTxtStyle(fontStyle).__merge({color})

  let children = []
  if (days > 0) {
    children.append(mkText($"{days}", monoStyle))
    children.append(mkText($"{locTable.days} ", txtStyle))
  }
  if (hours > 0) {
    children.append(mkText($"{hours}", monoStyle))
    children.append(mkText($"{locTable.hours} ", txtStyle))
  }
  if (minutes > 0) {
    children.append(mkText($"{minutes}", monoStyle))
    children.append(mkText($"{locTable.minutes} ", txtStyle))
  }
  children.append(mkText(format("%02d", seconds), monoStyle))
  children.append(mkText(locTable.seconds, txtStyle))
  return {
    flow = FLOW_HORIZONTAL
    children
  }
}

let tabSound = freeze({
  click  = "ui_sounds/button_click"
  hover  = "ui_sounds/menu_highlight"
  active = "ui_sounds/button_action"
})

function tabCtor(tab, is_current, handler) {
  let group = ElemGroup()
  let stateFlags = Watched(0)
  if ("isAvailable" in tab && (tab?.unavailableHoverHint ?? "")=="" ) {
    log("Error in tab", tab, "if tab can be unavailable, than unavailableHoverHint is required")
    logerr("unavailableHoverHint required")
  }
  let { isAvailable = Watched(true), unavailableHoverHint = null } = tab
  return function() {
    let sf = stateFlags.get()
    let isHover = (sf & S_HOVER)
    let borderColor = getBorderColor(sf, is_current)
    let enabled = isAvailable.get()
    let textColor = getTextColorForSelectedPanelText(is_current, isHover, !enabled)
    let fillColor =  selectFillColor(sf, is_current, null, !enabled)

    return {
      watch = [stateFlags, isAvailable]
      key = tab
      rendObj = ROBJ_BOX
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      size = SIZE_TO_CONTENT
      group
      onHover = @(on) setTooltip(on && !enabled ? unavailableHoverHint : null)
      behavior = Behaviors.Button
      skipDirPadNav = true
      sound = tabSound

      fillColor
      borderColor
      borderWidth = selBorders[BD_BOTTOM]
      padding = [fsh(1), fsh(2)]

      onClick = enabled ? handler : @() showMsgbox({text = unavailableHoverHint ?? loc("Error/Unavailable")})
      onElemState = @(s) stateFlags.set(s)

      children = tab?.text ? {
        rendObj = ROBJ_TEXT
        color = textColor

        text = tab.text
        group
      }.__update(body_txt) : tab.childrenConstr({
        color = textColor
        group
      })
    }
  }
}

let mkTabs = kwarg(function(tabs, currentTab, onChange) {
  
  
  
  
  
  
  
  
  
  
  return {
    rendObj = ROBJ_BOX
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    gap = hdpx(2)
    children = tabs.map(@(item) tabCtor(item, item.id == currentTab, @() onChange(item)))
  }
})

return{
  mkTabs
  mkSelectPanelItem
  mkSelectPanelTextCtor
  getTextColorForSelectedPanelText
  mkSelectPanelTextWithFaIconCtor
  mkPanel
  panelParams
  mkTitleString
  mkPaddingString
  fontIconButton
  mkTextWithFAIcon
  mkFATextWithTextButton
  textButton
  mkConsoleScreen
  mkText
  mkTextArea
  mkDescTextarea
  mkInfoTxt
  mkFlexInfoTxt
  mkTooltiped
  mkInfoTxtArea
  mkHelpConsoleScreen
  bluredPanel
  bluredPanelWindow
  sideNotificationStyle
  underlineComp
  VertSelectPanelGap
  VertSmallSelectPanelGap
  descriptionStyle
  mkMonospaceTimeComp
  BD_LEFT
  BD_RIGHT
  BD_CENTER
  BD_TOP
  BD_BOTTOM
  BD_LEFT_RIGHT
  BD_TOP_BOTTOM
  BD_NONE
}
