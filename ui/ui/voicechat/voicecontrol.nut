from "%ui/voiceChat/voice_settings.nut" import voiceActivationMode, voiceRecordingEnable, voice_activation_modes,
  proximityVoiceRecordingEnable, setRecordingEnabled

return {
  eventHandlers = {
    ["VoiceChat.Record"] = function(_event) {
      if (voiceActivationMode.get() == voice_activation_modes.pushToTalk)
        setRecordingEnabled(true)
      else if (voiceActivationMode.get() == voice_activation_modes.toggle)
        setRecordingEnabled(!voiceRecordingEnable.get())
    },
    ["VoiceChat.Record:end"] = function(_event) {
      if (voiceActivationMode.get() == voice_activation_modes.pushToTalk)
        setRecordingEnabled(false)
    },
    
    
    
    
    
    
    
    
    
    
  }
}
