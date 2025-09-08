require ecs
require app
require math.base
require math.random
require math.ang
require DagorSystem
require game.es.bighead_common
require game.events.events_active_matter
require Dacoll
require DagorMath


struct TraceCheck
  position : float3
  direction : float3
  length : float


def additional_waypoint_traces_check(position : float3; side : float)
  let halfSide = side * 0.5

  let backCenter = position - float3(halfSide, 0.0, 0.0)
  let backPositions = fixed_array<float3>(backCenter,
                        backCenter + float3(0.0, halfSide, halfSide),
                        backCenter + float3(0.0, -halfSide, halfSide),
                        backCenter + float3(0.0, -halfSide, -halfSide),
                        backCenter + float3(0.0, halfSide, -halfSide))

  let leftCenter = position - float3(0.0, 0.0, halfSide)
  let leftPositions = fixed_array<float3>(leftCenter,
                        leftCenter + float3(halfSide, halfSide, 0.0),
                        leftCenter + float3(-halfSide, halfSide, 0.0),
                        leftCenter + float3(-halfSide, -halfSide, 0.0),
                        leftCenter + float3(halfSide, -halfSide, 0.0))

  let bottomCenter = position - float3(0.0, halfSide, 0.0)
  let bottomPositions = fixed_array<float3>(bottomCenter,
                        bottomCenter + float3(halfSide, 0.0, halfSide),
                        bottomCenter + float3(halfSide, 0.0, -halfSide),
                        bottomCenter + float3(-halfSide, 0.0, halfSide),
                        bottomCenter + float3(-halfSide, 0.0, -halfSide))

  var checks : array<TraceCheck>
  reserve(checks, length(backPositions) + length(leftPositions) + length(bottomPositions) + 1)
  for pos in backPositions
    push(checks, TraceCheck(position = pos, direction = float3(1.0, 0.0, 0.0), length = side))
  for pos in leftPositions
    push(checks, TraceCheck(position = pos, direction = float3(0.0, 0.0, 1.0), length = side))
  for pos in bottomPositions
    push(checks, TraceCheck(position = pos, direction = float3(0.0, 1.0, 0.0), length = side))
  push(checks, TraceCheck(position = position - float3(halfSide), direction = normalize(float3(1.0, 1.0, 1.0)), length = side * sqrt(3.0)))

  var isOk = true
  for check in checks
    if rayhit_normalized(check.position, check.direction, check.length, ETF_ALL, -1)
      isOk = false
      break
  return isOk


def is_waypoint_available(position : float3; side : float)
  if !additional_waypoint_traces_check(position, side)
    return false
  var tm = scale_tm(side)
  tm[3] = position
  var haveRiCollision = true
  var haveWorldCollision = true
  dacoll_use_box_collision() <| $(var coll : CollisionObject)
    dacoll_set_collision_object_tm(coll, tm)
    haveRiCollision = test_collision_ri(coll, IDENT_BBOX)

  let mask = int(PhysLayer.EPL_ALL) & ~int(PhysLayer.EPL_CHARACTER)
  test_box_collision_world(tm, -1, PhysLayer.EPL_ALL, mask) <| $(contacts : array<CollisionContactData>#)
    haveWorldCollision = !empty(contacts)
  return !haveRiCollision && !haveWorldCollision


struct AStarEstimate
  position : float3
  estimate : float
  parent : int
  index : int


def choose_next_waypoint_idx(unused_indices : array<int>; estimates : array<AStarEstimate>; goal : float3)
  var curMin = FLT_MAX
  var curMinIdx = -1
  for idx in unused_indices
    let val = estimates[idx].estimate + distance(goal, estimates[idx].position)
    if val < curMin
      curMin = val
      curMinIdx = idx
  return curMinIdx


def get_neighboor_waypoints(waypoint : float3; step_length : float)
  let stepDirections = fixed_array<float3>(float3(1.0, 0.0, 0.0),
                  float3(-1.0, 0.0, 0.0),
                  float3(0.0, 1.0, 0.0),
                  float3(0.0, -1.0, 0.0),
                  float3(0.0, 0.0, 1.0),
                  float3(0.0, 0.0, -1.0),

                  float3(1.0, 1.0, 0.0),
                  float3(1.0, -1.0, 0.0),
                  float3(-1.0, 1.0, 0.0),
                  float3(-1.0, -1.0, 0.0),

                  float3(1.0, 0.0, 1.0),
                  float3(1.0, 0.0, -1.0),
                  float3(-1.0, 0.0, 1.0),
                  float3(-1.0, 0.0, -1.0),

                  float3(0.0, 1.0, 1.0),
                  float3(0.0, 1.0, -1.0),
                  float3(0.0, -1.0, 1.0),
                  float3(0.0, -1.0, -1.0))
  var result : array<float3>
  for direction in stepDirections
    let neighboorPosition = waypoint + step_length * direction
    push(result, neighboorPosition)
  return <- result


def reconstruct_path(final_index : int; estimates : array<AStarEstimate>; var path : Point3List)
  clear(path)
  var reversedResult : array<float3>
  push(reversedResult, estimates[final_index].position)
  var index = final_index
  var parent = estimates[index].parent
  while index != parent
    push(reversedResult, estimates[parent].position)
    index = parent
    parent = estimates[index].parent

  for i in iter_range(reversedResult)
    let reverseIdx = length(reversedResult) - 1 - i
    push(path, reversedResult[reverseIdx])


def calculate_path_a_star(from : float3;
                          to : float3;
                          box_side : float;
                          var path : Point3List;
                          max_trace_checks_num : int)
  var estimates : array<AStarEstimate>
  push(estimates, AStarEstimate(position = from, estimate = 0.0, parent = 0, index = 0))

  var unvisitedIndices : array<int>
  push(unvisitedIndices, 0)

  let halfSide = box_side * 0.5
  var trace_checks = 0

  while !empty(unvisitedIndices) && trace_checks < max_trace_checks_num
    let currentIdx = choose_next_waypoint_idx(unvisitedIndices, estimates, to)
    assume currentNode = estimates[currentIdx]

    let iidx = find_index(unvisitedIndices, currentIdx)
    erase(unvisitedIndices, iidx)

    ++trace_checks
    if !is_waypoint_available(currentNode.position, box_side)
      currentNode.estimate = FLT_MAX
      continue

    let diff = to - currentNode.position
    // if desired position is inside of the current waypoint, path is complete
    if abs(diff.x) < halfSide && abs(diff.y) < halfSide && abs(diff.z) < halfSide
      reconstruct_path(currentIdx, estimates, path)
      push(path, to)
      return

    let neighboors <- get_neighboor_waypoints(currentNode.position, box_side)
    for neighboor in neighboors
      var existingIdx = -1

      for e in estimates
        if distance_sq(e.position, neighboor) < square(halfSide)
          existingIdx = e.index
          break

      let edgePathWeight = currentNode.estimate + distance(currentNode.position, neighboor)
      if existingIdx == -1
        let newIndex = length(estimates)
        push(unvisitedIndices, newIndex)
        push(estimates, AStarEstimate(position = neighboor, estimate = edgePathWeight, parent = currentIdx, index = newIndex))
      else
        if edgePathWeight < estimates[existingIdx].estimate
          estimates[existingIdx].estimate = edgePathWeight
          estimates[existingIdx].parent = currentIdx

  // there's no path or we exceeded max search size
  var minLength = FLT_MAX
  var minIndex = -1
  for estimate in estimates
    let curDistSq = distance_sq(estimate.position, to)
    if curDistSq < minLength
      minLength = curDistSq
      minIndex = estimate.index
  debug("bighead: could not find path from {from} to {to}. Checked {length(estimates)} waypoints. Moving to the closest available waypoint at {estimates[minIndex].position}")
  reconstruct_path(minIndex, estimates, path)


[es(tag=server, on_appear)]
def bighead_init_path(evt : Event;
                      transform : float3x4;
                      bighead_movement__position : float3;
                      bighead_movement__testCubeSize : float;
                      bighead_movement__maxTestCubesNumber : int;
                      var bighead_movement__wayPointList : Point3List)
  calculate_path_a_star(transform[3],
                        bighead_movement__position,
                        bighead_movement__testCubeSize,
                        bighead_movement__wayPointList,
                        bighead_movement__maxTestCubesNumber)


[es(tag=server, no_order)]
def bighead_fly_to(update : ParallelUpdateFrameDelayed;
                   bighead_movement__waypointApproachDistance : float;
                   bighead_movement__approachSpeedViscocity : float;
                   bighead_movement__approachMaxSpeed : float;
                   bighead_movement__wayPointList : Point3List;
                   var bighead_movement__wayPointListIndex : int&;
                   var bighead_movement__approachSpeed : float&;
                   var transform : float3x4&)
  if bighead_movement__wayPointListIndex >= length(bighead_movement__wayPointList)
    return
  assume wishPos = bighead_movement__wayPointList[bighead_movement__wayPointListIndex]
  if distance_sq(transform[3], wishPos) < square(bighead_movement__waypointApproachDistance)
    bighead_movement__wayPointListIndex += 1
    return

  bighead_movement__approachSpeed = approach(bighead_movement__approachSpeed, bighead_movement__approachMaxSpeed, update.dt, bighead_movement__approachSpeedViscocity)
  let wishMoveDir = normalize(wishPos - transform[3])
  transform[3] += wishMoveDir * bighead_movement__approachSpeed * update.dt
