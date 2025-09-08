require ecs
require app
require soundEvent
require soundSystem
require danetlibs.renderer.includes.pufd_events
require weapon_sounds.modules.weapon_sounds_events
require game.events.events_game
require math.base


[es(tag=sound, on_appear, track=sound_banks_state__isPresetLoaded)]
def onboarding_interactive_music_appear(evt : Event;
                                        sound_banks_state__isPresetLoaded : bool;
                                        onboarding_interactive_music__path : string;
                                        var onboarding_interactive_music__event : SoundEvent&)
  if sound_banks_state__isPresetLoaded
    onboarding_interactive_music__event |> play(onboarding_interactive_music__path)
  else
    onboarding_interactive_music__event |> release()


[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es)]
def onboarding_interactive_music_update(evt : ParallelUpdateFrameDelayed;
                                        var onboarding_interactive_music__temperature : float&;
                                        onboarding_interactive_music__drain : float;
                                        onboarding_interactive_music__activateThreshold : float;
                                        onboarding_interactive_music__deactivateThreshold : float;
                                        onboarding_interactive_music__param : string;
                                        var onboarding_interactive_music__active : bool&;
                                        onboarding_interactive_music__event : SoundEvent&)

  var active = onboarding_interactive_music__active
  if onboarding_interactive_music__temperature >= onboarding_interactive_music__activateThreshold
    active = true
  elif onboarding_interactive_music__temperature < onboarding_interactive_music__deactivateThreshold
    active = false

  if onboarding_interactive_music__active != active
    onboarding_interactive_music__active = active
    set_var(onboarding_interactive_music__event, onboarding_interactive_music__param, active ? 1. : 0.)

  onboarding_interactive_music__temperature -= onboarding_interactive_music__drain * evt.dt
  onboarding_interactive_music__temperature = max(0., onboarding_interactive_music__temperature)


def add_heat(var onboarding_interactive_music__temperature : float&; heat : float)
  onboarding_interactive_music__temperature = min(onboarding_interactive_music__temperature + heat, 100.)


[es(tag=sound)]
def onboarding_interactive_music_trigger_shooting(evt : EventOnWeaponSound;
                                                  var onboarding_interactive_music__temperature : float&;
                                                  onboarding_interactive_music_trigger_shooting__rangeThreshold : float;
                                                  var onboarding_interactive_music_trigger_shooting__shotAtTime : float&;
                                                  onboarding_interactive_music_trigger_shooting__cooldown : float;
                                                  onboarding_interactive_music_trigger_shooting__heat : float)

  if length_sq(get_listener_pos() - evt.pos) < square(onboarding_interactive_music_trigger_shooting__rangeThreshold)
    if get_sync_time() >= onboarding_interactive_music_trigger_shooting__shotAtTime
      onboarding_interactive_music_trigger_shooting__shotAtTime = get_sync_time() + onboarding_interactive_music_trigger_shooting__cooldown
      add_heat(onboarding_interactive_music__temperature, onboarding_interactive_music_trigger_shooting__heat)


[es(tag=sound)]
def onboarding_interactive_music_trigger_hit(evt : EventOnEntityHit;
                                             var onboarding_interactive_music__temperature : float&;
                                             onboarding_interactive_music_trigger_hit__selfHeat : float;
                                             onboarding_interactive_music_trigger_hit__otherHeat : float)
  if evt.victim != evt.offender
    if has(evt.victim, "hero")
      add_heat(onboarding_interactive_music__temperature, onboarding_interactive_music_trigger_hit__selfHeat)
    elif has(evt.offender, "hero")
      add_heat(onboarding_interactive_music__temperature, onboarding_interactive_music_trigger_hit__otherHeat)
