from "%ui/ui_library.nut" import *

let { loc_opt, getOnlineSaveData, optionSpinner, optionCtor } = require("options_lib.nut")
let { get_setting_by_blk_path } = require("settings")

const CHOCOLATE_ROW_COUNT = "gameplay/chocolateRow"
const CHOCOLATE_COL_COUNT = "gameplay/chocolateCount"

let avValues = [3,4,5]

let chocolateRowSafe = getOnlineSaveData(CHOCOLATE_ROW_COUNT,
  @() get_setting_by_blk_path(CHOCOLATE_ROW_COUNT) ?? avValues[0])
let chocolateColSafe = getOnlineSaveData(CHOCOLATE_COL_COUNT,
  @() get_setting_by_blk_path(CHOCOLATE_COL_COUNT) ?? avValues[0])

let chocolateRowOption = optionCtor({
  name = loc_opt("gameplay/chocolateRowOption")
  setValue = chocolateRowSafe.setValue
  var = chocolateRowSafe.watch
  defVal = avValues[0]
  widgetCtor = optionSpinner
  valToString = @(v) $"{v}"
  restart = false
  available = avValues
  tab = "Interface"
  blkPath = CHOCOLATE_ROW_COUNT
})

let chocolateColOption = optionCtor({
  name = loc_opt("gameplay/chocolateColOption")
  setValue = chocolateColSafe.setValue
  var = chocolateColSafe.watch
  defVal = avValues[0]
  widgetCtor = optionSpinner
  valToString = @(v) $"{v}"
  restart = false
  available = avValues
  tab = "Interface"
  blkPath = CHOCOLATE_COL_COUNT
})

return {
  chocolateRowOption
  chocolateColOption
  chocolateRowSafeWatch = chocolateRowSafe.watch
  chocolateColSafeWatch = chocolateColSafe.watch
}