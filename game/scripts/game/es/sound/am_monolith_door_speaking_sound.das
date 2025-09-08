require ecs


[es(tag=sound, on_appear, track=rotating_door_sound__isClosed, REQUIRE=monolithDoorSpeakingSound)]
def am_monolith_door_speaking_sound(evt : Event;
                                    rotating_door_sound__isClosed : bool;
                                    var sound_control__allowSound : bool&)
  sound_control__allowSound = !rotating_door_sound__isClosed
