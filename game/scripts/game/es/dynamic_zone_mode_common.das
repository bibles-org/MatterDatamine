module dynamic_zone_mode_common shared
require DagorSystem


enum DynamicZoneControllerState
  NONE
  WAITING_FOR_ZONE_SHRINKING
  ZONE_SHRINKING
  EXTERMINATION


def print_dynamic_zone_controller(text : string)
  print("[DYNAMIC ZONE] {text}")


def logerr_dynamic_zone_controller(text : string)
  logerr("[DYNAMIC ZONE] {text}")

