from "%ui/ui_library.nut" import *

let { get_setting_by_blk_path } = require("settings")
let { nestWatched } = require("%dngscripts/globalState.nut")

const BARE_MINIMUM = "bareMinimum"
const MINIMUM = "minimum"
const LOW = "low"
const MEDIUM = "medium"
const HIGH = "high"
const ULTRA = "ultra"
const CUSTOM = "custom"

const graphicsPresetBlkPath = "graphics/preset"

let graphicsPreset = nestWatched("graphicsPreset", get_setting_by_blk_path(graphicsPresetBlkPath) ?? ULTRA)
let graphicsPresetUpdate = @(v) graphicsPreset.set(v)
let isBareMinimum = Computed(@() graphicsPreset.value == BARE_MINIMUM)

return {
  BARE_MINIMUM, MINIMUM, LOW, MEDIUM, HIGH, ULTRA, CUSTOM,
  graphicsPresetBlkPath,
  graphicsPreset,
  graphicsPresetUpdate,
  isBareMinimum
}