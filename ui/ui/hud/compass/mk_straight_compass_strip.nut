from "%ui/fonts_style.nut" import body_txt
from "%ui/components/colors.nut" import TextNormal

from "%ui/ui_library.nut" import *

let userPoints = require("%ui/hud/compass/compass_user_point.nut")
let { loudNoiseLevel } = require("%ui/hud/player_info/loud_noise_ui.nut")
let { assistantSpeakingScript } = require("%ui/hud/state/notes.nut")

#allow-auto-freeze

let step = 5
let defaultSize = [hdpx(600), hdpx(34)]

let compassFovSettings = {
  fov = 180      
}

let noize_strip_das = load_das("%ui/panels/noise_strip.das")

let noiseWidget = @() {
  watch = [ loudNoiseLevel, assistantSpeakingScript ]
  script = noize_strip_das
  size = defaultSize
  rendObj = ROBJ_DAS_CANVAS
  hplace = ALIGN_CENTER
  setupFunc = "setup_data"
  drawFunc = "draw_noise_strip"
  loudness = loudNoiseLevel.get()
  pos = [0, hdpx(25)]
  speech = assistantSpeakingScript.get() != null
}

let lookDirection = {
  data = {
    relativeAngle = 0 
  }

  transform = {}
  halign = ALIGN_CENTER
  valign = ALIGN_TOP

  rendObj = ROBJ_VECTOR_CANVAS
  size = hdpx(8)
  lineWidth = 2.0
  pos = [0, -hdpx(4)]
  color = TextNormal
  commands = [
    [VECTOR_LINE, 0, -100, 50,  20],
    [VECTOR_LINE, 50, 20, 100, -100],
  ]
}


function compassElem(text, angle, scale, lineHeight=hdpx(10)) {
  #forbid-auto-freeze
  let res = {
    data = {
      angle = angle 
    }

    transform = {}
    halign = ALIGN_CENTER
    valign = ALIGN_TOP
    flow = FLOW_VERTICAL

    children = [
      {
        rendObj = ROBJ_VECTOR_CANVAS
        size = [lineHeight, lineHeight]
        lineWidth = max(hdpx(2.8 * scale), hdpx(1.1))
        color = TextNormal
        commands = [
          [VECTOR_LINE, 50, 0, 50, 100 * scale],
        ]
      }
    ]
  }

  if (text)
    res.children.append(
      {
        rendObj = ROBJ_TEXT
        color = TextNormal
        opacity = (scale + 1.0) * 0.5
        text
      }.__update(body_txt, {fontSize = hdpx(18 * scale)})
    )

  return res
}

const bigCharScaleDef = 1.0
const microCharScaleDef = 0.5

let compassCardinalDir = @(text, angle, scale) compassElem(text, angle, bigCharScaleDef*scale)
let compassNotchDir = @(angle, scale) compassElem(null, angle, microCharScaleDef*scale)


let defaultsCompassObject = [
  {watch = userPoints, childrenCtor = @() userPoints.get()}
]

function mkStraightCompassStrip(compassObjects=[], globalScale = 1.0) {
  let children = ([].extend(defaultsCompassObject, compassObjects)).map(@(v) @(){
        size = flex()
        data = compassFovSettings
        behavior = DngBhv.PlaceOnCompassStrip
        watch = v.watch
        halign = ALIGN_CENTER
        children = v.childrenCtor()
      }
    )
  return function(){
    #forbid-auto-freeze
    let dirChildren = [lookDirection]
    let cardinalDirections = ["0", "45", "90", "135", "180", "225", "270", "315"]
    let minStep = step
    for (local angle = 0; angle < 360; angle += minStep) {
      let isCardinal = angle % 45 == 0
      let cardinalDir = angle % 45 == 0 ? angle / 45 : 0
      dirChildren.append(isCardinal
        ? compassCardinalDir(cardinalDirections[cardinalDir], angle, globalScale)
        : compassNotchDir(angle, globalScale))
    }
    #allow-auto-freeze
    return {
      size = defaultSize
      vplace = ALIGN_TOP
      halign = ALIGN_CENTER
      children = [
        noiseWidget
        {
          size = flex()
          data = compassFovSettings
          behavior = DngBhv.PlaceOnCompassStrip
          halign = ALIGN_CENTER
          children = dirChildren
        }
      ].extend(children)
    }
  }
}


return mkStraightCompassStrip
