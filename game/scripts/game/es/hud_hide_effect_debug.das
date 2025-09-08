options no_aot
require ecs
require game.utils.hero
require DagorConsole


[console_cmd(name="am.toggle_hud")]
def console_abacaba()
  let hero = get_controlled_hero()
  let hadEffect = find_query() <| $ [es(REQUIRE=hide_ui_game_effect)] (eid : EntityId; game_effect__attachedTo : EntityId)
    if game_effect__attachedTo != hero
      return false
    destroyEntity(eid)
    return true
  if !hadEffect
    createEntity("hide_ui_game_effect") <| $(init)
      set(init, "game_effect__attachedTo", hero)
