module nexus_beacon_common shared
require ecs.enum_macro


[export_enum]
enum NexusBeaconState
  INACTIVE
  COOLDOWN
  CHANGING
  CAPTURED
