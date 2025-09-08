import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { indicatorsFontStyle, indicatorsFontSize, indicatorsIcoSize, indicatorsGap } = require("style.nut")
let { vitalParameterSize } = require("vital_info_common.nut")
let {
  PlayerInfoVeryLow,
  PlayerInfoLow,
  PlayerInfoMedium,
  PlayerInfoNormal
} = require("%ui/components/colors.nut")

let breath_shortness = Watched()
let isHoldBreath = Watched(false)
let breath_low_anim_trigger = {}
let breath_low_threshold = 0.3

ecs.register_es("hero_breath_ui_es",
  {
    [["onChange", "onInit"]]= function trackComponentsBreath(_eid,comp){
      let isAlive = comp["isAlive"]
      if (!isAlive) {
        breath_shortness(null)
        isHoldBreath(false)
        anim_request_stop(breath_low_anim_trigger)
        return
      }
      isHoldBreath(comp["human_net_phys__isHoldBreath"])
      let timer = comp["human_breath__timer"]
      let max_hold_breath_time = comp["human_breath__maxHoldBreathTime"]
      let ratio = (timer>max_hold_breath_time || (max_hold_breath_time==0)) ? 0.0 : ((max_hold_breath_time - timer) / max_hold_breath_time)

      if (max_hold_breath_time == 0)
        breath_shortness(null)
      else
        breath_shortness(ratio)

      if (!(ratio > breath_low_threshold)) {
        anim_start(breath_low_anim_trigger)
      }
      else {
        anim_request_stop(breath_low_anim_trigger)
      }
    }
  },
  {
    comps_track = [
      ["human_breath__timer", ecs.TYPE_FLOAT, 0],
      ["isAlive", ecs.TYPE_BOOL, true],
      ["human_breath__maxHoldBreathTime", ecs.TYPE_FLOAT, 20.0],
      ["human_breath__recoverBreathMult", ecs.TYPE_FLOAT, 2.0],
      ["human_breath__asphyxiationTimer", ecs.TYPE_FLOAT, 0.0],
      ["human_net_phys__isHoldBreath", ecs.TYPE_BOOL, false],
    ]
    comps_rq = ["watchedByPlr"]
  }
)

function breathToColor(val) {
  if (val < 30)
    return PlayerInfoVeryLow
  else if (val < 50)
    return PlayerInfoLow
  else if (val < 80)
    return PlayerInfoMedium
  else
    return PlayerInfoNormal
}

let breathAnimations = freeze([
  { prop=AnimProp.color, from=Color(180, 180, 180), to=Color(220, 140, 140), duration=1, play=false, easing=OutCubic, loop=true, trigger="breath_0" }
  { prop=AnimProp.color, from=Color(180, 180, 180), to=Color(220, 140, 140), duration=0.8, play=false, easing=OutCubic, loop=true, trigger="breath_1" }
  { prop=AnimProp.color, from=Color(180, 180, 180), to=Color(220, 140, 140), duration=0.6, play=false, easing=OutCubic, loop=true, trigger="breath_2" }
  { prop=AnimProp.color, from=Color(180, 180, 180), to=Color(220, 140, 140), duration=0.3, play=false, easing=OutCubic, loop=true, trigger="breath_3" }
])

function stopAllAnims() {
  foreach (ba in breathAnimations)
    anim_request_stop(ba.trigger)
}

function startBreathAnimNum(num) {
  num = clamp(num, 0, breathAnimations.len())
  foreach (i, ba in breathAnimations) {
    if (i != num)
      anim_request_stop(ba.trigger)
  }
  anim_start(breathAnimations[num].trigger)
}

local prevBreathCheck = 0
let delayedBreathCheck = Watched(100)
delayedBreathCheck.subscribe(function(v) {
  if (prevBreathCheck <= v) {
    stopAllAnims()
  }
  else {
    if (v < 30)
      startBreathAnimNum(3)
    else if (v < 50)
      startBreathAnimNum(2)
    else if (v < 80)
      startBreathAnimNum(1)
    else if (v < 100)
      startBreathAnimNum(0)
  }
  prevBreathCheck = v
})


let lungsIco = Picture($"!ui/skin#lungs.svg:{hdpxi(25)}:{hdpxi(25)}:P")

let ico = @(size, color) @() {
  rendObj = ROBJ_IMAGE
  image = lungsIco
  color
  size = size
  vplace = ALIGN_CENTER
  hplace = ALIGN_LEFT
  transform = const {}
  animations = breathAnimations
}

let breathVisibleWatched = Computed(function() {
  return breath_shortness.get() < 1.0
})

function mkBreathComp(customHdpxi = hdpxi, override = {}) {
  gui_scene.clearTimer("breathDelayedCheckTimer")

  let interval = 1.0
  gui_scene.setInterval(interval, function() {
    delayedBreathCheck.set(((breath_shortness.get() ?? 0) * 100).tointeger())
  }, "breathDelayedCheckTimer")

  return @() {
    watch = delayedBreathCheck
    halign = ALIGN_CENTER
    vplace = ALIGN_CENTER
    hplace = ALIGN_LEFT
    gap = customHdpxi(indicatorsGap)
    size = [ customHdpxi(vitalParameterSize[0]), customHdpxi(vitalParameterSize[1]) ]
    children = [
      ico(customHdpxi(indicatorsIcoSize), breathToColor(delayedBreathCheck.get()))
      indicatorsFontStyle.__merge({
        fontSize = customHdpxi(indicatorsFontSize)
        color = breathToColor(delayedBreathCheck.get())
        text = $"{delayedBreathCheck.get()}%"
      })
    ]
  }.__update(override)
}


let breathPanel = {
  panel = mkBreathComp
  visibleWatched = breathVisibleWatched
}

return { breathPanel, mkBreathUI = mkBreathComp, breathVisibleWatched, isHoldBreath}