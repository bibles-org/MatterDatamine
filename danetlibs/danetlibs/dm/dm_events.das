module dm_events shared
require ecs

[cpp_event(unicast)]
struct EventOnHitByProjectile
  localHitPos : float3
  localHitDir : float3
  localNormal : float3
  caliber : float
  bulletTypeId : int
  nodeId : int
  pierced : bool
  projectileEid : EntityId

[cpp_event(unicast)]
struct EventOnRicochet
  localHitPos : float3
  localHitDir : float3
  localNormal : float3
  caliber : float
  nodeId : int
  projectileEid : EntityId

[cpp_event(unicast, with_scheme)]
struct CmdUpdateHitpoints
  time : float

[cpp_event(unicast, with_scheme)]
struct CmdApplyDamage
  offender : EntityId
  damageType : int
  shellId : int
  gunPropsId : int
  actionPropsId : int
  collNodeId : int
  deltaHp : float
  blockingDeltaHp : float
  stoppingPower : float
  hitPos : float3
  hitDir : float3
  hitNorm : float3
  dmgMult : float
  armorMult : float
  armorPenetration : float
  shatterCount : int
  causedBleeding : float
