module player_events shared
require ecs

[event(unicast)]
struct EventOnPlayerConnected
  spawnPlaceId : int
  reconnected : bool

[event(unicast)]
struct CmdSpawnEntityForPlayer{}

[event(unicast)]
struct CmdScheduleSpawnEntityForPlayer
  spawnAt : float

[event(unicast)]
struct CmdPossessEntity
  possessedEid : EntityId

[event(broadcast)]
struct PlayerStartQuitGameTimer {}

[event(broadcast)]
struct PlayerResetQuitGameTimer {}

[event(unicast, routing=ROUTING_CLIENT_TO_SERVER)]
struct PlayerRequestSpawnInWorld {}
