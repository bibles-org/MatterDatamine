import "%dngscripts/ecs.nut" as ecs
from "%ui/mainMenu/menus/options/options_lib.nut" import loc_opt, getOnlineSaveData, optionCheckBox, optionCtor, optionPercentTextSliderCtor
from "settings" import get_setting_by_blk_path
from "dasevents" import EventMissSecondMapHelpOptionChanged

from "%ui/ui_library.nut" import *


const MS_SECOND_MAP_HELP = "gameplay/msSecondMapHelp"
let msSecondMapHelpSave = getOnlineSaveData(MS_SECOND_MAP_HELP, @() get_setting_by_blk_path(MS_SECOND_MAP_HELP) ?? true)

const MS_SECOND_SARCASM = "gameplay/msSecondSarcasm"
let msSecondSarcasmSave = getOnlineSaveData(MS_SECOND_SARCASM, @() get_setting_by_blk_path(MS_SECOND_SARCASM) ?? 70)

let missSecondMapHelp = optionCtor({
  name = loc_opt("gameplay/miss_second_map_help")
  setValue = msSecondMapHelpSave.setValue
  var = msSecondMapHelpSave.watch
  defVal = true
  widgetCtor = optionCheckBox
  restart = false
  tab = "options/miss_second"
  blkPath = MS_SECOND_MAP_HELP
  valToString = @(v) v == null ? loc("option/nothing") : (v ? loc("option/on") : loc("option/off"))
})

msSecondMapHelpSave.watch.subscribe(function(val) {
  ecs.g_entity_mgr.broadcastEvent(EventMissSecondMapHelpOptionChanged({msSecondMapHelp = val}))
})

let missSecondSarcasm = optionCtor({
  name = loc_opt("gameplay/msSecondSarcasm")
  setValue = msSecondSarcasmSave.setValue
  var = msSecondSarcasmSave.watch
  defVal = 70
  widgetCtor = optionPercentTextSliderCtor
  restart = false
  min = 0
  max = 100
  unit = 0.1
  pageScroll = 0.1
  tab = "options/miss_second"
  blkPath = MS_SECOND_SARCASM
})

return {
  msSecondMapHelpSave,
  missSecondMapHelp,
  missSecondSarcasm
}