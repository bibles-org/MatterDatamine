module wounds_events shared

require ecs


[event(unicast)]
struct CmdResetTornWoundBoneDamage
  eid : EntityId

[cpp_event(unicast)]
struct EventOnDeathTornWoundApply
  collNodeId : int

[cpp_event(unicast)]
struct EventOnApplyWounds
  pos : float3
  normal : float3
  hitDir : float3
  coll_node : int
  explosion : bool
  damage : float
  caliberFactor : float

