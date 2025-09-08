require ecs
require game.es.player_common
require game.events.player_events


[es(tag=server)]
def player_spawn_in_world_server(evt : PlayerRequestSpawnInWorld; eid : EntityId)
  player_respawn_in_world_common(eid)
