module sound_net_events shared
require ecs

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdPlayLootSoundForEnemy
  hash : uint
  time : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdPlayLootSound
  hash : uint
  time : float

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct CmdHumanHitNetSound
  offender : EntityId
  damageType : int
  actionPropsId : int
  collNodeId : int
  shatterCount : int
  time : float
