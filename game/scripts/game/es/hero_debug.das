options no_aot
require ecs
require ecs.safe
require game.events.events_active_matter
require game.es.net_console_macro
require game.es.boxed_ammo_reload_common
require game.es.inventory_weapon_mod_common


[net_console_cmd(name="hero.interrupt_reload")]
def hero_interrupt_reload_cmd(@net_hero hero_eid : EntityId)
  interrupt_boxed_ammo_guns_reload(hero_eid, true)
  interrupt_magazine_ammo_guns_reload(hero_eid)