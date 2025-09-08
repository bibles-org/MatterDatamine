options no_aot
require ecs
require ecs.common
require game.utils.hero
require DagorConsole
require game.es.concussion_common
require DagorDebug3D
require BallisticsProps
require DaWeaponProps
require DaWeapons
require AnimV20
require GeomNodeTree

[console_cmd(name="affect.concussion")]
def console_activate_concussion()
  let hero = get_controlled_hero()
  let applied = find_query() <| $ [es(REQUIRE=concussionAffect)] (game_effect__attachedTo : EntityId)
    return game_effect__attachedTo == hero
  if applied
    disable_concussion_affect(hero)
  else
    let concussionTemplate = get_string(hero, "concussion__template", "")
    if concussionTemplate != ""
      enable_concussion_affect(hero, concussionTemplate)

[console_cmd(name="affect.concussion.all")]
def console_activate_concussion_all()
  query() <| $ [es(REQUIRE=human)] (eid : EntityId)
    if has_concussion_affect(eid)
      disable_concussion_affect(eid)
    else
      let concussionTemplate = get_string(eid, "concussion__template", "")
      enable_concussion_affect(eid, concussionTemplate)
