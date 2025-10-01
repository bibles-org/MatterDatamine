from "%dngscripts/sound_system.nut" import sound_set_volume
from "%dngscripts/platform.nut" import is_pc
from "%ui/mainMenu/menus/options/options_lib.nut" import getOnlineSaveData, optionSpinner, optionCtor, optionPercentTextSliderCtor, loc_opt, optionCheckBox
from "settings" import get_setting_by_blk_path, set_setting_by_blk_path_and_save
from "%ui/sound_state.nut" import soundOutputDeviceUpdate
from "%ui/mainMenu/audioModule/audio_settings.nut" import playerMusicVolumeSetting, playMusicOnBaseSetting,
  playMusicInRaidsSetting, playFreeStreamingMusicSetting, playerOnlyFavoriteSetting

from "%ui/ui_library.nut" import *

let { soundOutputDevicesList, soundOutputDevice } = require("%ui/sound_state.nut")

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
    setValue = function (v) {
      setValue(v)
      set_setting_by_blk_path_and_save(blkPath, v)
    }
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
  isAvailableWatched = Computed(@() is_pc && soundOutputDevicesList.get().len() > 0)
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

const SUBTITLES_FONT_SIZE = "sound/subtitles_font_size"
enum SubtitlesFontSizes {
  tiny = "tiny",
  normal = "medium",
  big = "big"
}

let subtitlesFontSizeOnlineSaveData = getOnlineSaveData(SUBTITLES_FONT_SIZE, @() get_setting_by_blk_path(SUBTITLES_FONT_SIZE) ?? SubtitlesFontSizes.normal)

let subtitles = optionCtor({
  name = loc("options/subtitles")
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
  name = loc("options/subtitlesBackground")
  setValue = subtitlesBackgroundOnlineSaveData.setValue
  var = subtitlesBackgroundOnlineSaveData.watch
  defVal = false
  widgetCtor = optionCheckBox
  restart = false
  tab = "Interface"
  blkPath = SUBTITLES_BACKGROUND
  valToString = @(v) v ? loc("option/on") : loc("option/off")
})

let subtitlesFontSize = optionCtor({
  name = loc("options/subtitlesFontSize")
  setValue = @(v) subtitlesFontSizeOnlineSaveData.setValue(v in SubtitlesFontSizes ? v : SubtitlesFontSizes.normal)
  available = [SubtitlesFontSizes.tiny, SubtitlesFontSizes.normal, SubtitlesFontSizes.big]
  var = subtitlesFontSizeOnlineSaveData.watch
  defVal = false
  widgetCtor = optionSpinner
  restart = false
  tab = "Interface"
  blkPath = SUBTITLES_FONT_SIZE
  valToString = @(v) loc_opt($"font_{v}") ?? "???"
})

return freeze({
  optVolumeMaster
  optVolumeSfx
  optVolumeInterface
  optVolumeMusic
  optVolumeDialogs
  soundOptions = [
    optOutputDevice,
    optVolumeMaster, optVolumeSfx,
    optVolumeInterface, optVolumeMusic, optVolumeDialogs,
    subtitles, subtitlesBackground, subtitlesFontSize,
    {name = loc("musicPlayer") isSeparator=true tab="Sound"},
    playerMusicVolumeSetting, playMusicOnBaseSetting,
    playMusicInRaidsSetting, playFreeStreamingMusicSetting, playerOnlyFavoriteSetting
  ]
  subtitlesNeeded = subtitlesOnlineSaveData.watch
  subtitlesBackgroundNeeded = subtitlesBackgroundOnlineSaveData.watch
  subtitlesFontSize = subtitlesFontSizeOnlineSaveData.watch
  SubtitlesFontSizes
})
