from "%ui/ui_library.nut" import *

let {get_setting_by_blk_path} = require("settings")
let { sound_set_volume } = require("%dngscripts/sound_system.nut")
let {is_pc} = require("%dngscripts/platform.nut")
let {soundOutputDevicesList, soundOutputDevice, soundOutputDeviceUpdate} = require("%ui/sound_state.nut")
let {
  getOnlineSaveData, optionSpinner, optionCtor, optionPercentTextSliderCtor, loc_opt, optionCheckBox
} = require("options_lib.nut")

function optionVolSliderCtor(opt, group, xmbNode) {
  let optSetValue = opt.setValue 
  function setValue(val) {
    optSetValue(val)
    sound_set_volume(opt.busName, val)
  }

  opt = opt.__merge({min = 0 max = 1 unit = 0.05 mult = 100 pageScroll = 0.05 setValue = setValue })

  return optionPercentTextSliderCtor(opt, group, xmbNode)
}

function soundOption(title, field) {
  let blkPath = $"sound/volume/{field}"
  let { watch, setValue } = getOnlineSaveData(blkPath,
    @() get_setting_by_blk_path(blkPath) ?? 1.0)
  return optionCtor({
    name = title
    tab = "Sound"
    widgetCtor = optionVolSliderCtor
    var = watch
    setValue
    defVal = 1.0
    blkPath
    busName = field
  })
}

let optVolumeMaster = soundOption(loc("options/volume_master"), "MASTER")
let optVolumeSfx = soundOption(loc("options/volume_sfx"), "effects")
let optVolumeInterface = soundOption(loc("options/volume_interface"), "interface")
let optVolumeMusic = soundOption(loc("options/volume_music"), "music")
let optVolumeDialogs = soundOption(loc("options/volume_dialogs"), "voices")

let optOutputDevice = optionCtor({
  name = loc("options/sound_device_out")
  tab = "Sound"
  widgetCtor = optionSpinner
  blkPath = "sound/output_device"
  isAvailableWatched = Computed(@() is_pc && soundOutputDevicesList.value.len() > 0)
  changeVarOnListUpdate = false
  var = soundOutputDevice
  setValue = soundOutputDeviceUpdate
  available = soundOutputDevicesList
  valToString = @(v) v?.name ?? ""
  isEqual = @(a,b) (a?.name ?? "")==(b?.name ?? "")
})

const SUBTITLES = "sound/subtitles"
let subtitlesOnlineSaveData = getOnlineSaveData(SUBTITLES, @() get_setting_by_blk_path(SUBTITLES) ?? true)
const SUBTITLES_BACKGROUND = "sound/subtitlesBackground"
let subtitlesBackgroundOnlineSaveData = getOnlineSaveData(SUBTITLES_BACKGROUND,
  @() get_setting_by_blk_path(SUBTITLES_BACKGROUND) ?? false)

let subtitles = optionCtor({
  name = loc_opt("sound/subtitles")
  setValue = subtitlesOnlineSaveData.setValue
  var = subtitlesOnlineSaveData.watch
  defVal = true
  widgetCtor = optionCheckBox
  restart = false
  tab = "Interface"
  blkPath = SUBTITLES
  valToString = @(v) v ? loc("option/on") : loc("option/off")
})

let subtitlesBackground = optionCtor({
  name = loc_opt("sound/subtitlesBackground")
  setValue = subtitlesBackgroundOnlineSaveData.setValue
  var = subtitlesBackgroundOnlineSaveData.watch
  defVal = false
  widgetCtor = optionCheckBox
  restart = false
  tab = "Interface"
  blkPath = SUBTITLES_BACKGROUND
  valToString = @(v) v ? loc("option/on") : loc("option/off")
})

return {
  optVolumeMaster
  optVolumeSfx
  optVolumeInterface
  optVolumeMusic
  optVolumeDialogs
  soundOptions = [
    optOutputDevice,
    optVolumeMaster, optVolumeSfx,
    optVolumeInterface, optVolumeMusic, optVolumeDialogs,
    subtitles, subtitlesBackground
  ]
  subtitlesNeeded = subtitlesOnlineSaveData.watch
  subtitlesBackgroundNeeded = subtitlesBackgroundOnlineSaveData.watch
}
