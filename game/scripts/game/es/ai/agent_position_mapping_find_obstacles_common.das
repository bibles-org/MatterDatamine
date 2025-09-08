module agent_position_mapping_find_obstacles_common shared

require ecs
require math.base
require NavmeshMapping
require Grid
require DngWalkerai
require walkerai
require BehNodes
require DagorMath
require DagorMathUtils
require math.linear
require RendInst
require Dacoll
require CollRes
require game.utils.team
require game.es.ecs_common
require danetlibs.navmesh_phys.main.nphys_find_obstacles_common
require DagorSystem
require danetlibs.pathfinder.main.pathfinder_common
require danetlibs.navmesh_phys.main.nphys_common


def find_obstacles_and_map(eid : EntityId; movement_is_voluntary : bool; given_destination : float3)
  query(eid) <| $ [es] (position_mapping__lastZone : EntityId;
                        walker_agent__standShootLocalPos : float3;
                        navmesh_phys__prevPos : float3;
                        navmesh_phys__currentPos : float3;
                        navmesh_phys__currentWalkVelocity : float3;
                        beh_tree__enabled : bool = true;
                        beh_tree : BehaviourTree;
                        path_corridor__corners : Point3List;
                        path_corridor__jumpLinkStart : float3 = float3(-1.0, -1.0, -1.0);
                        path_corridor__jumpLinkEnd : float3 = float3(-1.0, -1.0, -1.0);
                        path_corridor__isClimbing : bool = false;
                        path_corridor__overJumpLinkStart : bool = false;
                        path_corridor__overJumpLink : bool = false;
                        obstacle_avoider__avoidTriggers : bool = false;
                        obstacle_avoider__horBuffer : float = 2.0;
                        obstacle_avoider__vertBuffer : float = 0.5;
                        obstacle_avoider__maxPathDst : float = 5.0;
                        obstacle_avoider__vehicleSearchRadius : float = 15.0;
                        obstacle_avoider__riExtraObstacleLimit : int = 15;
                        obstacle_avoider__escapeOffset : float = 0.4;
                        nphys_pushable__prevElevation : float = -1.0;
                        nphys_pushable__elevation : float = -1.0;
                        transform : float3x4;
                        var navmesh_phys__immediateObstacleIdx : int?;
                        var agent_obstacles : AgentObstacles)
    // somehow the substitution of many variables in the errMsg string is not working with 32bit build,
    // so I'm doing in multiple steps

    validate_gameplay_position(navmesh_phys__currentPos) <| $()
      var errMsg = "eid={get_entity_info(eid)}, navmesh_phys__currentPos={navmesh_phys__currentPos}"
      errMsg = "{errMsg}, navmesh_phys__prevPos={navmesh_phys__prevPos}, navmesh_phys__currentWalkVelocity={navmesh_phys__currentWalkVelocity}"
      errMsg = "{errMsg}, path_corridor__isClimbing={path_corridor__isClimbing}, path_corridor__overJumpLinkStart={path_corridor__overJumpLinkStart}"
      errMsg = "{errMsg}, path_corridor__overJumpLink={path_corridor__overJumpLink}, path_corridor__jumpLinkStart={path_corridor__jumpLinkStart}"
      errMsg = "{errMsg}, path_corridor__jumpLinkEnd={path_corridor__jumpLinkEnd}, beh = {beh_tree__enabled ? beh_tree |> beh_tree_current_name(true) : "<N/A>"}"
      errMsg = "{errMsg}, nphys_pushable__prevElevation={nphys_pushable__prevElevation}, nphys_pushable__elevation={nphys_pushable__elevation}"
      errMsg = "{errMsg}, position_mapping__lastZone={position_mapping__lastZone}, transform={transform}"
      return <- errMsg

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
      find_obstacles_and_map(position_mapping__lastZone,
                             eid,
                             box,
                             navmesh_phys__prevPos,
                             normalize(navmesh_phys__currentWalkVelocity),
                             destination,
                             obstacle_avoider__escapeOffset,
                             obstacle_avoider__vehicleSearchRadius,
                             obstacle_avoider__riExtraObstacleLimit,
                             obstacle_avoider__avoidTriggers,
                             agent_obstacles)

    else
      var box = BBox3(navmesh_phys__prevPos, obstacle_avoider__escapeOffset)
      box |> bbox3_add(given_destination)
      box |> bbox3_inflateXZ(obstacle_avoider__horBuffer)
      find_obstacles_and_map(position_mapping__lastZone,
                             eid,
                             box,
                             navmesh_phys__prevPos,
                             normalize(navmesh_phys__currentWalkVelocity),
                             given_destination,
                             obstacle_avoider__escapeOffset,
                             obstacle_avoider__vehicleSearchRadius,
                             obstacle_avoider__riExtraObstacleLimit,
                             obstacle_avoider__avoidTriggers,
                             agent_obstacles)


def find_obstacles_and_map(mapping_zone : EntityId;
                           agent_eid : EntityId;
                           box : BBox3;
                           pos : float3;
                           walk_dir : float3;
                           destination : float3;
                           escape_offset : float;
                           vehicle_search_radius : float;
                           ri_limit : int;
                           avoid_triggers : bool;
                           var agent_obstacles : AgentObstacles;
                           slim_doors = false)
  find_door_obstacles_and_map(mapping_zone, box, walk_dir, escape_offset, agent_obstacles, slim_doors)
  find_vehicle_obstacles_and_map(mapping_zone, vehicle_search_radius, pos, destination, escape_offset, agent_obstacles)
  find_ri_extra_obstacles_and_map(mapping_zone, box, pos, destination, escape_offset, ri_limit, agent_obstacles)
  find_grid_obstacles_and_map(fixed_array(ecs_hash("humans"), ecs_hash("obstacles")), mapping_zone, agent_eid, box, pos, destination, escape_offset, agent_obstacles)
  if avoid_triggers
    find_grid_obstacles_and_map(fixed_array(ecs_hash("traceable_spheres")), mapping_zone, agent_eid, box, pos, destination, escape_offset, agent_obstacles)
  var requiresMergeCount = 0
  for o in agent_obstacles.obstacles
    if o.merge
      requiresMergeCount++
      if requiresMergeCount > 1
        merge_obstacles(destination, agent_obstacles)
        break


def find_door_obstacles_and_map(mapping_zone : EntityId; box : BBox3; walk_dir : float3; escape_offset : float; var agent_obstacles : AgentObstacles; slim_doors : bool)
  for_each_entity_in_grid(ecs_hash("doors"), navmesh_get_unmap_transform_in_zone(mapping_zone), box, GridEntCheck.BOUNDING) <| $(doorEid : EntityId)
    query(doorEid) <| $ [es(REQUIRE_NOT=dontCreateNphysObstacle)] (ri_extra : RiExtraComponent;
                                                                   transform : float3x4;
                                                                   obstacle__bufferSize = float2();
                                                                   nphys_obstacle__merge : Tag const?)
      let riType = handle_to_ri_type(ri_extra.handle)
      let riCollres = get_ri_gen_extra_collres(int(riType))
      if riCollres == null
        return
      let door_box = BBox3(riCollres.vFullBBox)
      let transformPos = navmesh_map_position_in_zone(transform[3], mapping_zone)
      let transformDir = navmesh_map_direction_in_zone(transform[0], transform[3], mapping_zone)
      let doorSize = door_box.width
      let doorSizeWithBuffers = (max(doorSize.x, doorSize.z) + escape_offset + obstacle__bufferSize.y)
      let doorEnd = transformPos + transformDir * doorSizeWithBuffers
      let doorVec = doorEnd - transformPos
      let up = float3(0, 1, 0)
      if abs(dot(doorVec, up)) > length(doorVec) * 0.9 // 0.9 might be too big, we really expect this to be 0
        return //ignore vertical doors, they're going to seriously confuse the agents
      let norm = normalize(cross(doorVec, up))
      let thickness = (escape_offset * 0.6 + obstacle__bufferSize.x)
      let doorNormOffset = norm * thickness
      let doorDir = dot(walk_dir, doorNormOffset) > .0 ? 1.0 : -1.0
      var obstacle = agent_obstacles_add_obstacle(agent_obstacles)
      obstacle.eid = doorEid
      obstacle.isDoor = true //TODO check and correct
      obstacle.center = (doorEnd + transformPos) * 0.5
      obstacle.merge = nphys_obstacle__merge != null
      obstacle.height = door_box.boxMax.y - door_box.boxMin.y
      if !slim_doors
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
      else
        emplace(obstacle.segments, ObstacleSegment(transformPos, doorEnd, -transformDir * doorDir))
        emplace(obstacle.segments, ObstacleSegment(doorEnd - doorNormOffset * 0.5, doorEnd + doorNormOffset * 0.5, norm * doorDir))
        obstacle.boundingRadiusSq = (square(doorSizeWithBuffers) + square(thickness)) * 0.25


def find_vehicle_obstacles_and_map(mapping_zone : EntityId; search_radius : float; pos, destination : float3; escape_offset : float; var agent_obstacles : AgentObstacles)
  let unmappedPos = navmesh_unmap_position_in_zone(pos, mapping_zone)
  validate_gameplay_position(unmappedPos) <| $()
    return <- "pos={pos}, mapping_zone={mapping_zone}"
  let sphere = BSphere3(unmappedPos, search_radius)
  for_each_entity_in_grid(ecs_hash("vehicles"), sphere, GridEntCheck.BOUNDING) <| $(obstacleEid : EntityId)
    query(obstacleEid) <| $ [es(REQUIRE_NOT=(aliveCreature, dontCreateNphysObstacle))] (transform : float3x4; collres : CollisionResource; obstacle__handle = 0; nphys_obstacle__merge : Tag const?)
      if obstacle__handle != 0
        logerr("find_vehicle_obstacles_and_map: nav obstacle without tile cache enabled")
        return
      let vbox = BBox3(collres.vFullBBox)
      let tm = navmesh_get_map_transform_in_zone(mapping_zone) * transform
      if vbox.isempty
        return
      add_box_obstacle(obstacleEid, vbox, tm, pos, destination, escape_offset, true, nphys_obstacle__merge != null, agent_obstacles) <| $(from, corner : float3; obstacle_height : float)
        let vertBuff = min(0.4, obstacle_height)
        let traceFrom = from + float3(.0, vertBuff, .0)
        let agentToCorner = corner + float3(.0, vertBuff, .0) - traceFrom
        let agentToCornerLen = length(agentToCorner)
        let traceLen = agentToCornerLen - vertBuff
        if traceLen < vertBuff
          return true
        let traceDir = agentToCorner * safeinv(agentToCornerLen)
        return !rayhit_normalized(traceFrom, traceDir, traceLen, ETF_DEFAULT, -1)


def find_ri_extra_obstacles_and_map(mapping_zone : EntityId;  box : BBox3; pos, destination : float3; escape_offset : float; max_count : int; var agent_obstacles : AgentObstacles)
  gather_ri_gen_extra_collidable(navmesh_get_unmap_transform_in_zone(mapping_zone), box) <| $(handles : array<riex_handle_t>#)
    var budgetLeft = max_count
    for h in handles
      let riEid = find_ri_extra_eid(h)
      query(riEid) <| $ [es(REQUIRE_NOT=dontCreateNphysObstacle)] (transform : float3x4;
                                                                   ri_extra : RiExtraComponent;
                                                                   ri_extra__name = "";
                                                                   nphys_obstacle__merge : Tag const?;
                                                                   nphys_obstacle__useHull : Tag const?)
        if empty(ri_extra__name)
          return
        let riType = handle_to_ri_type(ri_extra.handle)
        let riCollres = get_ri_gen_extra_collres(int(riType))
        if riCollres == null
          return
        let tm = navmesh_get_map_transform_in_zone(mapping_zone) * transform
        var riBox = BBox3()
        riBox |> bbox3f_to_scalar_bbox3(riCollres.vFullBBox)
        add_box_obstacle(riEid, riBox, tm, pos, destination, escape_offset, nphys_obstacle__useHull == null, nphys_obstacle__merge != null, agent_obstacles)
        budgetLeft--
      if budgetLeft <= 0
        return


def find_grid_obstacles_and_map(grids : uint[]; mapping_zone, agent_eid : EntityId; box : BBox3; pos, destination : float3; escape_offset : float; var agent_obstacles : AgentObstacles)
  for_each_entity_in_grid(grids, navmesh_get_unmap_transform_in_zone(mapping_zone), box, GridEntCheck.POS) <| $(obstacleEid : EntityId)
    if agent_eid != obstacleEid
      query(obstacleEid) <| $ [es(REQUIRE=createObstacle)] (collres : CollisionResource const?;
                                                            transform : float3x4;
                                                            nphys_obstacle__radius : float const?;
                                                            nphys_obstacle__height = 1.8;
                                                            nphys_obstacle__numSegments = 4;
                                                            obstacle__mayBeRotated = false;
                                                            nphys_obstacle__merge : Tag const?)
        let tm = navmesh_get_map_transform_in_zone(mapping_zone) * transform
        if collres != null && nphys_obstacle__radius == null
          let creatureBox = BBox3(collres.vFullBBox)
          if creatureBox.isempty
            return
          add_box_obstacle(obstacleEid, creatureBox, tm, pos, destination, escape_offset, !obstacle__mayBeRotated, nphys_obstacle__merge != null, agent_obstacles)
        elif nphys_obstacle__radius != null
          add_poly_obstacle(obstacleEid, *nphys_obstacle__radius, nphys_obstacle__numSegments, nphys_obstacle__height, tm, destination, escape_offset, nphys_obstacle__merge != null, agent_obstacles)
        else
          add_box_obstacle(obstacleEid, IDENT_BBOX, tm, pos, destination, escape_offset, !obstacle__mayBeRotated, nphys_obstacle__merge != null, agent_obstacles)


def trace_single_ri_against_path_with_dir(ri_eid : EntityId;
                                          startPos, up : float3;
                                          walker_agent__standShootLocalPos : float3;
                                          path_corners;
                                          max_path_index : int;
                                          trace_distance_budget : float;
                                          max_single_trace : float = 1.0) : int
  var result = -1
  var traceDistanceBudget = trace_distance_budget
  query(ri_eid) <| $ [es] (ri_extra : RiExtraComponent; transform : float3x4)
    let riType = handle_to_ri_type(ri_extra.handle)
    let riCollres = get_ri_gen_extra_collres(int(riType))
    if riCollres == null
      return
    var box = BBox3()
    box |> bbox3f_to_scalar_bbox3(riCollres.vFullBBox)
    let invTm = inverse(transform)
    var start = startPos
    for idx in range(max_path_index)
      let end = path_corners[idx]
      var traceDir = end - start
      let traceDirLen = length(traceDir)
      traceDir *= safeinv(traceDirLen)
      let currentTraceDist = min(max_single_trace, min(traceDistanceBudget, traceDirLen))
      traceDistanceBudget -= currentTraceDist

      let traceRight = 0.3 * normalize(cross(up, traceDir))
      //Use only Y to avoid problems with rotation
      var agentYOffset = up * walker_agent__standShootLocalPos.y
      let quat = dir_to_quat(traceDir)
      agentYOffset = quat * agentYOffset

      let traceFrom = fixed_array(
        start + agentYOffset + traceRight,
        start + agentYOffset - traceRight,
        start + agentYOffset * 0.5 + traceRight,
        start + agentYOffset * 0.5 - traceRight
      )
      for trace in traceFrom
        let p1 = invTm * trace
        let p2 = invTm * (trace + traceDir * currentTraceDist)
        if test_segment_box_intersection(p1, p2, box)
          result = idx
          return
      if traceDistanceBudget <= 0.0
        return
      start = end
  return result


def trace_obstacles_along_path_with_grav_dir(agent_obstacles : AgentObstacles; startPos, up : float3; path_corridor__corners : Point3List;
                                             walker_agent__standShootLocalPos : float3; traceDist : float; obstacle_predicate : block<(obstacle : ObstacleEx const) : bool>) : EntityId
  var result = INVALID_ENTITY_ID
  var nearestObstacleIdx = length(path_corridor__corners)
  for obstacle in agent_obstacles.obstacles
    if !invoke(obstacle_predicate, obstacle)
      continue
    var pathIdx = trace_single_ri_against_path_with_dir(obstacle.eid, startPos, up, walker_agent__standShootLocalPos, path_corridor__corners, nearestObstacleIdx, traceDist)
    if pathIdx == -1
      pathIdx = trace_single_obstacle_against_path(obstacle, startPos, path_corridor__corners, nearestObstacleIdx, traceDist)
    if pathIdx != -1 && pathIdx < nearestObstacleIdx
      result = obstacle.eid
      nearestObstacleIdx = pathIdx
  return result
