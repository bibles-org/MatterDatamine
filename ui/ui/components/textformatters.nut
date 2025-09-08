from "%ui/ui_library.nut" import *

let { h1_txt, h2_txt, body_txt, sub_txt } = require("%ui/fonts_style.nut")
let openUrl = require("%ui/components/openUrl.nut")
let { toIntegerSafe } = require("%sqstd/string.nut")

let defStyle = {
  defTextColor = Color(200,200,200)
  ulSpacing = hdpx(15)
  ulGap = hdpx(5)
  ulBullet = {rendObj = ROBJ_TEXT text=" • "}
  ulNoBullet= { rendObj = ROBJ_TEXT, text="   " }
  h1FontStyle = h1_txt
  h2FontStyle = h2_txt
  h3FontStyle = body_txt
  textFontStyle = body_txt
  noteFontStyle = sub_txt
  h1Color = Color(220,220,250)
  h2Color = Color(200,250,200)
  h3Color = Color(200,250,250)
  urlColor = Color(170,180,250)
  emphasisColor = Color(245,245,255)
  urlHoverColor = Color(220,220,250)
  noteColor = Color(128,128,128)
  padding = hdpx(5)
}

let noTextFormatFunc = @(object, _style=defStyle) object

function textArea(params, _fmtFunc=noTextFormatFunc, style=defStyle){
  return {
    rendObj = ROBJ_TEXTAREA
    text = params?.v
    behavior = Behaviors.TextArea
    color = style?.defTextColor ?? defStyle.defTextColor
    size = [flex(), SIZE_TO_CONTENT]
  }.__update(style?.textFontStyle ?? {}, params)
}

function url(data, fmtFunc=noTextFormatFunc, style=defStyle){
  let link = data?.url ?? data?.link
  if (link==null)
    return textArea(data, fmtFunc, style)
  let stateFlags = Watched(0)
  return function() {
    let color = stateFlags.get() & S_HOVER ? style.urlHoverColor : style.urlColor
    return {
      rendObj = ROBJ_TEXT
      text = data?.v ?? loc("see more...")
      behavior = Behaviors.Button
      color = color
      watch = stateFlags
      onElemState = @(sf) stateFlags(sf)
      children = {rendObj=ROBJ_FRAME borderWidth = [0,0,hdpx(1),0] color=color, size = flex()}
      function onClick() {
        openUrl(link)
      }
    }.__update(data)
  }
}

function mkUlElement(bullet){
  return function (elem, fmtFunc=noTextFormatFunc, _style=defStyle) {
    local res = fmtFunc(elem)
    if (res==null)
      return null
    if (type(res)!="array")
      res = [res]
    return {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      children = [bullet].extend(res)
    }
  }
}
function mkList(elemFunc){
  return function(obj, fmtFunc=noTextFormatFunc, style=defStyle) {
    return obj.__merge({
      flow = FLOW_VERTICAL
      size = [flex(), SIZE_TO_CONTENT]
      children = obj.v.map(@(elem) elemFunc(elem, fmtFunc, style))
    })
  }
}
function horizontal(obj, fmtFunc=noTextFormatFunc, _style=defStyle){
  return obj.__merge({
    flow = FLOW_HORIZONTAL
    size = [flex(), SIZE_TO_CONTENT]
    children = obj.v.map(@(elem) fmtFunc(elem))
  })
}

function accent(obj, fmtFunc=noTextFormatFunc, _style=defStyle){
  return obj.__merge({
    flow = FLOW_HORIZONTAL
    size = [flex(), SIZE_TO_CONTENT]
    rendObj = ROBJ_SOLID
    color = Color(0,30,50,30)
    children = obj.v.map(@(elem) fmtFunc(elem))
  })
}

function vertical(obj, fmtFunc=noTextFormatFunc, _style=defStyle){
  return obj.__merge({
    flow = FLOW_VERTICAL
    size = [flex(), SIZE_TO_CONTENT]
    children = obj.v.map(@(elem) fmtFunc(elem))
  })
}

let hangingIndent = calc_comp_size(defStyle.ulNoBullet)[0]

let bullets = mkList(mkUlElement(defStyle.ulBullet))
let indent = mkList(mkUlElement(defStyle.ulNoBullet))
let separatorCmp = {rendObj = ROBJ_FRAME borderWidth = [0,0,hdpx(1), 0] size = [flex(),hdpx(5)], opacity=0.2, margin=[hdpx(5), hdpx(20), hdpx(20), hdpx(5)]}

function textParsed(params, fmtFunc=noTextFormatFunc, style=defStyle){
  if (params?.v == "----")
    return separatorCmp
  return textArea(params, fmtFunc, style)
}

function column(obj, fmtFunc=noTextFormatFunc, _style=defStyle){
  return {
    flow = FLOW_VERTICAL
    size = [flex(), SIZE_TO_CONTENT]
    children = obj.v.map(@(elem) fmtFunc(elem))
  }
}

let getColWeightByPresetAndIdx = @(idx, preset) toIntegerSafe(preset?[idx+1], 100, false)

function columns(obj, fmtFunc=noTextFormatFunc, _style=defStyle){
  local preset = obj?.preset ?? "single"
  




  preset = preset.split("_")
  local cols = obj.v.filter(@(v) v?.t=="column")
  cols = cols.slice(0, preset.len())
  return {
    flow = FLOW_HORIZONTAL
    size = [flex(), SIZE_TO_CONTENT]
    children = cols.map(function(col, idx) {
      return {
        flow = FLOW_VERTICAL
        size = [flex(getColWeightByPresetAndIdx(idx, preset)), SIZE_TO_CONTENT]
        children = fmtFunc(col.v)
        clipChildren = true
      }
    })
  }
}

let formatters = {
  defStyle
  def=textArea,
  string=@(string, fmtFunc, style=defStyle) textParsed({v=string}, fmtFunc, style),
  textParsed
  textArea
  text=textArea,
  paragraph = textArea
  hangingText=@(obj, fmtFunc=noTextFormatFunc, style=defStyle) textArea(obj.__merge({ hangingIndent = hangingIndent }), fmtFunc, style)
  h1 = @(text, fmtFunc=noTextFormatFunc, style=defStyle) textArea(text.__merge(style.h1FontStyle, {color=style.h1Color, margin = [hdpx(15), 0, hdpx(25), 0]}), fmtFunc, style)
  h2 = @(text, fmtFunc=noTextFormatFunc, style=defStyle) textArea(text.__merge(style.h2FontStyle, {color=style.h2Color, margin = [hdpx(10), 0, hdpx(15), 0]}), fmtFunc, style)
  h3 = @(text, fmtFunc=noTextFormatFunc, style=defStyle) textArea(text.__merge(style.h3FontStyle, {color=style.h3Color, margin = [hdpx(5), 0, hdpx(10), 0]}), fmtFunc, style)
  emphasis = @(text, fmtFunc=noTextFormatFunc, style=defStyle) textArea(text.__merge({color=style.emphasisColor, margin = [hdpx(5),0]}), fmtFunc, style)
  columns
  column
  image = function(obj, _fmtFunc=noTextFormatFunc, style=defStyle) {
    return {
      rendObj = ROBJ_IMAGE
      image=Picture(obj.v)
      size = [obj?.width!=null ? hdpx(obj.width) : flex(), obj?.height != null ? hdpx(obj.height) : hdpx(450)]
      keepAspect=true padding=style.padding
      children = {
        rendObj = ROBJ_TEXT text = obj?.caption vplace = ALIGN_BOTTOM
        fontFxColor = Color(0,0,0,150)
        fontFxFactor = min(64, hdpx(64))
        fontFx = FFT_GLOW
      }
      hplace = ALIGN_CENTER
    }.__update(obj)
  }
  url
  button = url
  note = @(obj, fmtFunc=noTextFormatFunc, style=defStyle) textArea(obj.__merge(style.noteFontStyle, {color=style.noteColor}), fmtFunc, style)
  preformat = @(obj, fmtFunc=noTextFormatFunc, style=defStyle) textArea(obj.__merge({preformatted=FMT_KEEP_SPACES | FMT_NO_WRAP}), fmtFunc, style)
  bullets
  list = bullets
  indent
  sep = @(obj, _fmtFunc=noTextFormatFunc, _style=defStyle) separatorCmp.__merge(obj)
  accent
  horizontal
  vertical
  video = function(obj, _fmtFunc, style=defStyle) {
    let stateFlags = Watched(0)
    let width = hdpx(obj?.imageWidth ?? 300)
    let height = hdpx(obj?.imageHeight ?? 80)
    return @() {
      borderColor = stateFlags.get() & S_HOVER ? style.urlHoverColor : Color(25,25,25)
      borderWidth = hdpx(1)
      watch = stateFlags
      onElemState = @(sf) stateFlags.set(sf)
      behavior = Behaviors.Button
      fillColor = Color(12,12,12,255)
      rendObj = ROBJ_BOX
      size = [width, height]
      padding= hdpx(1)
      margin = hdpx(5)
      valign = ALIGN_BOTTOM
      hplace = ALIGN_CENTER
      keepAspect = true image = obj?.image
      children = freeze({
        rendObj = ROBJ_SOLID
        color = Color(0,0,0,150)
        halign = ALIGN_CENTER
        size = [flex(), SIZE_TO_CONTENT]
        children = {rendObj = ROBJ_TEXT text = obj?.caption ?? loc("Watch video") padding = hdpx(5)}
      })
      onClick = function() {
        if (obj?.v)
          openUrl(obj.v)
      }
    }.__update(obj)
  }
}

return formatters
