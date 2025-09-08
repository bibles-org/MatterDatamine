module nphys_events shared

require ecs
require DngDm
require RendInst
require DagorMath


[cpp_event(broadcast, with_scheme, cpp_gen=false)]
struct EventOnEntityHit
  victim : EntityId
  offender : EntityId
  hitResult : int
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

[cpp_event(unicast)]
struct CmdApplyRagdollParameters
  cur_time : float

[cpp_event(broadcast)]
struct EventRendinstDestroyed // server
  riexHandle : riex_handle_t
  riTm : float3x4
  riBBox : BBox3

[event(unicast)]
struct CmdPushPhys
  vel : float3
  push_immunity : float

[cpp_event(unicast)]
struct EventOnModsChanged {}

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct PathCorridorJumpLinkStartEndChanged
  start : float3
  end : float3