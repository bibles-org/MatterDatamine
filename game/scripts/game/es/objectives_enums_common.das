module objectives_enums_common shared
require ecs.enum_macro

// the same as in `active_matter/profileServer/structures/contracts_structures.das`
[export_enum]
enum ContractType
  PRIMARY
  SECONDARY
  STORY
  ITEM
  FREE_TO_USE //not used now, but saved to not raise all contracts version
  FREE_TO_USE_2 //not used now, but saved to not raise all contracts version
  MONSTER

[export_enum]
enum ObjectivePhotographAffectState
  NONE
  SHOOTED
