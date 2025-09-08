require ecs.ecs_quirrel
require active_matter.game.es.loot_preset_common


[quirrel_bind(module_name="das.loot_preset")]
def loot_preset_get_all_possible_items(template_name : string)
  return <- loot_preset_common::loot_preset_get_all_possible_items(template_name)
