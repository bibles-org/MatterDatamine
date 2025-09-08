require ecs
require soundEvent
require level


[es(tag=sound, on_disappear, REQUIRE_NOT=transform)]
def on_disappear_sound_extended(evt : Event;
                                on_disappear_sound__path : string;
                                item__humanOwnerEid : EntityId)
  if is_level_unloading()
    return

  query(item__humanOwnerEid) <| $ [es] (transform : float3x4)
    oneshot(on_disappear_sound__path, transform[3])
