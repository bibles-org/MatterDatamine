module shell_events shared
require ecs
require DaWeaponProps

[cpp_event(unicast)]
struct CmdShellExplodeClient
  pos : float3
  offsetedPos : float3
  shellVelocity : float3
  shellId : ShellPropIds
  gunPropsId : int
  offender : EntityId
  explVictim : EidList
  explDamageAndFatal : UInt8List
  fxInfoEid : EntityId