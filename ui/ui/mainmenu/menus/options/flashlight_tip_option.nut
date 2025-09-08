from "%ui/ui_library.nut" import *

let { getOnlineSaveData, optionCheckBox, optionCtor } = require("options_lib.nut")

const FLASHLIGHT_TIP_OPTION = "gameplay/flashlightTip"
let flashlightTipSave = getOnlineSaveData(FLASHLIGHT_TIP_OPTION, @() true)

let { watch, setValue } = flashlightTipSave

let flashlightTipOption = optionCtor({
  name = loc("gameplay/flashlightTipOption")
  setValue = setValue
  var = watch
  defVal = true
  widgetCtor = optionCheckBox
  restart = false
  tab = "Interface"
  valToString = @(v) v ? loc("option/on") : loc("option/off")
})

return {
  flashlightTipOption
  isFlashlightTipEnabled = watch
}