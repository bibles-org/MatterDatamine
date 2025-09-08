from "%ui/ui_library.nut" import *

let {body_txt, fontawesome} = require("%ui/fonts_style.nut")
let {BtnBdDisabled, BtnBdNormal, BtnBdHover, BtnBgHover, BtnBgActive, BtnBgDisabled,  BtnTextNormal} = require("%ui/components/colors.nut")
let {buttonSound} = require("%ui/components/sounds.nut")
let {setTooltip} = require("%ui/components/cursors.nut")
let fa = require("%ui/components/fontawesome.map.nut")

let fillColor = @(sf, active)
  ! active
    ? BtnBdDisabled
    : (sf & S_HOVER) ? BtnBdHover : BtnBdNormal

let spinnerLeftLoc = loc("spinner/prevValue", "Previous value")
let spinnerRightLoc = loc("spinner/nextValue", "Next value")

let mkSpinnerLine = @(sf, indexWatch, total, setValue, allValues, group, hint) @() {
  watch = indexWatch
  size = flex()
  gap = hdpx(4)
  padding = const [hdpx(2), hdpx(4), hdpx(2), 0]
  margin = const [0, 0, hdpx(4), 0]
  group
  flow = FLOW_HORIZONTAL
  children = array(total).map(@(_, idx) {
    size = flex()
    valign = ALIGN_BOTTOM
    children = {
      rendObj = ROBJ_SOLID
      size = const [flex(), hdpx(4)]
      color = indexWatch.get() != idx
        ? BtnBgDisabled
        : sf & S_HOVER ? BtnBgHover : BtnBdNormal
    }
    skipDirPadNav = true
    onHover = hint ? @(on) setTooltip(on ? hint : null) : null
    behavior = Behaviors.Button
    onClick = @() setValue(allValues[idx])
  })
}

let mkSpinnerBtn = @(isEnabled, icon, action, hint=null)
  watchElemState(@(sf){
    rendObj = ROBJ_BOX
    watch = isEnabled
    borderWidth = (sf & S_HOVER) && isEnabled.get() ? 1 : 0
    sound = buttonSound
    borderColor = BtnBdHover
    fillColor = (sf & S_HOVER) && isEnabled.get() ? BtnBgHover : null
    borderRadius = hdpx(1)
    behavior = Behaviors.Button
    onClick = @() isEnabled.get() ? action() : null
    padding = const [0, hdpx(10)]
    vplace = ALIGN_CENTER
    skipDirPadNav = true
    onHover = hint ? @(on) setTooltip(on ? hint : null) : null
    children = {
      rendObj = ROBJ_INSCRIPTION
      text = icon
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      color = fillColor(sf, isEnabled.get())
     }.__update(fontawesome, const {fontSize = hdpx(35)})
   }
  )

let spinner = kwarg(function(curValue, allValues, setValue = null,
  valToString = null, xmbNode= null, group = null, isEqual = null, hint=null 
) {
  setValue = setValue ?? @(v) curValue(v)
  valToString = valToString ?? @(v) v
  let valuesCount = max(allValues.len(), 1)
  let maxIdx = valuesCount - 1
  let curIdx = Computed(@() isEqual != null
    ? allValues.findindex(@(value) isEqual(value, curValue.get()))
    : allValues.indexof(curValue.get()))

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
          description = isLeftBtnEnabled.get() ? spinnerLeftLoc : const { skip = true }
        }
      ],
      ["Right | J:D.Right",
        { action = rightBtnAction, sound = buttonSound,
          description = isRightBtnEnabled.get() ? spinnerRightLoc : const { skip = true }
        }
      ]
    ]
  }

  let labelText = @(sf) {
    behavior = Behaviors.Marquee
    rendObj = ROBJ_TEXT
    vplace = ALIGN_CENTER
    valign = ALIGN_CENTER
    text = valToString(curValue.get())
    stopHover = false
    color = sf & S_HOVER ? BtnBgActive : BtnTextNormal
    size = flex()
    scrollOnHover = true
    clipChildren = true
    group
  }.__update(body_txt)

  let buttons = {
    flow = FLOW_HORIZONTAL
    size = SIZE_TO_CONTENT
    vplace = ALIGN_CENTER
    gap = hdpx(5)
    children = [
      mkSpinnerBtn(isLeftBtnEnabled, fa["angle-left"], leftBtnAction, hint)
      mkSpinnerBtn(isRightBtnEnabled, fa["angle-right"], rightBtnAction, hint)
    ]
  }

  return watchElemState(@(sf) {
      behavior = Behaviors.Button
      watch = [curIdx, curValue]
      xmbNode
      onHover = hint ? @(on) setTooltip(on ? hint : null) : null
      group
      eventPassThrough = false

      size = flex()
      flow = FLOW_HORIZONTAL
      children = [
        {
          size = flex()
          stopHover=false
          children = [
            labelText(sf)
            mkSpinnerLine(sf, curIdx, valuesCount, setValue, allValues,  group, hint)
          ]
        }
        buttons
        sf & S_HOVER ? hotkeysElem : null
      ]
    })
})



return spinner