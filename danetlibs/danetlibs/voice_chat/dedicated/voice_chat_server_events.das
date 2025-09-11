module voice_chat_server_events shared

require ecs


[cpp_event(unicast)]
struct VoiceChatServerRoomJoinRequest
  roomId : string

[cpp_event(unicast)]
struct VoiceChatServerRoomGetVolumes
  roomId : string

[cpp_event(broadcast)]
struct VoiceChatServerInitialized {}

[cpp_event(broadcast)]
struct VoiceChatServerShuttingDown {}
