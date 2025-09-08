require ecs
require math
require math.base
require game.events.events
require pathfinder
require DagorSystem
require danetlibs.swarm.main.swarm_events


let
  VERY_BIG_NUMBER = square(10000.0)


[es(tag=server)]
def jellyfish_boid_died(evt : EventSomeSwarmBoidDied;
                        transform : float3x4;
                        jellyfish__escapeRad : float;
                        am_habitat_swarm__minHeight : float;
                        var swarm_cluster__targetPos : float3&)
  var minEnemyDist = VERY_BIG_NUMBER
  var enemyPos = transform[3]
  let swarmPos = transform[3]
  query() <| $ [es(REQUIRE=possessedByPlr)] (isAlive : bool; transform : float3x4)
    let distSq = length_sq(transform[3] - swarmPos)
    if isAlive && distSq < minEnemyDist
      minEnemyDist = distSq
      enemyPos = transform[3]

  if minEnemyDist < VERY_BIG_NUMBER
    var direction = (swarmPos - enemyPos)
    direction = normalize(float3(direction.x, 0.0, direction.z))
    swarm_cluster__targetPos = swarmPos + direction * jellyfish__escapeRad
    project_to_nearest_navmesh_point(swarm_cluster__targetPos, 10.0)
    swarm_cluster__targetPos += float3(0.0, am_habitat_swarm__minHeight, 0.0)
