module server_debug_common shared
require ecs
require DngNet
require game.events.events_active_matter


def exec_server_cmd(message : string)
  find_query() <| $ [es(REQUIRE=player)] (eid : EntityId; is_local : bool)
    if is_local
      using() <| $(var data : Object)
        data |> set("mode", "team")
        data |> set("text", "/servercmd {message}")
        send_net_event(eid, CmdSendChatMessage(
          data = ecs_addr(data)
        ))
      return true
    return false