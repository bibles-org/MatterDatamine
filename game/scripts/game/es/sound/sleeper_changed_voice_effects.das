require ecs
require human_sounds.modules.human_voice_effect_common


[es(tag=sound, on_appear, track=loud_noise__accumulatedNoise, REQUIRE=sleeping_monster)]
def sleeper_changed_voice_effects_apply(evt : Event;
                                        var human_voice_effect__activeEffects : Object&;
                                        sleeper_changed_voice_effects__wokenEffect : string;
                                        sleeper_changed_voice_effects__sleepEffects : StringList;
                                        sleeper_changed_voice_effects__noiseThresholds : FloatList;
                                        changed_loud_noise__awakeThreshold : float;
                                        loud_noise__accumulatedNoise : float)
  clear_human_voice_effect(sleeper_changed_voice_effects__wokenEffect, human_voice_effect__activeEffects)
  for effect in sleeper_changed_voice_effects__sleepEffects
    clear_human_voice_effect(string(effect), human_voice_effect__activeEffects)

  for threshold, effect in sleeper_changed_voice_effects__noiseThresholds, sleeper_changed_voice_effects__sleepEffects
    if loud_noise__accumulatedNoise <= threshold * changed_loud_noise__awakeThreshold
      raise_human_voice_effect(string(effect), human_voice_effect__activeEffects)
      break


[es(tag=sound, on_disappear, REQUIRE=sleeping_monster)]
def sleeper_changed_voice_effects_on_wake(evt : Event;
                                          var human_voice_effect__activeEffects : Object&;
                                          sleeper_changed_voice_effects__wokenEffect : string;
                                          sleeper_changed_voice_effects__sleepEffects : StringList)
  raise_human_voice_effect(sleeper_changed_voice_effects__wokenEffect, human_voice_effect__activeEffects)
  for effect in sleeper_changed_voice_effects__sleepEffects
    clear_human_voice_effect(string(effect), human_voice_effect__activeEffects)


[es(tag=sound, on_appear, REQUIRE_NOT=sleeping_monster)]
def sleeper_changed_voice_effects_on_appear(evt : Event;
                                            var human_voice_effect__activeEffects : Object&;
                                            sleeper_changed_voice_effects__wokenEffect : string)
  raise_human_voice_effect(sleeper_changed_voice_effects__wokenEffect, human_voice_effect__activeEffects)
