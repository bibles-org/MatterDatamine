require ecs
require soundEvent
require soundHash
require game.events.events_active_matter


[es(tag=sound, track=human_parachute_effect__isOpened)]
def human_parachute_sound_open_close(evt : Event;
                                     human_parachute_effect__isOpened : bool;
                                     human_parachute_sound__openPath : string;
                                     human_parachute_sound__closePath : string;
                                     human_parachute_effect__attachedTo : EntityId)
  if !has(human_parachute_effect__attachedTo, "watchedByPlr")
    return
  oneshot(human_parachute_effect__isOpened ? human_parachute_sound__openPath : human_parachute_sound__closePath)
  sendEvent(human_parachute_effect__attachedTo, ParachuteDeployStateChanged())


[es(tag=sound, track=is_watched_sound, on_event=ParachuteDeployStateChanged)]
def human_parachute_sound_toggle(evt : Event;
                                 human_parachute_effect__eid : EntityId;
                                 is_watched_sound : bool;
                                 transform : float3x4;
                                 var sound_event_group : SoundEventGroup&)
  reject_sound(sound_event_group, sound_hash("parachute"))
  query(human_parachute_effect__eid) <| $ [es] (human_parachute_sound__path : string;
                                                human_parachute_effect__isOpened : bool)
    if human_parachute_effect__isOpened && is_watched_sound
      add_sound(sound_event_group, sound_hash("parachute"), play(human_parachute_sound__path, transform[3]))


[es(tag=sound, on_disappear, REQUIRE=human_parachute_sound__path)]
def human_parachute_sound_disappear(evt : Event;
                                    human_parachute_effect__attachedTo : EntityId)
  query(human_parachute_effect__attachedTo) <| $ [es(REQUIRE=watchedByPlr)] (var sound_event_group : SoundEventGroup&)
    release_sound(sound_event_group, sound_hash("parachute"))


[es(tag=sound, on_disappear, REQUIRE=watchedByPlr)]
def human_parachute_sound_disappear_on_change_spectator(evt : Event;
                                                        var sound_event_group : SoundEventGroup&)
  release_sound(sound_event_group, sound_hash("parachute"))
