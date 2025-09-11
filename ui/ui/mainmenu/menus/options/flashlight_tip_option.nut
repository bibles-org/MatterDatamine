from "%ui/mainMenu/menus/options/options_lib.nut" import getOnlineSaveData, optionCheckBox, optionCtor

from "%ui/ui_library.nut" import *


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