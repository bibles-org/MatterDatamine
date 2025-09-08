require ecs
require DagorMath
require soundEvent


[es(tag=sound, on_event=ParallelUpdateFrameDelayed)]
def gathering_am_sound(evt : Event;
                       game_effect__attachedTo : EntityId;
                       gathering_am_sound__path : string;
                       var gathering_am_sound__event : SoundEvent&)

  query(game_effect__attachedTo) <| $ [es] (transform : float3x4;
                                            am_storage__maxValue : int;
                                            am_storage__value : int)

    assume event = gathering_am_sound__event
    if !event.enabled
      event.enabled = true
      event.abandonOnReset = true
      event |> play(gathering_am_sound__path, transform[3])

    set_pos(event, transform[3])
    set_var(event, "progress", saturate(safediv(float(am_storage__value), float(am_storage__maxValue))))
