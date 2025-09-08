require ecs
require soundEvent
require game.events.events_active_matter
require sound_utils.modules.sound_player_common


[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es, REQUIRE=watchedByPlr)]
def heartrate_sound_update(evt : ParallelUpdateFrameDelayed;
                           sound_banks_state__isPresetLoaded : bool;
                           heartrate__value : float;
                           heartrate_sound__startFrom : float;
                           heartrate_sound__path : string;
                           heartrate_sound__updateInterval : float;
                           var heartrate_sound__updateAt : float&;
                           var heartrate_sound__event : SoundEvent&;
                           transform : float3x4;
                           isAlive : bool)

  if evt.curTime >= heartrate_sound__updateAt
    heartrate_sound__updateAt = evt.curTime + heartrate_sound__updateInterval
    let shouldPlay = heartrate__value > heartrate_sound__startFrom && isAlive && sound_banks_state__isPresetLoaded
    if heartrate_sound__event |> play_or_abandon(heartrate_sound__path, transform[3], shouldPlay)
      set_var(heartrate_sound__event, "bpm", heartrate__value)
      set_pos(heartrate_sound__event, transform[3])

[es(tag=sound, track=(is_watched_sound, sound_banks_state__isPresetLoaded), REQUIRE=(is_watched_sound, sound_banks_state__isPresetLoaded))]
def heartrate_sound_reset(evt : Event;
                          var heartrate_sound__event : SoundEvent&)
  heartrate_sound__event.enabled = false
  heartrate_sound__event |> release()
