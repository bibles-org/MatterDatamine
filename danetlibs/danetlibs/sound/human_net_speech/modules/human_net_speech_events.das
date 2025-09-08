module human_net_speech_events shared
require ecs


[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)] // server->client (internal)
struct CmdNetHumanSpeech
  phraseIdx : int
  time : float

[cpp_event(unicast)] // server->server only
struct CmdRequestHumanSpeech
  phrase : string
  listener : EntityId
  exceptPossessed : EntityId

[cpp_event(unicast)] // server->server only
struct CmdRequestHumanSpeechAbout
  phrase : string
  aboutEid : EntityId

[event(unicast)] // client->client
struct CmdClientHumanSpeech
  phrase : string

[event(unicast)] // client->client
struct EventOnHumanSpeak {}
