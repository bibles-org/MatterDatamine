options no_aot

require ecs
require DagorConsole
require game.es.net_console_macro


[net_console_cmd(name="am.xenohound_event")]
def console_xenohound_event(@net_hero hero_eid : EntityId)
  query(hero_eid) <| $ [es] (eid : EntityId)
    createEntity("xenohound_event") <| $(var init)
      init |> set("xenohound_event__targetEid", eid)