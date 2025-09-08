require ecs
require DagorMath
require soundEvent
require game.events.events_active_matter


[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es)]
def encounter_jump_quest_sounds_earthshake_update(evt : ParallelUpdateFrameDelayed;
                                                  encounter_jump_quest_earthshake__startAt : float;
                                                  encounter_jump_quest_earthshake__time : float;
                                                  sound_effect__event : SoundEvent)
  let endAt = encounter_jump_quest_earthshake__startAt + encounter_jump_quest_earthshake__time
  let progress = cvt(evt.curTime, encounter_jump_quest_earthshake__startAt, endAt, 0., 1.)
  set_var(sound_effect__event, "progress", progress)


[es(tag=sound, track=isAlive)]
def encounter_jump_quest_sounds_track_core_alive(evt : Event;
                                                 isAlive : bool;
                                                 encounter_jump_quest_core__explosionSound : string;
                                                 transform : float3x4)
  if !isAlive
    oneshot(encounter_jump_quest_core__explosionSound, transform[3])
