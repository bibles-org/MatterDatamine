module spawn_base shared
require ecs
require app
require DagorRandom
require DagorSystem
require math.base
require game.utils.team
require game.es.stat_bq_common
require game.es.ecs_common
require game.es.spawn_common


def get_closest_dist_sq(to_pos : float3;
                        positions : array<float3>) : float
  var closestDistSq = -1.0
  for pos in positions
    let distSq = distance_sq(pos, to_pos)
    if closestDistSq < 0.0 || distSq < closestDistSq
      closestDistSq = distSq
  return closestDistSq


def get_spawn_bases_full_info()
  var info : string
  query() <| $ [es(REQUIRE=respbase)] (eid : EntityId;
                                       active : bool;
                                       team : int;
                                       spawnBase__spawnGroupId : int = -1;
                                       transform : float3x4)
    info = "{info}[{get_entity_info(eid)}]: active={active} team={team} spawnBase__spawnGroupId={spawnBase__spawnGroupId} pos={transform[3]}\n"
  return <- info


def get_spawn_bases() : array<tuple<eid : EntityId; team : int; transform : float3x4>>
  var spawnBases : array<tuple<eid : EntityId; team : int; transform : float3x4>>
  query() <| $ [es(REQUIRE=respbase)] (eid : EntityId; active : bool; team : int; transform : float3x4)
    if active
      spawnBases |> emplace((eid, team, transform))
  if length(spawnBases) == 0
    logerr("[GET SPAWN BASES] No spawn bases found in world.
SPAWN BASES:
{get_spawn_bases_full_info()}")
  return <- spawnBases


def get_spawn_bases_for_team(team_id, wishSpawnPlaceId : int) : array<tuple<eid : EntityId; team : int; transform : float3x4>>
  var allSpawnBases <- get_spawn_bases()
  var spawnBasesForTeam : array<tuple<eid : EntityId; team : int; transform : float3x4>>
  for spawnBase in allSpawnBases
    query(spawnBase.eid) <| $ [es] (spawnBase__spawnGroupId = -1)
      if (spawnBase.team == team_id || spawnBase.team == TEAM_UNASSIGNED) && (wishSpawnPlaceId == -1 || spawnBase__spawnGroupId == wishSpawnPlaceId)
        spawnBasesForTeam |> emplace((spawnBase.eid, spawnBase.team, spawnBase.transform))
  if length(spawnBasesForTeam) == 0
    logerr("[GET SPAWN BASES] No spawn bases for team {team_id} found in world, trying fallback for all spawn bases with wishSpawnPlaceId {wishSpawnPlaceId}.
SPAWN BASES:
{get_spawn_bases_full_info()}")
    for spawnBase in allSpawnBases
      query(spawnBase.eid) <| $ [es] (spawnBase__spawnGroupId = -1)
        if (wishSpawnPlaceId == -1 || spawnBase__spawnGroupId == wishSpawnPlaceId)
          spawnBasesForTeam |> emplace((spawnBase.eid, spawnBase.team, spawnBase.transform))
  if length(spawnBasesForTeam) == 0
    logerr("[GET SPAWN BASES] No spawn bases with wishSpawnPlaceId {wishSpawnPlaceId} found in world, trying fallback for all spawn bases.
SPAWN BASES:
{get_spawn_bases_full_info()}")
    return <- allSpawnBases
  return <- spawnBasesForTeam


def get_random_spawn_base(bases : array<tuple<eid : EntityId; team : int; transform : float3x4>>) : EntityId
  return bases[rnd_int(0, length(bases) - 1)].eid


def get_time_to_consider_spawn_bases_dangerous()
  return 600.0


def find_spawn_base_danger_positions(team_id : int)
  var dangerPositions : array<float3>

  // spawned team
  query() <| $ [es] (transform : float3x4;
                     team : int;
                     isAlive : bool;
                     countAsAlive : bool)
    if countAsAlive && isAlive && !is_teams_friendly(team, team_id)
      dangerPositions |> push(transform[3])

  // team is spawning
  if get_sync_time() < get_time_to_consider_spawn_bases_dangerous()
    query() <| $ [es(REQUIRE=respbase)] (transform : float3x4; team : int)
      if team != TEAM_UNASSIGNED && !is_teams_friendly(team, team_id)
        dangerPositions |> push(transform[3])

  return <- dangerPositions


def find_spawn_base_danger_positions_players_only(team_id : int = TEAM_UNASSIGNED)
  var dangerPositions : array<float3>

  // spawned team
  query() <| $ [es] (transform : float3x4;
                     team : int;
                     isAlive : bool;
                     countAsAlive : bool;
                     possessedByPlr : EntityId)
    if countAsAlive && isAlive && !is_teams_friendly(team, team_id)
      query(possessedByPlr) <| $ [es] (playerIsBot : Tag const?)
        if playerIsBot == null
          dangerPositions |> push(transform[3])

  // team is spawning
  if get_sync_time() < get_time_to_consider_spawn_bases_dangerous()
    query() <| $ [es(REQUIRE=respbase)] (transform : float3x4; team : int)
      if team != TEAM_UNASSIGNED && !is_teams_friendly(team, team_id) && is_player_team(team)
        dangerPositions |> push(transform[3])

  return <- dangerPositions


def find_spawn_base(team_id : int;
                    wishSpawnPlaceId = -1) : FindSpawnBaseResult
  let spawnBases <- get_spawn_bases_for_team(team_id, wishSpawnPlaceId)
  if length(spawnBases) == 0
    return FindSpawnBaseResult(baseEid = INVALID_ENTITY_ID,
                               resultType = FindSpawnBaseResultType.SPAWN_BASES_NOT_FOUND)

  var validByTeamSpawnBases : array<tuple<eid : EntityId; team : int; transform : float3x4>>
  for spawnBase in spawnBases
    if spawnBase.team == team_id
      validByTeamSpawnBases |> push(spawnBase)

  if length(validByTeamSpawnBases) > 0
    return FindSpawnBaseResult(baseEid = get_random_spawn_base(validByTeamSpawnBases),
                               resultType = FindSpawnBaseResultType.RANDOM_FROM_TEAM_SPAWNS)


  var dangerPositions <- find_spawn_base_danger_positions(team_id)

  if length(dangerPositions) == 0 // no danger, choose random spawn
    return FindSpawnBaseResult(baseEid = get_random_spawn_base(spawnBases),
                               resultType = FindSpawnBaseResultType.RANDOM_NO_ENEMIES)

  var bestEffortBase = INVALID_ENTITY_ID
  var bestBaseDistToEnemySq = 0.0
  for spawnBase in spawnBases
    let enemyDistSq = get_closest_dist_sq(spawnBase.transform[3], dangerPositions)
    if enemyDistSq >= 0.0 && enemyDistSq > bestBaseDistToEnemySq
      bestBaseDistToEnemySq = enemyDistSq
      bestEffortBase = spawnBase.eid
    if enemyDistSq >= square(150.0) // 150.0 meters
      validByTeamSpawnBases |> push(spawnBase)

  if length(validByTeamSpawnBases) > 0
    return FindSpawnBaseResult(baseEid = get_random_spawn_base(validByTeamSpawnBases),
                               resultType = FindSpawnBaseResultType.RANDOM_FROM_SAFEST,
                               bestBaseDistToEnemySq = bestBaseDistToEnemySq,
                               dangerPositions <- dangerPositions)

  if (bestEffortBase == INVALID_ENTITY_ID)
    return FindSpawnBaseResult(baseEid = get_random_spawn_base(spawnBases),
                               resultType = FindSpawnBaseResultType.RANDOM,
                               bestBaseDistToEnemySq = bestBaseDistToEnemySq,
                               dangerPositions <- dangerPositions)

  return FindSpawnBaseResult(baseEid = bestEffortBase,
                             resultType = FindSpawnBaseResultType.FOUND_BEST,
                             bestBaseDistToEnemySq = bestBaseDistToEnemySq,
                             dangerPositions <- dangerPositions)


def mark_respawn_base(player_team : int;
                      base_eid : EntityId;
                      unmark_after_spawns : int = -1)
  print("[RAID] Marking spawn base <{base_eid}> for team {player_team}")
  let teamEid = get_team_eid(player_team)
  query(teamEid) <| $ [es] (team__markSpawnBase : bool)
    if !team__markSpawnBase
      return
    query(base_eid) <| $ [es] (var team : int&; var respawn_raid__unmarkAfterSpawns : int?)
      team = player_team
      if respawn_raid__unmarkAfterSpawns != null
        *respawn_raid__unmarkAfterSpawns = unmark_after_spawns
  query(teamEid) <| $ [es] (var team__spawnGroupId : int&)
    query(base_eid) <| $ [es] (spawnBase__spawnGroupId : int)
      team__spawnGroupId = spawnBase__spawnGroupId