module inventory_slots_common shared

let
  weapon_slots_prefix = "weapon_"
  common_slots_prefix   = "slot_"
  outfit_slots_prefix = "outfit_"
  equipment_mod_slots_prefix = "equipment_mod_"
  equipment_slots_prefix = "equipment_"
  inventory_slots_prefix = "inventory"
  stash_slots_prefix = "stash"
  pocket_slots_prefix = "equipment_mod_pocket_"


let
  weapon_slots = fixed_array(
    "{weapon_slots_prefix}primary",
    "{weapon_slots_prefix}secondary",
    "{weapon_slots_prefix}tertiary",
    "{weapon_slots_prefix}melee")
  common_slots = fixed_array(
    "{common_slots_prefix}ammo",
    "{common_slots_prefix}scope",
    "{common_slots_prefix}silencer",
    "{common_slots_prefix}magazine"
  )