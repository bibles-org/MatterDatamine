from "%ui/fonts_style.nut" import body_txt
import "string" as string

from "%ui/ui_library.nut" import *

let { isDowned, isAlive } = require("%ui/hud/state/health_state.nut")
let { isSpectator } = require("%ui/hud/state/spectator_state.nut")
let { downedEndTime } = require("%ui/hud/state/downed_state.nut")
let { medkitEndTime, medkitStartTime } = require("%ui/hud/state/entity_use_state.nut")
let { curTime } = require("%ui/hud/state/time_state.nut")
let { tipBack } = require("%ui/hud/tips/tipComponent.nut")

let color0 = Color(200,200,40,110)
let color1 = Color(200,200,200,180)
let overlapTipWithHeal = 1.0
let isInDowned = Computed(@() isDowned.get() && isAlive.get())

let animColor = [
  { prop=AnimProp.color, from=color0, to=color1, duration=1.0, play=true, loop=true, easing=CosineFull }
  { prop=AnimProp.scale, from=[1,1], to=[1.0, 1.1], duration=3.0, play=true, loop=true, easing=CosineFull }
]
let animAppear = [{ prop=AnimProp.translate, from=[sw(50),0], to=[0,0], duration=0.5, play=true, easing=InBack }]

let pivot = {pivot=[0,0.5]}
let tip = tipBack.__merge({
  transform = pivot
  animations = animAppear
  children = [
    @(){
      rendObj = ROBJ_TEXT
      text = loc(isSpectator.get() ? "tips/spectator_downed_tip" : "tips/downed_tip", {
        timeLeft = string.format("%d", max(downedEndTime.get() - curTime.get(), 0.0))
      })
      color = color0
      transform = pivot
      watch = [downedEndTime, curTime, isSpectator]
      animations = animColor
    }.__update(body_txt)
  ]
})
function mkTip(){
  let needTip = Computed(@()
      (downedEndTime.get() > curTime.get()) && ((medkitEndTime.get() < curTime.get()) || (medkitStartTime.get() + overlapTipWithHeal > curTime.get())))
  return @(){
    watch = needTip
    size = SIZE_TO_CONTENT
    children = needTip.get() ? tip : null
  }
}
return function() {
  return {
    watch = isInDowned
    size = SIZE_TO_CONTENT
    children = !isInDowned.get() ? null : mkTip()
  }
}
