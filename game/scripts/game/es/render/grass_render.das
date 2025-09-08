require ecs
require level
require WorldRenderer


[es(tag=render, REQUIRE=grass_eraser, on_event=EventLevelLoaded, on_appear)]
def grass_eraser_on_level_loaded(evt : Event;
                                 sphere_zone__radius : float;
                                 transform : float3x4)
  if !is_level_loaded()
    return

  erase_grass(transform[3], sphere_zone__radius)