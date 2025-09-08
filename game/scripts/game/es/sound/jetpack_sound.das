require app
require ecs
require soundEvent


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=(human_locomotion_es, human_jetpack_locomotion_es, sound_begin_update_es), before=sound_end_update_es)]
def jetpack_sound(evt : Event;
                  var jetpack_sound__event : SoundEvent&;
                  var jetpack_sound__time : float&;
                  jetpack_sound__path : string;
                  jetpack_sound__addTime = 0.25;
                  jetpack__active : bool;
                  sound_banks_state__isPresetLoaded : bool;
                  slot_attach__attachedTo : EntityId = INVALID_ENTITY_ID)
  if jetpack__active && sound_banks_state__isPresetLoaded && slot_attach__attachedTo != INVALID_ENTITY_ID
    if !is_valid_handle_value(jetpack_sound__event)
      jetpack_sound__event |> play(jetpack_sound__path)
    jetpack_sound__time = get_sync_time()
  elif is_valid_handle_value(jetpack_sound__event) && get_sync_time() > jetpack_sound__time + jetpack_sound__addTime
    abandon(jetpack_sound__event)
  if is_valid_handle_value(jetpack_sound__event)
    ecs::query(slot_attach__attachedTo) <| $ [es] (transform : float3x4)
      set_pos(jetpack_sound__event, transform[3])
