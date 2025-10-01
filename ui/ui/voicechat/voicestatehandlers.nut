from "%ui/voiceChat/voice_settings.nut" import setRecordingEnabled
from "eventbus" import eventbus_subscribe
from "%ui/voiceChat/voiceState.nut" import on_room_disconnect
from "%ui/ui_library.nut" import *

let voiceApi = require_optional("voiceApi")
let { voiceChatRestricted } = require("%ui/voiceChat/voiceChatGlobalState.nut")
let { soundRecordDevice } = require("%ui/sound_state.nut")
let platform = require("%dngscripts/platform.nut")
let { voiceRecordingEnable, voiceRecordingEnabledGeneration, voiceRecordVolume, voiceActivationMode,
  voicePlaybackVolume, voiceChatMode, voice_modes, voice_activation_modes,
  proximityVoiceRecordingEnable } = require("%ui/voiceChat/voice_settings.nut")

let speakingPlayers = Watched({})
if (voiceApi == null)
  return {speakingPlayers}

let { levelIsLoading, levelLoaded } = require("%ui/state/appState.nut")
let tempDisableVoice = platform.is_sony ? Computed(@() levelIsLoading.get() || !levelLoaded.get()) : Watched(false)

let order = { val = 0 }

function onSpeakingStatus(who, is_speaking) {
  if (is_speaking) {
    if (who in speakingPlayers.get())
      return
    speakingPlayers.mutate(@(v) v[who] <- order.val++)
  }
  else {
    if (!(who in speakingPlayers.get()))
      return
    speakingPlayers.mutate(@(v) v.$rawdelete(who))
  }
}

function onVoiceChat(new_value) {
  if (voiceChatRestricted.get()) {
    new_value = voice_modes.off
    log("Voice chat restriction is in effect")
  }

  log($"Voice chat mode changed to '{new_value}'")
  if (new_value == voice_modes.off) {
    voiceApi.enable_mic(false)
    voiceApi.enable_voice(false)
    speakingPlayers.set({})
  } else if (new_value == voice_modes.micOff) {
    voiceApi.enable_mic(false)
    voiceApi.enable_voice(true)
  } else if (new_value == voice_modes.on) {
    voiceApi.enable_mic(true)
    voiceApi.enable_voice(true)
  } else {
    log("Wrong value set for voiceChatMode: ", new_value)
  }
}

voiceChatRestricted.subscribe_with_nasty_disregard_of_frp_update(@(_val) onVoiceChat(voiceChatMode.get()))

tempDisableVoice.subscribe_with_nasty_disregard_of_frp_update(function(val) {
  if (val) {
    onVoiceChat(voice_modes.off)
  }
  else {
    onVoiceChat(voiceChatMode.get())
  }
})

let voiceSettingsDescr = {
  [voiceRecordVolume] = @(val) voiceApi.set_record_volume(val),
  [voicePlaybackVolume] = @(val) voiceApi.set_playback_volume(val),
  [voiceRecordingEnable] = @(val) voiceApi.set_recording(val),
  [voiceChatMode] = onVoiceChat,
  [proximityVoiceRecordingEnable] = @(val) voiceApi.enable_local_mic_for("danetvoice://proximity_chat", val),
}

foreach (watched, handler in voiceSettingsDescr)
  handler(watched.get())
foreach (watched, handler in voiceSettingsDescr)
  watched.subscribe_with_nasty_disregard_of_frp_update(handler)

function recordDeviceHandler(...){
  let dev = soundRecordDevice.get()
  voiceApi.set_record_device(dev?.id ?? -1)
  setRecordingEnabled(voiceRecordingEnable.get())
}
soundRecordDevice.subscribe_with_nasty_disregard_of_frp_update(recordDeviceHandler)
recordDeviceHandler()


voiceRecordingEnabledGeneration.subscribe(@(...) voiceApi.set_recording(voiceRecordingEnable.get()) )


eventbus_subscribe("voice.on_peer_stop_speaking", @(data) onSpeakingStatus(data.name, false))
eventbus_subscribe("voice.on_peer_start_speaking",
  function(data) {
    if (voiceChatMode.get() != voice_modes.off && !tempDisableVoice.get() &&
      !voiceChatRestricted.get()) {
      onSpeakingStatus(data.name, true)
    }
  })

eventbus_subscribe("voice.on_peer_left", @(data) onSpeakingStatus(data.name, false))
eventbus_subscribe("voice.on_room_disconnect",
  function(data) {
    on_room_disconnect(data.uri)
    speakingPlayers.set({})
  })
eventbus_subscribe("voice.on_room_connect",
  function(data) {
    if (!data.success)
      return
    onVoiceChat(voiceChatMode.get())
    if (voiceActivationMode.get() == voice_activation_modes.always)
      setRecordingEnabled(true)
    else
      setRecordingEnabled(voiceRecordingEnable.get())
  })

voiceActivationMode.subscribe_with_nasty_disregard_of_frp_update(function(value) {
  if (value == voice_activation_modes.always)
    setRecordingEnabled(true)
})

function voice_start_test() {
  voiceApi.join_echo_room()
  setRecordingEnabled(true)
}

function voice_stop_test() {
  voiceApi.leave_echo_room()
  setRecordingEnabled(false)
}

function mute_player(player_name) {
  voiceApi.mute_player_by_name(player_name)
}

function unmute_player(player_name) {
  voiceApi.unmute_player_by_name(player_name)
}

function set_recording(val) {
  voiceApi.set_recording(val)
}

console_register_command(voice_start_test, "voice.start_test")
console_register_command(voice_stop_test, "voice.stop_test")
console_register_command(mute_player, "voice.mute_player")
console_register_command(unmute_player, "voice.unmute_player")
console_register_command(set_recording, "voice.set_recording")





return {
  speakingPlayers
  mute_player
  unmute_player
}
