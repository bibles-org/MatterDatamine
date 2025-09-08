from "%ui/ui_library.nut" import *
from "dagor.debug" import logerr
from "debug" import getstackinfos
from "%ui/fonts_style.nut" import fontawesome
import "%ui/components/fontawesome.map.nut" as fa

let font = fontawesome.font
let fontSize = fontawesome.fontSize
let size = fontSize.tointeger()
let getDefSizePicName = memoize(@(ico) $"!ui/skin#{ico}:{size}:{size}:K")
let numerics = {integer=1, float=1}

function faComp(symbol, params = null) {
  let symType = type(symbol)
  if (type(symType) != "string" || (symbol not in fa && !symbol.endswith(".svg"))) {
    log($"faComp, {symbol}", getstackinfos(2))
    log($"first argument should be string: fontawesome symbol or .svg filename")
    logerr("incorrect faComp first argument")
  }
  if (symbol in fa) {
    if (params == null)
      return freeze({text = fa[symbol], rendObj = ROBJ_TEXT, font, fontSize})
    if (type(params) == "table") {
      return freeze({text=fa[symbol], rendObj = ROBJ_TEXT, font, fontSize}.__update(params))
    }
    else {
      log($"faComp params:", params, getstackinfos(2))
      logerr("incorrect faComp params argument")
      return freeze({text=fa[symbol], rendObj = ROBJ_TEXT, font, fontSize})
    }
  }
  if (params == null)
    return freeze({image = Picture(getDefSizePicName(symbol)), rendObj = ROBJ_IMAGE, size, keepAspect=KEEP_ASPECT_FIT})
  if (type(params) == "table") {
    if ("size" in params) {
      let psize = params.size
      let resSize = type(psize) == "array" && type(params.size[1]) in numerics && type(params.size[0]) in numerics
        ? psize.map(@(v) v.tointeger())
        : psize in numerics ? psize.tointeger() : size
      return freeze({image = Picture($"!ui/skin#{symbol}:{resSize?[0] ?? size}:{resSize?[1] ?? size}:K"), rendObj = ROBJ_IMAGE, keepAspect=KEEP_ASPECT_FIT}.__update(params))
    }
    else {
      let resSize = type(params?.fontSize) in numerics ? params.fontSize.tointeger() : size
      return freeze({image = Picture($"!ui/skin#{symbol}:{resSize}:{resSize}:K"), rendObj = ROBJ_IMAGE, size=resSize, keepAspect=KEEP_ASPECT_FIT}.__update(params))
    }
  }
  else {
    log($"faComp params:", params, getstackinfos(2))
    logerr("incorrect faComp params argument")
    return freeze({image = Picture(getDefSizePicName(symbol)), rendObj = ROBJ_IMAGE, size, keepAspect=KEEP_ASPECT_FIT})
  }
}

return faComp