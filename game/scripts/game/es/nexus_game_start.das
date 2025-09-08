require app
require ecs
require rapidjson
require DngNet
require game.es.nexus_common
require game.es.game_end_reasons_common
require game.es.endgame_common
require game.es.nexus_game_start_common
require game.events.events_active_matter


def abort_game(cur_time : float;
               var nexus_game_start__state : int&;
               var nexus_game_start__stateEndAt : float&)
  nexus_game_start__state = int(NexusGameStartState.Aborted)
  nexus_game_start__stateEndAt = -1.0f
  nexus_log("GAME START", "Aborting (current_time={cur_time})")
  find_query() <| $ [es] (nexus_players_controller__players : EidList)
    for playerEid in nexus_players_controller__players
      query(playerEid) <| $ [es] (team : int)
        send_player_endgame_result(team, playerEid, false, int(GameEndReasons.TIME_OUT), true)
    return true
  createEntity("nexus_battle_session_finisher")


def start_waiting(cur_time : float;
                  nexus_game_start__waitForLastPlayerTime : float;
                  var nexus_game_start__state : int&;
                  var nexus_game_start__stateEndAt : float&)
  nexus_game_start__state = int(NexusGameStartState.WaitingForPlayers)
  nexus_game_start__stateEndAt = cur_time + nexus_game_start__waitForLastPlayerTime
  broadcastEvent(EventNexusWaitingForEnoughPlayers())
  nexus_log("GAME START", "Wating for enough players until {nexus_game_start__stateEndAt} (current_time={cur_time}; duration={nexus_game_start__waitForLastPlayerTime})")


def start_warm_up(cur_time : float;
                  nexus_game_start__warmUpMaxTime : float;
                  var nexus_game_start__state : int&;
                  var nexus_game_start__stateEndAt : float&)
  let warmUpEndLimitAt = cur_time + nexus_game_start__warmUpMaxTime
  if nexus_game_start__state == int(NexusGameStartState.WaitingForPlayers)
    nexus_game_start__stateEndAt = min(nexus_game_start__stateEndAt, warmUpEndLimitAt)
  else
    nexus_game_start__stateEndAt = warmUpEndLimitAt
  nexus_game_start__state = int(NexusGameStartState.WarmUp)
  broadcastEvent(EventNexusWarmUp())
  nexus_log("GAME START", "Warm Up until {nexus_game_start__stateEndAt} (current_time={cur_time}; duration={nexus_game_start__stateEndAt - cur_time})")


def start_game(cur_time : float;
               var nexus_game_start__state : int&;
               var nexus_game_start__stateEndAt : float&)
  nexus_game_start__state = int(NexusGameStartState.Started)
  nexus_game_start__stateEndAt = -1.0f
  broadcast_net_event(EventNexusGameStart())
  nexus_log("GAME START", "Starting (current_time={cur_time})")


def enough_players_connected(cur_time : float;
                             nexus_game_start__warmUpMaxTime : float;
                             var nexus_game_start__state : int&;
                             var nexus_game_start__stateEndAt : float&)
  nexus_log("GAME START", "All needed players connected")
  if nexus_game_start__warmUpMaxTime > 0.0
    start_warm_up(cur_time, nexus_game_start__warmUpMaxTime, nexus_game_start__state, nexus_game_start__stateEndAt)
  else
    start_game(cur_time, nexus_game_start__state, nexus_game_start__stateEndAt)


[es(tag=server, on_appear)]
def nexus_game_start_if_enough_players_are_already_connected(evt : Event;
                                                             nexus_game_start__numPlayersLeftToStart : int;
                                                             nexus_game_start__warmUpMaxTime : float;
                                                             var nexus_game_start__state : int&;
                                                             var nexus_game_start__stateEndAt : float&)
  if nexus_game_start__numPlayersLeftToStart == 0
    enough_players_connected(get_sync_time(), nexus_game_start__warmUpMaxTime, nexus_game_start__state, nexus_game_start__stateEndAt)
    return


[es(tag=server, after=nexus_game_start_if_enough_players_are_already_connected, on_appear)]
def nexus_game_start_init_wait_for_last_player_time(evt : Event;
                                                    nexus_game_start__botWaitTime : float;
                                                    var nexus_game_start__jipTime : float&;
                                                    var nexus_game_start__waitForLastPlayerTime : float&)
  var jipEnableTime = json_get_or(get_matching_invite_data(), "jipEnableTime", 0.0)
  if jipEnableTime == 0.0
    jipEnableTime = float(json_get_or(get_matching_invite_data(), "jipEnableTime", 0))

  get_matching_invite_data() |> FindMember("mode_info", JsonType.kObjectType) <| $(modeinfo : JsonValue)
    modeinfo |> FindMember("teams", JsonType.kArrayType) <| $(teams : JsonValue)
      teams |> GetArray() <| $(teamsArray : JsonConstArray)
        for team in teamsArray
          var teamJip = json_get_or(team, "jipEnableTime", 0.0)
          if teamJip == 0.0
            teamJip = float(json_get_or(team, "jipEnableTime", 0))
          jipEnableTime = max(jipEnableTime, teamJip)

  nexus_game_start__jipTime = jipEnableTime
  nexus_game_start__waitForLastPlayerTime = nexus_game_start__jipTime + nexus_game_start__botWaitTime
  nexus_log("GAME START", "Waiting for last player duration inited = {nexus_game_start__waitForLastPlayerTime} (jipEnableTime={jipEnableTime}; botWaitTime={nexus_game_start__botWaitTime})")


[es(track=nexus_players_controller__numPlayersConnected)]
def nexus_start_waiting_if_someone_is_connected(evt : Event;
                                                nexus_players_controller__numPlayersConnected : int)
  if nexus_players_controller__numPlayersConnected == 0
    return
  find_query() <| $ [es] (nexus_game_start__waitForLastPlayerTime : float;
                          var nexus_game_start__state : int&;
                          var nexus_game_start__stateEndAt : float&)
    if nexus_game_start__state == -1
      start_waiting(get_sync_time(), nexus_game_start__waitForLastPlayerTime, nexus_game_start__state, nexus_game_start__stateEndAt)
    return true


[es(on_appear)]
def nexus_game_start_init_num_players_need_to_start_by_count(evt : Event;
                                                             nexus_game_start__playersCountToStart : int;
                                                             var nexus_game_start__numPlayersNeedToStart : int&)
  nexus_game_start__numPlayersNeedToStart = nexus_game_start__playersCountToStart
  nexus_log("GAME START", "Players need to start = {nexus_game_start__numPlayersNeedToStart}")


[es(tag=server, no_order)]
def nexus_game_start_state_update(act : UpdateStageInfoAct;
                                  nexus_game_start__numPlayersLeftToStart : int;
                                  nexus_game_start__startAfterWaitWithInsufficientPlayers : bool;
                                  var nexus_game_start__state : int&;
                                  var nexus_game_start__stateEndAt : float&)
  if nexus_game_start__stateEndAt < 0.0 || act.curTime < nexus_game_start__stateEndAt
    return

  if nexus_game_start__state == int(NexusGameStartState.WaitingForPlayers)
    nexus_log("GAME START", "Waiting time out (players_left_to_start={nexus_game_start__numPlayersLeftToStart}; start_with_insufficient_players={nexus_game_start__startAfterWaitWithInsufficientPlayers};)")
    let shouldStartGame = nexus_game_start__numPlayersLeftToStart == 0 || nexus_game_start__startAfterWaitWithInsufficientPlayers
    if shouldStartGame
      nexus_log("GAME START", "Proceed anyway")
      start_game(act.curTime, nexus_game_start__state, nexus_game_start__stateEndAt)
    else
      nexus_log("GAME START", "Not enough players to start game")
      abort_game(act.curTime, nexus_game_start__state, nexus_game_start__stateEndAt)
  elif nexus_game_start__state == int(NexusGameStartState.WarmUp)
    start_game(act.curTime, nexus_game_start__state, nexus_game_start__stateEndAt)
  else
    nexus_logerr("GAME START", "Invalid state({nexus_game_start__state}) for update")


[es(tag=server, track=nexus_game_start__numPlayersLeftToStart)]
def nexus_game_start_on_enough_players_connected_for_play(evt : Event;
                                                          nexus_game_start__numPlayersLeftToStart : int;
                                                          nexus_game_start__warmUpMaxTime : float;
                                                          var nexus_game_start__state : int&;
                                                          var nexus_game_start__stateEndAt : float&)
  if nexus_game_start__state > int(NexusGameStartState.WaitingForPlayers)
    return
  if nexus_game_start__numPlayersLeftToStart == 0
    enough_players_connected(get_sync_time(), nexus_game_start__warmUpMaxTime, nexus_game_start__state, nexus_game_start__stateEndAt)


[es(track=nexus_players_controller__numPlayersExpected)]
def nexus_game_start_update_num_players_need_to_start(evt : Event;
                                                      nexus_players_controller__numPlayersExpected : int)
  find_query() <| $ [es] (nexus_game_start__state : int;
                          nexus_game_start__playersProportionToStart : float;
                          var nexus_game_start__numPlayersNeedToStart : int&)
    if nexus_game_start__state > int(NexusGameStartState.WaitingForPlayers)
      return true
    nexus_game_start__numPlayersNeedToStart = (float(nexus_players_controller__numPlayersExpected) * nexus_game_start__playersProportionToStart) |> ceil() |> int()
    nexus_log("GAME START", "Players need to start = {nexus_game_start__numPlayersNeedToStart}")
    return true


[es(track=nexus_game_start__numPlayersNeedToStart)]
def nexus_game_start_update_players_left_to_start_on_requirements_changed(evt : Event;
                                                                          nexus_game_start__state : int;
                                                                          nexus_game_start__numPlayersNeedToStart : int;
                                                                          var nexus_game_start__numPlayersLeftToStart : int&)
  if nexus_game_start__state > int(NexusGameStartState.WaitingForPlayers)
    return
  find_query() <| $ [es] (nexus_players_controller__numPlayersConnected : int)
    nexus_game_start__numPlayersLeftToStart = max(0, nexus_game_start__numPlayersNeedToStart - nexus_players_controller__numPlayersConnected)
    nexus_log("GAME START", "Players left to start = {nexus_game_start__numPlayersLeftToStart}")
    return true


[es(track=nexus_players_controller__numPlayersConnected)]
def nexus_game_start_update_players_left_to_start_on_connected_count_changed(evt : Event;
                                                                             nexus_players_controller__numPlayersConnected : int)
  find_query() <| $ [es] (nexus_game_start__state : int;
                          nexus_game_start__numPlayersNeedToStart : int;
                          var nexus_game_start__numPlayersLeftToStart : int&)
    if nexus_game_start__state > int(NexusGameStartState.WaitingForPlayers)
      return true
    nexus_game_start__numPlayersLeftToStart = max(0, nexus_game_start__numPlayersNeedToStart - nexus_players_controller__numPlayersConnected)
    nexus_log("GAME START", "Players left to start = {nexus_game_start__numPlayersLeftToStart}")
    return true
