module dng_events shared
require ecs
require DngNet

[cpp_event(broadcast)]
struct EventOnClientConnected
  connectionId : int
  userId : uint64
  userName : das_string
  groupId : int64
  clientFlags : uint16
  platformUserId : das_string
  platformId : das_string
  matchingTeam : int
  appId : int

[cpp_event(broadcast)]
struct EventOnClientDisconnected
  connectionId : int
  disconnectReason : DisconnectionCause

// not DNG event, but very close to it and internal
[event(unicast)]
struct FinalizePlayerPreparing
  matchingTeam : int
  clientFlags : uint16
  isReconnected : bool

[cpp_event(broadcast)]
struct EventOnNetworkDestroyed
  last_client_dc : int // DisconnectionCause

[cpp_event(broadcast)]
struct EventOnConnectedToServer {}
