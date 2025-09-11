from "%ui/hud/tips/tipComponent.nut" import tipCmp

from "%ui/ui_library.nut" import *

let { isBurning } = require("%ui/hud/state/burning_state_es.nut")
let { isAlive } = require("%ui/hud/state/health_state.nut")

let color0 = Color(200,200,40,110)
let color1 = Color(200,200,200,180)

let animColor = [
  { prop=AnimProp.color, from=color0, to=color1, duration=1.0, play=true, loop=true, easing=CosineFull }
  { prop=AnimProp.scale, from=[1,1], to=[1.0, 1.1], duration=3.0, play=true, loop=true, easing=CosineFull }
]
let animAppear = [{ prop=AnimProp.translate, from=[sw(50),0], to=[0,0], duration=0.5, play=true, easing=InBack }]

let tip = tipCmp({
  inputId = "Human.PutOutFire"
  text = loc("tips/burning_tip")
  textStyle = {
    textColor = Color(200,200,40,110)
    textAnims = animColor
  }
  needCharAnimation = false
  animations = animAppear
})

return function() {
  return {
    watch = [isBurning, isAlive]
    size = SIZE_TO_CONTENT
    children = isBurning.get() && isAlive.get() ? tip : null
  }
}
