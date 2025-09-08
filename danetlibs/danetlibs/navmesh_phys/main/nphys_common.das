module nphys_common shared
require ecs
require ecs.safe
require math
require math.base
require math.linear
require danetlibs.navmesh_phys.main.nphys_events
require DagorMath
require walkerai
require pathfinder
require DagorMath
require DagorMathUtils
require DngWalkerai
require danetlibs.pathfinder.main.pathfinder_common


def set_mod_mult_value(var mods : Object; name : string; new_value : float; eid : EntityId)

  let was = mods[name] ?? 1.0
  if was == new_value
    return
  if new_value != 1.0
    set(mods, name, new_value)
  else
    erase(mods, name)
  sendEvent(eid, EventOnModsChanged())


def calc_change_mult_attr(map : Object)
  var mult = 1.0
  for mod in map
    mult *= mod.value ?? 1.0
  return mult


def accelerate_dir(cur_vel, wish_dir : float3; wish_speed, accel, dt : float)
  let curSpeed = dot(cur_vel, wish_dir)
  if curSpeed >= wish_speed
    return cur_vel
  return cur_vel + wish_dir * min(accel * dt, wish_speed - curSpeed)


def is_far_outside_obstacle(pos, dir : float3; agent_height, predict_dist : float; obstacle : ObstacleEx)
  let heightGain = predict_dist * dot(dir, float3(0, 1, 0))
  return ((pos.y + agent_height + min(0.0, heightGain) < obstacle.center.y) ||
          (pos.y + max(0.0, heightGain) > obstacle.center.y + obstacle.height) ||
          (distance(obstacle.center, float3(pos.x, obstacle.center.y, pos.z)) > sqrt(obstacle.boundingRadiusSq) + predict_dist))


def navigate_around_obstacles(pos, dir : float3; agent_height, navmesh_phys__doorOpenerDist : float;
                              agent_obstacles : AgentObstacles; leading, predict_dist : float;
                              var navmesh_phys__doorObstacleEid : EntityId&; var obstacle_penetration : float&; var navmesh_phys__immediateObstacleIdx : int&) : float3
  navmesh_phys__doorObstacleEid = INVALID_ENTITY_ID
  var bestObstaclePart = 1.0
  obstacle_penetration = 0.f
  let horDir = normalize(float3(dir.x, 0.0, dir.z))
  var resultDir = horDir
  var insideObstacle = false
  //All obstacles assumed to be convex
  for obstacle, idx in agent_obstacles.obstacles, iter_range(agent_obstacles.obstacles)
    if is_far_outside_obstacle(pos, dir, agent_height, predict_dist, obstacle)
      continue
    var segmentIdx : int
    var sidePos : float3
    let testPos = float3(pos.x, obstacle.center.y, pos.z)
    insideObstacle = test_is_inside_obstacle_ex(testPos, obstacle, segmentIdx, sidePos)
    if insideObstacle
      navmesh_phys__immediateObstacleIdx = idx
      let sideDir = obstacle.segments[segmentIdx].dir
      var fallbackDir = sidePos - testPos
      let fallbackDirLen = length(fallbackDir)
      if obstacle_penetration < fallbackDirLen
        obstacle_penetration = fallbackDirLen
        fallbackDir *= safeinv(fallbackDirLen)
        resultDir = lerp(sideDir, fallbackDir, float3(saturate(fallbackDirLen)))
        bestObstaclePart = 0.f
      continue

    for segment in obstacle.segments
      var start = segment.start
      var end = segment.end
      let segRawDir = end - start
      if dot(segRawDir, segment.dir) < 0.f
        swap(start, end)
      //Find segment which intersection point with 'horDir' is closest to pos
      var mua : float
      var mub : float
      let traceTo = testPos + horDir * predict_dist
      line_line_intersect(testPos, traceTo, start, end, mua, mub)
      if mua < 0.f || mua > bestObstaclePart || mub < 0.f || mub > 1.f
        continue // we have better obstacle
      let outDir = float3(segRawDir.z, .0, -segRawDir.x)
      if insideObstacle && dot(dir, outDir) > 0.0
        continue //heading out of the obstacle
      navmesh_phys__immediateObstacleIdx = idx
      if obstacle.isDoor && navmesh_phys__doorOpenerDist > 0f
        var doorMua : float
        var doorMub : float
        let doorTraceTo = testPos + horDir * navmesh_phys__doorOpenerDist
        line_line_intersect(testPos, doorTraceTo, start, end, doorMua, doorMub)
        if doorMua >= 0.f && doorMua <= 1.f
          query(obstacle.eid) <| $ [es] (isDoor : bool; rendinst_axis_rotation__targetAngle, door_operations__openedAngle : float)
            if isDoor
              let isDoorClosed = abs(rendinst_axis_rotation__targetAngle) < abs(door_operations__openedAngle)
              if isDoorClosed
                resultDir = float3()
                bestObstaclePart = 0f
                navmesh_phys__doorObstacleEid = obstacle.eid
          if bestObstaclePart <= 0f
            continue
      // turn by obstacle direction
      let cornerDir = lerp(segment.dir, normalize(end - testPos), float3(saturate(mua - leading)))
      resultDir = normalize(lerp(cornerDir, horDir, float3(saturate(mua - leading))))
      bestObstaclePart = mua
  resultDir *= 1.0 - square(dir.y)
  resultDir.y = dir.y
  return normalize(resultDir) //normalize just in case, to avoid rounding errors etc.


def test_is_inside_obstacle(pos : float3; obstacle : ObstacleEx)
  let distanceToObstacleCenterSq = distance_sq(obstacle.center, pos)
  let insideCurrentObstacle = obstacle.boundingRadiusSq > distanceToObstacleCenterSq && length(obstacle.segments) > 2
  if insideCurrentObstacle
    //Test if point is on the same side of all segments to see if it's inside
    assume firstSeg = obstacle.segments[0]
    let refSide = cross2d((firstSeg.end - firstSeg.start).xz, (pos - firstSeg.start).xz)
    for segment in obstacle.segments
      if refSide * cross2d((segment.end - segment.start).xz, (pos - segment.start).xz) < .0
        return false
    return true
  return false


def test_is_inside_obstacle_ex(pos : float3; obstacle : ObstacleEx; var nearest_segment_idx : int&; var side_pos : float3&) : bool
  nearest_segment_idx = -1
  if test_is_inside_obstacle(pos, obstacle)
    var minDistSq = FLT_MAX
    for idx, segment in iter_range(obstacle.segments), obstacle.segments
      let pt = closest_pt_on_seg(pos, segment.start, segment.end)
      let distSq = distance_sq(pt, pos)
      if distSq < minDistSq
        side_pos = pt
        minDistSq = distSq
        nearest_segment_idx = idx
  return nearest_segment_idx != -1


def collide_with_obstacles(pos : float3; wish_step : float2/*x, z*/; agent_obstacles : AgentObstacles) : tuple<step : float3; vel : float3; hasCollided : bool>
  var step = float3(wish_step.x, .0, wish_step.y)
  var resultingVelocity = step
  var hasCollided = false

  var isInsideObstacle = false
  var segIdx : int
  var sidePos : float3
  for obstacle in agent_obstacles.obstacles
    if test_is_inside_obstacle_ex(pos, obstacle, segIdx, sidePos)
      //Only allow to move out
      hasCollided = true
      let outOfObstacleDir = normalize(sidePos - pos)
      step = outOfObstacleDir * max(0.0, dot(step, outOfObstacleDir))
      isInsideObstacle = true

  if isInsideObstacle
    return (step, resultingVelocity, hasCollided)

  var bestMua = 1.f
  for obstacle in agent_obstacles.obstacles
    let destination = pos + step
    //Find segment which intersection point with 'step' is closest to pos
    for segment in obstacle.segments
      let start = segment.start
      let end = segment.end
      var mua : float
      var mub : float
      line_line_intersect(pos, destination, start, end, mua, mub)
      if mua < 0.f || mua > bestMua || mub < 0.f || mub > 1.f
        continue
      hasCollided = true
      bestMua = mua
      mua *= 0.95 //step away from the obstacle a little to avoid squeezing inside the obstacle due to rounding errors
      var segDir = normalize(end - start)
      if dot(segDir, step) < 0.f
        segDir *= -1.0
      resultingVelocity = segDir * dot(segDir, step) * (1.0 - mua)
      step = step * mua + resultingVelocity //Cover the remaining distance to the edge + move along the edge
  return (step, resultingVelocity, hasCollided)


def segment_intersects_obstacle(from, dir : float3; len : float; obstacle : ObstacleEx)
  let centerFlat = x0z(obstacle.center)
  let fromFlat = x0z(from)
  let dirFlat = normalize(x0z(dir))
  let sqDst = distance_sq_to_line(centerFlat, fromFlat, dirFlat)
  if sqDst > obstacle.boundingRadiusSq
    return false
  let maxDstSqToEnd = square(len) / 4.0 + sqDst
  let toFlat = x0z(fromFlat + dirFlat * len)
  if distance_sq(fromFlat, centerFlat) > maxDstSqToEnd && distance_sq(toFlat, centerFlat) > maxDstSqToEnd
    return false
  for seg in obstacle.segments
    var mua, mub : float
    line_line_intersect(fromFlat, toFlat, seg.start, seg.end, mua, mub)
    if mua >= 0.0 && mua <= 1.0 && mub >= 0.0 && mub <= 1.0
      return true
  return false


def trace_single_obstacle_against_path(obstacle : ObstacleEx;
                                       startPos : float3;
                                       path_corners;
                                       max_path_index : int;
                                       trace_distance_budget : float) : int
  if test_is_inside_obstacle(startPos, obstacle)
    return 0
  var traceDistanceBudget = trace_distance_budget
  var start = startPos
  for idx in range(max_path_index)
    if traceDistanceBudget <= 0f
      break
    let end = path_corners[idx]
    var traceDir = end - start
    let traceDirLen = length(traceDir)
    traceDir *= safeinv(traceDirLen)
    let currentTraceDist = min(traceDistanceBudget, traceDirLen)
    traceDistanceBudget -= traceDirLen
    if segment_intersects_obstacle(start, traceDir, currentTraceDist, obstacle)
      return idx
    start = end
  return -1


def trace_obstacles_along_path(agent_obstacles : AgentObstacles; startPos : float3; path_corridor__corners : Point3List;
                               walker_agent__standShootLocalPos : float3; traceDist : float; obstacle_predicate : block<(obstacle : ObstacleEx const) : bool>) : EntityId
  var result = INVALID_ENTITY_ID
  var nearestObstacleIdx = length(path_corridor__corners)
  for obstacle in agent_obstacles.obstacles
    if !invoke(obstacle_predicate, obstacle)
      continue
    var pathIdx = trace_single_ri_against_path(obstacle.eid, startPos, walker_agent__standShootLocalPos, path_corridor__corners, nearestObstacleIdx, traceDist)
    if pathIdx == -1
      pathIdx = trace_single_obstacle_against_path(obstacle, startPos, path_corridor__corners, nearestObstacleIdx, traceDist)
    if pathIdx != -1 && pathIdx < nearestObstacleIdx
      result = obstacle.eid
      nearestObstacleIdx = pathIdx
  return result

def distance_to_obstacle_fast(pos : float3; obstacle : ObstacleEx; var out_nearest_pos : float3&)
  let distanceToObstacleCenterSq = distance_sq(obstacle.center, pos)
  if distanceToObstacleCenterSq > obstacle.boundingRadiusSq * 2.0
    out_nearest_pos = obstacle.center
    return sqrt(distanceToObstacleCenterSq + obstacle.boundingRadiusSq) //approximation
  var bestDstSq = FLT_MAX
  for segment in obstacle.segments
    let p = closest_pt_on_seg(pos, segment.start, segment.end)
    let dstSq = distance_sq(p, pos)
    if dstSq < bestDstSq
      bestDstSq = dstSq
      out_nearest_pos = p
  return sqrt(bestDstSq)