require ecs
require level
require DngNet
require player
require DngActor
require DagorSystem
require DagorDataBlock
require game.utils.net_utils
require game.events.dng_events
require game.events.events_game
require game.events.player_events
require game.es.player.player_connect_common


[es(tag=server)]
def server_prepare_player_for_connected_client(evt : EventOnClientConnected)
  if !is_player_allow_connect(evt.clientFlags)
    print("[Client Connection] Connecting for connection #{evt.connectionId} is forbidded.")
    disconnect_connection(evt.connectionId)
    return

  var playerEid = try_reconnect_player(evt.connectionId, evt.userId)
  let isReconnected = playerEid != INVALID_ENTITY_ID

  if isReconnected && !is_player_allow_reconnect(playerEid, evt.clientFlags)
    print("[Client Connection] Disconnecting player <{playerEid}> connection #{evt.connectionId}. Reconnect not allowed.")
    disconnect_connection(evt.connectionId)
    return
  elif !isReconnected
    var playerTemplateName = dgs_get_settings() |> datablock_getStr("playerTemplateName", "common_player")
    query() <| $ [es] (player_template__override : string)
      playerTemplateName = player_template__override

    playerEid = createEntity(playerTemplateName) <| $(var init)
      init |> set("connid", evt.connectionId)
      init |> set("name", evt.userName)
      init |> set("userid", evt.userId)
      init |> set("possessed", INVALID_ENTITY_ID)
      init |> set("groupId", evt.groupId)
      init |> set("platformUid", evt.platformUserId)
      init |> set("platform", evt.platformId)
      init |> set("appId", evt.appId)

  // we want call some code on player entity, that already created (reconnect) or not (firts connect)
  sendEvent(playerEid, FinalizePlayerPreparing(matchingTeam = evt.matchingTeam, clientFlags = evt.clientFlags, isReconnected = isReconnected))


[es(tag=server, on_appear, REQUIRE=player)]
def server_start_player_preparing(evt : Event;
                                  eid : EntityId;
                                  connid : int;
                                  player__canBeLocal : bool;
                                  var replication : NetObject?)
  var clientConnection = get_client_connection(connid)
  if clientConnection != null
    *clientConnection |> connection_setUserEid(eid)
    broadcastEventImmediate(PlayerResetQuitGameTimer()) // reset only if actual human player is connected
    base_phys_actor_resizeSyncStates(connid)
    if replication != null
      *replication |> net_object_setControlledBy(connid)
  else // offline launch?
    if player__canBeLocal && get_local_player_eid() == INVALID_ENTITY_ID
      set_local_player_eid(eid)

  // limit number of player records
  var totalPlayersInGame = 0
  query() <| $ [es(REQUIRE=(player, possessed))] ()
    ++totalPlayersInGame
  find_query() <| $ [es(REQUIRE=(player, possessed))] (eid : EntityId; disconnected : bool)
    let NET_MAX_PLAYERS = get_NET_MAX_PLAYERS()
    if disconnected && totalPlayersInGame > NET_MAX_PLAYERS
      destroyEntity(eid)
      --totalPlayersInGame
    return totalPlayersInGame <= NET_MAX_PLAYERS


[es(tag=gameClient, on_appear, REQUIRE=player)]
def client_start_player_preparing(evt : Event; var replication : NetObject?)
  let serverConnection = get_server_conn()
  if serverConnection != null && replication != null
    *replication |> net_object_setControlledBy(connection_getId(*serverConnection))


[es(tag=server)]
def server_finalize_player_preparing(evt : FinalizePlayerPreparing;
                                     eid : EntityId;
                                     connid : int;
                                     var clientNetFlags : int&)
  var connection = get_client_connection(connid)
  let flagsToKeep = int(ClientNetFlags.CNF_SPAWNED_AT_LEAST_ONCE) | int(ClientNetFlags.CNF_RECONNECT_FORBIDDEN)
  clientNetFlags = ((clientNetFlags & flagsToKeep) | int(evt.clientFlags))

  if connection != null
    verify(*connection |> setEntityInScopeAlways(eid))
    send_net_event(eid, SetLocalPlayerMsg(), target_entity_conn(eid))

  // Use sendEventImmediate in order to assign team to the player immediately after creation
  sendEventImmediate(eid, EventOnPlayerConnected(spawnPlaceId = evt.matchingTeam, reconnected = evt.isReconnected))
