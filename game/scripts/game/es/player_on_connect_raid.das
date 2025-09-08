require app
require ecs
require DngNet
require DagorSystem
require DagorDataBlock
require game.utils.team
require game.es.ecs_common
require game.es.level_common
require game.events.player_events
require game.events.events_game
require game.events.events
require game.es.player.player_connect_common
require game.es.player_common


[es(tag=server, REQUIRE=player, before=player_team_selection_in_raid)]
def server_process_rented_equpment_connection_debug(evt : EventOnPlayerConnected;
                                                    var player__isRentedEquipment : bool&)
  if !is_raid_mode()
    return

  dgs_get_settings() |> datablock_get_block("debug") <| $(blk)
    if blk |> datablock_getBool("playWithRentedEquipment", false)
      player__isRentedEquipment = true


[es(REQUIRE=player)]
def player_team_selection_in_raid(evt : EventOnPlayerConnected;
                                  eid aka this_player_eid : EntityId;
                                  groupId aka this_player_groupId : int64;
                                  var team aka this_player_team, player__spawnPlaceId : int&;
                                  var player__teamEid aka this_player__teamEid : EntityId&;
                                  connid : int = INVALID_CONNECTION_ID)
  if !is_player_session()
    return

  player__spawnPlaceId = evt.spawnPlaceId

  if this_player_team != TEAM_UNASSIGNED
    find_query() <| $ [es] (eid : EntityId; team__id : int)
      if this_player_team == team__id
        this_player__teamEid = eid
        return true
      return false
    if this_player__teamEid != INVALID_ENTITY_ID
      print("[PLAYER_CONNECTED] Player <{get_player_info(this_player_eid)}> come with predefined team id <{this_player_team}> and assign to team eid <{this_player__teamEid}>.")
    else
      logerr("[PLAYER_CONNECTED] Player <{get_player_info(this_player_eid)}> come with predefined team id <{this_player_team}> but teams with this ID does not exist.")
      disconnect_connection(connid)
      return

  if this_player__teamEid == INVALID_ENTITY_ID
    find_query() <| $ [es(REQUIRE=player)] (eid, player__teamEid : EntityId; team : int; groupId : int64)
      if eid != this_player_eid && groupId == this_player_groupId && player__teamEid != INVALID_ENTITY_ID
        this_player_team = team
        this_player__teamEid = player__teamEid
        print("[PLAYER_CONNECTED] Team <{team}> has been set for player <{get_player_info(this_player_eid)}> because that's what his groupmates with eid <{eid}> have.")
        return true
      return false

  if this_player__teamEid == INVALID_ENTITY_ID
    find_query() <| $ [es] (am_teams__players : string)
      this_player__teamEid = create_new_raid_team(am_teams__players, evt.spawnPlaceId)
      print("[PLAYER_CONNECTED] New team {get_entity_info(this_player__teamEid)} has been created for player <{get_player_info(this_player_eid)}>.")
      return true

  if this_player__teamEid == INVALID_ENTITY_ID
    logerr("[PLAYER_CONNECTED] Player <{get_player_info(this_player_eid)}> can't find team at all!")
    disconnect_connection(connid)
    return

  query(this_player__teamEid) <| $ [es] (team__id : int; var team__memberEids : EidList)
    team__memberEids |> push(this_player_eid)
    this_player_team = team__id
    print("[PLAYER_CONNECTED] Player <{get_player_info(this_player_eid)}>. Team info:
{get_team_players_info(team__id)}")


  if connid != INVALID_CONNECTION_ID && get_client_connection(connid) != null
    broadcastEventImmediate(CmdAddEntityInNetScope(connid = connid, entityEid = this_player__teamEid))


[es(on_appear, tag=server, REQUIRE=playerIsBot)]
def server_bot_player_register_in_team(evt : Event; eid aka player_eid : EntityId; team : int)
  find_query() <| $ [es(REQUIRE=bot_team)] (team__id : int; var team__memberEids : EidList)
    if team__id != team
      return false
    push(team__memberEids, player_eid)
    return true


[es(tag=server, REQUIRE=eid, on_event=(EventOnPlayerConnected, EventOnClientDisconnected), after=event_on_client_disconnected)]
def server_player_connect_disconnect_log(evt : Event)
  if !is_player_session()
    return

  var totalPlayers = 0
  var totalDisconnected = 0
  var totalBots = 0
  query() <| $ [es(REQUIRE=player)] (playerIsBot : Tag const?; disconnected = false)
    ++totalPlayers
    totalDisconnected += disconnected ? 1 : 0
    totalBots += playerIsBot != null ? 1 : 0

  print("[PLAYER_CONNECTED] There are <{totalPlayers}> players in session (<{totalBots}> bots, <{totalDisconnected}> disconnected)")
