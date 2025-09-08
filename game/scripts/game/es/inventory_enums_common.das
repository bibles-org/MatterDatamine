module inventory_enums_common shared
require ecs.enum_macro


[export_enum]
enum PackFitCheckResult
  OK
  INVENTORY_FULL
  EQUIPMENT_FULL
