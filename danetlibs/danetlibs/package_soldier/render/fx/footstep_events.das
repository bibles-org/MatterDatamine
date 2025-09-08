module footstep_events shared
require ecs

[cpp_event(unicast)]
struct EventFootStep
  pos : float3
  normal : float3
  direction : float3
  nodeId : int
