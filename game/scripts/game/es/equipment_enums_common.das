module equipment_enums_common shared
require ecs.enum_macro


[export_enum]
enum EquipmentSlotFlags
  NONE          = 0
  REMOVED       = 0x1


[export_enum]
enum GunSlotFlags
  NONE          = 0
  REMOVED       = 0x1
  LOCKED        = 0x2