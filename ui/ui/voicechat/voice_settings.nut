from "%ui/ui_library.nut" import *

let {get_setting_by_blk_path} = require("settings")
let platform = require("%dngscripts/platform.nut")
let {nestWatched} = require("%dngscripts/globalState.nut")

let voice_modes = {
  on = "on"
  off = "off"
  micOff = "micOff"
}

let voice_activation_modes = {
  toggle = "toggle"
  pushToTalk = "pushToTalk"
  always = "always"
}

let validateMode = @(mode, list, defValue) mode in list ? mode : defValue

let voiceRecordVolume = nestWatched("voiceRecordVolume", clamp(get_setting_by_blk_path("voice/record_volume") ?? 1.0, 0.0, 1.0))
let voiceRecordVolumeUpdate = @(v) voiceRecordVolume.set(v)
let voicePlaybackVolume = nestWatched("voicePlaybackVolume", clamp(get_setting_by_blk_path("voice/playback_volume") ?? 1.0, 0.0, 1.0))
let voicePlaybackVolumeUpdate = @(v) voicePlaybackVolume.set(v)
let voiceRecordingEnable = nestWatched("voiceRecordingEnable", false)
let voiceRecordingEnableUpdate = @(v) voiceRecordingEnable.set(v)
let voiceRecordingEnabledGeneration = nestWatched("voiceRecordingEnabledGeneration", 0)
let voiceRecordingEnabledGenerationUpdate = @(v) voiceRecordingEnabledGeneration.set(v)
let voiceChatMode = nestWatched("voiceChatMode",
  validateMode(get_setting_by_blk_path("voice/mode"), voice_modes, platform.is_nswitch ? voice_modes.off : voice_modes.on)
)
let voiceChatModeUpdate = @(v) voiceChatMode.set(v)
let voiceActivationMode = nestWatched("voiceActivationMode",
  validateMode(get_setting_by_blk_path("voice/activation_mode"),
    voice_activation_modes,
    platform.is_pc ? voice_activation_modes.toggle : voice_activation_modes.always)
)
let voiceActivationModeUpdate = @(v) voiceActivationMode.set(v)
function setRecordingEnabled(val) {
  voiceRecordingEnableUpdate(val)
  voiceRecordingEnabledGenerationUpdate(voiceRecordingEnabledGeneration.value+1)
}

return {
  voiceRecordVolume, voiceRecordVolumeUpdate,
  voicePlaybackVolume, voicePlaybackVolumeUpdate,
  voiceRecordingEnable, voiceRecordingEnableUpdate,
  voiceRecordingEnabledGeneration, voiceRecordingEnabledGenerationUpdate,
  voiceChatMode, voiceChatModeUpdate,
  voiceActivationMode, voiceActivationModeUpdate
  setRecordingEnabled
  voice_modes
  voice_activation_modes
}
