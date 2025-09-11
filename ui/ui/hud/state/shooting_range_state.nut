from "%ui/components/commonComponents.nut" import mkText
from "%ui/fonts_style.nut" import body_txt, h1_txt
from "%ui/components/colors.nut" import TextHighlight, WindowBg
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { isInBattleState } = require("%ui/state/appState.nut")

let inShootingRange = Watched(null)

ecs.register_es("track_in_shooting_range_state",
  {
    onInit = @(_eid, _comp) inShootingRange.set(true)
    onDestroy = @(_eid, _comp) inShootingRange.set(false)
  },
  {
    comps_rq = [["player_base_enable_shooting"]]
  }
)

enum ShootingRangeUi {
  EnterWarn,
  ExitWarn,
  None
}
let warnToShow = Watched(ShootingRangeUi.None)

inShootingRange.subscribe_with_nasty_disregard_of_frp_update(function(value) {
  if (value == null || isInBattleState.get()) {
    warnToShow.set(ShootingRangeUi.None)
    return
  }
  if (value) {
    warnToShow.set(ShootingRangeUi.EnterWarn)
  } else {
    warnToShow.set(ShootingRangeUi.ExitWarn)
  }
})

const ALERT_ANIM_DURATION = 2
const SHORT_ANIM_DURATION = 0.4

let defTextStyle = { color = TextHighlight }.__update(body_txt)

let mkAnimText = @(txt, animations, override = {}) {
  clipChildren = true
  children = mkText(txt, {
    opacity = 0
    animations
  }.__update(defTextStyle, override))
}

let wrapperAnimations = static [
  { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.3, play = true, easing = OutCubic }
  { prop = AnimProp.opacity, from = 1, to = 1, duration = ALERT_ANIM_DURATION, play = true }
  { prop = AnimProp.opacity, from = 1, to = 0, duration = SHORT_ANIM_DURATION,
    delay = ALERT_ANIM_DURATION - SHORT_ANIM_DURATION, play = true, easing = OutCubic }
]

function shootingRangeWarn() {
  if (warnToShow.get() == ShootingRangeUi.None)
    return { watch = warnToShow }
  gui_scene.resetTimeout(ALERT_ANIM_DURATION, function() {
    warnToShow.set(ShootingRangeUi.None)
  })

  let textLoc = warnToShow.get() == ShootingRangeUi.EnterWarn
    ? loc("shooting_range/enter")
    : loc("shooting_range/exit")

  let childrenText = mkAnimText(textLoc, wrapperAnimations,
    { padding = hdpx(100)}.__update(h1_txt))
  let bgImageResolution = [hdpxi(200), hdpxi(100)]

  return {
    watch = warnToShow
    size = flex()
    stopMouse = true
    children = {
      hplace = ALIGN_CENTER
      halign = ALIGN_CENTER
      vplace = ALIGN_TOP
      valign = ALIGN_CENTER
      rendObj = ROBJ_IMAGE
      size = SIZE_TO_CONTENT
      color = WindowBg
      image = Picture($"!ui/skin#round_grad.svg:{bgImageResolution[0]}:{bgImageResolution[1]}:K")
      opacity = 0
      animations = wrapperAnimations
      children = childrenText
    }
  }
}


return {
  inShootingRange
  shootingRangeWarn
}