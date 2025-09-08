options no_aot
require ecs
require ecs.safe
require DagorConsole
require DagorSystem
require RendInst
require game.utils.net_utils
require game.es.net_console_macro
require game.events.events_active_matter
require DngNet


[console_cmd(name="ri.riextra_map_show")]
def console_ri_riextra_map_show()
  iterate_riextra_map() <| $(id : int;
                             name : string#)
    if !is_true_net_server()
      console_print("[{id}]{name}")
    print("[{id}]{name}")


[net_console_cmd(name="ri.riextra_map_validate")]
def console_ri_riextra_map_validate(@net_player player_eid : EntityId)
  iterate_riextra_map() <| $(id : int;
                             name : string#)
    send_net_event(player_eid, CmdValidateRIExtraIndex(id = id, name := name))


[es(tag=netClient, REQUIRE=player)]
def debug_validate_riextra_index(evt : CmdValidateRIExtraIndex)
  let serverName = evt.name
  let clientName = riex_getRIGenExtraName(uint(evt.id))
  if serverName != clientName
    logerr("client-server riExtraMap desync detected: [client][{evt.id}]{clientName} != [server][{evt.id}]{serverName}")