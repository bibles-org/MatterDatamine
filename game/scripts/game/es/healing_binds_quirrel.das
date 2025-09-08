require ecs
require ecs.ecs_quirrel
require game.es.damage_systems.damage_model_healing_common


[quirrel_bind(module_name="das.healing")]
def verify_healing_attempt_bind(hero_eid, item_eid : EntityId)
  return verify_healing_attempt(hero_eid, item_eid)


[quirrel_bind(module_name="das.healing")]
def show_healing_tip_bind(hero_eid, item_eid : EntityId)
  show_healing_tip(hero_eid, item_eid)


[quirrel_bind(module_name="das.healing")]
def set_wish_part_to_heal_bind(hero_eid : EntityId; part : string)
  set_wish_part_to_heal(hero_eid, part)


[quirrel_bind(module_name="das.healing")]
def get_most_needed_heal_item_bind(hero_eid : EntityId)
  return get_most_needed_heal_item(hero_eid)
