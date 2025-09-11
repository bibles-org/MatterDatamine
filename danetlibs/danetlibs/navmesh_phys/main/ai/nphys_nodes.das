options always_export_initializer = true
require ecs
require DagorSystem
require BehNodes
require DagorDataBlock
require DagorRandom
require ecs.common
require pathfinder
require math.base
require math.ang
require math.linear
require DagorMath
require DagorMathUtils
require AnimV20
require debug.logerr_once
require strings
require Grid
require GridCollision
require walkerai
require DngWalkerai
require RendInst
require CollRes
require DngBehTree // required for ECS_DECLARE_BOXED_TYPE(dtPathCorridor);
require DagorDebug3D
require danetlibs.navmesh_phys.main.nphys_common
require danetlibs.navmesh_phys.main.nphys_find_obstacles_common
require pathfinder
require danetlibs.navmesh_phys.main.ai.nphys_nodes_common


[beh_node(name="nPhysCorridorMoveToPos")]
class NPhysCorridorMoveToPos : NPhysCorridorMoveToPosBase {}

[beh_node(name="nPhysCorridorMoveToTarget")]
class NPhysCorridorMoveToTarget : NPhysCorridorMoveToTargetBase {}

[beh_node(name="nPhysCorridorMoveToDirectionalTarget")]
class NPhysCorridorMoveToDirectionalTarget : NPhysCorridorMoveToDirectionalTargetBase {}

[beh_node(name="nPhysLookAtPos")]
class NPhysLookAtPos : NPhysLookAtPosBase {}

[beh_node(name="nPhysLookAtDynPos")]
class NPhysLookAtDynPos : NPhysLookAtDynPosBase {}

[beh_node(name="nPhysLookAtEntity")]
class NPhysLookAtEntity : NPhysLookAtEntityBase {}

[beh_node(name="nPhysLookAtRi")]
class NPhysLookAtRi : NPhysLookAtRiBase {}

[beh_node(name="nPhysStareAtPos")]
class NPhysStareAtPos : NPhysLookAtPosBase
  override stare = true

[beh_node(name="nPhysStareAtEntity")]
class NPhysStareAtEntity : NPhysLookAtEntityBase
  override stare = true


[beh_node(name="nPhysStareAtRi")]
class NPhysStareAtRi : NPhysLookAtRiBase
  override stare = true


[beh_node(name="nPhysCorridorWriggleMoveToPos")]
class NPhysCorridorWriggleMoveToPos : NPhysCorridorMoveToPosBase

  def override update(dt : float) : EBehResult
    let res : EBehResult = AbstractNPhysCorridorMoveTo`update(self, dt)
    if res == EBehResult.ER_RUNNING
      let eid = beh_tree_eid(owner)
      query(eid) <| $ [es] (navmesh_phys__wriggleAmplitude : float;
                            navmesh_phys__wriggleFrequency : float;
                            var navmesh_phys__wishWalkDir : float3&)
        let rightDir = cross(navmesh_phys__wishWalkDir, float3(0.0, 1.0, 0.0))
        navmesh_phys__wishWalkDir += rightDir * sin(curTime * navmesh_phys__wriggleFrequency) * navmesh_phys__wriggleAmplitude
    return res


[beh_node(name="nPhysCorridorWriggleMoveToTarget")]
class NPhysCorridorWriggleMoveToTarget : NPhysCorridorMoveToPosBase

  def override update(dt : float) : EBehResult
    let res : EBehResult = AbstractNPhysCorridorMoveTo`update(self, dt)
    if res == EBehResult.ER_RUNNING
      let eid = beh_tree_eid(owner)
      query(eid) <| $ [es] (navmesh_phys__wriggleAmplitude : float;
                            navmesh_phys__wriggleFrequency : float;
                            var navmesh_phys__wishWalkDir : float3&)
        let rightDir = cross(navmesh_phys__wishWalkDir, float3(0.0, 1.0, 0.0))
        navmesh_phys__wishWalkDir += rightDir * sin(curTime * navmesh_phys__wriggleFrequency) * navmesh_phys__wriggleAmplitude
    return res

[beh_node(name="findDoorObstacle")]
class FindDoorObstacle : BehNodeAdapter
  traceDist : float = 1.0

  def override loadFromBlk(var data : DataBlock)
    traceDist = data |> datablock_getReal("traceDist", traceDist)
    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(navmesh_phys__wishLookDir,
                                      agent_dangers__standShootPos,
                                      walker_agent__standShootLocalPos,
                                      agent_obstacles,
                                      navmesh_phys__doorObstacleEid,
                                      door_obstacle_handler__immediateDoor))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> FindDoorObstacle is missing fields and will not function {*thisNode |> beh_node_hierarchy_name(true)}")

  def override update(dt : float) : EBehResult
    var res : EBehResult = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4;
                                          navmesh_phys__doorObstacleEid : EntityId;
                                          path_corridor__corners : Point3List;
                                          walker_agent__standShootLocalPos : float3;
                                          agent_obstacles : AgentObstacles;
                                          var door_obstacle_handler__immediateDoor : EntityId&)
      if doesEntityExist(navmesh_phys__doorObstacleEid)
        door_obstacle_handler__immediateDoor = navmesh_phys__doorObstacleEid
        res = EBehResult.ER_SUCCESS
        return
      let scale = float3(length(transform[0]), length(transform[1]), length(transform[2]))
      door_obstacle_handler__immediateDoor = trace_obstacles_along_path(agent_obstacles,
                                                                        transform[3],
                                                                        path_corridor__corners,
                                                                        walker_agent__standShootLocalPos * scale,
                                                                        traceDist) <| $(obstacle : ObstacleEx)
        var result = obstacle.isDoor
        if result
          query(obstacle.eid) <| $ [es] (rendinst_axis_rotation__targetAngle, door_operations__closedAngle : float)
            result = rendinst_axis_rotation__targetAngle == door_operations__closedAngle
        return result
      if door_obstacle_handler__immediateDoor != INVALID_ENTITY_ID
        res = EBehResult.ER_SUCCESS
    return res

[beh_node(name="findDestructableObstacle")]
class FindDestructableObstacle : BehNodeAdapter
  traceDist : float = 1.0

  def override loadFromBlk(var data : DataBlock)
    traceDist = data |> datablock_getReal("traceDist", traceDist)
    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(navmesh_phys__wishLookDir,
                                      agent_dangers__standShootPos,
                                      walker_agent__standShootLocalPos,
                                      agent_obstacles,
                                      destructable_obstacle_handler__isRi,
                                      destructable_obstacle_handler__targetEid))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> FindDestructableObstacle is missing fields and will not function {*thisNode |> beh_node_hierarchy_name(true)}")

  def override update(dt : float) : EBehResult
    var res : EBehResult = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4;
                                          path_corridor__corners : Point3List;
                                          walker_agent__standShootLocalPos : float3;
                                          agent_obstacles : AgentObstacles;
                                          var destructable_obstacle_handler__isRi : bool&;
                                          var destructable_obstacle_handler__targetEid : EntityId&)
      let scale = float3(length(transform[0]), length(transform[1]), length(transform[2]))
      destructable_obstacle_handler__targetEid = trace_obstacles_along_path(agent_obstacles,
                                                                            transform[3],
                                                                            path_corridor__corners,
                                                                            walker_agent__standShootLocalPos * scale,
                                                                            traceDist) <| $(obstacle : ObstacleEx)
        return has(obstacle.eid, "obstacle__isDestructible")
      destructable_obstacle_handler__isRi = has(destructable_obstacle_handler__targetEid, "ri_extra")
      if destructable_obstacle_handler__targetEid != INVALID_ENTITY_ID
        res = EBehResult.ER_SUCCESS
    return res

[beh_node(name="updateObstaclePenetration")]
class UpdateObstaclePenetration : BehNodeAdapter

  def override update(dt : float) : EBehResult
    var res : EBehResult = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (navmesh_phys__prevPos : float3;
                                          path_corridor__corners : Point3List;
                                          var agent_obstacles : AgentObstacles;
                                          var obstacle_avoider__penetration : float&)
      var segmentIdx : int
      var sidePos : float3
      let pos = navmesh_phys__prevPos
      obstacle_avoider__penetration = 0.0
      let obstaclesNotQueried = length(path_corridor__corners) == 0 && length(agent_obstacles.obstacles) == 0
      if obstaclesNotQueried
        find_obstacles(beh_tree_eid(owner), false, navmesh_phys__prevPos + float3(1, 0, 1))
      for obstacle in agent_obstacles.obstacles
        if test_is_inside_obstacle_ex(pos, obstacle, segmentIdx, sidePos)
          obstacle_avoider__penetration = max(obstacle_avoider__penetration, distance(pos, sidePos))
      if obstaclesNotQueried
        clear(agent_obstacles.obstacles)
      res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="nPhysForceAnimState")] // navmesh_phys_forced_anim_state template
class NPhysForceAnimState : BehNodeAdapter
  animState : string
  duration : float

  animStateId : int = -1

  waitTime : float = 0f

  def override loadFromBlk(var data : DataBlock)
    animState = data |> datablock_getStr("animState", animState)
    duration = data |> datablock_getReal("duration", duration)
    let eid = beh_tree_eid(owner)

    let found = query(eid) <| $ [es(REQUIRE=anim_state__forceAnimStateId)] (animchar : AnimcharBaseComponent)
      let animGraph = animchar.animGraph
      if animGraph != null
        animStateId = *animGraph |> anim_graph_getStateIdx(animState)

    if !found
      logerr("{eid}: <{getEntityTemplateName(eid)}> NPhysForceAnimState requires animchar and anim_state__forceAnimStateId fields")

  def override init()
    waitTime = duration

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (var anim_state__forceAnimStateId : int&)
      waitTime -= dt
      if waitTime > 0f
        res = EBehResult.ER_RUNNING
        anim_state__forceAnimStateId = animStateId
      else
        res = EBehResult.ER_SUCCESS
        if anim_state__forceAnimStateId == animStateId
          anim_state__forceAnimStateId = -1
    return res

  def override exit()
    if waitTime > 0f
      query(beh_tree_eid(owner)) <| $ [es] (var anim_state__forceAnimStateId : int&)
        if anim_state__forceAnimStateId == animStateId
          anim_state__forceAnimStateId = -1


[beh_node(name="isNphysEnabled")]
class IsNphysEnabled : BehNodeAdapter

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es(REQUIRE=navmeshPhys, REQUIRE_NOT=nphys__disabled)] ()
      res = EBehResult.ER_SUCCESS
    return res