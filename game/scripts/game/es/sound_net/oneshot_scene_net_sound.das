require ecs
require game.utils.sound_utils
require game.utils.team


[es(tag=server, on_appear, REQUIRE_NOT=oneshot_scene_net_sound__enemyDesc)]
def oneshot_scene_net_sound(evt : Event;
                            oneshot_scene_net_sound__desc : string;
                            transform : float3x4)
  broadcast_scene_net_sound(oneshot_scene_net_sound__desc, transform[3])


[es(tag=server, on_appear)]
def oneshot_scene_net_sound_hero_enemy(evt : Event;
                                       eid : EntityId;
                                       oneshot_scene_net_sound__desc : string;
                                       oneshot_scene_net_sound__enemyDesc : string;
                                       transform : float3x4)
  send_scene_net_sound(eid, oneshot_scene_net_sound__desc)
  broadcast_scene_net_sound(oneshot_scene_net_sound__enemyDesc, transform[3], TEAM_UNASSIGNED, INVALID_ENTITY_ID, eid/*except_possessed*/, true/*need_connections*/)
