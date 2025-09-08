module endgame_enums_common shared
require ecs.enum_macro


[export_enum]
enum EndgameControllerState
  NONE          = 0
  FADE_DELAY    = 1
  FADEIN        = 2
  DEBRIEFING    = 3
  SPECTATING    = 4