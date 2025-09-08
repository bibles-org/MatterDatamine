module swarm_events shared
require ecs

[cpp_event(unicast)]
struct EventSomeSwarmBoidBorn
  count : int

[cpp_event(unicast)]
struct EventSomeSwarmBoidDied
  pos : float3

[cpp_event(broadcast)]
struct EventProjectileFlight
  prevPos : float3
  normalizedDir : float3
  dist : float
  isLocalOwner : bool
