from "%ui/ui_library.nut" import *

let { ceil } = require("math")

let mkCommands = @(width) [
  [VECTOR_FILL_COLOR, 0],
  [VECTOR_WIDTH, width],
  [VECTOR_COLOR, Color(180, 180, 180, 200)],
  [VECTOR_ELLIPSE, 50, 50, 50, 50],
]

let mkCircle = @(size, pos) {
  rendObj = ROBJ_VECTOR_CANVAS
  size = [size, size]
  commands = [
    [VECTOR_COLOR, Color(180, 180, 180)],
    [VECTOR_FILL_COLOR, Color(180, 180, 180)],
    [VECTOR_ELLIPSE, 50, 50, 50, 50]
  ]
  pos
}

return function mkSpinner(height = hdpx(80), delay = 0) {
  let circleHeight = height / 3.4
  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [height, height]
    halign = ALIGN_CENTER
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    commands = mkCommands(ceil(height/15))
    transform = { }
    animations = [
      { prop = AnimProp.opacity, from = 0, to = 0, duration=delay, play = true }
      { prop = AnimProp.rotate, from = 45, to = 405, delay, duration = 1.5, play = true,
        easing = InOutCubic, loop = true }]
    children = [
      mkCircle(circleHeight, [0, - circleHeight / 2])
      mkCircle(circleHeight, [0, height - circleHeight / 2])
    ]
  }
}
