options no_aot
require ecs
require game.es.net_console_macro
require game.es.monster_common


[net_console_cmd(name="monster.spawn_changed_minion")]
def console_migration_debug(@net_hero hero_eid : EntityId)
  spawn_minion(hero_eid, 2.0, 3.0, "monster_changed_minion+monster_changed_minion_spawn_from_portal")
