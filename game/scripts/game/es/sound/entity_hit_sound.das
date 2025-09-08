require ecs
require app
require game.events.events_game
require soundEvent


[es(tag=sound)]
def entity_hit_sound(evt : EventOnEntityHit; // only offender or victim will recieve it
                     eid : EntityId;
                     transform : float3x4;
                     entity_hit_sound__path : string;
                     entity_hit_sound__cooldown : float;
                     var entity_hit_sound__nextAt : float&)
  if evt.victim == eid && get_sync_time() >= entity_hit_sound__nextAt
    entity_hit_sound__nextAt = get_sync_time() + entity_hit_sound__cooldown
    oneshot(entity_hit_sound__path, transform[3])
