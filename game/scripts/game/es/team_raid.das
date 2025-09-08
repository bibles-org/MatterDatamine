require ecs
require ecs.common
require game.utils.spawn_base
require game.events.events_game
require game.es.level_common
require game.es.spawn_common
require game.es.ecs_common
require game.es.player_common
require player


[es(tag=server, on_appear, REQUIRE_NOT=xenos_team)]
def assign_spawn_base_to_team(evt : Event;
                              eid aka team_eid : EntityId;
                              team__id, team__spawnPlaceId : int;
                              var team__spawnBaseEid : EntityId&)
  if team__spawnBaseEid == INVALID_ENTITY_ID
    let findSpawnBaseResult = find_spawn_base(team__id, team__spawnPlaceId)
    team__spawnBaseEid = findSpawnBaseResult.baseEid

    var spawnBasePos : float3
    var distToEnemySq = 0.0
    query(team__spawnBaseEid) <| $ [es] (transform aka spawn_base_transform : float3x4)
      spawnBasePos = spawn_base_transform[3]
      distToEnemySq = get_closest_dist_sq(spawnBasePos, findSpawnBaseResult.dangerPositions)

    // win32 could not handle format string with large number of arguments
    // so we use string concatenation instead
    var logMsg = "[SPAWN BASE] Init spawn base for team {team__id}!"
    logMsg = "{logMsg} team_eid = {get_entity_info(team_eid)}"
    logMsg = "{logMsg} team__spawnPlaceId = {team__spawnPlaceId}"
    logMsg = "{logMsg} team__spawnBaseEid = {get_entity_info(team__spawnBaseEid)}"
    logMsg = "{logMsg} spawnBasePos = {spawnBasePos}"
    logMsg = "{logMsg} findSpawnBaseResultType = {findSpawnBaseResult.resultType}"
    logMsg = "{logMsg} distToEnemy = {distToEnemySq > 0.0 ? sqrt(distToEnemySq) : 0.0}"
    logMsg = "{logMsg} bestBaseDistToEnemy = {findSpawnBaseResult.bestBaseDistToEnemySq > 0.0 ? sqrt(findSpawnBaseResult.bestBaseDistToEnemySq) : 0.0}"
    print(logMsg)

  query(team__spawnBaseEid) <| $ [es] (var team : int&)
    team = team__id


[es(tag=server, on_event=EventPlayerFirstSpawn)]
def unmark_spawn_base_on_spawn(evt : Event; eid aka player_eid : EntityId; team aka player_team : int)
  if player_team == TEAM_UNASSIGNED
    error("[RAID] Player <{player_eid}> has no team assigned on first spawn")
    return
  if !is_raid_mode()
    return

  find_query() <| $ [es(REQUIRE=respbase)] (eid aka base_eid : EntityId;
                                            var respawn_raid__unmarkAfterSpawns : int&;
                                            var team aka base_team : int&)
    if player_team != base_team
      return false
    if respawn_raid__unmarkAfterSpawns <= 0
      error("[RAID] Spawn base <{base_eid}> for team {base_team} on player <{player_eid}> unmarkAfterSpawns is already 0")
      return true

    respawn_raid__unmarkAfterSpawns -= 1
    print("[RAID] Unmarking spawn base <{base_eid}> for team {base_team} on player <{player_eid}> first spawn. Waiting for {respawn_raid__unmarkAfterSpawns} more spawns to unmark")
    if respawn_raid__unmarkAfterSpawns == 0
      base_team = TEAM_UNASSIGNED
    return true
