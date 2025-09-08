require ecs
require ecs.common
require player
require DngNet
require game.es.nexus_common
require game.events.events_game
require game.events.events_active_matter
require active_matter.game.es.nexus_round_mode_common


[es(tag=gameClient, REQUIRE=(nexus_player))]
def nexus_assistant_comment_on_game_finish(evt : EventNexusGameEnd;
                                           eid : EntityId;
                                           is_local : bool;
                                           team : int)
  if !is_local
    return

  var scriptName = ""
  if evt.winner == TEAM_UNASSIGNED
    scriptName = "nexus_game_draw"
  elif evt.winner == team
    scriptName = "nexus_game_win"
  else
    scriptName = "nexus_game_lose"
  sendEvent(eid, CmdStartAssistantSpeak(scriptName = scriptName, skipBeepSound = true))


[es(tag=gameClient, REQUIRE=(nexus_player, nexus_round_mode))]
def nexus_assistant_comment_on_round_finish(evt : EventNexusRoundModeRoundFinished;
                                            eid : EntityId;
                                            is_local : bool;
                                            team : int)
  if !is_local
    return

  let isWinner = evt.winnerTeam == team
  var scriptName = ""
  if evt.reason == int(NexusRoundFinishReason.TEAM_DIED)
    scriptName = isWinner ? "nexus_round_win_team_died" : "nexus_round_lose_team_died"
  elif evt.reason == int(NexusRoundFinishReason.CAPTURE)
    scriptName = isWinner ? "nexus_round_win_capture" : "nexus_round_lose_capture"
  elif evt.reason == int(NexusRoundFinishReason.CAPTURE_ADVANTAGE)
    scriptName = isWinner ? "nexus_round_win_capture_advantage" : "nexus_round_lose_capture_advantage"
  elif evt.reason == int(NexusRoundFinishReason.POINTS)
    scriptName = isWinner ? "nexus_round_win_points" : "nexus_round_lose_points"
  elif evt.reason == int(NexusRoundFinishReason.POINTS_ADVANTAGE)
    scriptName = isWinner ? "nexus_round_win_points_advantage" : "nexus_round_lose_points_advantage"
  elif evt.reason == int(NexusRoundFinishReason.ALL_DIED)
    scriptName = "nexus_round_draw_all_died"
  elif evt.reason == int(NexusRoundFinishReason.POINTS_DRAW)
    scriptName = "nexus_round_draw_points"
  elif evt.reason == int(NexusRoundFinishReason.TIME_OUT)
    scriptName = "nexus_round_draw_time_out"
  sendEvent(eid, CmdStartAssistantSpeak(scriptName = scriptName, skipBeepSound = true))


[es(tag=gameClient, REQUIRE=(nexus_player, nexus_round_mode), on_event=(EventNexusGameStart, EventNexusRoundModeRoundChange))]
def nexus_assistant_comment_on_round_preparation(evt : Event;
                                                 eid : EntityId;
                                                 is_local : bool)
  if !is_local
    return
  sendEvent(eid, CmdStartAssistantSpeak(scriptName = "nexus_round_preparation", skipBeepSound = true))


[es(tag=gameClient, REQUIRE=(nexus_player, nexus_round_mode))]
def nexus_assistant_comment_on_round_started(evt : EventNexusRoundModeRoundStarted;
                                             eid : EntityId;
                                             is_local : bool)
  if !is_local
    return
  sendEvent(eid, CmdStartAssistantSpeak(scriptName = "nexus_round_start", skipBeepSound = true))


[es(tag=gameClient, REQUIRE=(nexus_militant, nexus_round_mode))]
def nexus_assistant_comment_on_last_standing_in_round(evt : EventEntityDied;
                                                      team aka victim_team : int)
  let teammates = get_teammates(victim_team)
  if length(teammates) != 1
    return

  let isHero = has(teammates[0], "hero")
  let localPlayerEid = get_local_player_eid()
  var scriptName = ""
  query(localPlayerEid) <| $ [es] (team : int)
    if isHero
      scriptName = "nexus_last_standing_you"
    elif team == victim_team
      scriptName = "nexus_last_standing_ally"
    else
      scriptName = "nexus_last_standing_enemy"
  sendEvent(localPlayerEid, CmdStartAssistantSpeak(scriptName = scriptName, skipBeepSound = true))


[es(tag=gameClient, REQUIRE=nexus_history_beacon_capture, on_appear)]
def nexus_assistant_comment_on_beacon_capture(evt : Event;
                                              nexus_history__participants : EidList;
                                              nexus_history__team : int)
  let localPlayerEid = get_local_player_eid()
  let isHero = nexus_history__participants |> find_index(localPlayerEid) != -1
  var scriptName = ""
  query(localPlayerEid) <| $ [es] (team : int)
    if isHero
      scriptName = "nexus_you_captured_beacon"
    elif team == nexus_history__team
      scriptName = "nexus_ally_captured_beacon"
    else
      scriptName = "nexus_enemy_captured_beacon"
  sendEvent(localPlayerEid, CmdStartAssistantSpeak(scriptName = scriptName, skipBeepSound = true))


[es(tag=gameClient, REQUIRE=nexus_history_beacon_reset, on_appear)]
def nexus_assistant_comment_on_beacon_reseted(evt : Event;
                                              nexus_history__participants : EidList;
                                              nexus_history__team : int)
  let localPlayerEid = get_local_player_eid()
  let isHero = nexus_history__participants |> find_index(localPlayerEid) != -1
  var scriptName = ""
  query(localPlayerEid) <| $ [es] (team : int)
    if isHero
      scriptName = "nexus_you_reseted_beacon"
    elif team == nexus_history__team
      scriptName = "nexus_ally_reseted_beacon"
    else
      scriptName = "nexus_enemy_reseted_beacon"
  sendEvent(localPlayerEid, CmdStartAssistantSpeak(scriptName = scriptName, skipBeepSound = true))
