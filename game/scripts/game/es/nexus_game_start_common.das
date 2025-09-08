module nexus_game_start_common shared
require ecs.enum_macro


[export_enum]
enum NexusGameStartState
  None
  Aborted
  WaitingForPlayers
  WarmUp
  Started
