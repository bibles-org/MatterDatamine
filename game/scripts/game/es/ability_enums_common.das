module ability_enums_common shared
require ecs.enum_macro


[export_enum]
enum AbilityUseFailedReason
  COOLDOWN
  NOT_ENOUGH_CHARGES
  NOT_ENOUGH_STAMINA
  TOO_FAR


[export_enum]
enum MothmanDivingGrabState
  NONE
  GRABBING
  FLIGHT
  HOLD
