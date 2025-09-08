module player_connect_common shared
require ecs
require DngNet
require player
require matching
require DngActor
require GameTimers
require game.es.player_common
require game.events.player_events


def is_player_allow_connect(client_net_flags : uint16) : bool
  return (int(client_net_flags) & int(ClientNetFlags.CNF_RECONNECT_FORBIDDEN)) == 0


def disconnect_connection(connection_id : int; disconnect_reason = DisconnectionCause.DC_CONNECTION_CLOSED)
  var connection = get_client_connection(connection_id)
  if connection != null
    net_disconnect(*connection, disconnect_reason)


def is_player_allow_reconnect(player_eid : EntityId; client_net_flags : uint16) : bool
  // possessed entity wasn't spawned yet
  if (int(client_net_flags) & int(ClientNetFlags.CNF_SPAWNED_AT_LEAST_ONCE)) == 0
    return true

  var result = false
  query(player_eid) <| $ [es] (possessed : EntityId; team : int; var specTarget : EntityId&)
    if specTarget != INVALID_ENTITY_ID
      query(possessed) <| $ [es] (isAlive : bool)
        result = isAlive
    else
      // if spectator was active ensure that spectator target exist and alive or try to find new one
      query(specTarget) <| $ [es] (isAlive : bool)
        result = isAlive
      if !result
        specTarget = find_next_spec_target(team, specTarget, +1)
        result = specTarget != INVALID_ENTITY_ID
  return result


def try_reconnect_player(connection_id : int; user_id : uint64) : EntityId
  if user_id == INVALID_USER_ID || connection_id == INVALID_CONNECTION_ID
    return INVALID_ENTITY_ID
  var connection = get_client_connection(connection_id)
  if connection == null
    return INVALID_ENTITY_ID

  var result = INVALID_ENTITY_ID
  find_query() <| $ [es] (eid : EntityId;
                          userid : uint64;
                          var player : Player&;
                          var connid : int&;
                          var killEntityTimer : uint64&;
                          var disconnected : bool&;
                          var disconnectedAtTime : float&;
                          var replication : NetObject?)
    if userid != user_id
      return false

    var oldConnection = get_client_connection(connid)
    if oldConnection != null // reconnect
      print("[Reconnect] Changing connection for already existing player <{eid}> userid <{userid}>: #{connid} -> #{connection_id}.")
      *oldConnection |> connection_setUserPtr(null)
      connid = connection_id // before destroying the old one (to avoid calling EventOnClientDisconnected)
      net_disconnect(*oldConnection, DisconnectionCause.DC_CONNECTION_CLOSED)
    else
      connid = connection_id
    print("[Reconnect] Player player <{eid}> userid <{userid}> reconnected with connid = #{connection_id}.")

    if replication != null
      *replication |> net_object_setControlledBy(connection_id)
    connection_setUserEid(*connection, eid)
    game_timer_clear(killEntityTimer)
    assert(killEntityTimer == INVALID_TIMER_HANDLE)
    broadcastEventImmediate(PlayerResetQuitGameTimer())
    player |> resetSyncData()
    disconnected = false
    disconnectedAtTime = -1.0
    base_phys_actor_resizeSyncStates(connection_id)

    result = eid
    return true

  return result