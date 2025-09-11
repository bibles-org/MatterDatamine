from "%dngscripts/globalState.nut" import nestWatched

from "settings" import get_setting_by_blk_path
from "math" import fabs
from "%ui/options/mkOnlineSaveData.nut" import mkOnlineSaveData

from "%ui/ui_library.nut" import Computed, sw, sh, console_print, vlog, console_register_command
from "math" import max

let platform = require("%dngscripts/platform.nut")
let debugSafeAreaList = nestWatched("debugSafeAreaList", false)
let debugSafeAreaAmount = nestWatched("debugSafeAreaAmount", null)

let safeAreaShow = nestWatched("safeAreaShow", false)

let blkPath = "video/safeArea"
let safeAreaList = (platform.is_xbox) ? static [0.9, 0.95, 1.0]
  : platform.is_sony ? [require("sony").getDisplaySafeArea()]
  : debugSafeAreaList.get() ? static [0.9, 0.95, 1.0]
  : static [1.0]
let canChangeInOptions = @() safeAreaList.len() > 1

function validate(val) {
  if (safeAreaList.indexof(val) != null)
    return val
  local res = null
  foreach (v in safeAreaList)
    if (res == null || fabs(res - val) > fabs(v - val))
      res = v
  return res
}
let safeAreaDefault = @() canChangeInOptions() ? validate(get_setting_by_blk_path(blkPath) ?? safeAreaList.top())
  : safeAreaList.top()

let storedAmount = mkOnlineSaveData("safeAreaAmount", safeAreaDefault,
  @(value) canChangeInOptions() ? validate(value) : safeAreaDefault())

let storedAmountWatch = storedAmount.watch

function setAmount(val) {
  storedAmount.setValue(val)
  debugSafeAreaAmount.set(null)
}

let safeAreaAmount = Computed(@() debugSafeAreaAmount.get() ?? storedAmountWatch.get() ?? 1.0)
let safeAreaHorPadding = Computed(@() sw(100*(1-safeAreaAmount.get())/2))
let safeAreaVerPadding = Computed(@() sh(100*(1-safeAreaAmount.get())/2))

console_register_command(@() safeAreaShow.modify(@(v) !v), "ui.safeAreaShow")

console_register_command(
  function(val = 0.9) {
    if (val > 1.0 || val < 0.9) {
      vlog(@"SafeArea is supported between 0.9 (lowest visible area) and 1.0 (full visible area).
This range is according console requirements. (Resetting to use in options = '{0}')".subst(storedAmountWatch.get()))
      debugSafeAreaAmount.set(null)
      return
    }
    debugSafeAreaAmount.set(val)
  }, "ui.safeAreaSet"
)

return freeze({
  isWideScreen = sw(100).tofloat() / sh(100) > 1.5
  safeAreaCanChangeInOptions = canChangeInOptions
  safeAreaBlkPath = blkPath
  safeAreaVerPadding
  safeAreaHorPadding
  safeAreaSetAmount = setAmount
  safeAreaAmount
  safeAreaShow
  safeAreaList
})
