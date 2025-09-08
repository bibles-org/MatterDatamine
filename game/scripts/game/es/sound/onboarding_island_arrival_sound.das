require ecs
require soundEvent
require soundSystem


[es(tag=sound, on_appear, REQUIRE=hero)]
def onboarding_island_arrival_sound_track_hero(evt : Event)
  query() <| $ [es] (onboarding_island_arrival_sound__path : string;
                     var onboarding_island_arrival_sound__isArrived : bool&)
    if !onboarding_island_arrival_sound__isArrived
      onboarding_island_arrival_sound__isArrived = true
      oneshot(onboarding_island_arrival_sound__path, get_listener_pos())


[es(tag=sound, on_appear)]
def onboarding_island_arrival_sound(evt : Event;
                                    onboarding_island_arrival_sound__path : string;
                                    var onboarding_island_arrival_sound__isArrived : bool&)
  query() <| $ [es(REQUIRE=hero)] ()
    onboarding_island_arrival_sound__isArrived = true
    oneshot(onboarding_island_arrival_sound__path, get_listener_pos())
