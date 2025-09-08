options no_aot
require app
require DagorSystem
require DagorDebug3D
require game.events.events_active_matter
require game.es.net_console_macro
require game.es.nexus_common
require game.es.nexus_game_start_common
require game.es.nexus_game_end_common
require game.es.message_queue_common
require active_matter.game.es.objectives.objective_common


def team_win(team_id : int)
  broadcast_net_event(EventNexusGameEnd(winner = team_id, time = get_sync_time()))


[net_console_cmd(name="nexus.game_start")]
def nexus_game_start_cmd()
  find_query() <| $ [es] (var nexus_game_start__state : int&;
                          var nexus_game_start__stateEndAt : float&)
    if nexus_game_start__state == int(NexusGameStartState.Started) || nexus_game_start__state == int(NexusGameStartState.Aborted)
      return true

    nexus_game_start__state = int(NexusGameStartState.WarmUp)
    nexus_game_start__stateEndAt = get_sync_time()
    return true


[net_console_cmd(name="nexus.set_current_game_start_state_time")]
def nexus_game_start_set_current_state_time_cmd(time : float = 10000.0)
  find_query() <| $ [es] (nexus_game_start__state : int;
                          var nexus_game_start__stateEndAt : float&)
    if nexus_game_start__state == int(NexusGameStartState.Started) || nexus_game_start__state == int(NexusGameStartState.Aborted)
      return true
    nexus_game_start__stateEndAt = get_sync_time() + time
    return true


[net_console_cmd(name="nexus.game_win_hero")]
def nexus_game_hero_win_cmd(@net_hero eid : EntityId)
  team_win(get_int(eid, "team") ?? TEAM_UNASSIGNED)


[net_console_cmd(name="nexus.game_win_team")]
def nexus_team_win_cmd(team_id : int)
  team_win(team_id)


[net_console_cmd(name="nexus.result_simulate")]
def nexus_simulate_result(@net_player player_eid : EntityId)
  query(player_eid) <| $ [es] (team : int)
    let data <- get_player_nexus_result_data(player_eid, team, team, get_sync_time())
    let fileName = "nexus_result.json"
    sendJsonToFile(fileName, data)
