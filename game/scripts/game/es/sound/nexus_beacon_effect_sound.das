require ecs
require DagorMath
require soundEvent
require sound_utils.modules.sound_control_common
require game.events.events_active_matter


[es(tag=sound, REQUIRE_NOT=nexus_disable)]
def nexus_beacon_capture_device_effect_sound(evt : ParallelUpdateFrameDelayed;
                                             nexus_beacon_capture_device__progressVisual : float;
                                             sound_effect__event : SoundEvent&;
                                             sound_control__state : int;
                                             var nexus_beacon_capture_device_effect_sound__progress : float&)
  if have_sound(sound_control__state)
    if nexus_beacon_capture_device_effect_sound__progress != nexus_beacon_capture_device__progressVisual
      nexus_beacon_capture_device_effect_sound__progress = nexus_beacon_capture_device__progressVisual
      set_var(sound_effect__event, "progress", nexus_beacon_capture_device_effect_sound__progress)
  else
    nexus_beacon_capture_device_effect_sound__progress = -1.
