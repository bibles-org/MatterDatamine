module human_sounds_events shared
require ecs

[event(unicast)]
struct CmdHumanVoiceEffectOneshot
  phrase : string
  ignoreDisabledSoundControl : bool
  varName : string
  varValue : float
