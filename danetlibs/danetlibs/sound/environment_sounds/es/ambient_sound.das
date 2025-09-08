require ecs
require math.base
require soundSystem
require soundEvent
require danetlibs.renderer.includes.pufd_events


[es(tag=sound, on_appear, track=sound_banks_state__isPresetLoaded)]
def ambient_sound_toggle(evt : Event;
                         sound_banks_state__isPresetLoaded : bool;
                         ambient_sound__abandonOnReset : bool;
                         var ambient_sound__shouldPlay : bool&;
                         var ambient_sound__event : SoundEvent&)
  release(ambient_sound__event)
  ambient_sound__event.enabled = false
  ambient_sound__event.abandonOnReset = ambient_sound__abandonOnReset
  ambient_sound__shouldPlay = sound_banks_state__isPresetLoaded


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es)]
def ambient_sound_update(evt : Event;
                         ambient_sound__shouldPlay : bool;
                         ambient_sound__path : string;
                         var ambient_sound__event : SoundEvent&)

  if ambient_sound__shouldPlay
    if !ambient_sound__event.enabled
      ambient_sound__event.enabled = true
      ambient_sound__event |> play(ambient_sound__path, get_listener_pos())
    else
      set_pos(ambient_sound__event, get_listener_pos())
