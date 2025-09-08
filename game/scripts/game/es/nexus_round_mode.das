require app
require ecs
require ecs.common
require math.random
require DngNet
require player
require rapidjson
require DagorSystem
require game.es.nexus_common
require game.es.nexus_history_common
require game.es.nexus_beacon_common
require game.es.nexus_round_mode_common
require game.es.game_end_reasons_common
require game.es.endgame_common
require game.events.player_events
require game.events.dng_events
require game.events.events_game
require game.events.events_active_matter
require matching
require player
require game.utils.net_utils
require DagorDataBlock


def finish_game(winner : int;
                time : float)
  find_query() <| $ [es] (var nexus_game_controller__isGameFinished : bool&)
    if nexus_game_controller__isGameFinished
      return true
    broadcast_net_event(EventNexusGameEnd(winner = winner, time = time))
    nexus_game_controller__isGameFinished = true
    return true


def finish_round(winner : int;
                 reason : int;
                 time : float)
  find_query() <| $ [es] (var nexus_round_mode_game_controller__roundState : int&)
    if nexus_round_mode_game_controller__roundState != int(NexusRoundState.Started)
      return true
    broadcast_net_event(EventNexusRoundModeRoundFinished(winnerTeam = winner, reason = reason, time = time))
    nexus_round_mode_game_controller__roundState = int(NexusRoundState.Finished)
    return true


def speed_up_points_tick_time()
  find_query() <| $ [es] (nexus_round_mode_game_controller__pointsTickTimeFast : float;
                          var nexus_round_mode_game_controller__pointsTickTime : float&)
    nexus_round_mode_game_controller__pointsTickTime = nexus_round_mode_game_controller__pointsTickTimeFast
    return true


def change_team_points(team_eid : EntityId;
                       points : float;
                       points_to_win : float;
                       update_display_points : bool = false)
  var resultPoints = 0.0
  var overflow = 0.0
  query(team_eid) <| $ [es] (var nexus_round_mode_team__points : float&;
                             var nexus_round_mode_team__displayPoints : float&)
    nexus_round_mode_team__points += points

    if nexus_round_mode_team__points > points_to_win
      overflow = nexus_round_mode_team__points - points_to_win
      nexus_round_mode_team__points = points_to_win
    elif nexus_round_mode_team__points < 0.0
      overflow = nexus_round_mode_team__points
      nexus_round_mode_team__points = 0.0

    resultPoints = nexus_round_mode_team__points
    if update_display_points
      nexus_round_mode_team__displayPoints = nexus_round_mode_team__points
  return resultPoints, overflow


def get_points_to_add(points : float;
                      beacons_count : int;
                      sqrt_scaling : bool)
  if sqrt_scaling
    return sqrt(float(beacons_count)) * points
  return float(beacons_count) * points


def get_points_to_add_by_advantage(points : float;
                                   greater_beacons_count : int;
                                   lesser_beacons_count : int;
                                   sqrt_scaling : bool;
                                   advantage_by_beacons : bool)

  if advantage_by_beacons
    let beaconsDifference = greater_beacons_count - lesser_beacons_count
    return get_points_to_add(points, beaconsDifference, sqrt_scaling)

  let greaterPointsToAdd = get_points_to_add(points, greater_beacons_count, sqrt_scaling)
  let lesserPointsToSubtract = get_points_to_add(points, lesser_beacons_count, sqrt_scaling)
  return greaterPointsToAdd - lesserPointsToSubtract


def is_there_any_progress_in_points(team_one_beacons_count : int;
                                    team_two_beacons_count : int)
  var teamOneProgress = false
  var teamTwoProgress = false
  find_query() <| $ [es(REQUIRE=(nexus_game_controller, nexus_round_mode))] (nexus_round_mode_points_direct : Tag const?;
                                                                             nexus_round_mode_points_advantage : Tag const?;
                                                                             nexus_round_mode_points_advantage_equality_scoring : Tag const?)

    if nexus_round_mode_points_direct != null
      teamOneProgress = team_one_beacons_count != 0
      teamTwoProgress = team_two_beacons_count != 0
      return true
    elif nexus_round_mode_points_advantage != null
      if team_one_beacons_count != team_two_beacons_count
        teamOneProgress = team_one_beacons_count > team_two_beacons_count
        teamTwoProgress = team_two_beacons_count > team_one_beacons_count
        return true
      if team_one_beacons_count != 0 && team_two_beacons_count != 0 && nexus_round_mode_points_advantage_equality_scoring != null
        teamOneProgress = true
        teamTwoProgress = true
        return true
    return true
  return teamOneProgress, teamTwoProgress


def is_there_any_progress_in_points_for_team(team_beacons_count : int;
                                             enemy_team_beacons_count : int)
  var result = false
  find_query() <| $ [es(REQUIRE=(nexus_game_controller, nexus_round_mode))] (nexus_round_mode_points_direct : Tag const?;
                                                                             nexus_round_mode_points_advantage : Tag const?;
                                                                             nexus_round_mode_points_advantage_equality_scoring : Tag const?)
    if nexus_round_mode_points_direct != null
      result = team_beacons_count > 0
      return true
    if nexus_round_mode_points_advantage != null
      if team_beacons_count > enemy_team_beacons_count
        result = true
        return true
      if team_beacons_count == enemy_team_beacons_count && team_beacons_count != 0 && nexus_round_mode_points_advantage_equality_scoring != null
        result = true
        return true
    return true
  return result


def get_team_beacons_count(team : int)
  var teamBeaconsCount = 0
  find_query() <| $ [es] (team__id : int;
                          nexus_round_mode_team__capturedBeacons : EidList)
    if team != team__id
      return false
    teamBeaconsCount = length(nexus_round_mode_team__capturedBeacons)
    return true
  return teamBeaconsCount


def decide_winner_by_points(team_one_eid : EntityId;
                            team_two_eid : EntityId;
                            team_one_id : int;
                            team_two_id : int;
                            points_team_one : float;
                            points_team_two : float;
                            points_to_add_team_one : float;
                            points_to_add_team_two : float;
                            overflow_team_one : float;
                            overflow_team_two : float;
                            points_to_win : float)
  if points_team_one >= points_to_win && points_team_two >= points_to_win
    let overflowRatioTeamOne = overflow_team_one / points_to_add_team_one
    let overflowRatioTeamTwo = overflow_team_two / points_to_add_team_two

    if overflowRatioTeamOne > overflowRatioTeamTwo
      let pointsToSubtract = points_to_add_team_two * overflowRatioTeamOne
      change_team_points(team_two_eid, -pointsToSubtract, points_to_win)
      return team_one_id, false
    elif overflowRatioTeamOne < overflowRatioTeamTwo
      let pointsToSubtract = points_to_add_team_one * overflowRatioTeamTwo
      change_team_points(team_one_eid, -pointsToSubtract, points_to_win)
      return team_two_id, false
    else
      return TEAM_UNASSIGNED, true

  if points_team_one >= points_to_win
    return team_one_id, false
  if points_team_two >= points_to_win
    return team_two_id, false
  return TEAM_UNASSIGNED, false


def update_team_beacons(beacon_eid : EntityId;
                        team : int;
                        nexus_beacon__state : int;
                        nexus_beacon__controllingTeam : int;
                        var nexus_round_mode_team__capturedBeacons : EidList&)
  let isCaptured = nexus_beacon__controllingTeam == team && nexus_beacon__state == int(NexusBeaconState.CAPTURED)
  let index = find_index(nexus_round_mode_team__capturedBeacons, beacon_eid)
  if isCaptured && index == -1
    nexus_round_mode_team__capturedBeacons |> push(beacon_eid)
  elif !isCaptured && index != -1
    nexus_round_mode_team__capturedBeacons |> erase(index)


[es(tag=gameClient, REQUIRE=(nexus_player, nexus_round_mode))]
def nexus_round_mode_enable_spectator_on_spawn(evt : CmdNexusStartSpawnSequence;
                                               is_local : bool;
                                               var respawner__spectatorEnabled : bool&)
  if !is_local
    return

  respawner__spectatorEnabled = true
  find_query() <| $ [es(REQUIRE=static_cam)] (var camera__active : bool&)
    camera__active = false
    return true


[es(tag=gameClient, REQUIRE=(nexus_player, nexus_round_mode), on_appear, track=is_local)]
def nexus_round_mode_player_report_to_client_on_loaded(evt : Event;
                                                       is_local : bool;
                                                       eid aka player_eid : EntityId)
  if !is_local
    return

  send_net_event(player_eid, EventNexusPlayerLoaded())


[es(tag=server, REQUIRE=(nexus_player, nexus_round_mode), on_event=EventNexusPlayerLoaded)]
def nexus_round_mode_process_late_player(evt : Event;
                                         eid aka player_eid : EntityId)
  find_query() <| $ [es] (nexus_game_controller__isGameStarted : bool;
                          nexus_round_mode_game_controller__roundState : int)
    if !nexus_game_controller__isGameStarted
      return true

    if nexus_round_mode_game_controller__roundState == int(NexusRoundState.Started)
      send_net_event(player_eid, EnableSpectatorForPlayer(target = INVALID_ENTITY_ID), target_entity_conn(player_eid))
    return true


[es(tag=server, REQUIRE=(nexus_player, nexus_round_mode), on_event=(EventNexusGameStart, EventNexusRoundModeRoundChange), on_appear)]
def nexus_round_mode_lock_actions_for_player(evt : Event;
                                             eid aka player_eid : EntityId)
  find_query() <| $ [es] (nexus_game_controller__isGameStarted : bool;
                          nexus_round_mode_game_controller__roundState : int;
                          nexus_round_mode_lock_movement_before_round_start : Tag const?;
                          nexus_round_mode_lock_shooting_before_round_start : Tag const?)
    if nexus_round_mode_lock_movement_before_round_start == null && nexus_round_mode_lock_shooting_before_round_start == null
      return true
    if !nexus_game_controller__isGameStarted || (nexus_round_mode_game_controller__roundState != int(NexusRoundState.Preparation))
      return true
    if nexus_round_mode_lock_movement_before_round_start != null
      sendEvent(player_eid, CmdNexusLockMovementForPlayer())
    if nexus_round_mode_lock_shooting_before_round_start != null
      sendEvent(player_eid, CmdNexusLockShootingForPlayer())
    return true


[es(tag=server, REQUIRE=(nexus_player, nexus_round_mode))]
def nexus_round_mode_unlock_actions_for_player(evt : EventNexusRoundModeRoundStarted;
                                               eid aka player_eid : EntityId)
  find_query() <| $ [es(REQUIRE=(nexus_game_controller, nexus_round_mode))] (nexus_round_mode_lock_movement_before_round_start : Tag const?;
                                                                             nexus_round_mode_lock_shooting_before_round_start : Tag const?)
    if nexus_round_mode_lock_movement_before_round_start != null
      sendEvent(player_eid, CmdNexusUnlockMovementForPlayer())
    if nexus_round_mode_lock_shooting_before_round_start != null
      sendEvent(player_eid, CmdNexusUnlockShootingForPlayer())
    return true


[es(tag=server, REQUIRE_NOT=playerIsBot, REQUIRE=(nexus_player, nexus_round_mode), on_appear)]
def nexus_round_mode_player_choose_loadout_on_appear(evt : Event;
                                                     eid aka player_eid : EntityId;
                                                     var nexus_player_loadout__takenIndex : int&)
  send_net_event(player_eid, CmdNexusBattleSelectLoadout(loadoutIndex = nexus_player_loadout__takenIndex, selectAnyIfUnavailable = true))
  nexus_player_loadout__takenIndex = -1


[es(tag=server, REQUIRE=(nexus_player, nexus_round_mode, playerIsBot), on_appear, after=nexus_battle_create_bot_loadouts_on_appear)]
def nexus_round_mode_bot_player_choose_loadout_on_appear(evt : Event;
                                                         eid aka player_eid : EntityId;
                                                         var nexus_player_loadout__takenIndex : int&)
  find_query() <| $ [es] (nexus_loadouts__owner : EntityId;
                          nexus_loadouts__allLoadouts : Array)
    if nexus_loadouts__owner != player_eid
      return false
    let chosenLoadout = rnd_int(0, length(nexus_loadouts__allLoadouts) - 1)
    send_net_event(player_eid, CmdNexusBattleSelectLoadout(loadoutIndex = chosenLoadout, selectAnyIfUnavailable = true))
    nexus_player_loadout__takenIndex = -1
    return true


[es(tag=server, track=nexus_round_mode_game_controller__roundState)]
def nexus_round_mode_bot_players_schedule_spawn_on_round_preparation(evt : Event;
                                                                     nexus_round_mode_game_controller__roundStateEndAt : float;
                                                                     nexus_round_mode_game_controller__roundState : int)
  if nexus_round_mode_game_controller__roundState != int(NexusRoundState.Preparation)
    return

  let curTime = get_sync_time()
  let timeToSpawn = nexus_round_mode_game_controller__roundStateEndAt - curTime
  let spawnMinDelay = min(0.5, timeToSpawn)
  query() <| $ [es(REQUIRE=(nexus_player, nexus_round_mode, playerIsBot))] (eid aka player_eid : EntityId)
    let spawnDelay = rnd_float(spawnMinDelay, timeToSpawn)
    nexus_log("ROUND MODE", "Scheduling bot player <{player_eid}> spawn in {spawnDelay} seconds")
    addSubTemplate(player_eid, "nexus_round_mode_bot_player_delayed_spawn") <| $(var init)
      set(init, "nexus_round_mode_bot_player_delayed_spawn__spawnAt", curTime + spawnDelay)


[es(tag=server, no_order)]
def process_bot_player_delayed_spawn(upd : UpdateStageInfoAct;
                                     eid aka player_eid : EntityId;
                                     nexus_round_mode_bot_player_delayed_spawn__spawnAt : float)
  if upd.curTime < nexus_round_mode_bot_player_delayed_spawn__spawnAt
    return

  send_net_event(player_eid, RequestNexusSpawnPlayer())
  removeSubTemplate(player_eid, "nexus_round_mode_bot_player_delayed_spawn")


[es(tag=server, REQUIRE=(nexus_player, nexus_round_mode))]
def nexus_round_mode_try_spawn_player(evt : RequestNexusSpawnPlayer;
                                      eid aka player_eid : EntityId;
                                      nexus_player__spawned : bool)
  find_query() <| $ [es] (nexus_game_controller__spawnController : EntityId;
                          nexus_round_mode_game_controller__roundState : int)
    if nexus_round_mode_game_controller__roundState != int(NexusRoundState.Preparation) && !nexus_player__spawned
      return true
    sendEvent(nexus_game_controller__spawnController, CmdNexusSpawnPlayer(playerEid = player_eid, replaceForced = true, destroyPreviousPossessed = true))
    return true


[es(tag=server, REQUIRE=nexus_team, on_appear)]
def nexus_round_mode_team_init(evt : Event;
                               eid : EntityId;
                               nexus_round_mode_points : Tag const?)
  if is_points_mode() && nexus_round_mode_points == null
    nexus_log("ROUND MODE", "Add points template to team<{eid}>")
    addSubTemplate(eid, "nexus_round_mode_points_team")


[es(tag=server, REQUIRE=(nexus_game_controller, nexus_round_mode, nexus_round_mode_points), on_appear)]
def nexus_round_mode_points_init(evt : Event)
  nexus_log("ROUND MODE", "Init points game controller")
  query() <| $ [es(REQUIRE=nexus_team, REQUIRE_NOT=nexus_round_mode_points)] (eid : EntityId)
    nexus_log("ROUND MODE", "Add points template to team<{eid}>")
    addSubTemplate(eid, "nexus_round_mode_points_team")


[es(tag=server, REQUIRE=(nexus_game_controller, nexus_round_mode), REQUIRE_NOT=nexus_round_mode_points, on_appear)]
def nexus_round_mode_game_controller_init_type(evt : Event;
                                               eid : EntityId;
                                               nexus_round_mode_game_controller__defaultType : string)
  var nexusRoundModeType = ""
  get_matching_invite_data() |> FindMember("extraParams", JsonType.kObjectType) <| $(extraParams : JsonValue)
    if extraParams.IsNull
      nexusRoundModeType = nexus_round_mode_game_controller__defaultType
      nexus_log("ROUND MODE", "Enable game controller by default because 'extraParams' is null in matching invite data")
      return
    nexusRoundModeType = json_get_or(extraParams, "nexusRoundModeType", "")
    if empty(nexusRoundModeType)
      nexusRoundModeType = nexus_round_mode_game_controller__defaultType
      nexus_log("ROUND MODE", "Enable game controller by default because 'nexusRoundModeType' is missing in matching invite data")
    else
      nexus_log("ROUND MODE", "Enable game controller by matching data 'nexusRoundModeType':'{nexusRoundModeType}'")

  if empty(nexusRoundModeType)
    nexusRoundModeType = nexus_round_mode_game_controller__defaultType
    nexus_log("ROUND MODE", "Enable game controller by default because matching invite data is missing")

  if nexusRoundModeType == "points_direct"
    nexus_log("ROUND MODE", "Enable points_direct game controller")
    addSubTemplate(eid, "nexus_round_mode_points_game_controller+nexus_round_mode_points_direct")
  elif nexusRoundModeType == "points_advantage"
    nexus_log("ROUND MODE", "Enable points_advantage game controller")
    addSubTemplate(eid, "nexus_round_mode_points_game_controller+nexus_round_mode_points_advantage")
  elif nexusRoundModeType == "points_advantage_equality_scoring"
    nexus_log("ROUND MODE", "Enable points_advantage_equality_scoring game controller")
    addSubTemplate(eid, "nexus_round_mode_points_game_controller+nexus_round_mode_points_advantage+nexus_round_mode_points_advantage_equality_scoring")
  else
    nexus_logerr("ROUND MODE", "Invalid nexusRoundModeType")


[es(tag=server)]
def nexus_round_mode_points_start(evt : EventNexusGameStart;
                                  nexus_round_mode_game_controller__pointsTickTimeDefault : float;
                                  var nexus_round_mode_game_controller__pointsTickTime : float&)
  nexus_round_mode_game_controller__pointsTickTime = nexus_round_mode_game_controller__pointsTickTimeDefault


[es(tag=server)]
def nexus_round_mode_start(evt : EventNexusGameStart;
                           nexus_round_mode_game_controller__preparationTime : float;
                           var nexus_game_controller__isGameStarted : bool&;
                           var nexus_round_mode_game_controller__roundNumber : int&;
                           var nexus_round_mode_game_controller__roundState : int&;
                           var nexus_round_mode_game_controller__roundStateEndAt : float&)
  if nexus_game_controller__isGameStarted
    return

  let curTime = get_sync_time()
  nexus_round_mode_game_controller__roundNumber = 1
  nexus_game_controller__isGameStarted = true
  nexus_round_mode_game_controller__roundState = int(NexusRoundState.Preparation)
  nexus_round_mode_game_controller__roundStateEndAt = curTime + nexus_round_mode_game_controller__preparationTime
  nexus_log("ROUND MODE", "Starting game (current_time={curTime}; spawn_at={nexus_round_mode_game_controller__roundStateEndAt};)")


[es(tag=server, no_order)]
def nexus_round_mode_state_update(update : ParallelUpdateFrameDelayed;
                                  nexus_game_controller__spawnController : EntityId;
                                  nexus_round_mode_game_controller__preparationTime : float;
                                  nexus_round_mode_game_controller__debriefingTime : float;
                                  var nexus_round_mode_game_controller__roundNumber : int&;
                                  var nexus_round_mode_game_controller__roundState : int&;
                                  var nexus_round_mode_game_controller__roundStateEndAt : float&)
  if nexus_round_mode_game_controller__roundStateEndAt < 0.0 || update.curTime < nexus_round_mode_game_controller__roundStateEndAt
    return

  if nexus_round_mode_game_controller__roundState == int(NexusRoundState.Preparation)
    sendEvent(nexus_game_controller__spawnController, CmdNexusSpawnAllPlayers(replaceForced = true, ignoreAlreadySpawned = true, destroyPreviousPossessed = true))
    nexus_log("ROUND MODE", "Spawning all remaning players (current_time={update.curTime};)")
    nexus_round_mode_game_controller__roundState = int(NexusRoundState.Started)
    nexus_round_mode_game_controller__roundStateEndAt = -1.0
    broadcast_net_event(EventNexusRoundModeRoundStarted())
    nexus_log("ROUND MODE", "Round started (current_time={update.curTime};)")
  elif nexus_round_mode_game_controller__roundState == int(NexusRoundState.Finished) && nexus_round_mode_game_controller__debriefingTime > 0.0
    nexus_round_mode_game_controller__roundState = int(NexusRoundState.Debriefing)
    nexus_round_mode_game_controller__roundStateEndAt = update.curTime + nexus_round_mode_game_controller__debriefingTime
    broadcast_net_event(EventNexusRoundModeRoundDebriefing())
    nexus_log("ROUND MODE", "Round debriefing (current_time={update.curTime}; change_at={nexus_round_mode_game_controller__roundStateEndAt};)")
  elif nexus_round_mode_game_controller__roundState == int(NexusRoundState.Debriefing) || (nexus_round_mode_game_controller__roundState == int(NexusRoundState.Finished) && nexus_round_mode_game_controller__debriefingTime <= 0.0)
    ++nexus_round_mode_game_controller__roundNumber
    nexus_round_mode_game_controller__roundState = int(NexusRoundState.Preparation)
    nexus_round_mode_game_controller__roundStateEndAt = update.curTime + nexus_round_mode_game_controller__preparationTime
    broadcast_net_event(EventNexusRoundModeRoundChange())
    nexus_log("ROUND MODE", "Round changed (current_time={update.curTime}; spawn_at={nexus_round_mode_game_controller__roundStateEndAt};)")
  else
    nexus_round_mode_game_controller__roundState = -1
    nexus_round_mode_game_controller__roundStateEndAt = -1.0
    nexus_logerr("ROUND MODE", "Invalid state({nexus_round_mode_game_controller__roundState}) for update")


[es(tag=server, REQUIRE=(nexus_militant, nexus_round_mode))]
def nexus_round_mode_on_militant_died(evt : EventEntityDied;
                                      possessedByPlr : EntityId;
                                      team aka victim_team : int)
  if !is_game_started() || !is_round_state(NexusRoundState.Started)
    return

  let curTime = get_sync_time()
  var offenderPlr = INVALID_ENTITY_ID
  var offenderTeam = TEAM_UNASSIGNED
  query(evt.offender) <| $ [es] (possessedByPlr : EntityId;
                                 team : int)
    offenderPlr = possessedByPlr
    offenderTeam = team

  if offenderTeam == TEAM_UNASSIGNED || offenderTeam == victim_team
    query_players_with_hits(possessedByPlr, offenderPlr, victim_team) <| $(playerWithAssist : EntityId)
      query(playerWithAssist) <| $ [es] (team : int)
        offenderTeam = team

  var offenderTeamEid = INVALID_ENTITY_ID
  var victimPointsScore = 0.0
  var otherPointsScore = 0.0
  var victimBeaconsCount = 0
  var otherBeaconsCount = 0
  query() <| $ [es] (eid : EntityId;
                     team__id : int;
                     nexus_round_mode_team__capturedBeacons : EidList;
                     nexus_round_mode_team__points : float = 0.0)
    let beaconsCount = length(nexus_round_mode_team__capturedBeacons)
    if team__id == victim_team
      victimBeaconsCount = beaconsCount
      victimPointsScore = nexus_round_mode_team__points
    else
      otherBeaconsCount = beaconsCount
      otherPointsScore = nexus_round_mode_team__points
      if team__id == offenderTeam
        offenderTeamEid = eid

  var wonByPoints = false
  if offenderTeamEid != INVALID_ENTITY_ID
    find_query() <| $ [es] (nexus_round_mode_game_controller__pointsToWin : float;
                            nexus_round_mode_game_controller__pointsByKill : float)
      let (changePoints, changeOverflow) = change_team_points(offenderTeamEid, nexus_round_mode_game_controller__pointsByKill, nexus_round_mode_game_controller__pointsToWin, true)
      otherPointsScore = changePoints
      if otherPointsScore >= nexus_round_mode_game_controller__pointsToWin
        nexus_log("ROUND MODE", "Team {offenderTeam} is winner by points count after kill")
        finish_round(offenderTeam, int(NexusRoundFinishReason.POINTS), curTime)
        wonByPoints = true

      return true
  if wonByPoints
    return

  let otherTeam = get_other_team(victim_team)
  let isAnyVictimTeammateAlive = is_any_teammate_alive(victim_team)
  let isAnyOtherTeammateAlive = is_any_teammate_alive(otherTeam)
  if isAnyVictimTeammateAlive
    send_player_endgame_result(victim_team, possessedByPlr, true, int(GameEndReasons.NEXUS_BATTLE_DIED), false)
    return

  broadcastEvent(EventNexusWholeTeamDied(team = victim_team))

  if isAnyOtherTeammateAlive
    nexus_log("ROUND MODE", "Finishing round due to elimination of team {victim_team}")
    finish_round(otherTeam, int(NexusRoundFinishReason.TEAM_DIED), curTime)
  else
    let (victimProgress, otherProgress) = is_there_any_progress_in_points(victimBeaconsCount, otherBeaconsCount)
    if victimProgress || otherProgress
      nexus_log("ROUND MODE", "Finishing round due to elimination of all teams")
      if victimProgress && !otherProgress
        finish_round(victim_team, int(NexusRoundFinishReason.CAPTURE_ADVANTAGE), curTime)
      elif otherProgress && !victimProgress
        finish_round(otherTeam, int(NexusRoundFinishReason.CAPTURE_ADVANTAGE), curTime)
      else
        nexus_log("ROUND MODE", "Speed up finishing round due to an unclear winner")
        speed_up_points_tick_time()
    else
      nexus_log("ROUND MODE", "Finishing round due to elimination of all teams and no progress in points")
      if victimPointsScore > otherPointsScore
        finish_round(victim_team, int(NexusRoundFinishReason.POINTS_ADVANTAGE), curTime)
      elif victimPointsScore < otherPointsScore
        finish_round(otherTeam, int(NexusRoundFinishReason.POINTS_ADVANTAGE), curTime)
      else
        finish_round(TEAM_UNASSIGNED, int(NexusRoundFinishReason.ALL_DIED), curTime)


[es(tag=server, no_order)]
def nexus_round_mode_points_update(update : ParallelUpdateFrameDelayed;
                                   nexus_round_mode_game_controller__pointsToWin : float;
                                   nexus_round_mode_game_controller__pointsByTick : float;
                                   nexus_round_mode_game_controller__pointsTickTime : float;
                                   var nexus_round_mode_game_controller__pointsNextTickAt : float&;
                                   nexus_round_mode_points_direct : Tag const?;
                                   nexus_round_mode_points_advantage : Tag const?;
                                   nexus_round_mode_points_advantage_equality_scoring : Tag const?;
                                   nexus_round_mode_points_advantage_by_beacons : Tag const?;
                                   nexus_round_mode_points_scaling_sqrt : Tag const?)
  if !is_game_started() || !is_round_state(NexusRoundState.Started) || nexus_round_mode_game_controller__pointsNextTickAt < 0.0 || update.curTime < nexus_round_mode_game_controller__pointsNextTickAt
    return
  nexus_round_mode_game_controller__pointsNextTickAt += nexus_round_mode_game_controller__pointsTickTime

  var teamsBeacons : array<tuple<EntityId; int; int>>
  query() <| $ [es] (eid : EntityId;
                     team__id : int;
                     nexus_round_mode_team__capturedBeacons : EidList)
    teamsBeacons |> push((eid, length(nexus_round_mode_team__capturedBeacons), team__id))

  var winner = TEAM_UNASSIGNED
  var draw = false

  if nexus_round_mode_points_direct != null
    let pointsToAddTeamOne = get_points_to_add(nexus_round_mode_game_controller__pointsByTick, teamsBeacons[0]._1, nexus_round_mode_points_scaling_sqrt != null)
    let pointsToAddTeamTwo = get_points_to_add(nexus_round_mode_game_controller__pointsByTick, teamsBeacons[1]._1, nexus_round_mode_points_scaling_sqrt != null)
    let (pointsTeamOne, overflowTeamOne) = change_team_points(teamsBeacons[0]._0, pointsToAddTeamOne, nexus_round_mode_game_controller__pointsToWin)
    let (pointsTeamTwo, overflowTeamTwo) = change_team_points(teamsBeacons[1]._0, pointsToAddTeamTwo, nexus_round_mode_game_controller__pointsToWin)
    let (decidedWinner, decidedDraw) = decide_winner_by_points(teamsBeacons[0]._0, teamsBeacons[1]._0, teamsBeacons[0]._2, teamsBeacons[1]._2,
                                                               pointsTeamOne, pointsTeamTwo, pointsToAddTeamOne, pointsToAddTeamTwo, overflowTeamOne, overflowTeamTwo, nexus_round_mode_game_controller__pointsToWin)
    winner = decidedWinner
    draw = decidedDraw

  elif nexus_round_mode_points_advantage != null
    if teamsBeacons[0]._1 > teamsBeacons[1]._1
      let pointsToAdd = get_points_to_add_by_advantage(nexus_round_mode_game_controller__pointsByTick, teamsBeacons[0]._1, teamsBeacons[1]._1,
                                                       nexus_round_mode_points_scaling_sqrt != null, nexus_round_mode_points_advantage_by_beacons != null)
      let (points, overflow) = change_team_points(teamsBeacons[0]._0, pointsToAdd, nexus_round_mode_game_controller__pointsToWin)
      if points >= nexus_round_mode_game_controller__pointsToWin
        winner = teamsBeacons[0]._2
    elif teamsBeacons[0]._1 < teamsBeacons[1]._1
      let pointsToAdd = get_points_to_add_by_advantage(nexus_round_mode_game_controller__pointsByTick, teamsBeacons[1]._1, teamsBeacons[0]._1,
                                                       nexus_round_mode_points_scaling_sqrt != null, nexus_round_mode_points_advantage_by_beacons != null)
      let (points, overflow) = change_team_points(teamsBeacons[1]._0, pointsToAdd, nexus_round_mode_game_controller__pointsToWin)
      if points >= nexus_round_mode_game_controller__pointsToWin
        winner = teamsBeacons[1]._2
    elif teamsBeacons[0]._1 != 0 && teamsBeacons[1]._1 != 0 && nexus_round_mode_points_advantage_equality_scoring != null
      let (pointsTeamOne, overflowTeamOne) = change_team_points(teamsBeacons[0]._0, nexus_round_mode_game_controller__pointsByTick, nexus_round_mode_game_controller__pointsToWin)
      let (pointsTeamTwo, overflowTeamTwo) = change_team_points(teamsBeacons[1]._0, nexus_round_mode_game_controller__pointsByTick, nexus_round_mode_game_controller__pointsToWin)
      let (decidedWinner, decidedDraw) = decide_winner_by_points(teamsBeacons[0]._0, teamsBeacons[1]._0, teamsBeacons[0]._2, teamsBeacons[1]._2,
                                                                 pointsTeamOne, pointsTeamTwo, 1.0, 1.0, overflowTeamOne, overflowTeamTwo, nexus_round_mode_game_controller__pointsToWin)
      winner = decidedWinner
      draw = decidedDraw

  if winner == TEAM_UNASSIGNED && !draw
    return

  if draw
    nexus_log("ROUND MODE", "Both teams scored same amount of points to win so it is a draw")
    finish_round(TEAM_UNASSIGNED, int(NexusRoundFinishReason.POINTS_DRAW), update.curTime)
  else
    nexus_log("ROUND MODE", "Team {winner} is winner by points count")
    finish_round(winner, int(NexusRoundFinishReason.POINTS), update.curTime)


[es(tag=server, REQUIRE=nexus_round_mode)]
def nexus_round_mode_capture_beacons_on_other_team_die(evt : EventNexusRoundModeRoundFinished;
                                                       var nexus_beacon__state : int&;
                                                       var nexus_beacon__controllingTeam : int&;
                                                       var nexus_beacon__progress : float&)
  if evt.reason != int(NexusRoundFinishReason.TEAM_DIED) || nexus_beacon__state != int(NexusBeaconState.CAPTURED) || nexus_beacon__controllingTeam != get_other_team(evt.winnerTeam)
    return
  nexus_beacon__state = int(NexusBeaconState.INACTIVE)
  nexus_beacon__controllingTeam = TEAM_UNASSIGNED
  nexus_beacon__progress = 0.0


[es(tag=server, after=nexus_round_mode_points_update)]
def nexus_round_mode_points_display_update(update : ParallelUpdateFrameDelayed;
                                           nexus_round_mode_game_controller__pointsDisplayTickTime : float;
                                           var nexus_round_mode_game_controller__pointsDisplayNextTickAt : float&)
  if !is_game_started() || !is_round_state(NexusRoundState.Started) || nexus_round_mode_game_controller__pointsDisplayNextTickAt < 0.0 || update.curTime < nexus_round_mode_game_controller__pointsDisplayNextTickAt
    return
  nexus_round_mode_game_controller__pointsDisplayNextTickAt += nexus_round_mode_game_controller__pointsDisplayTickTime

  query() <| $ [es] (nexus_round_mode_team__points : float;
                     var nexus_round_mode_team__displayPoints : float&)
    nexus_round_mode_team__displayPoints = nexus_round_mode_team__points


[es(tag=server, REQUIRE=nexus_round_mode, track=(nexus_beacon__controllingTeam, nexus_beacon__state), on_appear)]
def nexus_round_mode_track_team_beacons(evt : Event;
                                        eid : EntityId;
                                        nexus_beacon__state : int;
                                        nexus_beacon__controllingTeam : int)
  query() <| $ [es] (team__id : int;
                     var nexus_round_mode_team__capturedBeacons : EidList&)
    update_team_beacons(eid, team__id, nexus_beacon__state, nexus_beacon__controllingTeam, nexus_round_mode_team__capturedBeacons)


[es(tag=server, REQUIRE=nexus_round_mode, on_appear)]
def nexus_round_mode_init_team_beacons(evt : Event;
                                       team__id : int;
                                       var nexus_round_mode_team__capturedBeacons : EidList&)
  query() <| $ [es(REQUIRE=nexus_round_mode)] (eid : EntityId;
                                               nexus_beacon__state : int;
                                               nexus_beacon__controllingTeam : int)
    update_team_beacons(eid, team__id, nexus_beacon__state, nexus_beacon__controllingTeam, nexus_round_mode_team__capturedBeacons)


[es(tag=server, track=nexus_round_mode_team__capturedBeacons)]
def nexus_round_mode_finish_round_on_reseting_capture_when_team_dead(evt : Event;
                                                                     team__id : int;
                                                                     nexus_round_mode_team__capturedBeacons : EidList)
  if !is_game_started() || !is_round_state(NexusRoundState.Started)
    return

  let otherTeam = get_other_team(team__id)
  let otherTeamBeaconsCount = get_team_beacons_count(otherTeam)
  if is_there_any_progress_in_points_for_team(length(nexus_round_mode_team__capturedBeacons), otherTeamBeaconsCount) || is_any_teammate_alive(team__id)
    return

  finish_round(otherTeam, int(NexusRoundFinishReason.CAPTURE_ADVANTAGE), get_sync_time())


[es(tag=server, track=nexus_round_mode_team__capturedBeacons)]
def nexus_round_mode_finish_round_on_capture_when_other_team_dead(evt : Event;
                                                                  team__id : int;
                                                                  nexus_round_mode_team__capturedBeacons : EidList)
  if !is_game_started() || !is_round_state(NexusRoundState.Started)
    return

  let otherTeam = get_other_team(team__id)
  let otherTeamBeaconsCount = get_team_beacons_count(otherTeam)
  if is_there_any_progress_in_points_for_team(otherTeamBeaconsCount, length(nexus_round_mode_team__capturedBeacons)) || is_any_teammate_alive(otherTeam)
    return

  finish_round(team__id, int(NexusRoundFinishReason.CAPTURE_ADVANTAGE), get_sync_time())


[es(tag=server, no_order)]
def nexus_round_mode_finish_round_on_time_out(act : UpdateStageInfoAct;
                                              nexus_round_mode_game_controller__timeOutAt : float)
  if nexus_round_mode_game_controller__timeOutAt < 0.0 || act.curTime < nexus_round_mode_game_controller__timeOutAt || !is_round_state(NexusRoundState.Started)
    return

  if is_points_mode()
    var winnerPoints = 0.0
    var winnerTeam = TEAM_UNASSIGNED
    query() <| $ [es] (team__id : int;
                       nexus_round_mode_team__points : float)
      if nexus_round_mode_team__points > winnerPoints
        winnerPoints = nexus_round_mode_team__points
        winnerTeam = team__id
      elif nexus_round_mode_team__points == winnerPoints && winnerTeam != TEAM_UNASSIGNED
        winnerTeam = TEAM_UNASSIGNED

    if winnerTeam != TEAM_UNASSIGNED
      nexus_log("ROUND MODE", "Finishing round due to time out (Winner is decided by points advantage)")
      finish_round(winnerTeam, int(NexusRoundFinishReason.POINTS_ADVANTAGE), act.curTime)
    else
      nexus_log("ROUND MODE", "Both teams scored same amount of points to win so it is a draw")
      finish_round(TEAM_UNASSIGNED, int(NexusRoundFinishReason.POINTS_DRAW), act.curTime)
    return

  nexus_log("ROUND MODE", "Finishing round in draw due to time out")
  finish_round(TEAM_UNASSIGNED, int(NexusRoundFinishReason.TIME_OUT), act.curTime)


[es(tag=server, after=(nexus_round_mode_increase_team_score, nexus_round_mode_detect_game_draw))]
def nexus_round_mode_round_finish(evt : EventNexusRoundModeRoundFinished;
                                  nexus_game_controller__isGameFinished : bool;
                                  nexus_round_mode_game_controller__delayAfterRoundFinish : float;
                                  var nexus_round_mode_game_controller__roundState : int&;
                                  var nexus_round_mode_game_controller__roundStateEndAt : float&)
  if nexus_game_controller__isGameFinished
    return

  let curTime = get_sync_time()
  nexus_round_mode_game_controller__roundState = int(NexusRoundState.Finished)
  nexus_round_mode_game_controller__roundStateEndAt = curTime + nexus_round_mode_game_controller__delayAfterRoundFinish
  nexus_log("ROUND MODE", "Round finished (current_time={curTime}; team_winner={evt.winnerTeam}; reason={evt.reason}; round_change_at={nexus_round_mode_game_controller__roundStateEndAt};)")


[es(tag=server)]
def nexus_round_mode_increase_team_score(evt : EventNexusRoundModeRoundFinished;
                                         team__id : int;
                                         var nexus_round_mode_team__wonRounds : int&)
  if team__id != evt.winnerTeam
    return

  nexus_round_mode_team__wonRounds += 1
  find_query() <| $ [es] (nexus_round_mode_game_controller__roundsToWin : int)
    if nexus_round_mode_game_controller__roundsToWin == nexus_round_mode_team__wonRounds
      finish_game(team__id, evt.time)
    return true


[es(tag=server)]
def nexus_round_mode_detect_game_draw(evt : EventNexusRoundModeRoundFinished;
                                      nexus_round_mode_game_controller__maxDrawRoundsInRow : int;
                                      var nexus_round_mode_game_controller__drawsInRow : int&)
  if evt.winnerTeam == TEAM_UNASSIGNED
    nexus_round_mode_game_controller__drawsInRow += 1
    nexus_log("ROUND MODE", "Draws in raw: {nexus_round_mode_game_controller__drawsInRow} out of {nexus_round_mode_game_controller__maxDrawRoundsInRow}")
    if nexus_round_mode_game_controller__drawsInRow == nexus_round_mode_game_controller__maxDrawRoundsInRow
      finish_game(TEAM_UNASSIGNED, evt.time)
  else
    nexus_round_mode_game_controller__drawsInRow = 0


[es(tag=server)]
def nexus_round_mode_set_time_out_for_new_round(evt : EventNexusRoundModeRoundStarted;
                                                nexus_round_mode_game_controller__roundTime : float;
                                                var nexus_round_mode_game_controller__timeOutAt : float&)
  nexus_round_mode_game_controller__timeOutAt = get_sync_time() + nexus_round_mode_game_controller__roundTime


[es]
def nexus_round_mode_disable_loadout_change(evt : EventNexusRoundModeRoundStarted;
                                            var nexus_loadout_controller__canChange : bool&)
  nexus_loadout_controller__canChange = false


[es]
def nexus_round_mode_enable_loadout_change(evt : EventNexusRoundModeRoundChange;
                                           var nexus_loadout_controller__canChange : bool&)
  nexus_loadout_controller__canChange = true


[es]
def nexus_round_mode_points_set_time_ticks(evt : EventNexusRoundModeRoundStarted;
                                           nexus_round_mode_game_controller__pointsTickTime : float;
                                           nexus_round_mode_game_controller__pointsDisplayTickTime : float;
                                           var nexus_round_mode_game_controller__pointsNextTickAt : float&;
                                           var nexus_round_mode_game_controller__pointsDisplayNextTickAt : float&)
  let curTime = get_sync_time()
  nexus_round_mode_game_controller__pointsNextTickAt = curTime + nexus_round_mode_game_controller__pointsTickTime
  nexus_round_mode_game_controller__pointsDisplayNextTickAt = curTime + nexus_round_mode_game_controller__pointsDisplayTickTime


[es]
def nexus_round_mode_points_reset_time_ticks(evt : EventNexusRoundModeRoundFinished;
                                             var nexus_round_mode_game_controller__pointsNextTickAt : float&;
                                             var nexus_round_mode_game_controller__pointsDisplayNextTickAt : float&)
  nexus_round_mode_game_controller__pointsNextTickAt = -1.0
  nexus_round_mode_game_controller__pointsDisplayNextTickAt = -1.0


[es(tag=server, REQUIRE=nexus_round_mode, REQUIRE_NOT=nexus_beacon__precapturedForTeam)]
def nexus_round_mode_reset_beacons(evt : EventNexusRoundModeRoundChange;
                                   var nexus_beacon__state : int&;
                                   var nexus_beacon__controllingTeam : int&;
                                   var nexus_beacon__progress : float&)
  nexus_beacon__state = int(NexusBeaconState.INACTIVE)
  nexus_beacon__controllingTeam = TEAM_UNASSIGNED
  nexus_beacon__progress = 0.0


[es(tag=server, REQUIRE=nexus_round_mode, after=nexus_round_mode_switch_precapture_team)]
def nexus_round_mode_precapture_beacons(evt : EventNexusRoundModeRoundChange;
                                        nexus_beacon__precapturedForTeam : int;
                                        nexus_beacon__progressToCapture : float;
                                        var nexus_beacon__state : int&;
                                        var nexus_beacon__controllingTeam : int&;
                                        var nexus_beacon__progress : float&)
  nexus_beacon__state = int(NexusBeaconState.CAPTURED)
  nexus_beacon__controllingTeam = nexus_beacon__precapturedForTeam
  nexus_beacon__progress = nexus_beacon__progressToCapture


[es(tag=server)]
def nexus_round_mode_switch_precapture_team(evt : EventNexusRoundModeRoundChange;
                                            var nexus_beacon__precapturedForTeam : int&)
  nexus_beacon__precapturedForTeam = get_other_team(nexus_beacon__precapturedForTeam)


[es(tag=server, REQUIRE=(nexus_player, nexus_round_mode), on_event=(EventNexusRoundModeRoundChange, EventNexusRoundModeRoundDebriefing))]
def nexus_round_mode_destroy_player_possesed(evt : Event;
                                             var possessed : EntityId&)
  if possessed == INVALID_ENTITY_ID
    return

  destroyEntity(possessed)
  possessed = INVALID_ENTITY_ID


[es(tag=server, REQUIRE=(nexus_militant, nexus_round_mode), on_event=(EventNexusRoundModeRoundChange, EventNexusRoundModeRoundDebriefing))]
def nexus_round_mode_destroy_millitant(evt : Event;
                                       eid : EntityId;
                                       possessedByPlr : EntityId)
  if possessedByPlr != INVALID_ENTITY_ID
    return

  destroyEntity(eid)


[es(tag=server, REQUIRE=(nexus_player, nexus_round_mode))]
def nexus_round_mode_select_loadout_on_round_change(evt : EventNexusRoundModeRoundChange;
                                                    eid : EntityId;
                                                    var nexus_player_loadout__takenIndex : int&)
  send_net_event(eid, CmdNexusBattleSelectLoadout(loadoutIndex = nexus_player_loadout__takenIndex, selectAnyIfUnavailable = true))
  nexus_player_loadout__takenIndex = -1


[es(tag=server, REQUIRE=item__humanOwnerEid)]
def nexus_round_mode_clear_items_with_owners(evt : EventNexusRoundModeRoundChange;
                                             eid : EntityId)
  destroyEntity(eid)


[es(tag=server)]
def nexus_round_mode_reset_time_out(evt : EventNexusRoundModeRoundFinished;
                                    var nexus_round_mode_game_controller__timeOutAt : float&)
  nexus_round_mode_game_controller__timeOutAt = -1.0


[es(tag=server, REQUIRE=respbase)]
def nexus_round_mode_switch_spawns(evt : EventNexusRoundModeRoundChange;
                                   var team : int&)
  team = get_other_team(team)


[es(tag=server)]
def nexus_round_mode_reset_points_tick_time(evt : EventNexusRoundModeRoundChange;
                                            nexus_round_mode_game_controller__pointsTickTimeDefault : float;
                                            var nexus_round_mode_game_controller__pointsTickTime : float&)
  nexus_round_mode_game_controller__pointsTickTime = nexus_round_mode_game_controller__pointsTickTimeDefault


[es(tag=server)]
def nexus_round_mode_sync_team_display_points(evt : EventNexusRoundModeRoundFinished;
                                              nexus_round_mode_team__points : float;
                                              var nexus_round_mode_team__displayPoints : float&)
  nexus_round_mode_team__displayPoints = nexus_round_mode_team__points


[es(tag=server)]
def nexus_round_mode_reset_team_score(evt : EventNexusRoundModeRoundChange;
                                      var nexus_round_mode_team__points : float&;
                                      var nexus_round_mode_team__displayPoints : float&)
  nexus_round_mode_team__points = 0.0
  nexus_round_mode_team__displayPoints = 0.0


[es(tag=server)]
def nexus_round_mode_reset_team_captured_points(evt : EventNexusRoundModeRoundChange;
                                                team__id : int;
                                                var nexus_round_mode_team__capturedBeacons : EidList&)
  clear(nexus_round_mode_team__capturedBeacons)
  query() <| $ [es] (eid : EntityId;
                     nexus_beacon__state : int;
                     nexus_beacon__controllingTeam : int)
    if nexus_beacon__state == int(NexusBeaconState.CAPTURED) && nexus_beacon__controllingTeam == team__id
      nexus_round_mode_team__capturedBeacons |> push(eid)


[es(tag=server)]
def nexus_round_mode_protect_sphere_switch_team(evt : EventNexusRoundModeRoundChange;
                                                var nexus_protect_sphere__team : int&)
  nexus_protect_sphere__team = get_other_team(nexus_protect_sphere__team)


[es(tag=server)]
def nexus_round_mode_reset_initial_am(evt : EventNexusRoundModeRoundChange;
                                      var nexus_battle_initial_am__playersGiven : EidList&)
  clear(nexus_battle_initial_am__playersGiven)


[es(tag=server)]
def nexus_round_mode_add_bots(evt : CmdNexusAddBots;
                              bot_spawner__generatedNames : StringList;
                              bot_spawner__playerTemplate : string;
                              var bot_names__nextNameId : int&)
  let numPlayersToSpawn = evt.number
  var nextGroupId = 0l
  query() <| $ [es] (groupId : int64)
    nextGroupId = max(nextGroupId, groupId)
  for _ in range(numPlayersToSpawn)
    let playerEid = createEntity(bot_spawner__playerTemplate) <| $(var init : ComponentsInitializer)
      init |> set("possessed", INVALID_ENTITY_ID)
      init |> set("connid", INVALID_CONNECTION_ID)
      init |> set("name", bot_spawner__generatedNames[bot_names__nextNameId])
      bot_names__nextNameId += 1
      bot_names__nextNameId %= length(bot_spawner__generatedNames)
      if bot_names__nextNameId == 0
        logerr("Not enough bot names({length(bot_spawner__generatedNames)}). Reseting names cursor to zero.")
      init |> set("userid", INVALID_USER_ID)
      init |> set("team", TEAM_UNASSIGNED)
      nextGroupId += 1l
      init |> set("groupId", nextGroupId)

    // we want call some code on player entity, that already created (reconnect) or not (firts connect)
    sendEvent(playerEid, FinalizePlayerPreparing(matchingTeam = -1, clientFlags = uint16(0), isReconnected = false))


[es(tag=server, REQUIRE=(nexus_game_controller, nexus_round_mode), REQUIRE_NOT=nexus_round_mode_keep_protect_spheres_before_round_start)]
def nexus_round_mode_disable_protect_spheres(evt : EventNexusGameStart)
  broadcastEvent(EventNexusDisableProtectSpheres())


[es(tag=server, REQUIRE=nexus_round_mode_keep_protect_spheres_before_round_start)]
def nexus_round_mode_enable_protect_spheres_at_round_change(evt : EventNexusRoundModeRoundChange)
  broadcastEvent(EventNexusEnableProtectSpheres())


[es(tag=server, REQUIRE=nexus_round_mode_keep_protect_spheres_before_round_start)]
def nexus_round_mode_disable_protect_spheres_at_round_start(evt : EventNexusRoundModeRoundStarted)
  broadcastEvent(EventNexusDisableProtectSpheres())


[es(tag=server)]
def nexus_round_mode_start_endgame_timer_on_other_team_left(evt : EventNexusRoundModeRoundChange)
  var needAbandonTimer = true
  dgs_get_settings() |> datablock_get_block("debug") <| $(blk)
    if blk |> datablock_getBool("nexusIgnoreAbandonedTimer", false)
      needAbandonTimer = false
  if !needAbandonTimer
    return

  let hasTimerAlready = find_query() <| $ [es(REQUIRE=nexus_team_abandoned_timer)] ()
    return true

  if hasTimerAlready
    return

  var hasFirstTeam = false
  var hasSecondTeam = false
  find_query() <| $ [es(REQUIRE=(nexus_player, nexus_round_mode))] (team : int; disconnected : bool)
    if disconnected
      return false
    if team == int(NexusTeam.FIRST)
      hasFirstTeam = true
    elif team == int(NexusTeam.SECOND)
      hasSecondTeam = true
    return hasFirstTeam && hasSecondTeam

  if !hasFirstTeam || !hasSecondTeam
    createEntity("nexus_team_abandoned_timer")


[es(tag=server, on_appear)]
def init_nexus_team_abandoned_timer(evt : Event;
                                    nexus_team_abandoned_timer__delay : float;
                                    var nexus_team_abandoned_timer__finishAt : float&)
  nexus_team_abandoned_timer__finishAt = get_sync_time() + nexus_team_abandoned_timer__delay


[es(tag=server, no_order)]
def update_nexus_team_abandoned_timer(act : UpdateStageInfoAct;
                                      eid aka timer_eid : EntityId;
                                      nexus_team_abandoned_timer__finishAt : float)
  if act.curTime < nexus_team_abandoned_timer__finishAt
    return

  let foundWinnerTeam = find_query() <| $ [es(REQUIRE=(nexus_player, nexus_round_mode))] (team : int; disconnected : bool)
    if disconnected
      return false
    nexus_log("ROUND", "Finishing game due to team {get_other_team(team)} abandonment")
    finish_game(team, act.curTime)
    return true

  if !foundWinnerTeam
    nexus_log("ROUND", "Finishing game due to both team abandonment")
    finish_game(TEAM_UNASSIGNED, act.curTime)

  destroyEntity(timer_eid)


[es(tag=server, track=disconnected, on_appear)]
def nexus_team_remove_abandoned_timer_on_reconnect(evt : Event;
                                                   disconnected : bool)
  if !disconnected
    return

  var hasFirstTeam = false
  var hasSecondTeam = false
  let hasBothTeams = find_query() <| $ [es(REQUIRE=(nexus_player, nexus_round_mode))] (team : int; disconnected : bool)
    if disconnected
      return false
    if team == int(NexusTeam.FIRST)
      hasFirstTeam = true
    elif team == int(NexusTeam.SECOND)
      hasSecondTeam = true
    return hasFirstTeam && hasSecondTeam

  if hasBothTeams
    find_query() <| $ [es(REQUIRE=nexus_team_abandoned_timer)] (eid : EntityId)
      destroyEntity(eid)
      return true


[es(tag=server, track=nexus_round_mode_game_controller__roundState)]
def nexus_reset_enemies_spectator_rights_on_round_change(evt : Event;
                                                         nexus_round_mode_game_controller__roundState : int)
  if nexus_round_mode_game_controller__roundState != int(NexusRoundState.Started)
    return

  query() <| $ [es] (var allowEnemiesToSpectate : bool&)
    allowEnemiesToSpectate = false


[es(tag=server)]
def nexus_allow_enemies_spectate_when_one_team_left(evt : EventNexusWholeTeamDied;
                                                    team : int;
                                                    var allowEnemiesToSpectate : bool&)
  if team != evt.team
    allowEnemiesToSpectate = true


[es(REQUIRE=destroy_on_nexus_round_start)]
def destroy_on_nexus_round_start(evt : EventNexusRoundModeRoundStarted;
                                 eid : EntityId)
  destroyEntity(eid)
