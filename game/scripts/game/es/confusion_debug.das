options no_aot
require ecs
require ecs.common
require game.utils.hero
require DagorConsole
require game.es.confusion_common

[console_cmd(name="affect.confusion")]
def console_activate_confusion(duration = 0.0; intensity = 0.0; speed = 0.0)
  let hero = get_controlled_hero()
  let applied = find_query() <| $ [es(REQUIRE=concussionAffect)] (game_effect__attachedTo : EntityId)
    return game_effect__attachedTo == hero
  if applied
    disable_confusion_affect(hero)
  else
    enable_confusion_affect(hero, duration, intensity, speed)