module nexus_stats_common shared
require ecs.enum_macro


[export_enum]
enum NexusStatType
  KILL
  ASSIST
  HIT
  GRENADE_KILL
  MELEE_KILL
  HEADSHOT_KILL
  TEAM_KILL
  LONGSHOT_KILL
  BEACON_CAPTURE
  BEACON_RESET
  DEATH


[export_enum]
enum NexusMvpReason
  MOST_KILLS
  MOST_HELP
  MOST_BEACON_CAPTURES
