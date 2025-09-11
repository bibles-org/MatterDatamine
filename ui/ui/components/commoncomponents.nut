from "%sqstd/math.nut" import getRomanNumeral
from "%sqstd/time.nut" import secondsToTime
from "%ui/fonts_style.nut" import h2_txt, body_txt, sub_txt, fontawesome
from "%ui/components/cursors.nut" import setTooltip
from "%ui/components/button.nut" import button, textButton, defButtonStyle, fontIconButton
from "string" import format
from "%ui/components/msgbox.nut" import showMsgbox
from "%ui/ui_library.nut" import *
from "dagor.debug" import logerr
from "%ui/components/colors.nut" import ConsoleFillColor, ConsoleBorderColor, BtnBgNormal, BtnBgHover, BtnBgSelected,
  BtnBgDisabled, BtnBdSelected, BtnBdTransparent, BtnBdHover, BtnTextHover, BtnTextActive, BtnTextHighlight,
  BtnTextNormal, BtnTextVisualDisabled, SelBdSelected, SelBdNormal, SelBdDisabled, SelBdHover, panelRowColor,
  InfoTextDescColor, InfoTextValueColor, TooltipBackground, ControlBgOpaque, DangerTextValueColor
from "%ui/components/tagsTable.style.nut" import defaultTagsTable
from "%ui/control/active_controls.nut" import isGamepad
import "%ui/components/gamepadImgByKey.nut" as gamepadImgByKey
import "%ui/components/fontawesome.map.nut" as fa
import "%ui/components/faComp.nut" as faComp

let { locTable } = require("%ui/helpers/time.nut")

#allow-auto-freeze

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

let VertSelectPanelGap = freeze({size=static [flex(), hdpx(2)] color = BtnBgNormal opacity = 0.7 rendObj = ROBJ_SOLID})
let VertSmallSelectPanelGap = freeze({size=static [flex(), hdpx(1)] color = BtnBgNormal opacity = 0.8 rendObj = ROBJ_SOLID})
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
  tagsTable=defaultTagsTable
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
    }.__update(textStyle ?? static {})
  })
}

let selectPanelTextFromCtor = @(ctor) ctor({stateFlags = Watched(0), watch = null, isSelected = @() false, disabled = false})

let mkSelectPanelTextWithFaIconCtor = @(fa_icon, text=null, textParams = body_txt) kwarg(@(stateFlags, watch, isSelected, disabled, group)
  function() {
    let isHover = (stateFlags.get() & S_HOVER)
    let color = disabled ? BtnTextVisualDisabled
      : isSelected() ? (isHover ? BtnTextHover : BtnTextActive)
      : (isHover ? BtnTextHighlight : BtnTextNormal)
    return {
      watch
      flow = FLOW_HORIZONTAL
      gap = hdpx(5)
      valign = ALIGN_CENTER
      group
      children = [
        faComp(fa_icon, {
          fontSize = (textParams.fontSize*0.91).tointeger()
          color
          needPreAlpha = false
        }.__merge(textParams, { font = fontawesome.font }))
        body_txt.__merge({
          rendObj = ROBJ_TEXT
          text
          color
        }.__merge(textParams))
      ]
    }
  }
)

function getBorderColor(sf, selected, style = null) {
  if (sf & S_HOVER)
    return style?.SelBdHover ?? SelBdHover
  if (selected)
    return style?.SelBdSelected ?? SelBdSelected
  return style?.SelBdNormal ?? SelBdNormal
}

let mkSelectPanelItem = kwarg(function(children, idx, state=null, onSelect=null, visual_params = null, onHover=null,
  sound = null, tooltip_text = null, multi=false, optional=false, default_state=not_set_state,
  border_align=BD_BOTTOM, disabled=false, cb = @(...) null, onDoubleClick = null, onlySelectedBd=false, onElemState=null, stateFlags=null, watch=null, group=null
){
  #forbid-auto-freeze
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
      size = static flex()
      onHover = onHoverRes
      onElemState = resOnElemState
      behavior = Behaviors.Button
      borderWidth = !disabled && (!onlySelectedBd || ((sf & S_HOVER) || selected)) ? bdw : 0
      borderColor = getBorderColor(sf, selected, visual_params?.style)
      onClick = disabled ? null : onClick
      onDoubleClick = disabled ? null : onDoubleClick
      padding = static hdpx(15)
      sound = merged_sound
      children
    }.__update(visual_params ?? static {})
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
  borderWidth = static [hdpx(1), 0]
  borderColor = ConsoleBorderColor
})

let defParams = freeze({})
function mkPanel(children, visual_params = null){
  return freeze({
    size = flex()
    children
  }.__update(panelParams, visual_params ?? defParams))
}

let mkTitleString = @[pure](text) {
  rendObj = ROBJ_TEXT
  margin = hdpx(10)
  text
  fontFx = FFT_GLOW
  fontFxColor = Color(0, 0, 0, 255)
}.__update(h2_txt)

let mkPaddingString = @[pure](text){
  size = FLEX_H
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  text
  margin = static [0, hdpx(10)]
}

let mkTextWithFAIcon = @[pure](fa_icon, text, font_style=body_txt) freeze({
  flow = FLOW_HORIZONTAL
  gap = hdpx(5)
  valign = ALIGN_CENTER
  children = [
    faComp(fa_icon, {
      fontSize = (font_style.fontSize*0.91).tointeger()
      color = BtnTextNormal
      needPreAlpha = false
    })
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

let mkText = @[pure](text, override = sub_txt) {
  rendObj = ROBJ_TEXT
  fontFx = FFT_GLOW
  fontFxColor = Color(0, 0, 0, 255)
  text
}.__update(override)

let mkTextArea = @[pure](text, override = static {}) {
  rendObj = ROBJ_TEXTAREA
  size = FLEX_H
  behavior = Behaviors.TextArea
  fontFx = FFT_GLOW
  fontFxColor = Color(0, 0, 0, 255)
  text
  tagsTable = defaultTagsTable
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
    size = FLEX_H
    children
  }
}

function helpFootnotes(footnotes) {
  if (footnotes == null)
    return null

  return {
    size = FLEX_H
    flow = FLOW_VERTICAL
    children = footnotes.map(@(v, idx) mkTextArea($"{idx+1}.{NBSP}{loc(v)}", sub_txt))
  }
}

function mkHelpConsoleScreen(device_image, help_data){
  return {
    rendObj = ROBJ_WORLD_BLUR_PANEL
    fillColor = ConsoleFillColor
    borderColor = ConsoleBorderColor
    borderWidth = static [0, 0, hdpx(1), 0]
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
        padding = static hdpx(20)
        flow = FLOW_VERTICAL
        gap = static hdpx(20)
        children = [
          {
            rendObj = ROBJ_TEXTAREA
            behavior = Behaviors.TextArea
            size = FLEX_H
            text = loc(help_data.content)
            fontFx = FFT_GLOW
            fontFxColor = Color(0, 0, 0, 255)
          }.__update(body_txt)
          help_data?.firstAccess
        ]
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
            size = static [flex(3),SIZE_TO_CONTENT]
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


function mkInfoTxt(title, val, textParam = {}, override = {}){
  return {
    flow = FLOW_HORIZONTAL gap = hdpx(10)
    children = [
      mkText(title, { color = InfoTextDescColor }.__update(textParam))
      mkText(val, { color = InfoTextValueColor }.__update(textParam))
    ]
  }.__update(override)
}

function underlineComp(children) {
  return {
    rendObj = ROBJ_BOX
    borderColor = BtnBdTransparent
    borderWidth = static [0,0,hdpx(1),0]
    size = FLEX_H
    children
  }
}

function mkFlexInfoTxt(title, val, textParam = null){
  return underlineComp({
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    gap = hdpx(6)
    children = [
      mkTextArea(title, {
        size = FLEX_H
        color = InfoTextDescColor
        minWidth = SIZE_TO_CONTENT
        maxWidth = hdpx(250)
        hplace = ALIGN_LEFT
      }.__update(body_txt, textParam ?? {}))
      mkTextArea(val, {
        size = FLEX_H
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
    size = FLEX_H
    text = $"<color={InfoTextDescColor}>{title}</color> {val}"
  }.__update(textParam ?? {})
}

function mkFATextWithTextButton(sym, text, callback, params = null) {
  let children = mkTextWithFAIcon(sym, text)
  return button(children, callback, {
    isEnabled = params?.isEnabled ?? true,
    size = flex(),
    style = static { BtnBgDisabled = BtnBgDisabled, BtnBgNormal = Color(60, 60, 60, 120) }
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
  }.__update(params ?? {}))
}

function mkTooltiped(content, tooltip, override = {}) {
  return freeze({
    behavior = Behaviors.Button
    onHover = @(on) setTooltip(on ? tooltip : null)
    skipDirPadNav = true
    children = content
    eventPassThrough = true
  }.__update(override))
}

let sideNotificationStyle = freeze({
  padding = hdpx(8)
  rendObj = ROBJ_WORLD_BLUR_PANEL
  fillColor = Color(10, 10, 10, 40)
  borderColor = BtnBdSelected
  borderWidth = static [0, 0, 0, hdpx(2)]

  transform = static {}
  animations = static [
    { prop=AnimProp.opacity, from=0, to=1, duration=0.3, play=true, easing=OutCubic }
    { prop=AnimProp.opacity, from=1, to=0, duration=0.3, playFadeOut=true, easing=OutCubic }
  ]
})
let mkTimeTxtStyle = memoize(@(fontStyle) {vplace = ALIGN_BOTTOM}.__merge(fontStyle))
let mkTimeMonoTxtStyle = memoize(function(fontStyle) {
  let bs = mkTimeTxtStyle(fontStyle)
  let monoWidth = calc_str_box({text="6"}.__update(bs))[0]
  return bs.__merge({monoWidth})
})

function mkMonospaceTimeComp(time, fontStyle = sub_txt, color = InfoTextValueColor) {
  #forbid-auto-freeze
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

function mkTimeComp(time, fontStyle = sub_txt, color = InfoTextValueColor) {
  #forbid-auto-freeze
  let { days=0, hours=0, minutes=0, seconds=0 } = secondsToTime(time)
  let txtStyle = mkTimeTxtStyle(fontStyle).__merge({color})

  let children = []
  if (days > 0)
    children.append(mkText($"{days}{locTable.days} ", txtStyle))
  if (hours > 0)
    children.append(mkText($"{hours}{locTable.hours} ", txtStyle))
  if (minutes > 0)
    children.append(mkText($"{minutes}{locTable.minutes} ", txtStyle))
  children.append(mkText(format("%02d", seconds), txtStyle))
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

function tabCtor(tab, is_current, handler, override) {
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
      group
      onHover = @(on) setTooltip(on && !enabled ? unavailableHoverHint : null)
      behavior = Behaviors.Button
      skipDirPadNav = true
      sound = tabSound

      fillColor
      borderColor
      borderWidth = selBorders[BD_BOTTOM]
      padding = static [fsh(1), fsh(2)]

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
    }.__update(override)
  }
}

function changeTab(delta, tabsList, currentTabId, onChange) {
  let curTabIdx = tabsList.findindex(@(v) v.id == currentTabId)
  if (curTabIdx == null)
    return
  let newIdx = curTabIdx + delta
  if (newIdx < 0 || newIdx >= tabsList.len())
    return
  let newTab = tabsList[newIdx]
  let { isAvailable = Watched(true), unavailableHoverHint = null } = newTab
  if (isAvailable.get())
    onChange(tabsList[newIdx])
  else
    showMsgbox({text = unavailableHoverHint ?? loc("Error/Unavailable")})
}

let mkTabs = kwarg(function(tabs, currentTab, onChange, override = {}) {
  
  
  
  
  
  
  
  
  
  
  let { disableHotkeys = false } = override
  let content = {
    flow = FLOW_HORIZONTAL
    gap = hdpx(2)
    children = tabs.map(@(item) tabCtor(item, item.id == currentTab, @() onChange(item), "tab_override" in override ? override.tab_override : override))
  }.__merge(override)

  function gamepadHotkeys() {
    if (!isGamepad.get() || disableHotkeys)
      return { watch = isGamepad }
    let contentWidth = calc_comp_size(content)
    return {
      watch = isGamepad
      size = [contentWidth[0], SIZE_TO_CONTENT]
      vplace = ALIGN_CENTER
      children = [
        gamepadImgByKey.mkImageCompByDargKey("J:LT", static { pos = [-hdpx(10), 0]})
        gamepadImgByKey.mkImageCompByDargKey("J:RT", static { hplace = ALIGN_RIGHT, pos = [hdpx(10), 0]})
      ]
    }.__merge(override)
  }
  return {
    size = FLEX_H
    hotkeys = disableHotkeys ? null : [
      ["J:RT", { action = @() changeTab(1, tabs, currentTab, onChange)}],
      ["J:LT", { action = @() changeTab(-1, tabs, currentTab, onChange)}]
    ]
    children = [
      content
      gamepadHotkeys
    ]
  }
})

return freeze({
  mkTabs
  mkSelectPanelItem
  mkSelectPanelTextCtor
  selectPanelTextFromCtor
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
  mkTimeComp
  BD_LEFT
  BD_RIGHT
  BD_CENTER
  BD_TOP
  BD_BOTTOM
  BD_LEFT_RIGHT
  BD_TOP_BOTTOM
  BD_NONE
  defSound
})
