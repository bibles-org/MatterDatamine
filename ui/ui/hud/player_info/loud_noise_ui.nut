from "%ui/hud/player_info/style.nut" import barHeight, barWidth
from "%ui/fonts_style.nut" import fontawesome
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
import "%ui/components/fontawesome.map.nut" as fa

let hideHud = require("%ui/hud/state/hide_hud.nut")

let noiseBarHeight = barHeight * 1
let iconSize = barHeight * 4
let loudNoiseLevel = Watched(0.0)
let maxBarNoise = 40.0

ecs.register_es("hud_loud_noise_state_es",
  {
    [["onInit","onChange"]] = @(_eid, comp) loudNoiseLevel.set(comp.loud_noise_meter__value),
    onDestroy = @(...) loudNoiseLevel.set(0)
  },
  {
    comps_track = [["loud_noise_meter__value", ecs.TYPE_FLOAT]]
    comps_rq = ["watchedByPlr"]
  }
)

function loudNoiseBar() {
  local children = null
  let stval = loudNoiseLevel.get()
  let showNoise = stval >= 0

  local width = barWidth

  if (showNoise) {
    let ratio = min(1.0, stval / maxBarNoise)
    let colorBg = Color(30, 30, 50, 40)
    local colorFg
    if (stval > maxBarNoise * 0.66)
      colorFg = Color(90, 0, 0, 90)
    else if (stval > maxBarNoise * 0.33)
      colorFg = Color(90, 90, 0, 90)
    else
      colorFg = Color(0, 90, 0, 90)

    children = [
      {
        rendObj = ROBJ_SOLID
        size = [width, noiseBarHeight]
        color = colorBg
        halign = ALIGN_LEFT
        children = {
          rendObj = ROBJ_SOLID
          color = colorFg
          size = [width*ratio,flex()]
        }
      }
    ]
  }


  return {
    size = [width, noiseBarHeight]
    watch = [loudNoiseLevel]
    children
  }
}

let loudNoiseComp = @(){
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  watch = hideHud
  size = [SIZE_TO_CONTENT, iconSize]
  gap = hdpx(3)
  children = hideHud.get() ? null : [
    freeze({
      rendObj = ROBJ_TEXT
      font = fontawesome.font
      text = fa["bullhorn"]
      fontSize = hdpx(15)
    })
    loudNoiseBar
  ]
}

return {
  loudNoiseComp
  loudNoiseLevel
  maxBarNoise
}