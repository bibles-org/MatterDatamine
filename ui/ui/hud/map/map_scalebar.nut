from "%sqstd/string.nut" import floatToStringRounded

from "%ui/components/colors.nut" import TextNormal, HudTipFillColor
from "%ui/fonts_style.nut" import tiny_txt
from "%ui/components/cursors.nut" import setTooltip
from "dagor.system" import DBGLEVEL

from "%ui/ui_library.nut" import *

let { currentMapVisibleRadius } = require("%ui/hud/map/map_state.nut")

let { tiledMapExist } = require("%ui/hud/map/tiled_map_ctx.nut")
let { hudIsInteractive } = require("%ui/hud/state/interactive_state.nut")


let fiexdReferenceScales = [ 1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000 ]

let textHeight = calc_str_box("A", tiny_txt)[1]

function mkScalebar(mapSize) {
  return function(){
    if (currentMapVisibleRadius.get() == 0)
      return { watch = currentMapVisibleRadius }

    let minDim = min(mapSize[0], mapSize[1])
    let resolution = currentMapVisibleRadius.get() * 2.0 / minDim

    let wishedScalebarSize = mapSize[0] * 0.1 
    let wishedScale = wishedScalebarSize * resolution

    let scale = fiexdReferenceScales.findvalue(@(s) s > wishedScale) ?? fiexdReferenceScales.top()
    let size = [scale / resolution, hdpxi(5)]

    let scalebar = {
      rendObj = ROBJ_VECTOR_CANVAS
      size = size
      color = TextNormal
      hplace = ALIGN_CENTER
      vplace = ALIGN_BOTTOM
      commands =
        [[ VECTOR_LINE, 0,0, 0,100, 100,100, 100,0 ]]
    }
    let metersLoc = loc("measureUnits/meters")
    let scaleText = {
      rendObj = ROBJ_TEXT
      text = $"{floatToStringRounded(scale, 1)} {metersLoc}"
      color = TextNormal
      halign = ALIGN_CENTER
      valign = ALIGN_TOP
      hplace = ALIGN_CENTER
      vplace = ALIGN_TOP
    }.__merge(tiny_txt)
    return {
      transform = tiledMapExist.get() ? null : { rotate = -90, pivot = [1, 1] }
      rendObj = ROBJ_SOLID
      color = HudTipFillColor
      watch = [currentMapVisibleRadius, tiledMapExist, hudIsInteractive]
      size = [scale / resolution, textHeight * 1.1]
      hplace = ALIGN_RIGHT
      vplace = tiledMapExist.get() ? ALIGN_BOTTOM : ALIGN_TOP
      margin = mapSize[0] * 0.01
      children = [scalebar, scaleText]
      skipDirPadNav = true

      behavior = (DBGLEVEL != 0 && hudIsInteractive.get()) ? Behaviors.Button : null
      function onHover(on) {
        if (on) {
          setTooltip($"DBG: Visible radius: {floatToStringRounded(currentMapVisibleRadius.get(), 0.1)}")
        } else {
          setTooltip(null)
        }
      }
    }
  }
}

return freeze({
  scalebar = {
    watch = currentMapVisibleRadius
    ctor = @(p) mkScalebar(p?.size)
  }
})
