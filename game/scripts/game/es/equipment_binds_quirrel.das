require game.utils.hero
require ecs.ecs_quirrel
require game.es.item_equip_common
require game.es.equipment_generator_common


[quirrel_bind(module_name="das.equipment")]
def hero_clean_all_equipment_and_gun_slots()
  let hero = get_controlled_hero()
  item_equip_common::hero_clean_all_equipment_and_gun_slots(hero)


[quirrel_bind(module_name="das.equipment")]
def generate_loadout_by_seed(generator_name : string; seed : int; var loadout_out : Array)
  var seedInternal = seed
  let generatedLoadoutBlk = $ <| (equipment : Array)
    loadout_out := equipment
  generate_loadout(
    generator_name,
    1.0 /*corrupt_chance*/,
    DEFAULT_BASE_VOLUME,
    true /*is_fill_inventories*/,
    seedInternal,
    generatedLoadoutBlk)
