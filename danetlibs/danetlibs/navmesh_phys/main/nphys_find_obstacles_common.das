module nphys_find_obstacles_common shared
require ecs
require ecs.common
require app
require math.base
require math.linear
require player
require DagorMath
require DagorSystem
require Grid
require GridCollision
require Dacoll
require CollRes
require RendInst
require DngWalkerai
require walkerai
require pathfinder
require daslib/algorithm
require danetlibs.navmesh_phys.main.nphys_common


def find_obstacles(eid : EntityId; movement_is_voluntary : bool; given_destination : float3)
  query(eid) <| $ [es] (walker_agent__standShootLocalPos : float3;
                        team : int = -1;
                        navmesh_phys__prevPos : float3;
                        navmesh_phys__currentWalkVelocity : float3;
                        path_corridor__corners : Point3List;
                        obstacle_avoider__horBuffer : float = 2.0;
                        obstacle_avoider__vertBuffer : float = 0.5;
                        obstacle_avoider__maxPathDst : float = 5.0;
                        obstacle_avoider__vehicleSearchRadius : float = 15.0;
                        obstacle_avoider__dmgZoneSearchRadius : float = 15.0;
                        obstacle_avoider__riExtraObstacleLimit : int = 15;
                        obstacle_avoider__dmgZoneObstacleLimit : int = 15;
                        obstacle_avoider__avoidsDamageZones : bool = true;
                        obstacle_avoider__escapeOffset : float = 0.4;
                        var navmesh_phys__immediateObstacleIdx : int?;
                        var agent_obstacles : AgentObstacles)
    if navmesh_phys__immediateObstacleIdx != null
      *navmesh_phys__immediateObstacleIdx = -1
    if movement_is_voluntary
      let box = setup_obstacle_bbox_from_path(path_corridor__corners,
                                              navmesh_phys__prevPos,
                                              walker_agent__standShootLocalPos.y,
                                              obstacle_avoider__horBuffer,
                                              obstacle_avoider__vertBuffer,
                                              obstacle_avoider__maxPathDst)
      if box.isempty || length(path_corridor__corners) == 0
        return
      let destination = path_corridor__corners[length(path_corridor__corners) - 1]
      find_obstacles(box,
                      navmesh_phys__prevPos,
                      normalize(navmesh_phys__currentWalkVelocity),
                      destination,
                      team,
                      obstacle_avoider__escapeOffset,
                      obstacle_avoider__vehicleSearchRadius,
                      obstacle_avoider__dmgZoneSearchRadius,
                      obstacle_avoider__riExtraObstacleLimit,
                      obstacle_avoider__dmgZoneObstacleLimit,
                      obstacle_avoider__avoidsDamageZones,
                      agent_obstacles)

    else
      var box = BBox3(navmesh_phys__prevPos, obstacle_avoider__escapeOffset)
      box |> bbox3_add(given_destination)
      box |> bbox3_inflateXZ(obstacle_avoider__horBuffer)
      find_obstacles(box,
                      navmesh_phys__prevPos,
                      normalize(navmesh_phys__currentWalkVelocity),
                      given_destination,
                      team,
                      obstacle_avoider__escapeOffset,
                      obstacle_avoider__vehicleSearchRadius,
                      obstacle_avoider__dmgZoneSearchRadius,
                      obstacle_avoider__riExtraObstacleLimit,
                      obstacle_avoider__dmgZoneObstacleLimit,
                      false,
                      agent_obstacles)


def find_obstacles(box : BBox3;
                   pos : float3;
                   walk_dir : float3;
                   destination : float3;
                   team : int;
                   escape_offset : float;
                   vehicle_search_radius : float;
                   damage_zone_search_radius : float;
                   ri_limit : int;
                   damage_zone_limit : int;
                   avoid_damage_zones : bool;
                   var agent_obstacles : AgentObstacles)
  find_door_obstacles(box, walk_dir, escape_offset, agent_obstacles)
  find_vehicle_obstacles(vehicle_search_radius, pos, destination, escape_offset, agent_obstacles)
  find_ri_extra_obstacles(box, pos, destination, escape_offset, ri_limit, agent_obstacles)
  find_creature_obstacles(box, pos, destination, escape_offset, agent_obstacles)
  if avoid_damage_zones
    find_damage_zone_obstacles(damage_zone_search_radius, pos, destination, escape_offset, damage_zone_limit, team, agent_obstacles)
  var requiresMergeCount = 0
  for o in agent_obstacles.obstacles
    if o.merge
      requiresMergeCount++
      if requiresMergeCount > 1
        merge_obstacles(destination, agent_obstacles)
        break


def setup_obstacle_bbox_from_path(path : Point3List; pos : float3; vert_height, hor_buffer, vert_buffer, path_distance_limit : float)
  var box = BBox3()
  var distanceLeft = path_distance_limit
  var from = pos
  box |> bbox3_add(from)
  for point in path
    var dir = point - from
    let dirLen = length(dir)
    dir *= safeinv(dirLen)
    let curDist = min(distanceLeft, dirLen)
    box |> bbox3_add(from + dir * curDist + float3(.0, vert_height + vert_buffer, .0))
    box |> bbox3_add(from + dir * curDist + float3(.0, -vert_buffer, .0))
    from = point
    distanceLeft -= dirLen
    if distanceLeft <= 0.0
      break
  box |> bbox3_inflateXZ(hor_buffer)
  return <- box


def get_floor_corners(transform : float3x4; box : BBox3) : array<float3>
  let boxMin = box.boxMin
  let boxMax = box.boxMax
  let boxFloor = boxMin.y
  var result : array<float3> <- [
              transform * float3(boxMin.x, boxFloor, boxMin.z),
              transform * float3(boxMax.x, boxFloor, boxMin.z),
              transform * float3(boxMax.x, boxFloor, boxMax.z),
              transform * float3(boxMin.x, boxFloor, boxMax.z)]
  return <- result


def get_convex_corners(transform : float3x4; box : BBox3)
  let boxMin = box.boxMin
  let boxMax = box.boxMax
  let allCorners = fixed_array<float3>(
                      transform * float3(boxMin.x, boxMin.y, boxMin.z),
                      transform * float3(boxMin.x, boxMin.y, boxMax.z),
                      transform * float3(boxMin.x, boxMax.y, boxMin.z),
                      transform * float3(boxMin.x, boxMax.y, boxMax.z),
                      transform * float3(boxMax.x, boxMin.y, boxMin.z),
                      transform * float3(boxMax.x, boxMin.y, boxMax.z),
                      transform * float3(boxMax.x, boxMax.y, boxMin.z),
                      transform * float3(boxMax.x, boxMax.y, boxMax.z))
  var boxFloor = FLT_MAX
  for c in allCorners
    boxFloor = min(c.y, boxFloor)
  var obstacle2d : array<float2>
  for c in allCorners
    obstacle2d |> push(c.xz)
  let hull <- convex_hull(obstacle2d)
  var result : array<float3>
  for h in hull
    result |> push(float3(h.x, boxFloor, h.y))
  return <- result


def enforce_convexness(var corners : array<float3>; var validCorners : array<bool>)
  var count = length(corners)
  var from = -1
  while ++from < count
    let mid = (from + 1) % count
    let to = (mid + 1) % count
    if cross2d((corners[mid] - corners[from]).xz, (corners[to] - corners[mid]).xz) < 0f
      corners |> erase(mid)
      validCorners |> erase(mid)
      from--
      count--

def add_box_obstacle(eid : EntityId;
                     box : BBox3;
                     transform : float3x4;
                     pos : float3;
                     destination : float3;
                     escape_offset : float;
                     use_simple_corners : bool;
                     merge : bool;
                     var agent_obstacles : AgentObstacles)
  add_box_obstacle(eid, box, transform, pos, destination, escape_offset, use_simple_corners, merge, agent_obstacles) <| $  [unused_argument(from, corner, height)] (from, corner : float3; height : float)
    return true


def add_box_obstacle(eid : EntityId;
                     box : BBox3;
                     transform : float3x4;
                     pos : float3;
                     destination : float3;
                     escape_offset : float;
                     use_simple_corners : bool;
                     merge : bool;
                     var agent_obstacles : AgentObstacles;
                     test_valid_corner : block<(pos, corner : float3; obstacle_height : float) : bool>)
  var vbox = box
  vbox |> bbox3_inflateXZ(escape_offset)
  let obstacleHeight = vbox.boxMax.y - vbox.boxMin.y
  var corners <- use_simple_corners ? get_floor_corners(transform, vbox) : get_convex_corners(transform, vbox)
  var validCorners : array<bool>
  resize(validCorners, length(corners))
  for i in iter_range(corners)
    var fixedCorner = corners[i]
    if length_sq(corners[i] - fixedCorner) > 4.f //mind vertical distance
      fixedCorner = corners[i]
    validCorners[i] = invoke(test_valid_corner, pos, fixedCorner, obstacleHeight)
    corners[i] = fixedCorner

  if length(corners) > 4
    enforce_convexness(corners, validCorners)

  var obstacle = agent_obstacles_add_obstacle(agent_obstacles)
  obstacle.eid = eid
  obstacle.center = transform[3]
  obstacle.merge = merge
  obstacle.height = obstacleHeight

  let destinationInPlane = float3(destination.x, obstacle.center.y, destination.z)
  let alongObstacleDir = normalize(destinationInPlane - obstacle.center)
  for i in iter_range(corners)
    let startIdx = i
    let endIdx = (i + 1) % length(corners)
    let start = corners[startIdx]
    let end = corners[endIdx]

    let sideDir = normalize(end - start)
    let validDir = validCorners[endIdx] && validCorners[(i + 2) % length(corners)]
    let invert = !validDir || dot(alongObstacleDir, sideDir) < .0

    emplace(obstacle.segments, ObstacleSegment(start, end, invert ? -sideDir : sideDir))
    obstacle.boundingRadiusSq = max(obstacle.boundingRadiusSq, distance_sq(obstacle.center, start))


def find_door_obstacles(box : BBox3; walk_dir : float3; escape_offset : float; var agent_obstacles : AgentObstacles)
  for_each_entity_in_grid(ecs_hash("doors"), box, GridEntCheck.BOUNDING) <| $(doorEid : EntityId)
    query(doorEid) <| $ [es(REQUIRE_NOT=dontCreateNphysObstacle)] (ri_extra : RiExtraComponent;
                                                                   transform : float3x4;
                                                                   obstacle__bufferSize = float2();
                                                                   nphys_obstacle__merge : Tag const?)
      let riType = handle_to_ri_type(ri_extra.handle)
      let riCollres = get_ri_gen_extra_collres(int(riType))
      if riCollres == null
        return
      let door_box = BBox3(riCollres.vFullBBox)
      let transformPos = transform[3]
      let transformDir = transform[0]
      let doorSize = door_box.width
      let doorEnd = transformPos + transformDir * (max(doorSize.x, doorSize.z) + escape_offset + obstacle__bufferSize.y)
      let norm = normalize(cross(doorEnd - transformPos, float3(0, 1, 0)))
      let doorNormOffset = norm * (escape_offset * 0.6 + obstacle__bufferSize.x)
      let doorDir = dot(walk_dir, doorNormOffset) > .0 ? 1.0 : -1.0
      var obstacle = agent_obstacles_add_obstacle(agent_obstacles)
      obstacle.eid = doorEid
      obstacle.isDoor = true //TODO check and correct
      obstacle.center = (doorEnd + transformPos) * 0.5
      obstacle.merge = nphys_obstacle__merge != null
      obstacle.height = door_box.boxMax.y - door_box.boxMin.y
      var vertices = fixed_array<float3>(
                        transformPos + doorNormOffset,
                        transformPos - doorNormOffset,
                        doorEnd - doorNormOffset,
                        doorEnd + doorNormOffset)

      var directions = fixed_array<float3>(
                        -norm * doorDir,
                        transformDir * doorDir,
                        norm * doorDir,
                        -transformDir * doorDir)

      for dir, idx in directions, iter_range(vertices)
        let v1 & = vertices[idx]
        let v2 & = vertices[(idx + 1) % length(vertices)]
        emplace(obstacle.segments, ObstacleSegment(v1, v2, dir))
        obstacle.boundingRadiusSq = max(obstacle.boundingRadiusSq, distance_sq(obstacle.center, vertices[idx]))


def find_vehicle_obstacles(search_radius : float; pos, destination : float3; escape_offset : float; var agent_obstacles : AgentObstacles)
  let sphere = BSphere3(pos, search_radius)
  for_each_entity_in_grid(ecs_hash("vehicles"), sphere, GridEntCheck.BOUNDING) <| $(obstacleEid : EntityId)
    query(obstacleEid) <| $ [es(REQUIRE_NOT=(aliveCreature, dontCreateNphysObstacle))] (transform : float3x4; collres : CollisionResource; obstacle__handle = 0; nphys_obstacle__merge : Tag const?)
      if obstacle__handle != 0
        logerr("find_vehicle_obstacles: nav obstacle without tile cache enabled")
        return
      let vbox = BBox3(collres.vFullBBox)
      if vbox.isempty
        return
      add_box_obstacle(obstacleEid, vbox, transform, pos, destination, escape_offset, true, nphys_obstacle__merge != null, agent_obstacles) <| $(from, corner : float3; obstacle_height : float)
        let vertBuff = min(0.4, obstacle_height)
        let traceFrom = from + float3(.0, vertBuff, .0)
        let agentToCorner = corner + float3(.0, vertBuff, .0) - traceFrom
        let agentToCornerLen = length(agentToCorner)
        let traceLen = agentToCornerLen - vertBuff
        if traceLen < vertBuff
          return true
        let traceDir = agentToCorner * safeinv(agentToCornerLen)
        return !rayhit_normalized(traceFrom, traceDir, traceLen, ETF_DEFAULT, -1)

def find_ri_extra_obstacles(box : BBox3; pos, destination : float3; escape_offset : float; max_count : int; var agent_obstacles : AgentObstacles)
  gather_ri_gen_extra_collidable(box) <| $(handles : array<riex_handle_t>#)
    var budgetLeft = max_count
    for h in handles
      let riEid = find_ri_extra_eid(h)
      query(riEid) <| $ [es(REQUIRE_NOT=(ri_extra__handle, dontCreateNphysObstacle))] (transform : float3x4;
                                                                                       ri_extra : RiExtraComponent;
                                                                                       obstacle__customBBoxMin : float3 const?;
                                                                                       obstacle__customBBoxMax : float3 const?;
                                                                                       obstacle__customBBoxOffset : float3 const?;
                                                                                       nphys_obstacle__merge : Tag const?;
                                                                                       nphys_obstacle__useHull : Tag const?)
        let riType = handle_to_ri_type(ri_extra.handle)
        let riCollres = get_ri_gen_extra_collres(int(riType))
        if riCollres == null
          return

        var riBox = BBox3()
        if obstacle__customBBoxMin == null || obstacle__customBBoxMax == null
          riBox |> bbox3f_to_scalar_bbox3(riCollres.vFullBBox)
        else
          riBox = BBox3(*obstacle__customBBoxMin, *obstacle__customBBoxMax)
        var tm := transform
        if obstacle__customBBoxOffset != null
          tm[3] += (transform * (*obstacle__customBBoxOffset)) - transform[3]
        add_box_obstacle(riEid, riBox, tm, pos, destination, escape_offset, nphys_obstacle__useHull == null, nphys_obstacle__merge != null, agent_obstacles)
        budgetLeft--
      if budgetLeft <= 0
        return

def find_damage_zone_obstacles(search_radius : float;
                               pos : float3;
                               destination : float3;
                               escape_offset : float;
                               max_count : int;
                               team : int;
                               var agent_obstacles : AgentObstacles)
  if team == TEAM_UNASSIGNED
    return
  var budgetLeft = max_count
  let radiusSq = square(search_radius)
  find_query() <| $ [es(REQUIRE_NOT=dontCreateNphysObstacle)] (transform : float3x4;
                                                               sphere_zone__radius : float;
                                                               eid : EntityId;
                                                               dmgzone__teamToDamage : int;
                                                               dmgzone__damage : float;
                                                               dmgzone__fireAffect : float = .0;
                                                               obstacle__segmentsPerMeter : float = 0.3;
                                                               nphys_obstacle__merge : Tag const?;
                                                               dmgzone__maxRadius = -1.f)
    if dmgzone__damage <= 0.f && dmgzone__fireAffect <= 0.f
      return false
    if dmgzone__teamToDamage != TEAM_UNASSIGNED && dmgzone__teamToDamage != team
      return false
    if distance_sq(transform[3], pos) > radiusSq
      return false

    let radius = dmgzone__maxRadius > 0.0 ? dmgzone__maxRadius : sphere_zone__radius

    //regular polygon around circle
    let numSegments = min(24, max(4, int(radius * TWOPI * obstacle__segmentsPerMeter)))

    add_poly_obstacle(eid, radius, numSegments, sphere_zone__radius, transform, destination, escape_offset, nphys_obstacle__merge != null, agent_obstacles)

    budgetLeft--
    return budgetLeft <= 0


def add_poly_obstacle(eid : EntityId;
                      radius : float;
                      num_segments : int;
                      height : float;
                      transform : float3x4;
                      destination : float3;
                      escape_offset : float;
                      merge : bool;
                      var agent_obstacles : AgentObstacles)
  let dAngle = TWOPI / float(num_segments) / 2.0
  let outerRadius = radius * cos(dAngle) + escape_offset

  var obstacle = agent_obstacles_add_obstacle(agent_obstacles)
  obstacle.eid = eid
  obstacle.center = transform[3]
  obstacle.merge = merge
  obstacle.height = height

  //testing validity of corners is skipped for now. TODO.
  //ideally creature should have a policy on how to deal with unescapable dmg_zone obstacles
  //avoid them at all cost and never cross them?
  //or make an effort to not cross them but go through anyway if the navigation is complicated
  //current implementation is the "never cross" policy. It may get them stuck when the zone is next to navmesh boundary.

  let destinationInPlane = float3(destination.x, obstacle.center.y, destination.z)
  let alongObstacleDir = normalize(destinationInPlane - obstacle.center)
  var s, c : float
  var prevVertex = transform[3] + float3(outerRadius, .0, .0)
  for i in range(0, num_segments)
    let endIdx = float((i + 1) % num_segments)
    sincos(dAngle * endIdx * 2.0, s, c)
    let nextVertex = transform[3] + float3(outerRadius * c, .0, outerRadius * s)
    let sideDir = normalize(nextVertex - prevVertex)
    let invert = dot(alongObstacleDir, sideDir) < .0
    emplace(obstacle.segments, ObstacleSegment(prevVertex, nextVertex, invert ? -sideDir : sideDir))
    prevVertex = nextVertex

  obstacle.boundingRadiusSq = square(outerRadius)


def find_creature_obstacles(box : BBox3; pos, destination : float3; escape_offset : float; var agent_obstacles : AgentObstacles)
  for_each_entity_in_grid(ecs_hash("humans"), box, GridEntCheck.BOUNDING) <| $(creatureEid : EntityId)
    query(creatureEid) <| $ [es(REQUIRE_NOT=dontCreateNphysObstacle, REQUIRE=createObstacle)] (collres : CollisionResource const?;
                                                                                               transform : float3x4;
                                                                                               nphys_obstacle__radius : float const?;
                                                                                               nphys_obstacle__height = 1.8;
                                                                                               nphys_obstacle__numSegments = 4;
                                                                                               obstacle__mayBeRotated = false;
                                                                                               nphys_obstacle__merge : Tag const?)
      if collres != null && nphys_obstacle__radius == null
        let creatureBox = BBox3(collres.vFullBBox)
        if creatureBox.isempty
          return
        add_box_obstacle(creatureEid, creatureBox, transform, pos, destination, escape_offset, !obstacle__mayBeRotated, nphys_obstacle__merge != null, agent_obstacles)
      elif nphys_obstacle__radius != null
        add_poly_obstacle(creatureEid, *nphys_obstacle__radius, nphys_obstacle__numSegments, nphys_obstacle__height, transform, destination, escape_offset, nphys_obstacle__merge != null, agent_obstacles)


def merge_obstacles(destination : float3; var agent_obstacles : AgentObstacles)
  var box : bbox3f
  var boxInited = false
  var points : array<float2>
  var i = length(agent_obstacles.obstacles)
  while --i >= 0
    if agent_obstacles.obstacles[i].merge
      if !boxInited && length(agent_obstacles.obstacles[i].segments) > 0
        boxInited = true
        bbox3f_init(box, agent_obstacles.obstacles[i].segments[0].start)
      for s in agent_obstacles.obstacles[i].segments
        points |> push(s.start.xz)
        box |> bbox3f_add_pt(s.start)
        let pointWithHeight = s.start + float3(.0, agent_obstacles.obstacles[i].height, .0)
        box |> bbox3f_add_pt(pointWithHeight)
      agent_obstacles.obstacles |> erase(i)
  var hull <- convex_hull(points)
  var obstacle = agent_obstacles_add_obstacle(agent_obstacles)
  obstacle.eid = INVALID_ENTITY_ID
  obstacle.center = (box.bmin + box.bmax).xyz * 0.5
  obstacle.center.y = box.bmin.y
  obstacle.height = box.bmax.y - box.bmin.y

  let destinationInPlane = float3(destination.x, obstacle.center.y, destination.z)
  let alongObstacleDir = normalize(destinationInPlane - obstacle.center)
  let prevVertex2d = hull[length(hull) - 1]
  var prevVertex = float3(prevVertex2d.x, obstacle.center.y, prevVertex2d.y)
  for h in hull
    let nextVertex = float3(h.x, box.bmin.y, h.y)
    let sideDir = normalize(nextVertex - prevVertex)
    let invert = dot(alongObstacleDir, sideDir) < .0
    emplace(obstacle.segments, ObstacleSegment(prevVertex, nextVertex, invert ? -sideDir : sideDir))
    obstacle.boundingRadiusSq = max(obstacle.boundingRadiusSq, distance_sq(obstacle.center, nextVertex))
    prevVertex = nextVertex