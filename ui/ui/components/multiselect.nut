from "%ui/ui_library.nut" import *
from "%ui/components/colors.nut" import BtnBdNormal, BtnBdActive, BtnBdHover, BtnBgNormal, BtnBgHover

let faComp = require("%ui/components/faComp.nut")
let {sound_play} = require("%dngscripts/sound_system.nut")
let {stateChangeSounds} = require("%ui/components/sounds.nut")
let { sub_txt } = require("%ui/fonts_style.nut")

let {font, fontSize} = sub_txt

let gap = hdpx(1)
let bigGap = hdpx(5)
let checkFontSize = hdpx(10)
let boxSize = hdpx(15)
let calcColor = @(sf)
  (sf & S_ACTIVE) ? BtnBdActive
  : (sf & S_HOVER) ? BtnBdHover
  : BtnBdNormal

function box(isSelected, sf) {
  let color = calcColor(sf)
  return {
    size = [boxSize, boxSize]
    rendObj = ROBJ_BOX
    fillColor = sf & S_HOVER ? BtnBgHover : BtnBgNormal
    borderWidth = hdpx(1)
    borderColor = color
    borderRadius = hdpx(1)
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = isSelected
      ? faComp("check", {color, fontSize = checkFontSize})
      : null
  }
}

let label = @(text, sf) {
  size = [flex(), SIZE_TO_CONTENT]
  rendObj = ROBJ_TEXT
  color = calcColor(sf)
  text
  font
  fontSize
  behavior = [Behaviors.Marquee]
  scrollOnHover = true
}

function optionCtor(option, isSelected, onClick) {
  let stateFlags = Watched(0)
  return function() {
    let sf = stateFlags.get()

    return {
      size = [flex(), SIZE_TO_CONTENT]
      padding = [fsh(0.5),fsh(1.0),fsh(0.5),fsh(1.0)]
      watch = stateFlags
      behavior = Behaviors.Button
      onElemState = @(s) stateFlags.set(s)
      onClick = function() {
        sound_play(isSelected ? "ui_sounds/flag_unset" : "ui_sounds/flag_set")
        onClick()
      }
      sound = stateChangeSounds
      stopHover = true

      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      gap = bigGap
      children = [
        box(isSelected, sf)
        label(option.text, sf)
      ]
    }
  }
}

let baseStyle = {
  root = {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap
  }
  optionCtor = optionCtor
}



let mkMultiselect = @(selected , options , minOptions = 0, maxOptions = 0, rootOverride = {}, style = baseStyle)
  function() {
    let numSelected = Computed(@() selected.value.filter(@(v) v).len())
    let mkOnClick = @(option) function() {
      let curVal = selected.value?[option.key] ?? false
      let resultNum = numSelected.value + (curVal ? -1 : 1)
      if ((minOptions == 0 || resultNum >= minOptions) 
          && (maxOptions==0 || resultNum <= maxOptions))
        selected.mutate(function(s) { s[option.key] <- !curVal })

    }
    return style.root.__merge({
      watch = selected
      children = options.map(@(option) style.optionCtor(option, selected.value?[option.key] ?? false, mkOnClick(option)))
    })
    .__merge(rootOverride)
 }

let multiselect = kwarg(mkMultiselect)

return multiselect