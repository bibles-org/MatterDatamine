module dedicated_utils_common shared
require ecs
require DngNet
require ecs.common
require game.es.app_common
require game.events.events_active_matter


def has_dedicated_permission(user_id : uint64; permission : string)
  if is_dev_circuit()
    return true

  var hasPermission = false
  find_query() <| $ [es] (userid : uint64; userPermissions : StringList)
    if userid == user_id
      hasPermission = find_index(userPermissions, permission) != -1
      return true
    return false
  return hasPermission


def has_dedicated_permission(player_eid : EntityId; permission : string)
  if is_dev_circuit()
    return true

  var hasPermission = false
  query(player_eid) <| $ [es] (userPermissions : StringList)
    hasPermission = find_index(userPermissions, permission) != -1
  return hasPermission


def send_log_to_clients(log_text : string)
  using() <| $(var data : Object)
    data |> set("team", -1)
    data |> set("name", "dedicated")
    data |> set("text", log_text)
    if !has_network()
      find_query() <| $ [es(REQUIRE=player)] (eid : EntityId; is_local : bool) // running offline
        if is_local
          send_net_event(eid, EventChatMessage(data = ecs_addr(data)))
        return is_local
    else
      var playersWithConnids : table<EntityId; int>
      query() <| $ [es(REQUIRE=player)] (connid : int; eid : EntityId; receive_logerr : bool)
        if connid != INVALID_CONNECTION_ID && receive_logerr && has_dedicated_permission(eid, "receive_server_messages")
          playersWithConnids.insert(eid, connid)
      for playerEid, playerConnid in keys(playersWithConnids), values(playersWithConnids)
        send_net_event(playerEid, EventChatMessage(data = ecs_addr(data)), array<IConnection?>(get_client_connection(playerConnid)))
