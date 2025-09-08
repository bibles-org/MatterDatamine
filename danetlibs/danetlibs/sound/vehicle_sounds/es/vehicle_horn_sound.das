require ecs
require ecs.common
require app
require sound_utils.modules.sound_player_common
require danetlibs.renderer.includes.pufd_events
require soundEvent
require soundHash


[es(tag=sound, track=vehicle_horn__endTime)]
def vehicle_horn_sound_toggle(evt : Event;
                              vehicle_horn__endTime : float;
                              vehicle_horn_sound__note : int;
                              var vehicle_horn_sound__event : SoundEvent&;
                              @shared_comp vehicle_horn_sound__path : Object;
                              sound_tags : Object;
                              is_watched_sound : bool;
                              transform : float3x4)

  let shouldPlay = get_sync_time() < vehicle_horn__endTime
  if vehicle_horn_sound__event.enabled != shouldPlay
    vehicle_horn_sound__event.enabled = shouldPlay
    abandon(vehicle_horn_sound__event)
    if vehicle_horn_sound__event.enabled
      vehicle_horn_sound__event |> reset(sound_player_common::play_path(vehicle_horn_sound__path, sound_tags, is_watched_sound, transform[3], false))
      set_var_optional(vehicle_horn_sound__event, "note", float(vehicle_horn_sound__note))


[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es)]
def vehicle_horn_sound_update(info : ParallelUpdateFrameDelayed;
                              vehicle_horn__endTime : float;
                              var vehicle_horn_sound__event : SoundEvent&;
                              transform : float3x4)
  if vehicle_horn_sound__event.enabled
    set_pos(vehicle_horn_sound__event, transform[3])
    if info.curTime >= vehicle_horn__endTime
      abandon(vehicle_horn_sound__event)
      vehicle_horn_sound__event.enabled = false
