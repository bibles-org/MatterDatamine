import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { vitalParameterSize } = require("vital_info_common.nut")
let { indicatorsFontStyle, indicatorsFontSize, indicatorsIcoSize, indicatorsGap } = require("style.nut")
let {
  PlayerInfoVeryLow,
  PlayerInfoLow,
  PlayerInfoMedium,
  PlayerInfoNormal
} = require("%ui/components/colors.nut")

let stamina = Watched(null)
let lowStamina  = Watched(false)
let scaleStamina = Watched(0)
let heartrate = Watched(0)
let fatigueThreshold = Watched(0)

let staminaAnimTrigger = persist("staminaAnimTrigger", @() {})

ecs.register_es("hud_stamina_state_es",
  {
    [["onInit","onChange"]] = function(_eid, comp){
      stamina.set(comp["view_stamina"])
      let isStaminaLow = comp["view_lowStamina"]
      lowStamina.set(isStaminaLow)
      if (isStaminaLow)
        anim_start(staminaAnimTrigger)
      else
        anim_request_stop(staminaAnimTrigger)
      scaleStamina.set(comp["entity_mods__staminaBoostMult"])
    },
    function onDestroy(_eid, _comp){
      stamina.set(null)
      lowStamina.set(null)
      scaleStamina.set(0)
    }
  },
  {
    comps_track = [
      ["view_stamina", ecs.TYPE_INT],
      ["view_lowStamina", ecs.TYPE_BOOL],
      ["entity_mods__staminaBoostMult", ecs.TYPE_FLOAT, 1.0],
    ]
    comps_rq = ["watchedByPlr"]
  }
)

console_register_command(@(value) stamina.set(value), "hud.stamina")

ecs.register_es("hud_hearbeat_state_es",
  {
    onUpdate = function(_eid, comp){ heartrate.set(comp.heartrate__value) }
  },
  {
    comps_ro = [["heartrate__value", ecs.TYPE_FLOAT]]
    comps_rq = ["watchedByPlr"]
  },
  { updateInterval = 2.0, before="*", after="*" }
)

ecs.register_es("hud_critical_hearbeat_state_es",
  {
    [["onInit","onChange"]] = function(_eid, comp){ fatigueThreshold.set(comp.heartrate__fatigueThreshold) }
  },
  {
    comps_track = [["heartrate__fatigueThreshold", ecs.TYPE_FLOAT]]
    comps_rq = ["watchedByPlr"]
  }
)

let thresholds = [162, 147]

function heartrateToColor(v) {
  if (v > thresholds[0])
    return PlayerInfoVeryLow
  else if (v > thresholds[1])
    return PlayerInfoLow
  else if (v > fatigueThreshold.get())
    return PlayerInfoMedium
  else
    return PlayerInfoNormal
}

let heartrateAnimations = freeze([
  { prop=AnimProp.scale, from=[1.0, 1.0], to=[1.1, 1.1], duration=0.5, play=false, easing=CosineFull, loopPause=0.6, loop=true, trigger="heartrate_0" }
  { prop=AnimProp.scale, from=[1.0, 1.0], to=[1.2, 1.2], duration=0.4, play=false, easing=CosineFull, loopPause=0.4, loop=true, trigger="heartrate_1" }
  { prop=AnimProp.scale, from=[0.9, 0.9], to=[1.2, 1.2], duration=0.3, play=false, easing=CosineFull, loopPause=0.2, loop=true, trigger="heartrate_2" }
  { prop=AnimProp.scale, from=[0.9, 0.9], to=[1.3, 1.3], duration=0.2, play=false, easing=CosineFull, loopPause=0.0, loop=true, trigger="heartrate_3" }
])

function startheartrateAnimNum(num) {
  let len = heartrateAnimations.len()
  num = clamp(num, 0, len)
  for (local i = 0; i < len; i++) {
    if (i != num)
      anim_request_stop($"heartrate_{i}")
  }
  anim_start($"heartrate_{num}")
}

heartrate.subscribe(function(v) {
  if (v > thresholds[0])
    startheartrateAnimNum(3)
  else if (v > thresholds[1])
    startheartrateAnimNum(2)
  else if (v > fatigueThreshold.get())
    startheartrateAnimNum(1)
  else
    startheartrateAnimNum(0)
})

let ico = memoize(@(color, iconSize) {
  rendObj = ROBJ_IMAGE
  image = Picture($"!ui/skin#heartbeat.svg:{iconSize}:{iconSize}:P")
  color
  size = [ iconSize, iconSize ]
  vplace = ALIGN_CENTER
  hplace = ALIGN_LEFT
  transform = {}
  animations = heartrateAnimations
})


function heartbeatComp(customHdpxi = hdpxi, override = {}) {
  return @(){
    watch = heartrate
    halign = ALIGN_CENTER
    vplace = ALIGN_CENTER
    hplace = ALIGN_LEFT
    gap = customHdpxi(indicatorsGap)
    size = [ customHdpxi(vitalParameterSize[0]), customHdpxi(vitalParameterSize[1]) ]
    children = [
      ico(heartrateToColor(heartrate.get().tointeger()), customHdpxi(indicatorsIcoSize))
      indicatorsFontStyle.__merge({
        fontSize = customHdpxi(indicatorsFontSize)
        color = heartrateToColor(heartrate.get().tointeger())
        text = $"{heartrate.get().tointeger()} "
      })
    ]
  }.__update(override)
}

let heartbeatPanel = {
  panel = heartbeatComp
  visibleWatched = Watched(true)
}

return { heartbeatPanel, mkHeartbeatUI=heartbeatComp }