module player_spawn_controller_common shared
require ecs.enum_macro

[export_enum]
enum PlayerSpawnControllerDefaultState
  NONE
  FADE
  REQUEST_REPLICATION
  DELAY
  DONE