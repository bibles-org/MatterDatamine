from "%ui/ui_library.nut" import *

let animChild = @(size, color, animations = []) {
  rendObj = ROBJ_SOLID
  size
  color
  pos = [0, -size[1]/2]
  opacity = 0.5
  animations
  transform = {
    rotate = 45.0
  }
}

let animChildren = @(animations) {
  flow = FLOW_HORIZONTAL
  pos = [-hdpx(80), 0]
  vplace = ALIGN_TOP
  gap = hdpx(40)
  size = flex()
  children = [
    animChild([hdpx(8), hdpx(400)], 0xAAAAAAAA, animations)
    animChild([hdpx(30), hdpx(400)], 0xAAAAAAAA, animations)
  ]
}

let glareAnimation = @(delay = 0) [
  { prop = AnimProp.translate, from = [-hdpx(1200), 0], to = [hdpx(1200), 0],
    duration = 4, play = true, loop = true, delay }
]

let marketAnimChildren = @(animations) {
  flow = FLOW_HORIZONTAL
  vplace = ALIGN_TOP
  gap = hdpx(40)
  size = flex()
  pos = [-hdpx(100), 0]
  children = [
    animChild([hdpx(30), hdpx(150)], 0xAAAAAAAA, animations)
    animChild([hdpx(8), hdpx(150)], 0xAAAAAAAA, animations)
  ]
}

let marketGlareAnim = @(trigger, duration = 0.6) [
  { prop = AnimProp.opacity, from = 0, to = 0.5,
    duration = 0.1, trigger }
  { prop = AnimProp.opacity, from = 0.5, to = 0.5,
    duration, trigger, easing = InOutCubic }
  { prop = AnimProp.translate, from = [0, 0], to = [hdpx(500), 0],
    duration, trigger, easing = InOutCubic }
]

return {
  animChildren
  glareAnimation
  marketAnimChildren
  marketGlareAnim
}