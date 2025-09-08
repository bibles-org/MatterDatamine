from "%ui/ui_library.nut" import *
from "math" import sqrt, pow, sin, PI

let { mkBitmapPicture } = require("%darg/helpers/bitmap.nut")

let easings = {
  function easeInOutCubic(x) {
    return x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
  }
  function easeOutSine(x){
    return sin((x * PI) / 2)
  }
  function easeOutQuad(x) {
    return 1 - (1 - x) * (1 - x)
  }

  function easeInQuad(x) {
    return x * x
  }
  function easeInExpo(x){
    return x == 0 ? 0 : pow(2, 10 * x - 10)
  }
  linear = @(x) x
}

let mkSmoothBWGradientY = kwarg(function(height = 12, isAlphaPremultiplied = true, easing = "easeInQuad") {
  let w = 4
  let ease = easings[easing]
  return mkBitmapPicture(w, height,
    function(_, bmp) {
      for (local y = 0; y < height; y++) {
        let t = ease(y.tofloat()/height)

        let color = Color(t*255, t*255, t*255, t*255)
        for (local x = 0; x < w; x++)
          bmp.setPixel(x, y, color)
      }
    }, isAlphaPremultiplied ? "" : "!")
})

return {
  mkSmoothBWGradientY
}
