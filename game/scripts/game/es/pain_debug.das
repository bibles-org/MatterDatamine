options no_aot

require ecs
require DagorConsole
require game.es.damage_systems.damage_model_common
require game.es.net_console_macro
require game.es.pain_common


[net_console_cmd(name="pain")]
def debug_pain(progress = 1f; @net_hero hero_eid : EntityId)
  add_pain_progress(hero_eid, progress)


[net_console_cmd(name="pain.immunity")]
def debug_pain_immunity(@net_hero hero_eid : EntityId)
  createEntity("painkiller_effect") <| $(var init)
    set(init, "game_effect__timeToDestroy", 99999f)
    set(init, "game_effect__attachedTo", hero_eid)


[net_console_cmd(name="pain.destroy_immunity")]
def debug_pain_immunity_destroy(@net_hero hero_eid : EntityId)
  query() <| $ [es(REQUIRE=painkillerEffect)] (eid, game_effect__attachedTo : EntityId)
    if game_effect__attachedTo == hero_eid
      destroyEntity(eid)