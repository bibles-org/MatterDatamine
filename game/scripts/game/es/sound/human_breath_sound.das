require ecs
require soundEvent
require soundHash
require sound_utils.modules.sound_player_common
require human_sounds.modules.human_voice_effect_common
require danetlibs.renderer.includes.pufd_events
require HumanPhys
require DagorMath
require DngHuman


[es(tag=sound, track=(is_watched_sound, sound_banks_state__isPresetLoaded), REQUIRE=(is_watched_sound, sound_banks_state__isPresetLoaded))]
def human_breath_sound_reset(evt : Event;
                             var human_breath_sound__enabled : bool&;
                             var human_voice_effect__activeEffects : Object&)
  human_breath_sound__enabled = false
  set_human_voice_effect("heavyBreath", false, human_voice_effect__activeEffects)


[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es, REQUIRE=watchedByPlr)]
def human_breath_sound_update(info : ParallelUpdateFrameDelayed;

                              human_net_phys__states : int;
                              isAlive : bool;

                              sound_banks_state__isPresetLoaded : bool;

                              heartrate__value : float;
                              human_breath_sound__heartrateMinMax : float2;
                              human_breath_sound__breathShortnessMul : float;

                              var human_breath_sound__enabled : bool&;
                              human_net_phys : HumanActor&;

                              var human_voice_effect__activeEffects : Object&;
                              human_voice_effect__type : string;
                              human_voice_effect__event : SoundEvent&)
  let ableToBreath = isAlive && sound_banks_state__isPresetLoaded && ((human_net_phys__states & int(StateFlag.ST_ON_GROUND)) != 0)

  var shortness = cvt(heartrate__value, human_breath_sound__heartrateMinMax.x, human_breath_sound__heartrateMinMax.y, 0., 1.)
  shortness = max(human_net_phys.phys.currentState.breathShortness * human_breath_sound__breathShortnessMul, shortness)
  let shouldPlay = ableToBreath && shortness > 0.

  if human_breath_sound__enabled != shouldPlay
    human_breath_sound__enabled = shouldPlay
    set_human_voice_effect("heavyBreath", shouldPlay, human_voice_effect__activeEffects)

  if human_breath_sound__enabled && human_voice_effect__type == "heavyBreath"
    set_var(human_voice_effect__event, "volume", shortness)
