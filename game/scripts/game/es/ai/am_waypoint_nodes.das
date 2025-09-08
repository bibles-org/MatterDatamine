options always_export_initializer = true

require app
require ecs
require ecs.common
require strings
require DagorSystem
require BehNodes
require DagorDataBlock
require Dacoll
require Grid
require GridCollision
require pathfinder
require math.base
require math.random
require DagorMath
require debug.logerr_once
require game.es.protected_am_core_common
require game.es.level_common
require game.es.grav_zones_common
require game.es.wandering_core_common


def is_waypoint_valid(pos : float3;
                      indoor_threshold = 0.5)
  var waterLevel = 0.0
  let hasWater = traceht_water(pos, waterLevel)
  if hasWater && waterLevel > pos.y
    return false

  if level_common::is_pos_indoor(pos, indoor_threshold)
    return false

  return true


def randomize_waypoints_height(var waypoints : Point3List;
                               height_perlin_factor : float;
                               eid : EntityId)
  // Randomize height by perlin noise
  for patrolPointIdx in iter_range(waypoints)
    assume patrolPoint = waypoints[patrolPointIdx]
    assume perlinFactor = height_perlin_factor
    let salt = float(int(256u * uint(eid)) % 32000) / 32000.0
    let perlinOffset = max(0.0, perlin_noise1(float(patrolPointIdx) * 38.57 + salt) * perlinFactor)

    let gravityDirection = get_grav_dir(patrolPoint)
    patrolPoint -= gravityDirection * perlinOffset



def detail_waypoints_path(segment_length : float;
                          var patrol_path : Point3List;
                          var patrol_path_point_index : int&)
  if length(patrol_path) == 0
    return

  let segmentLengthSq = square(segment_length)

  var newPathPointIndex = -1
  using() <| $(var newPath : Point3List)
    for i in range(length(patrol_path) - 1)
      let prevPointIdx = i
      let curPointIdx = i + 1

      let prevPoint = patrol_path[prevPointIdx]
      let curPoint = patrol_path[curPointIdx]

      if patrol_path_point_index == i
        newPathPointIndex = length(newPath)

      newPath |> push(prevPoint)

      let curSegmentDelta = curPoint - prevPoint
      let curSegmentLengthSq = length_sq(curSegmentDelta)
      if curSegmentLengthSq > segmentLengthSq
        let curSegmentLength = sqrt(curSegmentLengthSq)
        let toCurPointDir = curSegmentDelta / curSegmentLength

        let newPointsCount = int(curSegmentLength / segment_length) - 1
        var newPoint = prevPoint
        for _ in range(newPointsCount)
          newPoint += toCurPointDir * segment_length
          newPath |> push(newPoint)

    if newPathPointIndex == -1
      newPathPointIndex = length(newPath)
    newPath |> push(patrol_path[length(patrol_path) - 1])

    patrol_path := newPath
    patrol_path_point_index = newPathPointIndex


[beh_node(name="followWaypoints")]
class FollowWaypoints : BehNodeAdapter
  waypointGenRadius : float = 100.0
  waypointSearchRadius : float = 50.0
  perlinHeightFactor : float = 0.0

  def override loadFromBlk(var data : DataBlock)
    waypointGenRadius = data |> datablock_getReal("waypointGenRadius", waypointGenRadius)
    waypointSearchRadius = data |> datablock_getReal("waypointSearchRadius", waypointSearchRadius)
    perlinHeightFactor = data |> datablock_getReal("perlinHeightFactor", perlinHeightFactor)

  def override init()
    let agent_eid = beh_tree_eid(owner)
    query(agent_eid) <| $ [es] (transform aka agent_transform : float3x4;
                                follow_waypoints__origin : float3;
                                var follow_waypoints__patrolPathPointIndex : int&;
                                var follow_waypoints__waypoints : Point3List;
                                var follow_waypoints__patrolPathMode : int&)
      if length(follow_waypoints__waypoints) == 0
        if !are_grav_zones_loaded()
          return
        if waypointSearchRadius > 0.0
          var closestWaypointsEid = INVALID_ENTITY_ID
          var closestWaypointIndex = -1
          var closestWaypointDistSq = FLT_MAX
          query() <| $ [es] (eid aka waypoints_eid : EntityId;
                             transform aka waypoints_transform : float3x4;
                             navmesh_waypoints__center : float3;
                             navmesh_waypoints__boundingRadius : float;
                             navmesh_waypoints__waypoints : Point3List;
                             navmesh_waypoints__localSpace : bool;
                             navmesh_waypoints__projectedWaypoints : Point3List const?)
            assume pregenWaypoints = (navmesh_waypoints__projectedWaypoints != null ? *navmesh_waypoints__projectedWaypoints : navmesh_waypoints__waypoints)
            if distance_sq(agent_transform[3], navmesh_waypoints__center) > square(navmesh_waypoints__boundingRadius + waypointSearchRadius)
              return

            for waypointIdx in iter_range(pregenWaypoints)
              var waypointPosition = pregenWaypoints[waypointIdx]
              if navmesh_waypoints__projectedWaypoints == null && navmesh_waypoints__localSpace
                waypointPosition = waypoints_transform * waypointPosition
              let distToWaypointSq = distance_sq(agent_transform[3], waypointPosition)
              if distToWaypointSq < closestWaypointDistSq
                closestWaypointsEid = waypoints_eid
                closestWaypointIndex = waypointIdx
                closestWaypointDistSq = distToWaypointSq
          query(closestWaypointsEid) <| $ [es] (transform aka waypoints_transform : float3x4;
                                                navmesh_waypoints__waypoints : Point3List;
                                                navmesh_waypoints__localSpace : bool;
                                                navmesh_waypoints__projectedWaypoints : Point3List const?;
                                                navmesh_waypoints__looped : bool)
            if navmesh_waypoints__projectedWaypoints != null
              follow_waypoints__waypoints := *navmesh_waypoints__projectedWaypoints
            else
              follow_waypoints__waypoints := navmesh_waypoints__waypoints
              if navmesh_waypoints__localSpace
                for waypointPosition in follow_waypoints__waypoints
                  waypointPosition = waypoints_transform * waypointPosition
            follow_waypoints__patrolPathPointIndex = closestWaypointIndex
            follow_waypoints__patrolPathMode = (navmesh_waypoints__looped ? int(ProtectedAmCorePatrolPathMode.LOOP)
                                                                          : int(ProtectedAmCorePatrolPathMode.PING_PONG))
            detail_waypoints_path(3.0, follow_waypoints__waypoints, follow_waypoints__patrolPathPointIndex)
            randomize_waypoints_height(follow_waypoints__waypoints, perlinHeightFactor, agent_eid)

        if length(follow_waypoints__waypoints) == 0
          let rndPatrolPointOffset = rnd_dir2() * rnd_float(0.5, 1.0) * waypointGenRadius
          var rndPatrolPoint = follow_waypoints__origin + float3(rndPatrolPointOffset.x, 0.0, rndPatrolPointOffset.y)
          project_to_nearest_navmesh_point(rndPatrolPoint, 1.0)
          if !is_waypoint_valid(rndPatrolPoint, 2.5)
            return

          let extents = float3(1.5, FLT_MAX, 1.5)

          var startPathPoint = transform[3]
          var height = 10.0
          if tracedown_normalized(startPathPoint, height, ETF_ALL)
            startPathPoint.y = transform[3].y - height
          project_to_nearest_navmesh_point(startPathPoint, 1.0)

          var isStartPathPointValid = true
          using(follow_waypoints__origin, startPathPoint, extents) <| $(var req : pathfinder::FindRequest#)
            var closestPathNode : float3
            let originToCurPointPath = find_path(req, 2.0, 2.0) <| $(data)
              if length(data) > 0
                closestPathNode = data[length(data) - 1]
            if originToCurPointPath == FindPathResult.FPR_PARTIAL
              startPathPoint = closestPathNode
              return

            if originToCurPointPath != FindPathResult.FPR_FULL
              isStartPathPointValid = false
          if !isStartPathPointValid
            return

          using(startPathPoint, rndPatrolPoint, extents) <| $(var req : pathfinder::FindRequest#)
            let resPath = find_path(req, 2.0, 2.0) <| $(data)
              let pointsCount = length(data)
              if pointsCount > 1 && pointsCount < 1000
                let checkPointIndex0 = int(float(pointsCount) * 0.25)
                let checkPointIndex1 = int(float(pointsCount) * 0.5)
                let checkPointIndex2 = int(float(pointsCount) * 0.75)
                if (is_waypoint_valid(data[checkPointIndex0]) &&
                    is_waypoint_valid(data[checkPointIndex1]) &&
                    is_waypoint_valid(data[checkPointIndex2]))
                  for p in data
                    follow_waypoints__waypoints |> push(p)
            if resPath == FindPathResult.FPR_FAILED
              follow_waypoints__waypoints |> clear()
            elif length(follow_waypoints__waypoints) > 0 && perlinHeightFactor > 0.0
              randomize_waypoints_height(follow_waypoints__waypoints, perlinHeightFactor, agent_eid)


  def override update(dt : float) : EBehResult
    let agent_eid = beh_tree_eid(owner)
    var res = EBehResult.ER_FAILED
    query(agent_eid) <| $ [es] (follow_waypoints__patrolPathMode : int;
                                follow_waypoints__patrolSpeedMinMax : float2;
                                follow_waypoints__patrolAligmentRatio : float;
                                follow_waypoints__waypoints : Point3List;
                                follow_waypoints__patrolHeight : float;
                                follow_waypoints__maxDt : float;
                                var transform : float3x4;
                                var follow_waypoints__patrolPathForward : bool&;
                                var follow_waypoints__patrolSpeed : float&;
                                var follow_waypoints__patrolPathPointIndex : int&;
                                var follow_waypoints__velocity : float3&)
      let pathNodesCount = length(follow_waypoints__waypoints)
      if pathNodesCount == 0
        return

      assume patrolPathPointIndex = follow_waypoints__patrolPathPointIndex
      if patrolPathPointIndex < 0 || follow_waypoints__patrolPathPointIndex >= pathNodesCount
        if follow_waypoints__patrolPathMode == int(ProtectedAmCorePatrolPathMode.PING_PONG)
          patrolPathPointIndex = patrolPathPointIndex < 0 ? 0 : pathNodesCount - 1
          follow_waypoints__patrolPathForward = !follow_waypoints__patrolPathForward
        elif follow_waypoints__patrolPathMode == int(ProtectedAmCorePatrolPathMode.LOOP)
          patrolPathPointIndex = patrolPathPointIndex < 0 ? pathNodesCount - 1 : 0
        else
          logerr_once("patrolPathMode not set in {getEntityTemplateName(agent_eid)}")
          res = EBehResult.ER_FAILED
          return

      let patrolPoint = follow_waypoints__waypoints[patrolPathPointIndex] + float3(0.0, follow_waypoints__patrolHeight, 0.0)

      let isLastPatrolPoint = ((follow_waypoints__patrolPathForward && patrolPathPointIndex == (pathNodesCount - 1)) ||
                              (!follow_waypoints__patrolPathForward && patrolPathPointIndex == 0))

      if isLastPatrolPoint && follow_waypoints__patrolPathMode != int(ProtectedAmCorePatrolPathMode.LOOP)
        follow_waypoints__patrolSpeed = approach(follow_waypoints__patrolSpeed, follow_waypoints__patrolSpeedMinMax.x, dt, 0.5)
      else
        follow_waypoints__patrolSpeed = approach(follow_waypoints__patrolSpeed, follow_waypoints__patrolSpeedMinMax.y, dt, 0.5)

      let toWaypointDir = normalize(patrolPoint - transform[3])
      let currentDir = normalize(follow_waypoints__velocity)
      let aligmentDir = normalize(toWaypointDir - currentDir)
      let dir = (dot(toWaypointDir, currentDir) > 0.99 ? toWaypointDir :
          (follow_waypoints__patrolAligmentRatio * aligmentDir + (1.0 - follow_waypoints__patrolAligmentRatio) * toWaypointDir))

      if length_sq(patrolPoint - transform[3]) <= square(0.5)
        follow_waypoints__patrolPathForward ? patrolPathPointIndex++ : patrolPathPointIndex--
        if patrolPathPointIndex >= 0 && patrolPathPointIndex < pathNodesCount
          if !is_waypoint_valid(follow_waypoints__waypoints[patrolPathPointIndex], 0.1)
            return
      else
        let force = dir * follow_waypoints__patrolSpeed
        follow_waypoints__velocity += force * min(dt, follow_waypoints__maxDt)
        transform[3] += follow_waypoints__velocity * min(dt, follow_waypoints__maxDt)
      res = EBehResult.ER_RUNNING
    return res


[beh_node(name="findNextWaypoint")]
class FindNextWaypoint : BehNodeAdapter
  posParam : string
  @hidden posParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)

  def override update(dt : float) : EBehResult
    let agent_eid = beh_tree_eid(owner)
    var res = EBehResult.ER_FAILED
    query(agent_eid) <| $ [es] (var wandering_core__waypointIdx : int&;
                                var wandering_core__waypointIncrement : int&;
                                wandering_core__waypointsEid : EntityId;
                                transform aka core_transform : float3x4)
      query(wandering_core__waypointsEid) <| $ [es] (navmesh_waypoints__waypoints : Point3List;
                                                     navmesh_waypoints__looped : bool;
                                                     navmesh_waypoints__localSpace : bool;
                                                     transform aka waypoints_transform : float3x4;
                                                     navmesh_waypoints__projectedWaypoints : Point3List const?)
        let (idx, pos, incr) = get_next_waypoint(wandering_core__waypointIdx,
                                              wandering_core__waypointIncrement,
                                              navmesh_waypoints__projectedWaypoints != null ? *navmesh_waypoints__projectedWaypoints : navmesh_waypoints__waypoints,
                                              navmesh_waypoints__looped,
                                              navmesh_waypoints__projectedWaypoints != null ? false : navmesh_waypoints__localSpace,
                                              waypoints_transform,
                                              core_transform[3])
        wandering_core__waypointIdx = idx
        wandering_core__waypointIncrement = incr
        res = idx != -1 ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED
        if idx != -1
          if !has(agent_eid, posParam, posParamHash)
            logerr_once("{agent_eid}: entity without output param '{posParam}:{posParamHash}' / {*thisNode |> beh_node_hierarchy_name(true)}")
          setOptional(agent_eid, posParam, posParamHash, pos)
    return res


def get_next_waypoint(from_idx : int;
                      increment : int;
                      waypoints : Point3List;
                      looped : bool;
                      local_space : bool;
                      waypoints_transform : float3x4;
                      agent_pos : float3)
  var outIdx = from_idx
  var outPos : float3
  var outIncr = increment

  if from_idx != -1
    let count = length(waypoints)
    let next = from_idx + increment
    if next >= count || next < 0
      if !looped
        outIncr *= -1
        outIdx = from_idx + outIncr
      else
        outIdx = (from_idx + increment + count) % count
    else
      outIdx = next
  else
    let (dst, idx) = find_nearest_waypoint(agent_pos, waypoints, waypoints_transform, local_space)
    outIdx = idx
  outPos = local_space ? waypoints_transform * waypoints[outIdx] : waypoints[outIdx]
  return outIdx, outPos, outIncr