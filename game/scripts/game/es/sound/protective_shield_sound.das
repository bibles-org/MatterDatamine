require ecs
require soundEvent


[es(tag=sound, track=(protective_shield__absorbedHits, protective_shield__activeAt), REQUIRE=(protective_shield__absorbedHits, protective_shield__activeAt))]
def protective_shield_sound(evt : Event; item__containerOwnerEid : EntityId;
                            protective_shield_sound__path : string)
  query(item__containerOwnerEid) <| $ [es] (is_watched_sound : bool; transform : float3x4)
    if is_watched_sound
      oneshot(protective_shield_sound__path, transform[3])
