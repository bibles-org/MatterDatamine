options no_aot

require ecs
require DagorConsole
require game.es.net_console_macro
require danetlibs.render_debug.main.net_draw_debug_common


[net_console_cmd(name="am.tree_horde_event")]
def console_tree_horde_event(@net_hero hero_eid : EntityId)
  query(hero_eid) <| $ [es] (transform : float3x4)
    createEntity("tree_horde_event") <| $(var init)
      init |> set("transform", transform)


[net_console_cmd(name="am.tree_horde_event_debug")]
def console_tree_horde_event_debug(debug : bool = true)
  query() <| $ [es] (var tree_horde_event__debug : bool&)
    tree_horde_event__debug = debug


[es(tag=server, no_order)]
def tree_horde_event_debug(upd : UpdateStageInfoAct;
                           transform : float3x4;
                           tree_horde_event__enemiesMarkRadius : float;
                           tree_horde_event__debug : bool;
                           tree_horde_event__goal : EntityId)
  if !tree_horde_event__debug
    return

  net_draw_debug_sphere_buffered(transform[3], tree_horde_event__enemiesMarkRadius, E3DCOLOR(0xffffffff), 12, 1)
  query(tree_horde_event__goal) <| $ [es] (transform : float3x4)
    net_draw_debug_sphere_buffered(transform[3], 1.0, E3DCOLOR(0xff00ff00), 12, 1)
