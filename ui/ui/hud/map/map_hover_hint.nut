from "math" import abs
from "%ui/fonts_style.nut" import tiny_txt
from "%ui/components/commonComponents.nut" import mkText
from "%ui/components/colors.nut" import BtnBdNormal, MapIconEnable, MapIconDisable

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { hudIsInteractive } = require("%ui/hud/state/interactive_state.nut")
let { isInPlayerSession } = require("%ui/hud/state/gametype_state.nut")
let { watchedHeroPos } = require("%ui/hud/state/watched_hero.nut")

#allow-auto-freeze

local waterLevel = 0.0

ecs.register_es("water_level",
{
  onInit = @(_evt, _eid, comp) waterLevel = comp.water_level
  onDestroy = @(...) waterLevel = 0.0
},
{
  comps_ro = [
    ["water_level", ecs.TYPE_FLOAT]
  ]
})


const HEIGHT_THRESHOLD = 1

let mapHoverHintText = @(hintText) {
  padding = static [hdpx(1), hdpx(2), hdpx(1), hdpx(2)]
  rendObj = ROBJ_TEXT
  text = hintText
  fontSize = hdpx(15)
  color = Color(255, 255, 255)
  fontFx = FFT_GLOW
  fontFxColor = Color(30, 30, 10)
  fontFxFactor = 12
}

let altitudeStyle = tiny_txt.__merge({
  hplace = ALIGN_CENTER
})

let markUp = freeze({
  rendObj = ROBJ_VECTOR_CANVAS
  size = hdpxi(7)
  margin = hdpxi(3)
  fillColor = MapIconEnable
  color = BtnBdNormal
  commands = [
    [VECTOR_WIDTH, 0],
    [VECTOR_POLY, 0,100, 50,0, 100,100],
  ]
})

let markDown = freeze({
  rendObj = ROBJ_VECTOR_CANVAS
  size = hdpxi(7)
  margin = hdpxi(3)
  fillColor = MapIconDisable
  color = BtnBdNormal
  commands = [
    [VECTOR_WIDTH, 0],
    [VECTOR_POLY, 0,0, 50,100, 100,0],
  ]
})

let mkAltitudeText = @(altitude) function() {
  let heroPos = watchedHeroPos.get()
  
  let lowerThanHero = isInPlayerSession.get() && heroPos && altitude - heroPos.y < -HEIGHT_THRESHOLD
  let difference = heroPos ? abs(altitude - heroPos.y).tointeger() : 0
  

  let diffLoc = $"{difference}{loc("measureUnits/meters")} | " 
  return {
    watch = [watchedHeroPos, isInPlayerSession]
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    children = [
      !lowerThanHero ? markUp : markDown,
      heroPos ? mkText(diffLoc, altitudeStyle) : null,
      mkText(loc("marker_tooltip/altitude", {value=altitude.tointeger()}), altitudeStyle)
    ]
  }
}

let mapHoverableMarker = function(data, transform, text, markerConstructor, params = {}){
  let stateFlags = Watched(0)
  let {showAltitude=true, watch=null} = params
  let altitude = (showAltitude && data?.worldPos != null) ? (data.worldPos.y - waterLevel) : null
  let translate = altitude ? static [0, -sh(5.5)] : static [0, -sh(4.0)]
  let hoverText = text == null ? null : {
    size = SIZE_TO_CONTENT
    transform = {
      translate
    }
    rendObj = ROBJ_BOX
    fillColor = Color(40, 40, 40, 150)
    zOrder = Layers.Upper
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    children = [
      altitude ? mkAltitudeText(altitude) : null,
      mapHoverHintText(text)
    ]
  }

  
  
  
  let zeroSizeContainer = {
    size = 0
    halign = ALIGN_CENTER
    children = hoverText
  }
  return @() {
    watch = watch==null ? [stateFlags, hudIsInteractive] : [stateFlags, hudIsInteractive].extend(type(watch)=="array" ? watch : [watch])
    data = (typeof data == "function") ? data() : data
    transform
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    flow = FLOW_VERTICAL
    behavior = hudIsInteractive.get() ? Behaviors.Button : null
    onElemState = @(v) stateFlags.set(v)
    eventPassThrough = true
    skipDirPadNav = true
    stopHover = true
    children = [
      markerConstructor(stateFlags),
      stateFlags.get() & S_HOVER ? zeroSizeContainer : null
    ]
  }.__update(params ?? {})
}

return mapHoverableMarker
