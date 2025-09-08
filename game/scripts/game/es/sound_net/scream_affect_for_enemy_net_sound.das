require ecs
require game.utils.sound_utils


[es(tag=server, on_appear)]
def scream_affect_for_enemy_net_sound(evt : Event;
                                      scream_affect_for_enemy_net_sound__desc : string;
                                      game_effect__attachedTo : EntityId)

  ecs::query(game_effect__attachedTo) <| $ [es] (transform : float3x4)
    broadcast_scene_net_sound(scream_affect_for_enemy_net_sound__desc,
                              transform[3],
                              TEAM_UNASSIGNED,
                              INVALID_ENTITY_ID,
                              game_effect__attachedTo/*except_possessed*/)
