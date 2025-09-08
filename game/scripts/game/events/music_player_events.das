module music_player_events shared
require ecs

[event(broadcast)]
struct CmdMusicPlayerPlay
  track : string
  pos : int

[event(broadcast)]
struct CmdMusicPlayerStop {}
