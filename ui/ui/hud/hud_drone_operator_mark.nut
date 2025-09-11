from "%sqstd/math.nut" import round_by_value

from "%ui/fonts_style.nut" import sub_txt
from "%ui/helpers/common_queries.nut" import get_pos
from "dagor.math" import Point3

from "%ui/ui_library.nut" import *

let { droneOperator, isDroneMode, distanceToOperator, droneOperatorLang } = require("%ui/hud/state/drone_state.nut")
let { curTime } = require("%ui/hud/state/time_state.nut")

let lineWidth = 0.20
let viewfinderLineLength = 33

let targetCaptureColor = Color(85, 255, 85, 255)

function droneOperatorLabel() {
  let distance = round_by_value(distanceToOperator.get(), 0.1)
  return {
    rendObj = ROBJ_TEXT
    color = Color(255, 255, 255, 255)
    size = SIZE_TO_CONTENT
    text = $"{loc(droneOperatorLang.get(), "Unknown")} ({distance}m)"
    fontSize = sub_txt.fontSize
    hplace = ALIGN_LEFT
    vplace = ALIGN_BOTTOM
    watch = [curTime, distanceToOperator]
    transform = {
      translate = [0, sh(2.25)]
    }
  }
}

function mkDroneOperatorMark() {
  let dist = 5.0 / (distanceToOperator.get() > 0.0 ? distanceToOperator.get() : 10.0)
  return @() {
    watch = droneOperator
    size = [ph(15 * dist), ph(24 * dist)]
    data = {
      eid = droneOperator.get()
      minDistance = 0
      maxDistance = 10000
      clampToBorder = false
      worldPos = get_pos(droneOperator.get()) + Point3(0.0, 0.7, 0.0)
    }
    markerFlags = DngBhv.MARKER_SHOW_ONLY_IN_VIEWPORT
    transform = {}

    children = {
      size = flex()

      transform = {}

      children = [
        
        {
          rendObj = ROBJ_SOLID
          size = [fsh(lineWidth), ph(viewfinderLineLength)]
          color = targetCaptureColor
          hplace = ALIGN_LEFT
          vplace = ALIGN_BOTTOM
        }
        {
          rendObj = ROBJ_SOLID
          size = [ph(viewfinderLineLength * 0.5), fsh(lineWidth)]
          color = targetCaptureColor
          hplace = ALIGN_LEFT
          vplace = ALIGN_BOTTOM
        }
        
        {
          rendObj = ROBJ_SOLID
          size = [fsh(lineWidth), ph(viewfinderLineLength)]
          color = targetCaptureColor
          hplace = ALIGN_LEFT
          vplace = ALIGN_TOP
        }
        {
          rendObj = ROBJ_SOLID
          size = [ph(viewfinderLineLength * 0.5), fsh(lineWidth)]
          color = targetCaptureColor
          hplace = ALIGN_LEFT
          vplace = ALIGN_TOP
        }
        
        {
          rendObj = ROBJ_SOLID
          size = [fsh(lineWidth), ph(viewfinderLineLength)]
          color = targetCaptureColor
          hplace = ALIGN_RIGHT
          vplace = ALIGN_BOTTOM
        }
        {
          rendObj = ROBJ_SOLID
          size = [ph(viewfinderLineLength * 0.5), fsh(lineWidth)]
          color = targetCaptureColor
          hplace = ALIGN_RIGHT
          vplace = ALIGN_BOTTOM
        }
        
        {
          rendObj = ROBJ_SOLID
          size = [fsh(lineWidth), ph(viewfinderLineLength)]
          color = targetCaptureColor
          hplace = ALIGN_RIGHT
          vplace = ALIGN_TOP
        }
        {
          rendObj = ROBJ_SOLID
          size = [ph(viewfinderLineLength * 0.5), fsh(lineWidth)]
          color = targetCaptureColor
          hplace = ALIGN_RIGHT
          vplace = ALIGN_TOP
        }
        
        droneOperatorLabel
      ]
    }
  }
}

function droneOperatorMark() {
  return {
    size = flex()
    behavior = DngBhv.Projection
    watch = [
      isDroneMode,
      distanceToOperator
    ]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      {
        size = flex()
        data = {
          isViewport = true
        }
      }
      isDroneMode.get() ? mkDroneOperatorMark() : null
    ]
  }
}

function hudDroneOperatorMark() {
  return {
    watch = isDroneMode
    size = flex()
    children = isDroneMode.get() ? {
      size = flex()
      children = [
        @() {
          size = flex()
          watch = [
            isDroneMode,
            droneOperator,
            distanceToOperator
          ]
          children = [
            droneOperatorMark
          ]
        }
      ]
    } : null
  }
}

return {
  size = flex()

  children = [
    hudDroneOperatorMark
  ]
}