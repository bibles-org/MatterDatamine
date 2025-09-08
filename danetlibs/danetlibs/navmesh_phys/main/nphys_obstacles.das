require ecs
require ecs.common
require math.base
require app
require DngWalkerai
require DagorMath
require danetlibs.navmesh_phys.main.nphys_common
require danetlibs.navmesh_phys.main.nphys_find_obstacles_common


[es(tag=server, on_appear)]
def init_obstacle_avoider(evt : Event; eid : EntityId; obstacle_avoider__updateInterval : float; var obstacle_avoider__updateAt : float&)
  obstacle_avoider__updateAt = get_sync_time() + obstacle_avoider__updateInterval * eid_frnd(eid)

[es(tag=server, before=beh_tree_update_es, REQUIRE_NOT=(deadEntity, nphys__disabled, nphys__customObstacles))]
def update_obstacles_around_path(act : UpdateStageInfoAct;
                                 eid : EntityId;
                                 obstacle_avoider__updateInterval : float;
                                 navmesh_phys__prevPos : float3;
                                 navmesh_phys__currentWalkVelocity : float3;
                                 nphys_pushable__unlockMovementAt : float = 0.0;
                                 var obstacle_avoider__updateAt : float&;
                                 var agent_obstacles : AgentObstacles)
  if act.curTime > obstacle_avoider__updateAt
    obstacle_avoider__updateAt = act.curTime + obstacle_avoider__updateInterval
    clear(agent_obstacles.obstacles)
    let destination = navmesh_phys__prevPos + x0z(navmesh_phys__currentWalkVelocity) * obstacle_avoider__updateInterval * 2.0
    find_obstacles(eid, nphys_pushable__unlockMovementAt < act.curTime, destination)

[es(tag=server, after=beh_tree_update_es, before=(update_navmesh_phys, nphys_push_update), REQUIRE_NOT=(deadEntity, nphys__disabled, nphys__no_obstacle_navigation))]
def navmesh_phys_avoid_obstacles(act : UpdateStageInfoAct;
                                 navmesh_phys__atTime : float;
                                 navmesh_phys__currentPos : float3;
                                 agent_obstacles : AgentObstacles;
                                 navmesh_phys__agentHeight : float = 2f;
                                 navmesh_phys__doorOpenerDist : float = 0f;
                                 navmesh_phys__currentWalkVelocity : float3;
                                 var navmesh_phys__immediateObstacleIdx : int?;
                                 var navmesh_phys__doorObstacleEid : EntityId?;
                                 var obstacle_avoider__penetration : float&;
                                 var navmesh_phys__wishWalkDir : float3&)
  if navmesh_phys__atTime < act.curTime
    var fakeEid : EntityId
    var fakeIdx : int
    //we're using transform but perhaps curPos is more relevant?
    navmesh_phys__wishWalkDir = navigate_around_obstacles(navmesh_phys__currentPos, navmesh_phys__wishWalkDir, navmesh_phys__agentHeight,
      navmesh_phys__doorOpenerDist, agent_obstacles, /*leading*/ 0.1,
      clamp(length(navmesh_phys__currentWalkVelocity), 2f, 5f),
      navmesh_phys__doorObstacleEid == null ? fakeEid : *navmesh_phys__doorObstacleEid, obstacle_avoider__penetration,
      navmesh_phys__immediateObstacleIdx == null ? fakeIdx : *navmesh_phys__immediateObstacleIdx)


[es(tag=server, before=nphys_push_update, REQUIRE_NOT=(deadEntity, nphys__disabled))]
def navmesh_phys_detect_stuck(act : UpdateStageInfoAct;
                              navmesh_phys__timeStep : float;
                              navmesh_phys__atTime : float;
                              navmesh_phys__currentWalkVelocity : float3;
                              navmesh_phys__currentPos : float3;
                              navmesh_phys__maxWalkSpeed : float;
                              navmesh_phys__wishWalkSpeed : float;
                              navmesh_phys__walkSpeedMult : float;
                              var stuck_detector__avgPos : float3&;
                              var stuck_detector__value : float&;
                              stuck_detector__posTau = 0.15;
                              stuck_detector__valueTau = 0.07)
  if navmesh_phys__atTime < act.curTime
    let fullSteps = ceil(safediv((act.curTime - navmesh_phys__atTime), navmesh_phys__timeStep))
    var speed = length(navmesh_phys__currentWalkVelocity)
    if speed == 0.0
      speed = navmesh_phys__maxWalkSpeed * navmesh_phys__wishWalkSpeed * navmesh_phys__walkSpeedMult
    //recalc tau in case fps is low and fullSteps is > 1
    let tau = safediv(fullSteps, ((1.0 / stuck_detector__posTau) + fullSteps - 1.0))

    stuck_detector__avgPos = (1.0 - tau) * stuck_detector__avgPos + tau * navmesh_phys__currentPos
    let step = speed * navmesh_phys__timeStep * fullSteps
    let expectedDiff = safediv(step * (1.0 - tau), tau) //Expected diff between avgPos and currentPos after inf time given the speed
    let actualDiff = length(stuck_detector__avgPos - navmesh_phys__currentPos)

    let newValue = expectedDiff > 0.0 ? max(0.0, expectedDiff - actualDiff) / expectedDiff : 0.0
    //if fullSteps > 1 valueTau should be greater too but it's not super important
    stuck_detector__value = ((1.0 - stuck_detector__valueTau) * stuck_detector__value +
                                        stuck_detector__valueTau * newValue)
