/*
require app
require ecs
require DngNet
require player
require ecs.safe
require daslib.algorithm
require math.random
require DagorSystem
require game.events.events_game
require game.events.player_events
require game.events.events_active_matter
require game.es.item_equip_common
require game.es.game_end_reasons_common
require game.es.endgame_common
require game.es.nexus_common


def are_there_available_loadouts(nexus_battle_loadouts__availableLoadouts : Array)
  for index in iter_range(nexus_battle_loadouts__availableLoadouts)
    var loadoutPtr = nexus_battle_loadouts__availableLoadouts[index] as Object
    if loadoutPtr == null
      continue

    assume loadout = *loadoutPtr
    let loadoutCount = loadout.count ?? 0

    if loadoutCount > 0
      return true
  return false


// looser_team == TEAM_UNASSIGNED means both teams loose
def finish_battle(looser_team : int)
  var alreadyFinished = false
  find_query() <| $ [es(REQUIRE_NOT=nexus_round_mode_game_controller)] (var nexus_game_controller__isBattleFinished : bool&)
    alreadyFinished = nexus_game_controller__isBattleFinished
    nexus_game_controller__isBattleFinished = true
    return true
  if alreadyFinished
    return

  query() <| $ [es] (team__id : int; team__memberEids : EidList)
    if team__id == looser_team || looser_team == TEAM_UNASSIGNED
      send_team_endgame_result(team__id, team__memberEids, false, int(GameEndReasons NEXUS_BATTLE_LOST), true)
    else
      send_team_endgame_result(team__id, team__memberEids, false, int(GameEndReasons NEXUS_BATTLE_WON), true)

  createEntity("nexus_battle_session_finisher")


def is_nexus_battle_in_progress()
  let portalDidntEvict = find_query() <| $ [es(REQUIRE_NOT=nexus_round_mode_game_controller)] (nexus_game_controller__isBattleFinished : bool; nexus_game_controller__activatedPortal : EntityId)
    var state = -1
    query(nexus_game_controller__activatedPortal) <| $ [es] (nexus_portal__state : int)
      state = nexus_portal__state
    return !nexus_game_controller__isBattleFinished && state != int(NexusPortalStates FINISHED_EVICTING)

  let isZoneActive = find_query() <| $ [es(REQUIRE=moving_zone__targetPos)] (active : bool)
    return active

  return portalDidntEvict && !isZoneActive


def find_available_loadout_index(nexus_battle_loadouts__availableLoadouts : Array)
  for index in iter_range(nexus_battle_loadouts__availableLoadouts)
    var loadoutPtr = nexus_battle_loadouts__availableLoadouts[index] as Object
    if loadoutPtr == null
      continue

    assume loadout = *loadoutPtr
    let isPrivate = loadout.isPrivate ?? false
    let maxDeployed = loadout.maxDeployed ?? 0
    let deploymentLimit = maxDeployed - loadout.curDeployed ?? 0
    let selectedLoadoutCount = loadout.count ?? 0

    if isPrivate || selectedLoadoutCount <= 0 || (maxDeployed > 0 && deploymentLimit <= 0)
      continue
    return index
  return -1


def resolve_private_loadout_pretendents(target_team : int = TEAM_UNASSIGNED)
  query() <| $ [es] (team aka loadout_team : int; var nexus_battle_loadouts__availableLoadouts : Array)
    if target_team != TEAM_UNASSIGNED && target_team != loadout_team
      return
    var loadoutPretendents : array<array<EntityId>> // loadout index -> list of players
    resize(loadoutPretendents, length(nexus_battle_loadouts__availableLoadouts))

    query() <| $ [es] (team aka player_team : int
                       nexus_player_loadout__chosenIndex : int
                       eid aka player_eid : EntityId
                       possessed : EntityId)
      var isPossessedAlive = false
      query(possessed) <| $ [es] (isAlive : bool)
        isPossessedAlive = isAlive

      if player_team != loadout_team || isPossessedAlive
        return

      assume index = nexus_player_loadout__chosenIndex
      if index < 0 || index >= length(nexus_battle_loadouts__availableLoadouts)
        return

      var loadoutPtr = nexus_battle_loadouts__availableLoadouts[index] as Object
      if loadoutPtr == null
        return

      assume loadout = *loadoutPtr
      let isPrivate = loadout.isPrivate ?? false
      if isPrivate
        push(loadoutPretendents[index], player_eid)

    for loadoutIndex in iter_range(loadoutPretendents)
      assume pretendents = loadoutPretendents[loadoutIndex]
      var loadoutPtr = nexus_battle_loadouts__availableLoadouts[loadoutIndex] as Object
      if loadoutPtr == null
        continue
      assume loadout = *loadoutPtr
      let maxDeployed = loadout.maxDeployed ?? 0
      let deploymentLimit = max(maxDeployed - loadout.curDeployed ?? 0, 0)
      let slotsAvailable = maxDeployed > 0 ? min(loadout.count ?? 0, deploymentLimit) : loadout.count ?? 0
      if length(pretendents) <= slotsAvailable
        continue

      // first few pretendents are chosen
      shuffle(pretendents)

      for pretendentIndex in range(slotsAvailable, length(pretendents))
        query(pretendents[pretendentIndex]) <| $ [es] (var nexus_player_loadout__chosenIndex : int&)
          let alternativeLoadout = find_available_loadout_index(nexus_battle_loadouts__availableLoadouts)
          if alternativeLoadout == -1
            nexus_player_loadout__chosenIndex = -1
            return
          var alternativeLoadoutPtr = nexus_battle_loadouts__availableLoadouts[alternativeLoadout] as Object
          if alternativeLoadoutPtr == null
            nexus_player_loadout__chosenIndex = -1
            return
          set(*alternativeLoadoutPtr, "count", ((*alternativeLoadoutPtr).count ?? 0) - 1)
          nexus_player_loadout__chosenIndex = alternativeLoadout


def process_spawn_wave(var players_to_spawn : EidList
                       target_team : int = TEAM_UNASSIGNED
                       spawn_sequence_delay : float = 1.0
                       spawn_undecided : bool = false)
  resolve_private_loadout_pretendents(target_team)
  var spawnedPlayers : array<int>
  for player, index in players_to_spawn, iter_range(players_to_spawn)
    if target_team != TEAM_UNASSIGNED
      var wrongTeam = false
      query(player) <| $ [es] (team aka player_team : int)
        wrongTeam = player_team != target_team
      if wrongTeam
        continue

    if spawn_undecided
      query(player) <| $ [es] (var nexus_player_loadout__chosenIndex : int&; team aka player_team : int)
        if nexus_player_loadout__chosenIndex < 0
          find_query() <| $ [es] (team : int
                                  nexus_battle_loadouts__availableLoadouts : Array)
            if team != player_team
              return false
            nexus_player_loadout__chosenIndex = find_available_loadout_index(nexus_battle_loadouts__availableLoadouts)
            return true

    if give_loadout_to_nexus_player(player)
      send_net_event(player, [[CmdScheduleSpawnEntityForPlayer spawnAt=get_sync_time() + spawn_sequence_delay]])
      push(spawnedPlayers, index)

  reverse(spawnedPlayers)
  for i in spawnedPlayers
    erase(players_to_spawn, i)


[es(tag=server, no_order, REQUIRE_NOT=nexus_round_mode_spawn_controller)]
def update_nexus_spawn_controller(update : ParallelUpdateFrameDelayed
                                  nexus_spawn_controller__spawnSequenceDelay : float
                                  var nexus_spawn_controller__spawnAt : float&
                                  var nexus_spawn_controller__didSpawn : bool&
                                  var nexus_spawn_controller__playersToSpawn : EidList)
  if update.curTime < nexus_spawn_controller__spawnAt || nexus_spawn_controller__spawnAt < 0.0
    return

  nexus_spawn_controller__spawnAt = -1.0
  if !is_nexus_battle_in_progress()
    return

  process_spawn_wave(nexus_spawn_controller__playersToSpawn,
                     TEAM_UNASSIGNED,
                     nexus_spawn_controller__spawnSequenceDelay,
                     true)

  nexus_spawn_controller__didSpawn = true


[es(tag=server, track=nexus_player_loadout__chosenIndex)]
def nexus_start_additional_spawn_wave(evt : Event
                                      nexus_player_loadout__chosenIndex : int
                                      eid aka player_eid : EntityId
                                      team aka player_team : int)
  if nexus_player_loadout__chosenIndex < 0
    return

  find_query() <| $ [es] (team aka additional_spawner_team : int
                          nexus_wave_mode_additional_waves_spawn_controller__spawnDelay : float
                          nexus_wave_mode_additional_waves_spawn_controller__numWaves : int
                          nexus_wave_mode_additional_waves_spawn_controller__wavesSpawned : int
                          var nexus_wave_mode_additional_waves_spawn_controller__spawnAt : float&)
    if additional_spawner_team != player_team
      return false

    if nexus_wave_mode_additional_waves_spawn_controller__spawnAt > 0.0
      // wave spawn is already in progress
      return true

    if nexus_wave_mode_additional_waves_spawn_controller__numWaves == nexus_wave_mode_additional_waves_spawn_controller__wavesSpawned
      // no more waves can be spawned
      return true

    let startWave = find_query() <| $ [es] (nexus_spawn_controller__playersToSpawn : EidList; nexus_spawn_controller__didSpawn : bool)
      if !nexus_spawn_controller__didSpawn || !has_value(nexus_spawn_controller__playersToSpawn, player_eid)
        return false
      return true

    if !startWave
      return true

    nexus_wave_mode_additional_waves_spawn_controller__spawnAt = get_sync_time() + nexus_wave_mode_additional_waves_spawn_controller__spawnDelay
    return true


[es(no_order, tag=server)]
def nexus_process_additional_spawn_wave(update : ParallelUpdateFrameDelayed
                                        team aka additional_spawner_team : int
                                        nexus_spawn_controller__spawnSequenceDelay : float
                                        var nexus_wave_mode_additional_waves_spawn_controller__wavesSpawned : int&
                                        var nexus_wave_mode_additional_waves_spawn_controller__spawnAt : float&)
  assume spawnAt = nexus_wave_mode_additional_waves_spawn_controller__spawnAt
  if spawnAt < 0.0 || get_sync_time() < spawnAt
    return

  spawnAt = -1.0
  nexus_wave_mode_additional_waves_spawn_controller__wavesSpawned += 1

  if !is_nexus_battle_in_progress()
    return

  find_query() <| $ [es] (var nexus_spawn_controller__playersToSpawn : EidList)
    process_spawn_wave(nexus_spawn_controller__playersToSpawn,
                       additional_spawner_team,
                       nexus_spawn_controller__spawnSequenceDelay)
    return true


[es(track=nexus_portal__state, tag=server, REQUIRE_NOT=nexus_round_mode_beacon)]
def nexus_portal_evict(evt : Event
                       nexus_portal__state : int
                       nexus_portal__controllingTeam : int
                       nexus_portal__zoneDamageAfterEvict : float
                       nexus_portal__zoneContractionTimeAfterEvict : float
                       transform aka nexus_portal_transform : float3x4)
  if nexus_portal__state != int(NexusPortalStates FINISHED_EVICTING)
    return

  let isOtherTeamAlive = find_query() <| $ [es(REQUIRE=nexus_militant)] (team : int; isAlive : bool)
    if team == nexus_portal__controllingTeam
      return false
    return isAlive

  if !isOtherTeamAlive
    let looserTeam = (nexus_portal__controllingTeam == int(NexusTeam SECOND) ? int(NexusTeam FIRST) : int(NexusTeam SECOND))
    finish_battle(looserTeam)

  find_query() <| $ [es] (var active : bool&
                          var dmgzone__teamToDamage : int&
                          var dmgzone__damage : float&
                          var moving_zone__targetPos : float3&
                          var moving_zone__targetRadius : float&
                          var moving_zone__startEndTime : float2&)
    active = true
    dmgzone__damage = nexus_portal__zoneDamageAfterEvict
    dmgzone__teamToDamage = nexus_portal__controllingTeam == int(NexusTeam SECOND) ? int(NexusTeam FIRST) : int(NexusTeam SECOND)
    moving_zone__targetPos = nexus_portal_transform[3]
    moving_zone__targetRadius = 0.0
    moving_zone__startEndTime.x = get_sync_time()
    moving_zone__startEndTime.y = get_sync_time() + nexus_portal__zoneContractionTimeAfterEvict
    return true


[es(tag=server, REQUIRE=nexus_militant, REQUIRE_NOT=nexus_round_mode_militant)]
def nexus_battle_finish_battle(evt : EventEntityDied; possessedByPlr : EntityId; team aka victim_team : int)
  let isAnyTeammateAlive = find_query() <| $ [es(REQUIRE=nexus_militant, REQUIRE_NOT=deadEntity)] (team : int; isAlive : bool)
    if !isAlive // deadEntity tag may be delayed
      return false
    if team == victim_team
      return true
    return false

  let areLoadoutsAvailable = find_query() <| $ [es] (team aka loadout_team : int; nexus_battle_loadouts__availableLoadouts : Array)
    if loadout_team != victim_team
      return false
    return are_there_available_loadouts(nexus_battle_loadouts__availableLoadouts)

  let areRespawnsAvailable = find_query() <| $ [es] (team aka respawner_team : int
                                                     nexus_wave_mode_additional_waves_spawn_controller__wavesSpawned : int
                                                     nexus_wave_mode_additional_waves_spawn_controller__numWaves : int)
    if respawner_team != victim_team
      return false
    return nexus_wave_mode_additional_waves_spawn_controller__wavesSpawned < nexus_wave_mode_additional_waves_spawn_controller__numWaves

  var notControlingTeam = -1
  let isEvictionFinished = find_query() <| $ [es(REQUIRE=nexus_portal)] (nexus_portal__state : int; nexus_portal__controllingTeam : int)
    notControlingTeam = (nexus_portal__controllingTeam == int(NexusTeam SECOND) ? int(NexusTeam FIRST) :
                         nexus_portal__controllingTeam == int(NexusTeam FIRST) ? int(NexusTeam SECOND) : -1)
    return nexus_portal__state == int(NexusPortalStates FINISHED_EVICTING)

  let canTeammatesRespawn = areLoadoutsAvailable && areRespawnsAvailable
  if isAnyTeammateAlive || (!isEvictionFinished && canTeammatesRespawn) // battle doesn't end yet
    send_player_endgame_result(victim_team, possessedByPlr, true, int(GameEndReasons NEXUS_BATTLE_DIED), false)
    return

  let isZoneActive = find_query() <| $ [es(REQUIRE=moving_zone__targetPos)] (active : bool)
    return active

  // zone is activated by the draw timer -> its to late to win by killing everyone
  if !isEvictionFinished && isZoneActive
    return

  // all teammates of victim are dead
  // eviction is finished or teammates can't respawn
  finish_battle(!isEvictionFinished ? victim_team : notControlingTeam)


[es(tag=server, on_event=EventLevelLoaded, after=moving_zone_init)]
def init_nexus_draw_time(evt : Event
                         nexus_wave_mode_game_controller__timeBeforeDraw : float
                         nexus_wave_mode_game_controller__onDrawZoneCollapseTime : float
                         var nexus_wave_mode_game_controller__activateDrawZoneAt : float&
                         var nexus_wave_mode_game_controller__drawAt : float&)
  let curTime = get_sync_time()
  nexus_wave_mode_game_controller__activateDrawZoneAt = curTime + nexus_wave_mode_game_controller__timeBeforeDraw
  nexus_wave_mode_game_controller__drawAt = nexus_wave_mode_game_controller__activateDrawZoneAt + nexus_wave_mode_game_controller__onDrawZoneCollapseTime
  find_query() <| $ [es] (nexus_portal__zoneDamageAfterEvict : float; transform : float3x4)
    find_query() <| $ [es] (var active : bool&
                            var dmgzone__teamToDamage : int&
                            var dmgzone__damage : float&
                            var moving_zone__targetPos : float3&
                            var moving_zone__targetRadius : float&
                            var moving_zone__startEndTime : float2&)
      active = false
      dmgzone__damage = nexus_portal__zoneDamageAfterEvict
      dmgzone__teamToDamage = TEAM_UNASSIGNED
      moving_zone__targetPos = transform[3]
      moving_zone__startEndTime.x = curTime + nexus_wave_mode_game_controller__timeBeforeDraw
      moving_zone__startEndTime.y = moving_zone__startEndTime.x + nexus_wave_mode_game_controller__onDrawZoneCollapseTime
      moving_zone__targetRadius = 0.0
      return true
    return true


[es(tag=server, REQUIRE=nexus_wave_mode)]
def nexus_battle_finish_in_draw(evt : EventNexusBattleDraw)
  finish_battle(TEAM_UNASSIGNED)


[es(tag=server, no_order)]
def nexus_trigger_draw_on_timer(upd : UpdateStageInfoAct
                                nexus_wave_mode_game_controller__drawAt : float
                                var nexus_wave_mode_game_controller__activateDrawZoneAt : float&)
  let curTime = get_sync_time()
  if nexus_wave_mode_game_controller__activateDrawZoneAt > 0.0 && nexus_wave_mode_game_controller__activateDrawZoneAt < curTime
    nexus_wave_mode_game_controller__activateDrawZoneAt = -1.0
    find_query() <| $ [es(REQUIRE=moving_zone__targetPos)] (var active : bool&)
      active = true
      return true
    return

  if nexus_wave_mode_game_controller__drawAt < 0.0 || nexus_wave_mode_game_controller__drawAt > curTime
    return

  broadcastEvent([[EventNexusBattleDraw]])


[es(tag=server)]
def server_nexus_battle_request_join_spawn_queue(evt : CmdNexusBattleJoinSpawnQueue
                                                 eid aka player_eid : EntityId
                                                 var nexus_player_loadout__takenIndex : int&)
  if !is_nexus_battle_in_progress()
    return

  send_net_event(player_eid, [[CmdNexusBattleSelectLoadout loadoutIndex=nexus_player_loadout__takenIndex, selectAnyIfUnavailable=true]])
  nexus_player_loadout__takenIndex = -1
*/
