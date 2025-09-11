from "%ui/voiceChat/voice_settings.nut" import voiceRecordVolumeUpdate, voiceChatModeUpdate, voicePlaybackVolumeUpdate, voiceActivationModeUpdate
from "%ui/matchingClient.nut" import matchingCall
from "%ui/ui_library.nut" import *

let localSettings = require("%ui/options/localSettings.nut")("voice/", false)
let { voiceChatEnabled } = require("%ui/voiceChat/voiceChatGlobalState.nut")
let voiceApi = require_optional("voiceApi")
let { voiceRecordVolume, voiceChatMode, voicePlaybackVolume, voiceActivationMode, voice_modes, voice_activation_modes } = require("%ui/voiceChat/voice_settings.nut")

let initialized = mkWatched(persist, "initialized", false)
let joinedVoiceRooms = persist("joinedVoiceRooms", @() {})

let validation_tbl = {
  voiceChatMode = @(v) voice_modes?[v] ?? voiceChatMode.get()
  voiceActivationMode = @(v) voice_activation_modes?[v] ?? voiceActivationMode.get()
}

let validate_setting = @(key, val) validation_tbl?[key](val) ?? val

function loadVoiceSettings() {
  log("loadVoiceSettings")
  let noop = { 
    voiceRecordVolume = [localSettings(voiceRecordVolume.get(), "record_volume"), voiceRecordVolumeUpdate]
    voicePlaybackVolume = [localSettings(voicePlaybackVolume.get(), "playback_volume"), voicePlaybackVolumeUpdate]
    voiceChatMode = [voiceChatEnabled.get() ? localSettings(voiceChatMode.get(), "mode") : Watched(voice_modes.off), voiceChatModeUpdate]
    voiceActivationMode = [localSettings(voiceActivationMode.get(), "activation_mode"), voiceActivationModeUpdate]
  }.each(function(v, key) {
    let [watched, update] = v
    update(validate_setting(key, watched.get()))
  })
}


if (!initialized.get() && voiceApi != null) {
  loadVoiceSettings()
  initialized.set(true)
}

function leave_voice_chat(voice_chat_id, cb = null) {
  if (voiceApi && voiceChatEnabled.get() && voice_chat_id in joinedVoiceRooms) {
    matchingCall("mproxy.voice_leave_channel", function(_) { cb?() }, { channel = voice_chat_id })
    voiceApi.leave_room(joinedVoiceRooms[voice_chat_id]?.chanUri ?? "")
    joinedVoiceRooms.$rawdelete(voice_chat_id)
  }
}

function join_voice_chat(voice_chat_id) {
  log($"joining voice {voice_chat_id}")
  if (voiceApi && voiceChatEnabled.get() && !(voice_chat_id in joinedVoiceRooms)) {
    matchingCall("mproxy.voice_join_channel",
                      function(response) {
                        debugTableData(response)
                        if (response.error == 0) {
                          if (!(voice_chat_id in joinedVoiceRooms))
                            return
                          let voiceToken = response?.token
                          let voiceChan = response?.channel
                          let voiceName = response?.name
                          if (voiceToken != null && voiceChan != null && voiceName != null) {
                            log($"join into voice chat as {voiceName} channel: {voiceChan} token: {voiceToken}")
                            voiceApi.join_room(voiceName, voiceToken, voiceChan)
                            joinedVoiceRooms[voice_chat_id].chanUri <- voiceChan
                            return
                          }
                        }
                        log($"failed to join voice channel {voice_chat_id}")
                      },
                      { channel = voice_chat_id })
    joinedVoiceRooms[voice_chat_id] <- {}
  }
}


function on_room_disconnect(voice_chat_id) {
  if (voice_chat_id in joinedVoiceRooms) {
    log($"reconnect to voice room {voice_chat_id}")
    joinedVoiceRooms.$rawdelete(voice_chat_id)
    join_voice_chat(voice_chat_id)
  }
}

return {
  leave_voice_chat
  join_voice_chat
  on_room_disconnect
}
