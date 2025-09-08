require app
require ecs
require rapidjson
require ecs.common
require DngNet
require game.events.events_active_matter
require game.es.level_common
require game.es.nexus_common
require game.utils.debug_bots
require game.es.nexus_game_start_common


[es(tag=server, on_appear)]
def nexus_players_init_num_players_expeted(evt : Event;
                                           var nexus_players_controller__numPlayersExpected : int&)
  if nexus_players_controller__numPlayersExpected > 0
    return
  var expectedPlayersFromMatching = 0
  get_matching_invite_data() |> FindMember("mode_info", JsonType.kObjectType) <| $(modeinfo : JsonValue)
    expectedPlayersFromMatching = json_get_or(modeinfo, "maxPlayers", 0)
  if !is_true_net_server() && expectedPlayersFromMatching == 0
    expectedPlayersFromMatching = 1

  var numBots = get_bots_num_from_cmdline()
  if numBots == 0
    get_matching_invite_data() |> FindMember("mode_info", JsonType.kObjectType) <| $(modeinfo : JsonValue)
      numBots = json_get_or(modeinfo, "botpop", 0)
  nexus_players_controller__numPlayersExpected = expectedPlayersFromMatching + numBots
  nexus_log("PLAYERS", "Players expected = {nexus_players_controller__numPlayersExpected} ({numBots} bots)")

  if numBots > 0
    broadcastEvent(CmdNexusAddBots(number = numBots))


[es(tag=server, track=nexus_game_start__jipTime)]
def nexus_players_init_bot_spawner(evt : Event;
                                   nexus_game_start__jipTime : float)
  var needBotsSpawner = true
  get_matching_invite_data() |> FindMember("extraParams", JsonType.kObjectType) <| $(extraParams : JsonValue)
    if extraParams.IsNull
      return
    needBotsSpawner = json_get_or(extraParams, "fillTeamsWithBots", true)
  nexus_log("PLAYERS", "Need bots spawner = {needBotsSpawner}")
  if needBotsSpawner
    nexus_log("PLAYERS", "Will start spawning bots at {nexus_game_start__jipTime}")
    find_query() <| $ [es(REQUIRE=nexus_players_controller)] (eid : EntityId)
      addSubTemplate(eid, "nexus_players_bots_spawner") <| $(var init)
        set(init, "nexus_bots_spawner__startSpawnAt", nexus_game_start__jipTime)
      return true


[es(tag=server, no_order)]
def nexus_players_start_filling_teams_with_bots(upd : UpdateStageInfoAct;
                                                eid aka controller_eid : EntityId;
                                                nexus_players_controller__numPlayersExpected : int;
                                                nexus_players_controller__numPlayersConnected : int;
                                                var nexus_bots_spawner__startSpawnAt : float&;
                                                var nexus_bots_spawner__updateInterval : float&;
                                                var nexus_bots_spawner__nextSpawnAt : float&)
  if nexus_bots_spawner__startSpawnAt < 0.0 || upd.curTime < nexus_bots_spawner__startSpawnAt
    return

  nexus_bots_spawner__startSpawnAt = -1.0
  var finishBotsSpawnAt = -1.0
  find_query() <| $ [es] (nexus_game_start__state : int; nexus_game_start__stateEndAt : float)
    if nexus_game_start__state == int(NexusGameStartState.WaitingForPlayers)
      finishBotsSpawnAt = nexus_game_start__stateEndAt - 0.5
    return true

  let needBots = nexus_players_controller__numPlayersExpected - nexus_players_controller__numPlayersConnected
  if needBots <= 0
    nexus_log("PLAYERS", "No bots needed, stopping bot spawner before start")
    removeSubTemplate(controller_eid, "nexus_players_bots_spawner")
    return

  if finishBotsSpawnAt > 0.0
    let timeForSpawning = max(finishBotsSpawnAt - upd.curTime, 0.1)
    nexus_bots_spawner__updateInterval = timeForSpawning / float(needBots)

  // interval is too small, makes more sense to spawn all bots at once
  if nexus_bots_spawner__updateInterval <= 0.1
    nexus_log("PLAYERS", "Spawning {needBots} bots immediately and stopping spawner before start")
    broadcastEvent(CmdNexusAddBots(number = needBots))
    removeSubTemplate(controller_eid, "nexus_players_bots_spawner")
    return

  nexus_bots_spawner__nextSpawnAt = upd.curTime + nexus_bots_spawner__updateInterval
  nexus_log("PLAYERS", "Spawning {needBots} bots in intervals of {nexus_bots_spawner__updateInterval}s")


[es(tag=server, after=nexus_players_start_filling_teams_with_bots)]
def nexus_players_filling_teams_with_bots_update(upd : UpdateStageInfoAct;
                                                 eid aka controller_eid : EntityId;
                                                 nexus_players_controller__numPlayersExpected : int;
                                                 nexus_players_controller__numPlayersConnected : int;
                                                 nexus_bots_spawner__updateInterval : float;
                                                 var nexus_bots_spawner__nextSpawnAt : float&)
  if nexus_bots_spawner__nextSpawnAt < 0.0 || upd.curTime < nexus_bots_spawner__nextSpawnAt
    return

  nexus_bots_spawner__nextSpawnAt = upd.curTime + nexus_bots_spawner__updateInterval

  if nexus_players_controller__numPlayersConnected >= nexus_players_controller__numPlayersExpected
    nexus_log("PLAYERS", "No more bots needed, stopping bot spawner")
    removeSubTemplate(controller_eid, "nexus_players_bots_spawner")
    nexus_bots_spawner__nextSpawnAt = -1.0
    return
  nexus_log("PLAYERS", "Need {nexus_players_controller__numPlayersExpected - nexus_players_controller__numPlayersConnected} more bots, spawning 1")
  broadcastEvent(CmdNexusAddBots(number = 1))

  // check 2 times, because player spawn can take several frames, this way less chance to spawn excessive number of bots
  if nexus_players_controller__numPlayersConnected + 1 >= nexus_players_controller__numPlayersExpected
    nexus_log("PLAYERS", "No more bots needed, stopping bot spawner")
    removeSubTemplate(controller_eid, "nexus_players_bots_spawner")
    nexus_bots_spawner__nextSpawnAt = -1.0


[es(tag=server, on_appear, REQUIRE=nexus_player)]
def nexus_players_increase_num_players_connected(evt : Event;
                                                 eid aka player_eid : EntityId)
  if !is_nexus_mode()
    return
  find_query() <| $ [es] (nexus_players_controller__numPlayersExpected : int;
                          var nexus_players_controller__numPlayersConnected : int&;
                          var nexus_players_controller__players : EidList)
    if has_value(nexus_players_controller__players, player_eid)
      nexus_logwarn("PLAYERS", "Player <{player_eid}> already counted")
    else
      if nexus_players_controller__numPlayersConnected >= nexus_players_controller__numPlayersExpected
        nexus_logerr("PLAYERS", "Player <{player_eid}> connected, but no more players are expected.")
      push(nexus_players_controller__players, player_eid)
      ++nexus_players_controller__numPlayersConnected
    return true


[es(tag=server, on_disappear, REQUIRE=nexus_player)]
def nexus_players_decrease_num_players_connected(evt : Event;
                                                 eid aka player_eid : EntityId)
  if !is_nexus_mode()
    return
  find_query() <| $ [es] (var nexus_players_controller__numPlayersConnected : int&;
                          var nexus_players_controller__players : EidList)
    let index = find_index(nexus_players_controller__players, player_eid)
    if index < 0
      nexus_logwarn("PLAYERS", "Player <{player_eid}> not counted initially")
    else
      erase(nexus_players_controller__players, index)
      --nexus_players_controller__numPlayersConnected
    return true


[es(tag=server, on_appear)]
def nexus_player_effect_init(evt : Event;
                             nexus_player_effect__owner : EntityId;
                             nexus_player_effect__template : string;
                             var nexus_player_effect__possessedEffect : EntityId&)
  query(nexus_player_effect__owner) <| $ [es] (possessed : EntityId)
    if possessed != INVALID_ENTITY_ID
      nexus_log("PLAYERS", "Enable effect '{nexus_player_effect__template}' for possessed<{possessed}>")
      nexus_player_effect__possessedEffect = createEntity(nexus_player_effect__template) <| $(init)
        set(init, "game_effect__attachedTo", possessed)


[es(tag=server, on_disappear)]
def nexus_player_effect_destroy(evt : Event;
                                nexus_player_effect__possessedEffect : EntityId)
  if nexus_player_effect__possessedEffect != INVALID_ENTITY_ID
    destroyEntity(nexus_player_effect__possessedEffect)


[es(tag=server, REQUIRE=nexus_player, track=possessed)]
def nexus_player_effect_track_possessed(evt : Event;
                                        eid aka player_eid : EntityId;
                                        possessed : EntityId)
  find_query() <| $ [es] (nexus_player_effect__owner : EntityId;
                          nexus_player_effect__template : string;
                          var nexus_player_effect__possessedEffect : EntityId&)
    if nexus_player_effect__owner != player_eid || nexus_player_effect__template != nexus_player_effect__template
      return false

    if nexus_player_effect__possessedEffect == INVALID_ENTITY_ID
      nexus_log("PLAYERS", "Enable effect '{nexus_player_effect__template}' for possessed<{possessed}>")
      nexus_player_effect__possessedEffect = createEntity(nexus_player_effect__template) <| $(init)
        set(init, "game_effect__attachedTo", possessed)
      return true

    if possessed == INVALID_ENTITY_ID
      nexus_log("PLAYERS", "Disable effect '{nexus_player_effect__template}' for previous possessed of player<{player_eid}>")
      destroyEntity(nexus_player_effect__possessedEffect)
      nexus_player_effect__possessedEffect = INVALID_ENTITY_ID
      return true

    query(nexus_player_effect__possessedEffect) <| $ [es] (var game_effect__attachedTo : EntityId&)
      nexus_log("PLAYERS", "Change possessed of effect '{nexus_player_effect__template}' from <{game_effect__attachedTo}> to <{possessed}>")
      game_effect__attachedTo = possessed
    return true


def nexus_player_effect_create_or_increase_reqeusters_count(player_eid : EntityId;
                                                            player_effect_template : string)
  let effectAlreadyExists = find_query() <| $ [es] (nexus_player_effect__owner : EntityId;
                                                    nexus_player_effect__template : string;
                                                    var nexus_player_effect__requestersCount : int&)
    if nexus_player_effect__owner != player_eid || nexus_player_effect__template != player_effect_template
      return false
    ++nexus_player_effect__requestersCount
    return true

  if effectAlreadyExists
    nexus_log("PLAYERS", "Effect '{player_effect_template}' requesters count increased for player<{player_eid}>")
    return

  nexus_log("PLAYERS", "Enable effect '{player_effect_template}' for player<{player_eid}>")
  createEntity("nexus_player_effect") <| $(init)
    set(init, "nexus_player_effect__owner", player_eid)
    set(init, "nexus_player_effect__template", player_effect_template)
    set(init, "nexus_player_effect__requestersCount", 1)


def nexus_player_effect_destroy_or_decrease_reqeusters_count(player_eid : EntityId;
                                                             player_effect_template : string)
  find_query() <| $ [es] (eid : EntityId;
                          nexus_player_effect__owner : EntityId;
                          nexus_player_effect__template : string;
                          var nexus_player_effect__requestersCount : int&)
    if nexus_player_effect__owner != player_eid || nexus_player_effect__template != player_effect_template
      return false
    --nexus_player_effect__requestersCount
    if nexus_player_effect__requestersCount <= 0
      nexus_log("PLAYERS", "Disable effect '{player_effect_template}' for player<{player_eid}>")
      destroyEntity(eid)
    else
      nexus_log("PLAYERS", "Effect '{player_effect_template}' requesters count decreased for player<{player_eid}>")
    return true


[es(tag=server, REQUIRE=nexus_player)]
def nexus_player_lock_shooting(evt : CmdNexusLockShootingForPlayer;
                               eid aka player_eid : EntityId)
  nexus_player_effect_create_or_increase_reqeusters_count(player_eid, "nexus_mode_disable_shooting")


[es(tag=server, REQUIRE=nexus_player)]
def nexus_player_unlock_shooting(evt : CmdNexusUnlockShootingForPlayer;
                                 eid aka player_eid : EntityId)
  nexus_player_effect_destroy_or_decrease_reqeusters_count(player_eid, "nexus_mode_disable_shooting")


[es(tag=server, REQUIRE=nexus_player)]
def nexus_player_lock_input(evt : CmdNexusLockInputForPlayer;
                            eid aka player_eid : EntityId)
  nexus_player_effect_create_or_increase_reqeusters_count(player_eid, "nexus_mode_disable_input")


[es(tag=server, REQUIRE=nexus_player)]
def nexus_player_unlock_input(evt : CmdNexusUnlockInputForPlayer;
                              eid aka player_eid : EntityId)
  nexus_player_effect_destroy_or_decrease_reqeusters_count(player_eid, "nexus_mode_disable_input")


[es(tag=server, REQUIRE=nexus_player)]
def nexus_player_disable_movement(evt : CmdNexusLockMovementForPlayer;
                                  eid aka player_eid : EntityId)
  nexus_player_effect_create_or_increase_reqeusters_count(player_eid, "nexus_mode_disable_movement")


[es(tag=server, REQUIRE=nexus_player)]
def nexus_player_unlock_movement(evt : CmdNexusUnlockMovementForPlayer;
                                 eid aka player_eid : EntityId)
  nexus_player_effect_destroy_or_decrease_reqeusters_count(player_eid, "nexus_mode_disable_movement")
