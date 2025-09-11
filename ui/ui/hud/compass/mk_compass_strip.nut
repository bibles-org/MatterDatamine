from "%ui/fonts_style.nut" import tiny_txt
from "%ui/components/colors.nut" import TextNormal

from "%ui/ui_library.nut" import *

let userPoints = require("%ui/hud/compass/compass_user_point.nut")

#allow-auto-freeze

let lookDirection = {
  data = {
    relativeAngle = 0 
  }

  transform = {}

  
  rendObj = ROBJ_VECTOR_CANVAS
  size = static [hdpx(10), hdpx(7)]
  color = TextNormal
  commands = [
    [VECTOR_LINE, 0, 0, 50,  100],
    [VECTOR_LINE, 100, 0, 50, 100],
  ]
}


function compassElem(text, angle, lineHeight=hdpx(5), textStyle=tiny_txt) {

  let res = {
    data = {
      angle 
    }

    transform = {}
    halign = ALIGN_CENTER
    valign = ALIGN_TOP
    flow = FLOW_VERTICAL

    children = [
      text ? {
        rendObj = ROBJ_TEXT
        color = TextNormal
        text
      }.__update(textStyle) : null
      {
        rendObj = ROBJ_SOLID
        size = [angle == 0 ? hdpx(3) : hdpx(1), lineHeight]
        color = angle == 0 ? Color(255, 255, 255) : Color(160, 160, 160)
      }
    ]
  }

  return res
}

let compassFovSettings = {}

let defaultsCompassObject = [
  {watch = userPoints, childrenCtor = @() userPoints.get()}
]

let compassCardinalDir = @(text, angle) compassElem(text, angle, hdpx(6))

let compassNotchDir = @(angle) compassElem(null, angle, hdpx(2))


let defaultRadius = hdpx(180)
local mkCompassStrip = kwarg(function mkCompassStripImlp(diameter=defaultRadius, compassObjects=[], override = {}) {
  let children = ((clone defaultsCompassObject).extend(compassObjects)).map(@(v) @(){
        size = flex()
        data = compassFovSettings
        behavior = DngBhv.PlaceOnRoundCompassStrip
        watch = v.watch
        children = v.childrenCtor()
      }
    )
  return function(){
    #forbid-auto-freeze
    let compassDirs = []
    let cardinalDirections = ["0", "45", "90", "135", "180", "225", "270", "315"]
    for (local angle = 0; angle < 360; angle += 5) {
      let isCardinal = angle % 45 == 0
      let cardinalDir = angle % 45 == 0 ? angle / 45 : 0
      compassDirs.append(isCardinal ? compassCardinalDir(cardinalDirections[cardinalDir], angle) :
                          compassNotchDir(angle))
    }
    #allow-auto-freeze
    let animatedDirs = {
      size = [ diameter, diameter ]
      behavior = DngBhv.PlaceOnRoundCompassStrip
      children = compassDirs
    }.__update(override)

    return {
      size = [ diameter, diameter ]
      children = [
        {
          behavior = DngBhv.PlaceOnRoundCompassStrip
          size = flex()
          children = lookDirection
        }
      animatedDirs
    ].extend(children)
    }
  }
})


return mkCompassStrip
