module spawn_common shared
require ecs
require math.base
require DngActor
require DagorSystem
require DagorMath
require DagorRandom
require Grid
require game.es.server_debug_common
require pathfinder
require DngNet


enum SpawnSequenceControllerState
  INIT
  INIT_REQUEST
  SEQUENCE
  DONE


enum FindSpawnBaseResultType
  NONE
  SPAWN_BASES_NOT_FOUND
  RANDOM_FROM_TEAM_SPAWNS
  RANDOM_NO_ENEMIES
  RANDOM_FROM_SAFEST
  RANDOM
  FOUND_BEST


struct FindSpawnBaseResult
  baseEid : EntityId
  resultType : FindSpawnBaseResultType
  bestBaseDistToEnemySq : float
  dangerPositions : array<float3>


def find_safe_spawn_pos(team aka player_team : int;
                        safe_spawn_rad : float = 100.0)
  var saveRespawnTransforms : array<float3x4>
  var bestOtherRespawnTransform : tuple<rad : float; tm : float3x4>
  bestOtherRespawnTransform.tm = IDENT_TM
  query() <| $ [es(REQUIRE=respbase)] (transform : float3x4; active : bool)
    if active
      let sphere = BSphere3(transform[3], safe_spawn_rad)
      var enemySqRadius = 0f
      let nearEnemy = find_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.POS) <| $(enemyEid : EntityId; enemyPos : float3)
        var result = false
        query(enemyEid) <| $ [es(REQUIRE=human)] (isAlive : bool; team aka human_team : int)
          result = isAlive && human_team != player_team
          enemySqRadius = length_sq(enemyPos - transform[3])
        return result
      if nearEnemy == INVALID_ENTITY_ID
        saveRespawnTransforms |> push(transform)
      else
        if enemySqRadius >= bestOtherRespawnTransform.rad
          bestOtherRespawnTransform.rad = enemySqRadius
          bestOtherRespawnTransform.tm = transform

  if length(saveRespawnTransforms) == 0 && bestOtherRespawnTransform.rad == 0f // fallback to any spawn
    find_query() <| $ [es(REQUIRE=respbase)] (transform : float3x4; active : bool)
      if active
        saveRespawnTransforms |> push(transform)
      return active
  let tm = length(saveRespawnTransforms) != 0 ? saveRespawnTransforms[grnd() % length(saveRespawnTransforms)] : bestOtherRespawnTransform.tm

  var navPos = tm[3]
  project_to_nearest_navmesh_point(navPos, 3.0)
  return navPos