options no_aot
require ecs
require ecs.common
require DagorConsole
require game.es.server_debug_common
require game.es.net_console_macro


[console_cmd(name="server.cmd", is_hook=true)]
def do_server_cmd(cmd : string; arg1 : string = ""; arg2 : string = ""; arg3 : string = ""; arg4 : string = ""; arg5 : string = ""; arg6 : string = ""; arg7 : string = "")
  let message = "{cmd} {arg1} {arg2} {arg3} {arg4} {arg5} {arg6} {arg7}"
  exec_server_cmd(message)


[net_console_cmd(name="server.stats")]
def server_stats_cmd()
  let found = find_query() <| $ [es(REQUIRE=server_stats_controller)] (eid : EntityId)
    destroyEntity(eid)
    return true

  if !found
    createEntity("server_stats_controller")


[net_console_cmd(name="unlocks.add_unlock")]
def server_unlocks_add_unlock(unlock : string; @net_player player_eid : EntityId)
  query(player_eid) <| $ [es] (var player__newUnlocks : StringList&)
    if -1 == player__newUnlocks |> find_index(unlock)
      player__newUnlocks |> push(unlock)

