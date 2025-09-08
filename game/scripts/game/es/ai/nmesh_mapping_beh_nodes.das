options always_export_initializer = true
require ecs
require app
require game.es.ecs_common
require strings
require BehNodes
require danetlibs.navmesh_phys.main.ai.nphys_nodes_common
require game.es.ai.agent_position_mapping_common
require DagorMath
require DagorDebug3D
require NavmeshMapping
require pathfinder
require DagorDataBlock
require debug.logerr_once
require math.base
require DagorMathUtils
require DagorRandom
require game.es.ai.agent_position_mapping_find_obstacles_common
require game.es.ai.walker_common
require game.es.ecs_common
require walkerai
require DngWalkerai


[beh_node(name="mapBbPosition")]
class MapBbPosition : BehNodeAdapter
  posParam : int
  toParam : int

  def override loadFromBlk(var data : DataBlock)
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3(0.0))
    toParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "to", ""), float3(0.0))

  def override update(dt : float) : EBehResult
    let unmappedPos = owner.blackBoard |> datablock_getPoint3(posParam)
    let mappedPos = navmesh_map_position(unmappedPos)
    owner.blackBoard |> set(toParam, mappedPos)
    return EBehResult.ER_SUCCESS


[beh_node(name="unmapBbPosition")]
class UnmapBbPosition : BehNodeAdapter
  posParam : int
  toParam : int

  def override loadFromBlk(var data : DataBlock)
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", ""), float3(0.0))
    toParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "to", ""), float3(0.0))

  def override update(dt : float) : EBehResult
    let mappedPos = owner.blackBoard |> datablock_getPoint3(posParam)
    let unmappedPos = navmesh_unmap_position(mappedPos)
    validate_gameplay_position(unmappedPos) <| $()
      return <- "mappedPos={mappedPos}"
    owner.blackBoard |> set(toParam, unmappedPos)
    return EBehResult.ER_SUCCESS


[beh_node(name="mapComponentPosition")]
class MapComponentPosition : BehNodeAdapter
  fromParam : string
  @hidden fromParamHash : uint
  toParam : string
  @hidden toParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("from", fromParam, fromParamHash, thisNode)
    data |> load_ecs_param("to", toParam, toParamHash, thisNode)

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    let unmappedPosRef = eid |> get_Point3(fromParam, fromParamHash)
    if unmappedPosRef == null
      return EBehResult.ER_FAILED

    var mappedPosRef = eid |> getRW_Point3(toParam, toParamHash)
    if mappedPosRef == null
      return EBehResult.ER_FAILED

    let mappedPos = navmesh_map_position(*unmappedPosRef)
    *mappedPosRef = mappedPos

    return EBehResult.ER_SUCCESS


[beh_node(name="unmapComponentPosition")]
class UnmapComponentPosition : BehNodeAdapter
  fromParam : string
  @hidden fromParamHash : uint
  toParam : string
  @hidden toParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("from", fromParam, fromParamHash, thisNode)
    data |> load_ecs_param("to", toParam, toParamHash, thisNode)

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    let mappedPosRef = eid |> get_Point3(fromParam, fromParamHash)
    if mappedPosRef == null
      return EBehResult.ER_FAILED

    var unmappedPosRef = eid |> getRW_Point3(toParam, toParamHash)
    if unmappedPosRef == null
      return EBehResult.ER_FAILED

    let unmappedPos = navmesh_unmap_position(*mappedPosRef)
    validate_gameplay_position(unmappedPos) <| $()
      return <- "mappedPos={*mappedPosRef}"
    *unmappedPosRef = unmappedPos

    return EBehResult.ER_SUCCESS


[beh_node(name="nPhysCorridorMoveToPosWithNavmeshMapping")]
class NPhysCorridorMoveToPosWithNavmeshMapping : NPhysCorridorMoveToPosBase
  def override getTargetPos(agent_eid : EntityId; var res : float3&; var lost_target : bool&) : bool
    let success = NPhysCorridorMoveToPosBase`getTargetPos(self, agent_eid, res, lost_target)
    navmesh_update_position_mapping_state_on_get_target(agent_eid, res)
    return success

  [unused_argument(children)] def override drawDebug(children : bool) : void
    AbstractNPhysCorridorMoveTo`drawDebug(self, children)
    let eid = beh_tree_eid(owner)
    query(eid) <| $ [es] (navmesh_phys__wishWalkDir : float3;
                          navmesh_phys__wishWalkSpeed : float;
                          path_corridor__corners : Point3List const?)
      var currentPos : float3
      if !NPhysCorridorMoveToPosBase`getCurrentPos(self, eid, currentPos)
        return
      let mappedPos = navmesh_map_position(currentPos)
      let mappedWalkDir = navmesh_map_direction(navmesh_phys__wishWalkDir, currentPos)
      var mappedPosOnNavmesh = mappedPos
      project_to_nearest_navmesh_point(mappedPosOnNavmesh, 0.5)
      draw_debug_arrow_buffered(currentPos, currentPos + navmesh_phys__wishWalkDir * navmesh_phys__wishWalkSpeed, E3DCOLOR(0xff00ff00), 1)
      draw_debug_arrow_buffered(mappedPos, mappedPos + mappedWalkDir * navmesh_phys__wishWalkSpeed, E3DCOLOR(0xff00ff00), 1)
      draw_debug_sphere_buffered(mappedPos, 0.4, E3DCOLOR(0xffff0000), 3)
      draw_debug_sphere_buffered(mappedPosOnNavmesh, 0.3, E3DCOLOR(0xff0000ff), 3)
      draw_debug_line_buffered(mappedPos, currentPos, E3DCOLOR(0xff0000ff), 3)
      if path_corridor__corners != null
        assume path = *path_corridor__corners
        var prev = currentPos
        for pos in path
          let drawPos = navmesh_unmap_position(pos)
          draw_debug_line_buffered(prev, drawPos, E3DCOLOR(0xffffffff), 2)
          prev = drawPos
        var targetPos : float3
        var lost : bool
        if NPhysCorridorMoveToPosBase`getTargetPos(self, eid, targetPos, lost)
          draw_debug_line_buffered(prev, targetPos, E3DCOLOR(0xffffffff), 2)


[beh_node(name="nPhysCorridorMoveToTargetWithNavmeshMapping")]
class NPhysCorridorMoveToTargetWithNavmeshMapping : NPhysCorridorMoveToTargetBase
  def override getTargetPos(agent_eid : EntityId; var res : float3&; var lost_target : bool&) : bool
    let success = NPhysCorridorMoveToTargetBase`getTargetPos(self, agent_eid, res, lost_target)
    navmesh_update_position_mapping_state_on_get_target(agent_eid, res)
    return success


def nphys_teleport_to_position_with_navmesh_mapping(eid : EntityId;
                                                    pos : float3)
  var result = false
  query(eid) <| $ [es] (var position_mapping__lastZone : EntityId?;
                        var transform aka my_transform : float3x4;
                        var navmesh_phys__prevPos : float3&;
                        var navmesh_phys__currentPos : float3&;
                        var navmesh_phys__currentPoly : int64&)
    let destinationMappingZone = navmesh_mapping_find_best_zone_for_position(pos)
    var teleportPosMapped = navmesh_map_position_in_zone(pos, destinationMappingZone)
    var teleportPoly = INVALID_POLY_REF
    project_to_nearest_navmesh_point(teleportPosMapped, float3(0.75), teleportPoly)
    my_transform[3] = navmesh_unmap_position_in_zone(teleportPosMapped, destinationMappingZone)
    validate_gameplay_position(my_transform[3]) <| $()
      return <- "teleportPosMapped={teleportPosMapped}, destinationMappingZone={destinationMappingZone}"
    navmesh_phys__prevPos = teleportPosMapped
    navmesh_phys__currentPos = teleportPosMapped
    navmesh_phys__currentPoly = int64(teleportPoly)
    if position_mapping__lastZone != null
      *position_mapping__lastZone = destinationMappingZone
    result = true
  return result


[beh_node(name="nPhysTeleportWithNavmeshMapping")]
class NPhysTeleportWithNavmeshMapping : BehNodeAdapter
  posParam : string
  @hidden posParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    let targetPosRef = eid |> get_Point3(posParam, posParamHash)
    if targetPosRef == null
      logerr_once("{eid}: nPhysCorridorMoveToPosWithNavmeshMapping unable to find target position '{posParam}:{posParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return EBehResult.ER_FAILED

    return nphys_teleport_to_position_with_navmesh_mapping(eid, *targetPosRef) ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="nPhysTeleportAlongTargetLookDirWithNavmeshMapping")]
class NPhysTeleportAlongTargetLookDirWithNavmeshMapping : BehNodeAdapter
  targetParam : string
  @hidden targetParamHash : uint
  distance : float2

  def override loadFromBlk(var data : DataBlock)
    distance = data |> datablock_getPoint2("distance", distance)
    data |> load_ecs_param("targetParam", targetParam, targetParamHash)

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let eid = beh_tree_eid(owner)
    let targetEid = get_Eid(eid, targetParam, targetParamHash) ?? INVALID_ENTITY_ID
    query(targetEid) <| $ [es] (transform aka target_transform : float3x4;
                                position_mapping__lastZone : EntityId const?)
      assume lastZone = position_mapping__lastZone
      let targetPos = (lastZone != null ? navmesh_map_position_in_zone(target_transform[3], *lastZone)
                                        : navmesh_map_position(target_transform[3]))
      let targetLookDir = (lastZone != null ? navmesh_map_direction_in_zone(target_transform[0], target_transform[3], *lastZone)
                                            : navmesh_map_direction(target_transform[0], target_transform[3]))
      var teleportPos = targetPos + targetLookDir * rnd_float(distance.x, distance.y)
      teleportPos = (lastZone != null ? navmesh_unmap_position_in_zone(teleportPos, *lastZone)
                                      : navmesh_unmap_position(teleportPos))
      validate_gameplay_position(teleportPos) <| $()
        return <- "lastZone={lastZone}, targetPos={targetPos}, targetLookDir={targetLookDir}, distance={distance}"

      if nphys_teleport_to_position_with_navmesh_mapping(eid, teleportPos)
        result = EBehResult.ER_SUCCESS
    return result


// slightly changed version of nMeshFindPointNearTarget node from DNG
[beh_node(name="nMeshFindPointNearTargetWithNavmeshMapping")]
class NMeshFindPointNearTargetWithNavmeshMapping : BehNodeAdapter
  posParam : string
  @hidden posParamHash : uint
  targetParam : string
  @hidden targetParamHash : uint
  dist : float2 = float2(1f)
  @hidden distSq : float2 = float2(1f)
  tries : int = 5
  angleRangeSpread : float2 = float2(-0.25 * PI, 0.25 * PI)
  oppositePoint : bool = false
  reusePrevPos : bool = false
  tracerayNavmesh : bool = false
  checkPath : bool = true
  extents : float3 = float3(1)

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)
    data |> load_optional_ecs_param("targetParam", targetParam, targetParamHash)
    dist = data |> datablock_getPoint2("dist", dist)
    distSq = float2(square(dist.x), square(dist.y))
    tries = data |> datablock_getInt("tries", tries)
    extents = data |> datablock_getPoint3("extents", extents)
    oppositePoint = data |> datablock_getBool("oppositePoint", oppositePoint)
    reusePrevPos = data |> datablock_getBool("reusePrevPos", reusePrevPos)
    tracerayNavmesh = data |> datablock_getBool("tracerayNavmesh", tracerayNavmesh)
    checkPath = data |> datablock_getBool("checkPath", checkPath)
    angleRangeSpread = data |> datablock_getPoint2("angleRangeSpread", float2(rad_to_deg(angleRangeSpread.x), rad_to_deg(angleRangeSpread.y)))
    angleRangeSpread = float2(deg_to_rad(angleRangeSpread.x), deg_to_rad(angleRangeSpread.y))

  def getTarget(eid : EntityId; from_pos : float3; var pos : float3&; var spread_dir : float3&) : bool
    let targetParamRef = eid |> get_Eid(targetParam, targetParamHash)
    if targetParamRef == null
      logerr_once("{eid}: nMeshFindPointNearTarget can't to find target '{targetParam}:{targetParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return false

    var success = false
    query(*targetParamRef) <| $ [es] (transform : float3x4)
      pos = transform[3]
      success = true
    if success
      spread_dir = oppositePoint ? pos - from_pos : from_pos - pos
    return success

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let eid = beh_tree_eid(owner)
    query(eid) <| $ [es] (transform : float3x4;
                          position_mapping__lastZone : EntityId;
                          navmesh_phys__climbJumpMaxUpHeight : float const?)
      let fromPos = transform[3]
      var targetPos, dir : float3
      if !self->getTarget(eid, fromPos, targetPos, dir)
        return
      let baseAngle = atan2(dir.z, dir.x)
      if reusePrevPos
        let prevPos = get_Point3(eid, posParam, posParamHash)
        if prevPos != null
          let distPrevPosSq = distance_sq(*prevPos, targetPos)
          if distPrevPosSq >= distSq.x && distPrevPosSq <= distSq.y
            let dirToTarget = *prevPos - targetPos
            let dirAngle = atan2(dirToTarget.z, dirToTarget.x)
            let angleDelta = angle_diff(dirAngle, baseAngle)
            if angleDelta >= angleRangeSpread.x && angleDelta <= angleRangeSpread.y
              res = EBehResult.ER_SUCCESS
              return
      let targetMappingZone = navmesh_mapping_find_best_zone_for_position(targetPos)
      let mappedTargetPos = navmesh_map_position_in_zone(targetPos, targetMappingZone)
      for _ in range(tries)
        let randAngle = rnd_float(baseAngle + angleRangeSpread.x, baseAngle + angleRangeSpread.y)
        var sine, cosine : float
        sincos(randAngle, sine, cosine)
        var mappedResPos = mappedTargetPos + float3(cosine, 0f, sine) * rnd_float(min(dist.x + extents.x, dist.y - extents.x), dist.y - extents.x)
        if !project_to_nearest_navmesh_point(mappedResPos, extents)
          continue
        var resPos = navmesh_unmap_position_in_zone(mappedResPos, targetMappingZone)
        validate_gameplay_position(resPos) <| $()
          return <- "mappedResPos={mappedResPos}, targetMappingZone={targetMappingZone}"

        if tracerayNavmesh
          var hitPos = float3()
          if traceray_navmesh(mappedTargetPos, mappedResPos, extents, hitPos)
            let hitDistSq = distance_sq(targetPos, hitPos)
            if hitDistSq < distSq.x || hitDistSq > distSq.y
              continue
            resPos = navmesh_unmap_position_in_zone(hitPos, targetMappingZone)
            validate_gameplay_position(resPos) <| $()
              return <- "hitPos={hitPos}, targetMappingZone={targetMappingZone}"

        if checkPath
          var checkPathRes = false
          let mappedFrom = navmesh_map_position_in_zone(fromPos, position_mapping__lastZone)
          let mappedRes = navmesh_map_position_in_zone(resPos, targetMappingZone)
          using(mappedFrom, mappedRes, extents) <| $(var req : FindRequest#)
            if navmesh_phys__climbJumpMaxUpHeight != null
              req.includeFlags |= int(PolyFlag.POLYFLAG_JUMP)
            req.maxJumpUpHeight = navmesh_phys__climbJumpMaxUpHeight ?? 0.f
            checkPathRes = check_path(req, extents.x, extents.x)

          if !checkPathRes
            continue
        res = EBehResult.ER_SUCCESS
        if !has(eid, posParam, posParamHash)
          logerr_once("{eid}: entity without output param '{posParam}:{posParamHash}' / {*thisNode |> beh_node_hierarchy_name(true)}")
        setOptional(eid, posParam, posParamHash, resPos)
        break
    return res


[beh_node(name="nMeshFindDirectionalPointNearTargetWithNavmeshMapping")]
class NMeshFindDirectionalPointNearTargetWithNavmeshMapping : NMeshFindPointNearTargetWithNavmeshMapping
  directionAngle : float = 0f
  direction : float3

  def override loadFromBlk(var data : DataBlock)
    NMeshFindPointNearTargetWithNavmeshMapping`loadFromBlk(self, data)
    directionAngle = data |> datablock_getReal("directionAngle", directionAngle)
    sincos(deg_to_rad(directionAngle), direction.z, direction.x)

  [unused_argument(from_pos)] def override getTarget(eid : EntityId; from_pos : float3; var pos : float3 &; var spread_dir : float3 &) : bool
    let targetParamRef = eid |> get_Eid(targetParam, targetParamHash)
    if targetParamRef == null
      logerr_once("{eid}: NMeshFindDirectionalPointNearTarget can't to find target '{targetParam}:{targetParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return false

    var success = false
    query(*targetParamRef) <| $ [es] (transform : float3x4)
      pos = transform[3]
      success = true
      spread_dir = transform |> rotate <| direction
      if oppositePoint
        spread_dir *= -1f
    return success


[beh_node(name="nMeshFindRandomPointWithNavmeshMapping")]
class NMeshFindRandomPointWithNavmeshMapping : BehNodeAdapter
  posParam : string
  @hidden posParamHash : uint
  dist : float2 = float2(1f)
  mappingZone : EntityId


  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)
    dist = data |> datablock_getPoint2("dist", dist)

  def getAroundPos(eid : EntityId) : float3
    var res : float3
    let found = query(eid) <| $ [es] (transform : float3x4)
      res = transform[3]
    if !found
      logerr_once("{eid}: NMeshFindRandomPoint can't find entity transform {*thisNode |> beh_node_hierarchy_name(true)}")
      return float3()
    mappingZone = navmesh_mapping_find_best_zone_for_position(res)
    return navmesh_map_position_in_zone(res, mappingZone)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let eid = beh_tree_eid(owner)
    var resPos : float3
    let aroundPos = self->getAroundPos(eid)
    if find_random_point_inside_circle(aroundPos, rnd_float(dist.x, dist.y), 1., resPos)
      res = EBehResult.ER_SUCCESS
      if !eid |> has(posParam, posParamHash)
        logerr_once("{eid}: entity without output param '{posParam}:{posParamHash}' / {*thisNode |> beh_node_hierarchy_name(true)}")
      let pos = navmesh_unmap_position_in_zone(resPos, mappingZone)
      validate_gameplay_position(pos) <| $()
        return <- "resPos={resPos}, mappingZone={mappingZone}"
      setOptional(eid, posParam, posParamHash, pos)
    return res


[beh_node(name="nMeshFindRandomPointAroundPosWithNavmeshMapping")]
class NMeshFindRandomPointAroundPosWithNavmeshMapping : NMeshFindRandomPointWithNavmeshMapping
  aroundPos : string
  @hidden aroundPosHash : uint

  def override loadFromBlk(var data : DataBlock)
    NMeshFindRandomPointWithNavmeshMapping`loadFromBlk(self, data)
    data |> load_ecs_param("aroundPos", aroundPos, aroundPosHash, thisNode)

  def override getAroundPos(eid : EntityId) : float3
    let aroundPosRef = eid |> get_Point3(aroundPos, aroundPosHash)
    if aroundPosRef == null
      logerr_once("{eid}: nMeshFindRandomPointAroundPos can't find aroundPos '{aroundPos}:{aroundPosHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return float3()
    mappingZone = navmesh_mapping_find_best_zone_for_position(*aroundPosRef)
    return navmesh_map_position_in_zone(*aroundPosRef, mappingZone)


[beh_node(name="nMeshFindRandomPointAroundTargetWithNavmeshMapping")]
class NMeshFindRandomPointAroundTargetWithNavmeshMapping : NMeshFindRandomPointWithNavmeshMapping
  targetParam : string
  @hidden targetParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    NMeshFindRandomPointWithNavmeshMapping`loadFromBlk(self, data)
    data |> load_ecs_param("targetParam", targetParam, targetParamHash, thisNode)

  def override getAroundPos(eid : EntityId) : float3
    let targetParamRef = eid |> get_Eid(targetParam, targetParamHash)
    var res = float3()
    if targetParamRef == null
      logerr_once("{eid}: nMeshFindRandomPointAroundTarget can't to find target '{targetParam}:{targetParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return res

    query(*targetParamRef) <| $ [es] (transform : float3x4)
      res = transform[3]
    mappingZone = navmesh_mapping_find_best_zone_for_position(res)
    return navmesh_map_position_in_zone(res, mappingZone)


[beh_node(name="nPhysLookAtPosWithPositionMapping")]
class NPhysLookAtPosWithPositionMapping : NPhysLookAtPosBase
  def override getTargetPos(eid : EntityId) : float3
    return navmesh_map_position(NPhysLookAtPosBase`getTargetPos(self, eid))


[beh_node(name="nPhysStareAtPosWithPositionMapping")]
class NPhysStareAtPosWithPositionMapping : NPhysLookAtPosWithPositionMapping
  override stare = true


[beh_node(name="nPhysLookAtEntityWithPositionMapping")]
class NPhysLookAtEntityWithPositionMapping : NPhysLookAtEntityBase
  def override getTargetPos(eid : EntityId) : float3
    return navmesh_map_position(NPhysLookAtEntityBase`getTargetPos(self, eid))

[beh_node(name="nPhysStareAtEntityWithPositionMapping")]
class NPhysStareAtEntityWithPositionMapping : NPhysLookAtEntityWithPositionMapping
  override stare = true

[beh_node(name="nPhysLookAtRiWithPositionMapping")]
class NPhysLookAtRiWithPositionMapping : NPhysLookAtRiBase
  def override getTargetPos(eid : EntityId) : float3
    return navmesh_map_position(NPhysLookAtRiBase`getTargetPos(self, eid))


class AbstractFindObstacleWithNavmeshMapping : BehNodeAdapter
  traceDist : float = 1.0

  def override loadFromBlk(var data : DataBlock)
    traceDist = data |> datablock_getReal("traceDist", traceDist)
    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(transform,
                                      path_corridor__corners,
                                      walker_agent__standShootLocalPos,
                                      agent_obstacles))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> AbstractFindObstacleWithNavmeshMapping is missing fields and will not function {*thisNode |> beh_node_hierarchy_name(true)}")

  def findObstacle(obstacle_predicate : block<(obstacle : ObstacleEx const) : bool>) : EntityId
    var outObstacle = INVALID_ENTITY_ID
    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4;
                                          path_corridor__corners : Point3List;
                                          walker_agent__standShootLocalPos : float3;
                                          agent_obstacles : AgentObstacles;
                                          navmesh_phys__currentPos : float3 const?;
                                          position_mapping__lastZone : EntityId = INVALID_ENTITY_ID)
      let scale = float3(length(transform[0]), length(transform[1]), length(transform[2]))
      //unmap copy
      using() <| $(var mapped_obstacles : AgentObstacles)
        using() <| $(var mapped_path_corridor : Point3List)
          for obstacle in agent_obstacles.obstacles
            var mapped_obstacle = agent_obstacles_add_obstacle(mapped_obstacles)
            mapped_obstacle.center = navmesh_unmap_position_in_zone(obstacle.center, position_mapping__lastZone)
            validate_gameplay_position(mapped_obstacle.center) <| $()
              return <- "obstacle.center={obstacle.center}, position_mapping__lastZone={position_mapping__lastZone}"
            mapped_obstacle.isDoor = obstacle.isDoor
            mapped_obstacle.merge = obstacle.merge
            mapped_obstacle.eid = obstacle.eid
            mapped_obstacle.boundingRadiusSq = obstacle.boundingRadiusSq
            mapped_obstacle.height = obstacle.height
            for segment in obstacle.segments
              let v1 = navmesh_unmap_position_in_zone(segment.start, position_mapping__lastZone)
              validate_gameplay_position(v1) <| $()
                return <- "segment.start={segment.start}, position_mapping__lastZone={position_mapping__lastZone}"
              let v2 = navmesh_unmap_position_in_zone(segment.end, position_mapping__lastZone)
              validate_gameplay_position(v2) <| $()
                return <- "segment.end={segment.end}, position_mapping__lastZone={position_mapping__lastZone}"
              let pos = navmesh_phys__currentPos != null ? *navmesh_phys__currentPos : transform[3]
              let dir = navmesh_unmap_direction_in_zone(segment.dir, pos, position_mapping__lastZone)
              mapped_obstacle.segments |> emplace(ObstacleSegment(v1, v2, dir))
          for corner in path_corridor__corners
            let unmappedPos = navmesh_unmap_position_in_zone(corner, position_mapping__lastZone)
            validate_gameplay_position(unmappedPos) <| $()
              return <- "corner={corner}, position_mapping__lastZone={position_mapping__lastZone}"
            mapped_path_corridor |> push(unmappedPos)
          outObstacle = trace_obstacles_along_path_with_grav_dir(mapped_obstacles,
                                                                  transform[3],
                                                                  transform[1],
                                                                  mapped_path_corridor,
                                                                  walker_agent__standShootLocalPos * scale,
                                                                  traceDist,
                                                                  obstacle_predicate)
    return outObstacle


[beh_node(name="findDestructableObstacleWithNavmeshMapping")]
class FindDestructableObstacleWithNavmeshMapping : AbstractFindObstacleWithNavmeshMapping

  def override loadFromBlk(var data : DataBlock)
    AbstractFindObstacleWithNavmeshMapping`loadFromBlk(self, data)
    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(destructable_obstacle_handler__isRi,
                                      destructable_obstacle_handler__targetEid))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> FindDestructableObstacleWithNavmeshMapping is missing fields and will not function {*thisNode |> beh_node_hierarchy_name(true)}")

  def override update(dt : float) : EBehResult
    var res : EBehResult = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (var destructable_obstacle_handler__isRi : bool&;
                                          var destructable_obstacle_handler__targetEid : EntityId&)
      destructable_obstacle_handler__targetEid = self->findObstacle() <| $(obstacle : ObstacleEx)
        return has(obstacle.eid, "obstacle__isDestructible")
      destructable_obstacle_handler__isRi = has(destructable_obstacle_handler__targetEid, "ri_extra")
      if destructable_obstacle_handler__targetEid != INVALID_ENTITY_ID
        res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="findDoorObstacleWithNavmeshMapping")]
class FindDoorObstacleWithNavmeshMapping : AbstractFindObstacleWithNavmeshMapping
  pushableOnly : bool = false

  def override loadFromBlk(var data : DataBlock)
    let eid = beh_tree_eid(owner)
    AbstractFindObstacleWithNavmeshMapping`loadFromBlk(self, data)
    pushableOnly = data |> datablock_getBool("pushableOnly", pushableOnly)
    if !(query(eid) <| $ [es(REQUIRE=(door_obstacle_handler__immediateDoor))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> FindDoorObstaclWithNavmeshMapping is missing fields and will not function {*thisNode |> beh_node_hierarchy_name(true)}")

  def override update(dt : float) : EBehResult
    var res : EBehResult = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4;
                                          path_corridor__corners : Point3List;
                                          navmesh_phys__currentPos : float3 const?;
                                          var door_obstacle_handler__immediateDoor : EntityId&)
      door_obstacle_handler__immediateDoor = self->findObstacle() <| $(obstacle : ObstacleEx)
        var result = obstacle.isDoor
        if result
          query(obstacle.eid) <| $ [es] (rendinst_axis_rotation__targetAngle, door_operations__openedAngle : float)
            result = abs(rendinst_axis_rotation__targetAngle - door_operations__openedAngle) > 5.0
        if result && pushableOnly && length(path_corridor__corners) > 0
          var pos = navmesh_phys__currentPos != null ? *navmesh_phys__currentPos : transform[3]
          result = false
          for idx in range(min(3, length(path_corridor__corners)))
            let doorIsPushable = check_door_is_pushable(obstacle.eid, pos, path_corridor__corners[idx])
            pos = path_corridor__corners[idx]
            result ||= doorIsPushable > 0
            if doorIsPushable != 0 //we have a result
              break
        return result
      if door_obstacle_handler__immediateDoor != INVALID_ENTITY_ID
        res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="patrollerWithNavmeshMapping")]
class PatrollerWithNavmeshMapping : BehNodeAdapter

  def override loadFromBlk(var data : DataBlock)
    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(patroller__radius, patroller__maxWaypoints, patroller__aroundPos, patroller__waypoints, patroller__currentWaypointUpdateAt, patroller__currentWaypointUpdateInterval, patroller__currentWaypointIdx, patroller__currentWaypoint))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> Patroller requires patroller.radius, patroller.maxWaypoints, patroller.aroundPos, patroller.waypoints, patroller.currentWaypointIdx and patroller.currentWaypoint fields")


  [unused_argument(pos)] def isValidPos(pos : float3) { return true; }

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (patroller__radius : float;
                                          patroller__maxWaypoints : int;
                                          patroller__aroundPos : float3;
                                          patroller__currentWaypointUpdateInterval : float;
                                          var patroller__currentWaypointUpdateAt : float&;
                                          var patroller__waypoints : Point3List&;
                                          var patroller__currentWaypointIdx : int&;
                                          var patroller__currentWaypoint : float3&)
      let curTime = get_sync_time()
      if curTime < patroller__currentWaypointUpdateAt
        res = EBehResult.ER_SUCCESS
        return
      patroller__currentWaypointIdx = (patroller__currentWaypointIdx + 1) % patroller__maxWaypoints

      let mappingZone = navmesh_mapping_find_best_zone_for_position(patroller__aroundPos)
      let aroundPosMapped = navmesh_map_position_in_zone(patroller__aroundPos, mappingZone)

      let reqMorePoints = patroller__currentWaypointIdx - length(patroller__waypoints) + 1
      if reqMorePoints > 0
        for _ in range(reqMorePoints)
          var pos : float3
          if find_random_point_inside_circle(aroundPosMapped, patroller__radius, 1., pos)
            pos = navmesh_unmap_position_in_zone(pos, mappingZone)
            validate_gameplay_position(pos) <| $()
              return <- "aroundPosMapped={aroundPosMapped}, patroller__radius={patroller__radius}, mappingZone={mappingZone}"
            if self->isValidPos(pos)
              patroller__waypoints |> push(pos)

      if patroller__currentWaypointIdx >= length(patroller__waypoints)
        if length(patroller__waypoints) == 0
          return // no way, restart
        patroller__currentWaypointIdx = 0

      patroller__currentWaypoint = patroller__waypoints[patroller__currentWaypointIdx]
      patroller__currentWaypointUpdateAt = curTime + patroller__currentWaypointUpdateInterval
      res = EBehResult.ER_SUCCESS

    return res