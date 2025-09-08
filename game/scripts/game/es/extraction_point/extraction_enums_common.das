module extraction_enums_common shared
require ecs.enum_macro

[export_enum]
enum ExtractionStatusForHero
  OK
  WRONG_TIME
  PRIMARY_CONTRACT_NOT_COMPLETED
