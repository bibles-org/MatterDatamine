require ecs
require soundHash
require soundEvent
require sound_utils.modules.sound_player_common
require sound_utils.modules.sound_control_common
require active_matter.game.es.skeleton_swarm_state_common


[es(tag=sound, track=skeleton_swarm__aiState, REQUIRE=(swarmMovementSound, skeletonSwarmSound))]
def skeleton_swarm_sound_stand(evt : Event;
                               sound_control__state : int;
                               skeleton_swarm__aiState : int;
                               @shared_comp sound_paths : Object;
                               sound_tags : Object;
                               transform : float3x4)
  if have_sound(sound_control__state) && skeleton_swarm__aiState == int(SkeletonSwarmAiState.SKELETON_STAND)
    sound_player_common::play_path("transform", sound_paths, sound_tags, false/*is_watched_sound*/, transform[3])


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es, REQUIRE=(swarmMovementSound, skeletonSwarmSound))]
def skeleton_swarm_sound_movement(evt : Event;
                                  sound_control__state : int;
                                  sound_event_group : SoundEventGroup&;
                                  skeleton_swarm__aiState : int)
  if have_sound(sound_control__state)
    let handle = get_sound(sound_event_group, sound_hash("movement"))
    let speed = skeleton_swarm__aiState == int(SkeletonSwarmAiState.MOVE) ? 1. : 0.
    let target = skeleton_swarm__aiState != int(SkeletonSwarmAiState.STAND) ? 1. : 0.
    set_var(handle, "target", target)
    set_var(handle, "speed", speed)
