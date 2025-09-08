require ecs
require human_sounds.modules.human_voice_effect_common


[es(tag=sound, on_appear)]
def human_voice_effect_assigned_appear(evt : Event;
                                       human_voice_effect_assigned : string;
                                       var human_voice_effect__activeEffects : Object&)
  raise_human_voice_effect(human_voice_effect_assigned, human_voice_effect__activeEffects)


[es(tag=sound, on_disappear)]
def human_voice_effect_assigned_disappear(evt : Event;
                                          human_voice_effect_assigned : string;
                                          var human_voice_effect__activeEffects : Object&)
  clear_human_voice_effect(human_voice_effect_assigned, human_voice_effect__activeEffects)
