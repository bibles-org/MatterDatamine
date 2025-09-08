require ecs
require app
require soundEvent
require sound_utils.modules.sound_player_common
require game.events.events_active_matter

[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es)]
def stalker_statue_sound_update(evt : ParallelUpdateFrameDelayed;
                                stalker_statue_sound__movePath : string;
                                stalker_statue_sound__moveUntil : float;
                                transform : float3x4;
                                var stalker_statue_sound__isOn : bool&;
                                var stalker_statue_sound__event : SoundEvent&)
  let shouldBeOn = stalker_statue_sound__moveUntil > evt.curTime
  if stalker_statue_sound__isOn != shouldBeOn
    stalker_statue_sound__isOn = shouldBeOn
    stalker_statue_sound__event |> play_or_abandon(stalker_statue_sound__movePath, transform[3], shouldBeOn)


[es(tag=sound)]
def stalker_statue_sound_set_time(evt : EventStatueMove; var stalker_statue_sound__moveUntil : float&)
  stalker_statue_sound__moveUntil = get_sync_time() + evt.duration


[es(tag=sound)]
def stalker_statue_sound_pre_attack(evt : EventStatueAttackImminent;
                                    stalker_statue_sound__preAttackPath : string;
                                    transform : float3x4)
  oneshot(stalker_statue_sound__preAttackPath, transform[3])


[es(tag=sound)]
def stalker_statue_sound_attack(evt : EventStatueAttacked;
                                stalker_statue_sound__hitPath : string;
                                transform : float3x4)
  oneshot(stalker_statue_sound__hitPath, transform[3])