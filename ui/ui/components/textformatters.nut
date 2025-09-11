from "%sqstd/string.nut" import toIntegerSafe
from "%ui/fonts_style.nut" import h1_txt, h2_txt, body_txt, sub_txt
from "%ui/components/openUrl.nut" import openUrl
from "%ui/ui_library.nut" import *
import "datacache"
from "%sqstd/math.nut" import getRomanNumeral
from "%sqstd/string.nut" import toIntegerSafe
from "eventbus" import eventbus_subscribe_onehit

const CACHE_NAME = "video"
datacache.init_cache(CACHE_NAME, {
  mountPath = "videocache"
})

function load_movie(name, movieStatus) {
  eventbus_subscribe_onehit($"datacache.{name}", function(resp) {
    if ("error" in resp) {
      movieStatus.set({
        name = null
        error = resp.error
      })
    } else {
      movieStatus.set({
        name = resp.path
        error = null
      })
    }
  })
  datacache.request_entry(CACHE_NAME, name)
}


let defStyle = freeze({
  defTextColor = Color(200,200,200)
  ulSpacing = hdpx(15)
  ulGap = hdpx(5)
  ulBullet = { rendObj = ROBJ_TEXT text=" •  "}
  ulNoBullet= { rendObj = ROBJ_TEXT, text = "   " }
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
  lineGaps = hdpx(5)
  olArabic = @(index, _style = {}) {
    rendObj = ROBJ_TEXT
    text = $" {index}. "
    minWidth = hdpx(40)
    halign = ALIGN_RIGHT
  }
  olRoman = @(index, _style = {}) {
    rendObj = ROBJ_TEXT
    text = $" { getRomanNumeral(index) }. "
    minWidth = hdpx(50)
    halign = ALIGN_RIGHT
  }
})

let noTextFormatFunc = @(object, _style=defStyle) object

let isNumeric = @(val) typeof val == "int" || typeof val == "float"

function textArea(params, _fmtFunc=noTextFormatFunc, style=defStyle){
  return {
    rendObj = ROBJ_TEXTAREA
    text = params?.v
    behavior = Behaviors.TextArea
    color = style?.defTextColor ?? defStyle.defTextColor
    size = FLEX_H
  }.__update(style?.textFontStyle ?? {}, params)
}

function textAreaContainer(containerParams, params, _fmtFunc=noTextFormatFunc, style=defStyle) {
  return containerParams.__update({
    size = FLEX_H
    children = {
      rendObj = ROBJ_TEXTAREA
      text = params?.v
      behavior = Behaviors.TextArea
      color = style?.defTextColor ?? defStyle.defTextColor
      size = FLEX_H
    }.__update(style?.textFontStyle ?? {}, params)
  })
}

let transcode = freeze({
  center = @(v) v != null ? { halign = ALIGN_CENTER } : null
  margin = @(v) typeof v == "array" && v.len() > 1 && v.len() < 5
    ? { margin =  v.map(@(m) isNumeric(m) ? hdpx(m) : 0 ) }
    : isNumeric(v) ? { margin = [hdpx(v), hdpx(v)] }
    : null
  size = @(v) isNumeric(v) ? { size = [hdpx(v), SIZE_TO_CONTENT]}
    : typeof v == "array" ? { size = [
        isNumeric(v?[0]) ? hdpx(v[0]) : SIZE_TO_CONTENT,
        isNumeric(v?[1]) ? hdpx(v[1]) : SIZE_TO_CONTENT
      ]}
    : { size = SIZE_TO_CONTENT }
})

function transcodeTable(data){
  let res = {}
  foreach (key, val in data){
    if (key not in transcode || val == null)
      continue
    if (typeof transcode[key] == "function"){
      let line = transcode[key](val)
      if (line != null)
        res.__update(line)
    }
    else
      res[key] <- transcode[key] ?? val
  }

  return res
}

function url(data, fmtFunc=noTextFormatFunc, style=defStyle){
  let link = data?.url ?? data?.link
  let transcodedData = transcodeTable(data)
  if (link==null)
    return textArea(transcodedData, fmtFunc, style)
  let stateFlags = Watched(0)
  return function() {
    let color = stateFlags.get() & S_HOVER ? style.urlHoverColor : style.urlColor
    return {
      rendObj = ROBJ_TEXT
      text = data?.v ?? loc("see more...")
      behavior = Behaviors.Button
      color = color
      watch = stateFlags
      onElemState = @(sf) stateFlags.set(sf)
      children = {rendObj=ROBJ_FRAME borderWidth = static [0,0,hdpx(1),0] color=color, size = flex()}
      function onClick() {
        openUrl(link)
      }
    }.__update(transcodedData)
  }
}

function mkUlElement(bullet){
  return function (elem, fmtFunc = noTextFormatFunc, style = defStyle, index = null) {
    local res = fmtFunc(elem)
    if (res == null)
      return null
    if (type(res) != "array")
      res = [res]
    let isBulletFn = type(bullet) == "function"
    return {
      size = FLEX_H
      flow = FLOW_HORIZONTAL
      children = [
        isBulletFn ? bullet(index, style) : bullet
      ].extend(res)
    }
  }
}

function mkList(elemFunc, startIndex = null){
  return function(obj, fmtFunc = noTextFormatFunc, style = defStyle) {
    local index = startIndex
    return obj.__merge({
      flow = FLOW_VERTICAL
      size = FLEX_H
      children = obj.v.map(@(elem) elemFunc(elem, fmtFunc, style, index != null ? index++ : null))
    })
  }
}

function horizontal(obj, fmtFunc=noTextFormatFunc, _style=defStyle){
  return obj.__merge({
    flow = FLOW_HORIZONTAL
    size = FLEX_H
    children = obj.v.map(@(elem) fmtFunc(elem))
  })
}

function accent(obj, fmtFunc=noTextFormatFunc, _style=defStyle){
  return obj.__merge({
    flow = FLOW_HORIZONTAL
    size = FLEX_H
    rendObj = ROBJ_SOLID
    color = Color(0,30,50,30)
    children = obj.v.map(@(elem) fmtFunc(elem))
  })
}

function vertical(obj, fmtFunc=noTextFormatFunc, _style=defStyle){
  return obj.__merge({
    flow = FLOW_VERTICAL
    size = FLEX_H
    children = obj.v.map(@(elem) fmtFunc(elem))
  })
}

let hangingIndent = calc_comp_size(defStyle.ulNoBullet)[0]

let bullets = mkList(mkUlElement(defStyle.ulBullet))
let numeric = mkList(mkUlElement(defStyle.olArabic), 1)
let indent = mkList(mkUlElement(defStyle.ulNoBullet))
let separatorCmp = {rendObj = ROBJ_FRAME borderWidth = static [0,0,hdpx(1), 0] size = static [flex(),hdpx(5)], opacity=0.2, margin=static [hdpx(5), hdpx(20), hdpx(20), hdpx(5)]}
let list = @(obj, fmtFunc = noTextFormatFunc, _style = defStyle) obj?.type == "olist" 
  ? numeric(obj, fmtFunc)
  : bullets(obj, fmtFunc)

function textParsed(params, fmtFunc=noTextFormatFunc, style=defStyle){
  if (params?.v == "----")
    return separatorCmp
  return textArea(params, fmtFunc, style)
}

function column(obj, fmtFunc=noTextFormatFunc, _style=defStyle){
  return {
    flow = FLOW_VERTICAL
    size = FLEX_H
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
    size = FLEX_H
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
  textAreaContainer
  text=textArea,
  paragraph = textArea
  hangingText=@(obj, fmtFunc=noTextFormatFunc, style=defStyle) textArea(obj.__merge({ hangingIndent = hangingIndent }), fmtFunc, style)
  h1 = @(text, fmtFunc=noTextFormatFunc, style=defStyle) textArea(text.__merge(style.h1FontStyle, {color=style.h1Color, margin = static [hdpx(15), 0, hdpx(25), 0]}), fmtFunc, style)
  h2 = @(text, fmtFunc=noTextFormatFunc, style=defStyle) textArea(text.__merge(style.h2FontStyle, {color=style.h2Color, margin = static [hdpx(10), 0, hdpx(15), 0]}), fmtFunc, style)
  h3 = @(text, fmtFunc=noTextFormatFunc, style=defStyle) textArea(text.__merge(style.h3FontStyle, {color=style.h3Color, margin = static [hdpx(5), 0, hdpx(10), 0]}), fmtFunc, style)
  emphasis = @(text, fmtFunc=noTextFormatFunc, style=defStyle) textArea(text.__merge({color=style.emphasisColor, margin = static [hdpx(5),0]}), fmtFunc, style)
  columns
  column
  image = function(obj, _fmtFunc=noTextFormatFunc, style=defStyle) {
    return {
      rendObj = ROBJ_IMAGE
      image=Picture(obj.v)
      size = [obj?.width!=null ? hdpx(obj.width) : flex(), obj?.height != null ? hdpx(obj.height) : hdpx(200)]
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
  list
  olist = numeric
  indent
  sep = @(obj, _fmtFunc=noTextFormatFunc, _style=defStyle) separatorCmp.__merge(obj)
  accent
  horizontal
  vertical
  video = function(obj, _fmtFunc, _style=defStyle) {
    let movieStatus = Watched({
      name = null
      error = null
    })
    load_movie(obj.v, movieStatus)
    return {
      size = [sw((obj?.width ?? 100) * 0.56), sw((obj?.height ?? 100) * 0.315)]
      hplace = ALIGN_CENTER
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = function() {
        let status = movieStatus.get()
        return {
          watch = movieStatus
          size = flex()
          rendObj = ROBJ_MOVIE
          movie = status.name
          behavior = status.name ? Behaviors.Movie : null
          keepAspect = KEEP_ASPECT_FIT
          loop = true

          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          children = status.error ? {
            rendObj = ROBJ_TEXT
            text = status.error
          } : null
        }
      }
    }.__update(obj)
  }
  transcodeTable
  load_movie
}

return freeze(formatters)
