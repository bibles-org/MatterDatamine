from "%sqstd/math.nut" import round_by_value

from "%ui/fonts_style.nut" import sub_txt, body_txt, h2_txt
from "%ui/components/colors.nut" import Alert, TextNormal
from "dagor.math" import Point3
from "%ui/helpers/common_queries.nut" import get_pos

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { photographObjectiveInPlace, photographObjectiveTargetEid, photographObjectiveTargetInView,
  photographObjectiveTargetName, photographObjectiveDetectedTargetEid, photographUIActive,
  showCameraTargetObscuredTip } = require("%ui/hud/state/hud_objective_photograph_state.nut")
let { curTime } = require("%ui/hud/state/time_state.nut")
let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")
let { safeAreaVerPadding } = require("%ui/options/safeArea.nut")

let lineWidth = 0.20
let viewfinderLineLength = 33
let viewfinderLineColorDefault = Color(195, 195, 195, 155)
let viewfinderLineColorInvalidPlace = Color(250, 5, 5, 255)
let viewfinderLineColorTargetInView = Color(5, 255, 5, 255)

let targetCaptureColor = Color(85, 255, 255, 255)

let detectedTargetCaptureWarnColor = Color(170, 170, 100, 110)
let detectedTargetCaptureErrColor = Color(200, 140, 100, 110)

let invalidPlaceTextColor1 = Alert
let invalidPlaceTextColor2 = Color(255,30,30,220)


function get_distance_between(eid0, eid1) {
  let pos0 = get_pos(eid0)
  let pos1 = get_pos(eid1)
  return (pos0 - pos1).length()
}


function mkInvalidPlaceFill() {
  return {
    rendObj = ROBJ_SOLID
    size = flex()
    color = Color(20, 0, 0, 125)
    animations = static [
      { prop=AnimProp.opacity, from=0.0, to=1.0, duration=0.35, play=true, easing=OutCubic }
      { prop=AnimProp.opacity, from=1.0, to=0.0, duration=0.25, playFadeOut=true, easing=OutCubic }
    ]
  }
}


function mkFlashFill(){
  return {
    rendObj = ROBJ_SOLID
    size = flex()
    color = Color(90, 90, 90, 40)
    opacity = 0.0
    animations = static [
      { trigger="photograph_flash", prop=AnimProp.opacity, from=1, to=0, duration=1.5, easing=OutCubic }
    ]
  }
}


function photographTargetLabel() {
  let distance = round_by_value(
    get_distance_between(
      watchedHeroEid.get(),
      photographObjectiveTargetEid.get()),
    0.1)
  return {
    rendObj = ROBJ_TEXT
    color = Color(255, 255, 255, 255)
    size = SIZE_TO_CONTENT
    text = $"{loc(photographObjectiveTargetName.get(), "Unknown")} ({distance}m)"
    fontSize = sub_txt.fontSize
    hplace = ALIGN_LEFT
    vplace = ALIGN_BOTTOM
    watch = static [curTime, photographObjectiveTargetName]
    transform = static {
      translate = [0, sh(2.25)]
    }
  }
}

function mkPhotographObjectiveTarget() {
  return {
    size = ph(27)

    data = {
      eid = photographObjectiveTargetEid.get()
      minDistance = 0
      maxDistance = 10000
      clampToBorder = false
      worldPos = get_pos(photographObjectiveTargetEid.get())
    }
    markerFlags = DngBhv.MARKER_SHOW_ONLY_IN_VIEWPORT
    transform = static {}
    animations =  static [
      { prop=AnimProp.opacity, from=1.0, to=0.0, duration=0.05, playFadeOut=true, easing=InCubic }
    ]

    children = {
      size = flex()

      transform = static {}

      animations = static [
        { prop=AnimProp.scale, from=[1.5, 1.5], duration=0.55, play=true, easing=OutCubic }
        { prop=AnimProp.opacity, from=0, to=1, duration=0.55, play=true, easing=OutCubic }
      ]

      children = [
        
        static {
          rendObj = ROBJ_SOLID
          size = [fsh(lineWidth), ph(viewfinderLineLength)]
          color = targetCaptureColor
          hplace = ALIGN_LEFT
          vplace = ALIGN_BOTTOM
        }
        static {
          rendObj = ROBJ_SOLID
          size = [ph(viewfinderLineLength), fsh(lineWidth)]
          color = targetCaptureColor
          hplace = ALIGN_LEFT
          vplace = ALIGN_BOTTOM
        }
        
        static {
          rendObj = ROBJ_SOLID
          size = [fsh(lineWidth), ph(viewfinderLineLength)]
          color = targetCaptureColor
          hplace = ALIGN_LEFT
          vplace = ALIGN_TOP
        }
        static {
          rendObj = ROBJ_SOLID
          size = [ph(viewfinderLineLength), fsh(lineWidth)]
          color = targetCaptureColor
          hplace = ALIGN_LEFT
          vplace = ALIGN_TOP
        }
        
        static {
          rendObj = ROBJ_SOLID
          size = [fsh(lineWidth), ph(viewfinderLineLength)]
          color = targetCaptureColor
          hplace = ALIGN_RIGHT
          vplace = ALIGN_BOTTOM
        }
        static {
          rendObj = ROBJ_SOLID
          size = [ph(viewfinderLineLength), fsh(lineWidth)]
          color = targetCaptureColor
          hplace = ALIGN_RIGHT
          vplace = ALIGN_BOTTOM
        }
        
        static {
          rendObj = ROBJ_SOLID
          size = [fsh(lineWidth), ph(viewfinderLineLength)]
          color = targetCaptureColor
          hplace = ALIGN_RIGHT
          vplace = ALIGN_TOP
        }
        static {
          rendObj = ROBJ_SOLID
          size = [ph(viewfinderLineLength), fsh(lineWidth)]
          color = targetCaptureColor
          hplace = ALIGN_RIGHT
          vplace = ALIGN_TOP
        }
        
        photographTargetLabel
      ]
    }
  }
}

function mkPhotographObjectiveDetectedTarget() {
  let colorW = Computed(@() showCameraTargetObscuredTip.get() ? detectedTargetCaptureErrColor : detectedTargetCaptureWarnColor)
  return {
    data = {
      eid = photographObjectiveDetectedTargetEid.get()
      minDistance = 0
      maxDistance = 10000
      clampToBorder = true
      worldPos = get_pos(photographObjectiveDetectedTargetEid.get())
    }
    transform = {}

    animations = [
      { prop=AnimProp.opacity, from=1.0, to=0.0, duration=0.05, playFadeOut=true, easing=InCubic }
    ]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      @() {
        data = {
          clampToBorder = true
        }
        clampBorderOffset = safeAreaVerPadding.get() + hdpxi(30)
        markerFlags = DngBhv.MARKER_SHOW_ONLY_WHEN_CLAMPED
        transform = {}

        rendObj = ROBJ_IMAGE
        image = Picture($"ui/skin#eye.svg:{hdpxi(40)}:{hdpxi(40)}:P")
        color = TextNormal
        size = hdpxi(40)
      }
      @() {
        watch = colorW
        size = sh(25)
        markerFlags = DngBhv.MARKER_SHOW_ONLY_IN_VIEWPORT
        children = [
          
          {
            rendObj = ROBJ_SOLID
            size = [fsh(lineWidth), ph(viewfinderLineLength)]
            color = colorW.get()
            hplace = ALIGN_LEFT
            vplace = ALIGN_BOTTOM
          }
          {
            rendObj = ROBJ_SOLID
            size = [ph(viewfinderLineLength), fsh(lineWidth)]
            color = colorW.get()
            hplace = ALIGN_LEFT
            vplace = ALIGN_BOTTOM
          }
          
          {
            rendObj = ROBJ_SOLID
            size = [fsh(lineWidth), ph(viewfinderLineLength)]
            color = colorW.get()
            hplace = ALIGN_LEFT
            vplace = ALIGN_TOP
          }
          {
            rendObj = ROBJ_SOLID
            size = [ph(viewfinderLineLength), fsh(lineWidth)]
            color = colorW.get()
            hplace = ALIGN_LEFT
            vplace = ALIGN_TOP
          }
          
          {
            rendObj = ROBJ_SOLID
            size = [fsh(lineWidth), ph(viewfinderLineLength)]
            color = colorW.get()
            hplace = ALIGN_RIGHT
            vplace = ALIGN_BOTTOM
          }
          {
            rendObj = ROBJ_SOLID
            size = [ph(viewfinderLineLength), fsh(lineWidth)]
            color = colorW.get()
            hplace = ALIGN_RIGHT
            vplace = ALIGN_BOTTOM
          }
          
          {
            rendObj = ROBJ_SOLID
            size = [fsh(lineWidth), ph(viewfinderLineLength)]
            color = colorW.get()
            hplace = ALIGN_RIGHT
            vplace = ALIGN_TOP
          }
          {
            rendObj = ROBJ_SOLID
            size = [ph(viewfinderLineLength), fsh(lineWidth)]
            color = colorW.get()
            hplace = ALIGN_RIGHT
            vplace = ALIGN_TOP
          }
        ]
      }
    ]
  }
}

function photographTargetMarks() {
  return {
    size = flex()
    behavior = DngBhv.Projection
    watch = [
      safeAreaVerPadding,
      photographObjectiveTargetEid,
      photographObjectiveDetectedTargetEid,
      photographObjectiveInPlace
    ]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER

    animations = [
      { prop=AnimProp.opacity, from=1.0, to=0.0, duration=0.35, playFadeOut=true, easing=InCubic }
    ]

    children = [
      {
        size = flex()
        data = {
          isViewport = true
        }
      }
      
      photographObjectiveTargetEid.get() == ecs.INVALID_ENTITY_ID && photographObjectiveDetectedTargetEid.get() != ecs.INVALID_ENTITY_ID ? mkPhotographObjectiveDetectedTarget() : null
      
      photographObjectiveTargetEid.get() != ecs.INVALID_ENTITY_ID ? mkPhotographObjectiveTarget() : null
    ]
  }
}

function mkWrongPlaceLabel() {
  return {
    rendObj = ROBJ_TEXT
    size = flex()
    text = loc("photo/wrong_place", "Wrong location")
    fontSize = h2_txt.fontSize
    animations = [
      {prop = AnimProp.color, from = invalidPlaceTextColor1, to = invalidPlaceTextColor2, duration = 1.5, loop = true, play = true, easing = CosineFull }
    ]
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
  }
}

function mkCameraUi() {
  let isTargetValid = (photographObjectiveTargetEid.get() != ecs.INVALID_ENTITY_ID) && photographObjectiveTargetInView.get()

  let viewfinderColor = photographObjectiveInPlace.get() ? (
    isTargetValid ? viewfinderLineColorTargetInView
                  : viewfinderLineColorDefault) : viewfinderLineColorInvalidPlace
  return {
    size = static [ph(100), flex()]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER

    children = [
      
      {
        size = static [ph(80), ph(40)]

        animations = [
          { prop=AnimProp.opacity, from=0, to=1, duration=0.65, play=true, easing=OutCubic }
          { prop=AnimProp.opacity, from=1.0, to=0.0, duration=0.35, playFadeOut=true, easing=InCubic }
        ]

        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        hplace = ALIGN_CENTER
        vplace = ALIGN_CENTER

        children = [
          
          {
            rendObj = ROBJ_SOLID
            size = [fsh(lineWidth), ph(viewfinderLineLength)]
            color = viewfinderColor
            hplace = ALIGN_LEFT
            vplace = ALIGN_BOTTOM
          }
          {
            rendObj = ROBJ_SOLID
            size = [ph(viewfinderLineLength), fsh(lineWidth)]
            color = viewfinderColor
            hplace = ALIGN_LEFT
            vplace = ALIGN_BOTTOM
          }
          
          {
            rendObj = ROBJ_SOLID
            size = [fsh(lineWidth), ph(viewfinderLineLength)]
            color = viewfinderColor
            hplace = ALIGN_LEFT
            vplace = ALIGN_TOP
          }
          {
            rendObj = ROBJ_SOLID
            size = [ph(viewfinderLineLength), fsh(lineWidth)]
            color = viewfinderColor
            hplace = ALIGN_LEFT
            vplace = ALIGN_TOP
          }
          
          {
            rendObj = ROBJ_SOLID
            size = [fsh(lineWidth), ph(viewfinderLineLength)]
            color = viewfinderColor
            hplace = ALIGN_RIGHT
            vplace = ALIGN_BOTTOM
          }
          {
            rendObj = ROBJ_SOLID
            size = [ph(viewfinderLineLength), fsh(lineWidth)]
            color = viewfinderColor
            hplace = ALIGN_RIGHT
            vplace = ALIGN_BOTTOM
          }
          
          {
            rendObj = ROBJ_SOLID
            size = [fsh(lineWidth), ph(viewfinderLineLength)]
            color = viewfinderColor
            hplace = ALIGN_RIGHT
            vplace = ALIGN_TOP
          }
          {
            rendObj = ROBJ_SOLID
            size = [ph(viewfinderLineLength), fsh(lineWidth)]
            color = viewfinderColor
            hplace = ALIGN_RIGHT
            vplace = ALIGN_TOP
          }
          
          photographObjectiveInPlace.get() && !isTargetValid ? {
            rendObj = ROBJ_SOLID
            size = [fsh(lineWidth), ph(viewfinderLineLength * 0.5)]
            color = viewfinderColor
            hplace = ALIGN_CENTER
            vplace = ALIGN_CENTER
          } : null
          photographObjectiveInPlace.get() && !isTargetValid ? {
            rendObj = ROBJ_SOLID
            size = [ph(viewfinderLineLength * 0.5), fsh(lineWidth)]
            color = viewfinderColor
            hplace = ALIGN_CENTER
            vplace = ALIGN_CENTER
          } : null
          !photographObjectiveInPlace.get() ? mkWrongPlaceLabel() : null
        ]
      }
    ]
  }
}


function photographObjective() {
  return {
    watch = photographUIActive
    size = flex()
    children = photographUIActive.get() ? {
      size = flex()
      animations = [
        { prop=AnimProp.opacity, from=1.0, to=0.0, duration=0.45, playFadeOut=true, easing=InCubic }
      ]
      children = [
        @() {
          size = flex()
          watch = [
            photographObjectiveInPlace,
            photographObjectiveTargetEid,
            photographObjectiveTargetInView
          ]
          children = [
            
            !photographObjectiveInPlace.get() ? mkInvalidPlaceFill() : null

            
            photographTargetMarks

            
            mkCameraUi()
          ]
        }

        
        mkFlashFill()
      ]


    } : null
  }
}

return {
  photographObjective
}
