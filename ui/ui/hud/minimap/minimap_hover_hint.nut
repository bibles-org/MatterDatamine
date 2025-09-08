from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { abs } = require("math")
let { hudIsInteractive } = require("%ui/hud/state/interactive_state.nut")
let { tiny_txt } = require("%ui/fonts_style.nut")
let { mkText } = require("%ui/components/commonComponents.nut")
let { isInPlayerSession } = require("%ui/hud/state/gametype_state.nut")
let { watchedHeroPos } = require("%ui/hud/state/watched_hero.nut")
let { BtnBdNormal, MapIconEnable, MapIconDisable } = require("%ui/components/colors.nut")

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

let minimapHoverHintText = @(hintText) {
  padding = [hdpx(1), hdpx(2), hdpx(1), hdpx(2)]
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
  size = [hdpxi(7), hdpxi(7)]
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
  size = [hdpxi(7), hdpxi(7)]
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
  let higherThanHero = isInPlayerSession.get() && heroPos && altitude - heroPos.y > HEIGHT_THRESHOLD
  let lowerThanHero = isInPlayerSession.get() && heroPos && altitude - heroPos.y < -HEIGHT_THRESHOLD
  let difference = heroPos ? abs(altitude - heroPos.y).tointeger() : 0

  let diffLoc = $"{difference}{loc("measureUnits/meters")} | " 
  return {
    watch = [watchedHeroPos, isInPlayerSession]
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    children = [
      higherThanHero ? markUp : null,
      lowerThanHero ? markDown : null,
      higherThanHero || lowerThanHero ? mkText(diffLoc, altitudeStyle) : null,
      mkText(loc("marker_tooltip/altitude", {value=altitude.tointeger()}), altitudeStyle)
    ]
  }
}

let minimapHoverableMarker = function(data, transform, text, markerConstructor, additionalWatched = null, showAltitude = true){
  let stateFlags = Watched(0)
  let altitude = (showAltitude && data?.worldPos != null) ? (data.worldPos.y - waterLevel) : null
  let translate = altitude ? [0, -sh(5.5)] : [0, -sh(4.0)]
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
      minimapHoverHintText(text)
    ]
  }

  
  
  
  let zeroSizeContainer = {
    size = [0,0]
    halign = ALIGN_CENTER
    children = hoverText
  }
  return @() {
    data = (typeof data == "function") ? data() : data
    watch = additionalWatched ? [stateFlags, hudIsInteractive, additionalWatched] : [stateFlags, hudIsInteractive]
    transform
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    flow = FLOW_VERTICAL
    behavior = hudIsInteractive.value ? Behaviors.Button : null
    onElemState = @(v) stateFlags(v)
    eventPassThrough = true
    stopHover = true
    children = [
      markerConstructor(stateFlags),
      stateFlags.get() & S_HOVER ? zeroSizeContainer : null
    ]
  }
}

return minimapHoverableMarker
