module melee_events shared
require ecs

[cpp_event(unicast, with_scheme)]
struct EventMeleeAction
  actorEid : EntityId
  propsId : int

[cpp_event(unicast, with_scheme)]
struct EventMeleeAttackHit
  pos : float3
  power : float
  targetEid : EntityId
