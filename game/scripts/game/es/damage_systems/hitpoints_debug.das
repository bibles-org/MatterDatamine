options no_aot
require ecs
require game.es.net_console_macro
require game.es.damage_systems.damage_model_common
require game.es.damage_systems.damage_model_armor_common


[net_console_cmd(name="hitpoints.set_hero_hp")]
def set_hero_hp(value : float; @net_hero eid : EntityId)
  query(eid) <| $ [es] (var hitpoints__hp : float&)
    hitpoints__hp = value


[net_console_cmd(name="hitpoints.set_hero_downed")]
def set_hero_downed(@net_hero eid : EntityId)
  let painEffect <- BodyPartEffect(
    effectTemplate = "damage_model_effect_down_state"
  )
  human_damage_model_start_effect(eid, painEffect)


[net_console_cmd(name="hitpoints.hero_god_mode")]
def hero_god_mode(@net_hero eid : EntityId)
  human_damage_model_set_hp_in_percent(eid, 99999f)
  human_damage_model_set_armor_hp_in_percent(eid, 99999f)
