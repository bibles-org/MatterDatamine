module am_encounter_workbench_enums_common shared public
require ecs.enum_macro


enum EncounterWorkbenchClientMode
  DEFAULT
  REPAIR


[export_enum]
enum EncounterWorkbenchMenuState
  NONE
  REPAIR