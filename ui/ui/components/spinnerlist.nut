from "%ui/fonts_style.nut" import body_txt, fontawesome
from "%ui/components/colors.nut" import BtnBdDisabled, BtnBdNormal, BtnBdHover, BtnBgHover, BtnBgActive, BtnBgDisabled, BtnTextNormal
from "%ui/components/sounds.nut" import buttonSound
from "%ui/components/cursors.nut" import setTooltip
from "%ui/cursorState.nut" import showCursor
from "%ui/ui_library.nut" import *
import "%ui/components/fontawesome.map.nut" as fa

#allow-auto-freeze

let fillColor = @(sf, active)
  ! active
    ? BtnBdDisabled
    : (sf & S_HOVER) ? BtnBdHover : BtnBdNormal

let spinnerLeftLoc = loc("spinner/prevValue")
let spinnerRightLoc = loc("spinner/nextValue")

let mkSpinnerLine = @(sf, indexWatch, total, setValue, allValues, group, hint) @() {
  watch = [indexWatch, showCursor]
  size = FLEX_H
  gap = hdpx(4)
  padding = static [hdpx(2), hdpx(4), hdpx(2), 0]
  margin = static [hdpx(4), 0, hdpx(4), 0]
  group
  flow = FLOW_HORIZONTAL
  children = array(total).map(@(_, idx) {
    size = flex()
    valign = ALIGN_BOTTOM
    children = {
      rendObj = ROBJ_SOLID
      size = static [flex(), hdpx(4)]
      color = indexWatch.get() != idx
        ? BtnBgDisabled
        : sf & S_HOVER ? BtnBgHover : BtnBdNormal
    }
    skipDirPadNav = true
    onHover = hint ? @(on) setTooltip(on ? hint : null) : null
    behavior = showCursor.get() ? Behaviors.Button : null
    onClick = @() setValue(allValues[idx])
  })
}

let mkSpinnerBtn = function(isEnabled, icon, action, hint=null, arrowSize = hdpx(35)) {
  let stateFlags = Watched(0)
  return function() {
    let sf = stateFlags.get()
    return {
      rendObj = ROBJ_BOX
      watch = [stateFlags, isEnabled, showCursor]
      onElemState = @(s) stateFlags.set(s)
      borderWidth = (sf & S_HOVER) && isEnabled.get() ? 1 : 0
      sound = buttonSound
      borderColor = BtnBdHover
      fillColor = (sf & S_HOVER) && isEnabled.get() ? BtnBgHover : null
      borderRadius = hdpx(1)
      behavior = showCursor.get() ? Behaviors.Button : null
      onClick = @() isEnabled.get() ? action() : null
      padding = static [0, hdpx(10)]
      vplace = ALIGN_CENTER
      skipDirPadNav = true
      onHover = hint ? @(on) setTooltip(on ? hint : null) : null
      children = {
        rendObj = ROBJ_INSCRIPTION
        text = icon
        hplace = ALIGN_CENTER
        vplace = ALIGN_CENTER
        color = fillColor(sf, isEnabled.get())
      }.__update(fontawesome, { fontSize = arrowSize })
    }
  }
}

#allow-auto-freeze

let spinner = kwarg(function(curValue, allValues, setValue = null,
  valToString = null, xmbNode= null, group = null, isEqual = null, hint=null, 
  textStyle = body_txt, size = flex(), arrowSize = hdpx(35)
) {
  #forbid-auto-freeze
  setValue = setValue ?? @(v) curValue.set(v)
  valToString = valToString ?? @(v) v
  let valuesCount = max(allValues.len(), 1)
  let maxIdx = valuesCount - 1
  let curIdx = Computed(@() isEqual != null
    ? allValues.findindex(@(value) isEqual(value, curValue.get()))
    : allValues?.indexof(curValue.get()))

  let isLeftBtnEnabled = Computed(@() curIdx.get() != null && curIdx.get() > 0)
  let isRightBtnEnabled = Computed(@() curIdx.get() != null && curIdx.get() < maxIdx)
  function leftBtnAction() { if (isLeftBtnEnabled.get()) setValue(allValues[curIdx.get() - 1]) }
  function rightBtnAction() { if (isRightBtnEnabled.get()) setValue(allValues[curIdx.get() + 1]) }

  let hotkeysElem = @(){
    watch = [isLeftBtnEnabled, isRightBtnEnabled]
    key = $"hotkeys{isLeftBtnEnabled.get()}{isRightBtnEnabled.get()}"
    hotkeys = [
      ["Left | J:D.Left",
        { action = leftBtnAction, sound = buttonSound,
          description = spinnerLeftLoc
        }
      ],
      ["Right | J:D.Right",
        { action = rightBtnAction, sound = buttonSound,
          description = spinnerRightLoc
        }
      ]
    ]
  }

  let labelText = @(sf) {
    behavior = Behaviors.Marquee
    rendObj = ROBJ_TEXT
    vplace = ALIGN_BOTTOM
    valign = ALIGN_BOTTOM
    text = valToString(curValue.get())
    stopHover = false
    color = sf & S_HOVER ? BtnBgActive : BtnTextNormal
    size
    scrollOnHover = true
    clipChildren = true
    group
  }.__update(textStyle)

  let buttons = {
    flow = FLOW_HORIZONTAL
    size = SIZE_TO_CONTENT
    vplace = ALIGN_CENTER
    gap = hdpx(5)
    children = [
      mkSpinnerBtn(isLeftBtnEnabled, fa["angle-left"], leftBtnAction, hint, arrowSize)
      mkSpinnerBtn(isRightBtnEnabled, fa["angle-right"], rightBtnAction, hint, arrowSize)
    ]
  }
  let stateFlags = Watched(0)
  let amount = allValues.len()
  return function() {
    let sf = stateFlags.get()
    return {
      behavior = showCursor.get() ? Behaviors.Button : null
      watch = [stateFlags, curIdx, curValue, showCursor]
      onElemState = @(s) stateFlags.set(s)
      onClick = amount == 0 ? null
        : function() {
            let current = curIdx.get()
            let nextIndex = current == null ? 0
              : (current + 1) % amount
            setValue(allValues[nextIndex])
          }
      xmbNode
      onHover = hint ? @(on) setTooltip(on ? hint : null) : null
      group
      eventPassThrough = true

      size
      flow = FLOW_HORIZONTAL
      children = [
        {
          size
          stopHover=false
          flow = FLOW_VERTICAL
          children = [
            labelText(sf)
            mkSpinnerLine(sf, curIdx, valuesCount, setValue, allValues,  group, hint)
          ]
        }
        buttons
        sf & S_HOVER ? hotkeysElem : null
      ]
    }
  }
})



return spinner
