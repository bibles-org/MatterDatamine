require ecs.safe
require game.es.human_weap_common
require game.es.human.human_reload_common
require game.es.inventory_common
require game.es.inventory_checks_common
require ecs.ecs_quirrel
require game.utils.hero


[quirrel_bind(module_name="das.human_weap")]
def unload_ammo_from_gun_to_inventory(weapon_slot_name : string; to_inventory_eid : EntityId)
  human_weap_common::request_unload_ammo_from_gun(get_controlled_hero(), weapon_slot_name, to_inventory_eid)


[quirrel_bind(module_name="das.human_weap")]
def try_load_weapon_ammo_from_inventory(weapon_slot_name : string; from_inventory_eid : EntityId)
  human_weap_common::request_load_weapon_from_inventory(get_controlled_hero(), weapon_slot_name, from_inventory_eid)


[quirrel_bind(module_name="das.human_weap")]
def load_weapon_ammo_from_inventory(ammo_eid : EntityId; slot_name : string)
  human_weap_common::load_weapon_ammo_from_inventory(get_controlled_hero(), ammo_eid, slot_name)


[quirrel_bind(module_name="das.human_weap")]
def choose_weapon(slot_name : string)
  human_weap_common::choose_weapon(get_controlled_hero(), slot_name)


[quirrel_bind(module_name="das.human_weap")]
def is_inventory_have_volume_for_ammo(inventory_eid : EntityId; ammo_template : string; ammo_count : int)
  let maxCount = get_boxed_item_count_to_fit_inventory(inventory_eid, ammo_template, ammo_count)
  return ammo_count <= maxCount
