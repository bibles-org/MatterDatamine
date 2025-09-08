require ecs
require DagorMath
require soundHash
require soundEvent
require sound_utils.modules.sound_control_common

[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es, REQUIRE=(swarmMovementSound, clusterSwarmSound))]
def cluster_swarm_sound_update(evt : Event;
                               sound_control__state : int;
                               sound_event_group : SoundEventGroup&;
                               swarm_cluster__velocity : float3;
                               swarm_cluster__maxSpeed : float;
                               swarm_cluster__target : ecs::EntityId)
  if have_sound(sound_control__state)
    let handle = get_sound(sound_event_group, sound_hash("movement"))
    let speed = safediv(length(swarm_cluster__velocity), swarm_cluster__maxSpeed)
    let target = swarm_cluster__target != INVALID_ENTITY_ID ? 1. : 0.
    set_var(handle, "speed", speed)
    set_var(handle, "target", target)
