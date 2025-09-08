require ecs
require human_sounds.modules.human_voice_effect_common


[es(tag=sound, on_appear, before=human_voice_effect_on_change, track=pain__active)]
def human_voice_effect_pain_toggle(evt : Event;
                                   pain__active : bool;
                                   var human_voice_effect__activeEffects : Object&)
  if pain__active
    raise_human_voice_effect("pain", human_voice_effect__activeEffects)
  else
    clear_human_voice_effect("pain", human_voice_effect__activeEffects)


[es(tag=sound, on_disappear, before=human_voice_effect_on_change)]
def human_voice_effect_pain_clear_on_disappearing(evt : Event;
                                                  var human_voice_effect__activeEffects : Object&)
  clear_human_voice_effect("pain", human_voice_effect__activeEffects)