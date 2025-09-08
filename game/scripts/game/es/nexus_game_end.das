require app
require ecs
require DngNet
require game.es.message_queue_common
require game.es.nexus_common
require game.es.nexus_game_end_common
require game.events.events_active_matter
require active_matter.game.es.objectives.objective_common


def game_end(cur_time : float;
             delay_after_game_end : float;
             var nexus_game_end__state : int&;
             var nexus_game_end__stateEndAt : float&)
  nexus_game_end__state = int(NexusGameEndState.GameEnded)
  nexus_game_end__stateEndAt = cur_time + delay_after_game_end
  nexus_log("GAME END", "Game ended")


def start_debriefing(cur_time : float;
                     debriefing_time : float;
                     var nexus_game_end__state : int&;
                     var nexus_game_end__stateEndAt : float&)
  nexus_game_end__state = int(NexusGameEndState.Debriefing)
  nexus_game_end__stateEndAt = cur_time + debriefing_time
  broadcast_net_event(EventNexusGameDebriefing())
  nexus_log("GAME END", "Game debriefing")


def end_session(var nexus_game_end__state : int&;
                var nexus_game_end__stateEndAt : float&)
  nexus_game_end__state = int(NexusGameEndState.SessionEnded)
  nexus_game_end__stateEndAt = -1.0
  nexus_log("GAME END", "Session ended")
  exit_game("Nexus session finished")


def request_clients_leave(cur_time : float;
                          clients_leave_time : float;
                          var nexus_game_end__state : int&;
                          var nexus_game_end__stateEndAt : float&)
  nexus_game_end__state = int(NexusGameEndState.ClientsLeave)
  nexus_game_end__stateEndAt = cur_time + clients_leave_time
  nexus_log("GAME END", "Requesting clients to leave")


[es(tag=server)]
def nexus_game_end_init(evt : EventNexusGameEnd;
                        nexus_game_end__delayAfterGameEnd : float;
                        nexus_game_end__debriefingTime : float;
                        nexus_game_end__clientsLeaveTime : float;
                        var nexus_game_end__state : int&;
                        var nexus_game_end__stateEndAt : float&;
                        var nexus_game_end__winnerTeam : int&)
  nexus_log("GAME END", "Game ended with winner={evt.winner}")
  nexus_game_end__winnerTeam = evt.winner
  let curTime = get_sync_time()
  if nexus_game_end__delayAfterGameEnd > 0.0
    nexus_game_end__state = int(NexusGameEndState.GameEnded)
    nexus_game_end__stateEndAt = curTime + nexus_game_end__delayAfterGameEnd
    broadcastEvent(EventNexusGameWaitForDebriefing())
  elif nexus_game_end__debriefingTime > 0.0
    start_debriefing(curTime, nexus_game_end__debriefingTime, nexus_game_end__state, nexus_game_end__stateEndAt)
  elif nexus_game_end__clientsLeaveTime > 0.0
    request_clients_leave(curTime, nexus_game_end__clientsLeaveTime, nexus_game_end__state, nexus_game_end__stateEndAt)
  else
    end_session(nexus_game_end__state, nexus_game_end__stateEndAt)


[es(tag=server, no_order)]
def nexus_game_end_state_update(act : UpdateStageInfoAct;
                                nexus_game_end__debriefingTime : float;
                                nexus_game_end__clientsLeaveTime : float;
                                var nexus_game_end__state : int&;
                                var nexus_game_end__stateEndAt : float&)
  if nexus_game_end__stateEndAt < 0.0 || act.curTime < nexus_game_end__stateEndAt
    return

  if nexus_game_end__state == int(NexusGameEndState.GameEnded)
    start_debriefing(act.curTime, nexus_game_end__debriefingTime, nexus_game_end__state, nexus_game_end__stateEndAt)
  elif nexus_game_end__state == int(NexusGameEndState.Debriefing)
    request_clients_leave(act.curTime, nexus_game_end__clientsLeaveTime, nexus_game_end__state, nexus_game_end__stateEndAt)
  elif nexus_game_end__state == int(NexusGameEndState.ClientsLeave)
    end_session(nexus_game_end__state, nexus_game_end__stateEndAt)
  else
    nexus_logerr("GAME END", "Invalid state({nexus_game_end__state}) for update")


[es(tag=server, REQUIRE=nexus_player)]
def nexus_game_end_remove_militants_on_debriefing(evt : EventNexusGameDebriefing;
                                                  var possessed : EntityId&)
  destroyEntity(possessed)
  possessed = INVALID_ENTITY_ID


[es(tag=server, REQUIRE=nexus_player, REQUIRE_NOT=playerIsBot)]
def nexus_game_end_send_game_result(evt : EventNexusGameEnd;
                                    eid : EntityId;
                                    userid : uint64;
                                    team : int)
  let data <- get_player_nexus_result_data(eid, team, evt.winner, evt.time)
  nexus_log("GAME END", "Result: {data}")
  if has_network()
    sendToProfileServer("apply_nexus_result", userid, data)
