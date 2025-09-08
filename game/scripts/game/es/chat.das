require ecs
require DngNet
require strings
require ecs.safe
require DagorConsole
require game.events.events
require game.es.dedicated_utils_common
require game.events.events_active_matter


let
  SERVERCMD_PREFIX = "/servercmd"
  AUTOREPLACE_HERO = ":hero:"
  AUTOREPLACE_PLAYER = ":player:"


[es(tag=server)]
def server_recieve_chat_message(evt : CmdSendChatMessage;
                                eid, possessed : EntityId;
                                team aka speaker_team : int;
                                userid : uint64;
                                name : string;
                                player__teamEid = INVALID_ENTITY_ID)
  if (evt.data == null)
    return

  let isIncognitoTeam = player__teamEid |> has("team__incognito")
  let isServerCmd = (starts_with(evt.data.text ?? "", SERVERCMD_PREFIX) &&
                    has_dedicated_permission(eid, "send_server_commands"))

  if (isIncognitoTeam && !isServerCmd)
    return

  let mode = evt.data.mode ?? "team"

  if isServerCmd
    var text = (evt.data.text ?? "") |> slice(length(SERVERCMD_PREFIX))
    text = text |> replace(AUTOREPLACE_HERO, "{possessed}")
    text = text |> replace(AUTOREPLACE_PLAYER, "{eid}")
    console_command("net.set_console_connection_id {evt.data.fromconnid ?? -1}")
    send_log_to_clients("{name}: {text}")
    console_command(text)
    print("console command '{text}' received userid:{userid}")
    return

  using() <| $(var data : Object)
    data |> set("team", team)
    data |> set("name", name)
    data |> set("sender", eid)
    data |> set("senderUserId", userid)
    data |> set("text", evt.data.text ?? "")

    if mode == "team" || mode == "qteam"
      if has_network()
        var playersWithConnids : table<EntityId; int>
        query() <| $ [es(REQUIRE=player)] (connid : int; eid : EntityId; team : int)
          if speaker_team == team
            playersWithConnids.insert(eid, connid)
        for playerEid, playerConnid in keys(playersWithConnids), values(playersWithConnids)
          send_net_event(playerEid, EventChatMessage(data = ecs_addr(data)), array<IConnection?>(get_client_connection(playerConnid)))
      else
        find_query() <| $ [es(REQUIRE=player)] (eid : EntityId; is_local : bool) // running offline
          if is_local
            send_net_event(eid, EventChatMessage(data = ecs_addr(data)))
          return is_local


[es(tag=server)]
def send_error_to_all_clients(evt : EventDebugChatMessageAllClients)
  send_log_to_clients(evt.data.text ?? "")
