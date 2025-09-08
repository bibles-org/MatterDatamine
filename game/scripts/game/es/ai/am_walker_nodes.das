options always_export_initializer = true
require app
require ecs
require net
require Dacoll
require ecs.common
require ecs.safe
require daslib.algorithm
require DagorDataBlock
require DagorRandom
require DagorTime
require BehNodes
require DngWalkerai
require pathfinder
require inventory
require Grid
require DagorMath
require gameObject
require game.es.extraction_point.extraction_point_common
require game.events.events
require game.events.inventory_events
require game.es.ai.walker_common
require game.es.inventory_common
require game.es.inventory_checks_common
require game.es.inventory_item_common
require game.events.events_active_matter
require game.events.events_game
require debug.logerr_once
require level
require math.base
require math.random
require danetlibs.pathfinder.main.pathfinder_common
require active_matter.game.utils.poly_area
require active_matter.game.es.regions_common
require active_matter.game.es.moving_zone_common
require game.es.grav_zones_common
require AnimV20
require GeomNodeTree
require NavmeshMapping
require game.es.custom_region_common
require danetlibs.navmesh_phys.main.nphys_find_obstacles_common
require game.es.ai.agent_position_mapping_find_obstacles_common


// calc deterministic pos by given eid
def get_region_pos_by_eid(region : SplineRegion; eid : EntityId) : float3
  let idx = int(uint(eid)) % length(region.border)
  return lerp(region.border[idx], region.border[(idx + 1) % length(region.border)], float3(eid_frnd(eid)))


// calc deterministic pos by given eid
def get_region_pos_by_eid(points : Point2List; eid : EntityId) : float3
  let idx = int(uint(eid)) % length(points)
  let point = lerp(points[idx], points[(idx + 1) % length(points)], float2(eid_frnd(eid)))
  return float3(point.x, traceht_lmesh(point), point.y)


def is_region_in_zone(region : SplineRegion; zone_pos : float3; zone_radius : float) : bool
  let zoneRadiusSq = square(zone_radius)
  for border in region.border
    if distance_sq(border, zone_pos) > zoneRadiusSq
      return false
  return true


def get_regions_in_radius_in_zone(eid : EntityId; pos : float3; radius : float; zone : MovingZone;
                                  var region_centers : array<float4>; var region_radius : array<float>; var dist_sum : float&) : void
  dist_sum = 0.f
  let radiusSq = square(radius)
  query() <| $ [es] (transform : float3x4; custom_region__points : Point2List)
    let targetPos = get_region_pos_by_eid(custom_region__points, eid) // target pos in region for given bot
    if distance_sq(targetPos, pos) > radiusSq // too far position
      return
    if !inside_zone(zone, targetPos) // unsafe position
      return
    let dist = distance(targetPos, pos) // calc dist to target corner/position
    region_centers |> push(float4(transform[3], dist)) // but here pass center
    region_radius |> push(max(length(transform[0]), length(transform[2])))
    dist_sum += dist


def get_players_num_in_regions(region_centers : array<float4>; region_radius : array<float>; var players_and_bots_num : array<int2>) : void
  players_and_bots_num |> resize(length(region_centers))
  for center, radius, num in region_centers, region_radius, players_and_bots_num
    let sphere = BSphere3(center.xyz, radius)
    for_each_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.BOUNDING) <| $ [unused_argument(_)] (eid : EntityId; _ : float3)
      query(eid) <| $ [es(REQUIRE=heroForPlayer, REQUIRE_NOT=deadEntity)] (beh_tree__enabled = false)
        if beh_tree__enabled
          num.y++ // bots count
        else
          num.x++ // players count


def get_active_mattery_pos_in_radius_in_zone(pos : float3; radius : float; zone : MovingZone; var dist_sum : float&; var positions : array<float4>) : void
  dist_sum = 0.f
  let zoneRadiusSq = square(zone.radius)
  let radiusSq = square(radius)
  query() <| $ [es(REQUIRE=artifact__extractable)] (transform : float3x4)
    assume am_pos = transform[3]
    if distance_sq(am_pos, zone.pos) > zoneRadiusSq || distance_sq(am_pos, pos) > radiusSq
      return
    let dist = distance(am_pos, pos)
    positions |> push(float4(am_pos, dist))
    dist_sum += dist

  query() <| $ [es] (am_core__moveTo : float3)
    assume am_pos = am_core__moveTo
    if distance_sq(am_pos, zone.pos) > zoneRadiusSq || distance_sq(am_pos, pos) > radiusSq
      return
    let dist = distance(am_pos, pos)
    positions |> push(float4(am_pos, dist))
    dist_sum += dist


def get_item_extraction_pos_in_radius_in_zone(pos : float3; radius : float; zone : MovingZone; var dist_sum : float&; var positions : array<float4>) : void
  dist_sum = 0.f
  let zoneRadiusSq = square(zone.radius)
  let radiusSq = square(radius)
  query() <| $ [es(REQUIRE=extraction_items_point)] (transform : float3x4; extraction__currentState : int)
    if (extraction__currentState == int(ExtractionPointState.DISABLED)
        || distance_sq(transform[3], zone.pos) > zoneRadiusSq || distance_sq(transform[3], pos) > radiusSq)
      return
    let dist = distance(transform[3], pos)
    positions |> push(float4(transform[3], dist))
    dist_sum += dist


[beh_node(name="findGameObjPos")]
class FindGameObjPos : BehNodeAdapter
  posParam : int = -1
  gameObjType : string = "loot_box"
  nearestOutOf : int = 1
  avoidEnemiesDistance = 15.
  maxDistance = 350.

  def override loadFromBlk(var data : DataBlock)
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", "wishPosition"), float3())
    nearestOutOf = data |> datablock_getInt("nearestOutOf", nearestOutOf)
    gameObjType = data |> datablock_getStr("gameObjType", gameObjType)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    find_query() <| $ [es] (game_objects : GameObjects)
      let objs = game_objects |> get_scene_game_objects_by_name(gameObjType)
      if objs == null
        return true

      query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4)
        var positions : array<float3>

        let box = BBox3(transform[3], maxDistance)
        objs |> for_scene_game_objects(box) <| $ [unused_argument(ni)] (ni : uint; tm : float3x4#)
          positions |> push(tm[3])
        let count = length(positions)
        if count <= 0
          logerr_once("no game objects around me {transform[3]} radius: {maxDistance}")
          return
        var foundPos = float3(FLT_MAX)
        var tries = nearestOutOf
        while tries-- > 0
          let index = uint(rnd_int(0, count - 1))
          var pos = positions[index]
          if project_to_nearest_navmesh_point(pos, float3(1.0))
            let distK = 10. / (1. + distance(pos, transform[3]))
            if gfrnd() < distK
              foundPos = pos
        if foundPos.x < FLT_MAX
          res = EBehResult.ER_SUCCESS
          owner.blackBoard |> set(posParam, foundPos)
      return true
    return res


[beh_node(name="findExtractionPoint")]
class FindExtractionPoint : BehNodeAdapter
  posParam : int = -1
  reqActiveState : bool = false

  def override loadFromBlk(var data : DataBlock)
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", "wishPosition"), float3())
    reqActiveState = data |> datablock_getBool("reqActiveState", reqActiveState)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    var bestPos : float3
    var bestDstSq = FLT_MAX

    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4)
      let agentPos = transform[3]
      query() <| $ [es] (transform : float3x4; extraction__currentState : int)
        if (extraction__currentState != int(ExtractionPointState.DISABLED)
          && (!reqActiveState || extraction__currentState == int(ExtractionPointState.ACTIVE)))
          let dstSq = distance_sq(transform[3], agentPos)
          if dstSq < bestDstSq
            bestDstSq = dstSq
            bestPos = transform[3]
    if bestDstSq != FLT_MAX
      res = EBehResult.ER_SUCCESS
      owner.blackBoard |> set(posParam, bestPos)
    return res


[beh_node(name="activateNearestExtractionPoint")]
class ActivateNearestExtractionPoint : BehNodeAdapter

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    var nearestExtraction : EntityId
    var nearestExtractionPointState : int
    var bestDstSq = 25.

    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (transform : float3x4)
      let agentPos = transform[3]
      query() <| $ [es] (eid : EntityId; transform : float3x4; extraction__currentState : int)
        if extraction__currentState != int(ExtractionPointState.DISABLED)
          let dstSq = distance_sq(transform[3], agentPos)
          if dstSq < bestDstSq
            bestDstSq = dstSq
            nearestExtraction = eid
            nearestExtractionPointState = extraction__currentState
    if nearestExtraction != INVALID_ENTITY_ID
      res = EBehResult.ER_SUCCESS
      if nearestExtractionPointState == int(ExtractionPointState.INACTIVE)
        sendEvent(nearestExtraction, CmdUse(requesterEid = agentEid))
    return res


[beh_node(name="cryForHelp")]
class CryForHelp : BehNodeAdapter
  radius : float2 = float2(10)
  enemyParam : string
  @hidden enemyParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("enemyParam", enemyParam, enemyParamHash, thisNode)
    radius = datablock_getPoint2(data, "radius", radius)

  def override update(dt : float) : EBehResult
    let ownerEid = beh_tree_eid(owner)
    let offender = ownerEid |> get_Eid(enemyParam, enemyParamHash) ?? INVALID_ENTITY_ID
    query(offender) <| $ [es] (isAlive : bool; transform aka offender_transform : float3x4)
      if isAlive
        query(ownerEid) <| $ [es] (transform aka owner_transform : float3x4; team aka owner_team : int)
          query() <| $ [es(REQUIRE=answersToCryForHelp)] (transform : float3x4; team : int; eid : EntityId)
            if eid != ownerEid && team == owner_team
              let diff = transform[3] - owner_transform[3]
              if abs(diff.x) < radius.x && abs(diff.y) < radius.y && abs(diff.z) < radius.x
                sendEvent(eid, CmdCryForHelp(enemy = offender, enemyPos = offender_transform[3]))
    return EBehResult.ER_SUCCESS


[es(tag=server, REQUIRE=answersToCryForHelp)]
def on_being_called_for_help(evt : CmdCryForHelp; var beh_tree : BehaviourTree)
  beh_tree.blackBoard |> get_or_create("lastKnownEnemy", int(uint(INVALID_ENTITY_ID)))
  let existingEnemy = beh_tree.blackBoard |> datablock_getInt("lastKnownEnemy", int(uint(INVALID_ENTITY_ID)))
  if existingEnemy == int(uint(INVALID_ENTITY_ID))
    beh_tree.blackBoard |> set("lastKnownEnemy", int(uint(evt.enemy)))
    beh_tree.blackBoard |> set("laskKnownEnemyPosition", evt.enemyPos)
    beh_tree_reset(beh_tree)


[beh_node(name="findAttractRegionInZone")]
class FindAttractRegionInZone : BehNodeAdapter
  posParam : int = -1
  tries : int = 2
  radius : float = 700.f
  regionPos : string
  @hidden regionPosHash : uint

  def override loadFromBlk(var data : DataBlock)
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", "default"), float3())
    tries = data |> datablock_getInt("tries", tries)
    radius = datablock_getReal(data, "radius", radius)
    data |> load_ecs_param("regionPos", regionPos, regionPosHash, thisNode)
    let ownerEid = beh_tree_eid(owner)
    if !(query(ownerEid) <| $ [es(REQUIRE=am_bot__visitedAttractRegions)] {})
      logerr("{ownerEid}: findAttractRegionInZone node requires am_bot__visitedAttractRegions")

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)

    var regionPosRef = ownerEid |> getRW_Point3(regionPos, regionPosHash)
    if regionPosRef == null
      logerr_once("{ownerEid}: findAttractRegionInZone node can't find regionPos '{regionPos}:{regionPosHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return EBehResult.ER_FAILED

    query(ownerEid) <| $ [es] (transform : float3x4;
                               am_bot__visitedAttractRegions : Point3List)
      let zone = get_current_moving_zone()
      var regionsDistSum, amDistSum, extractionDistSum : float = 0.f
      var attractPosArray : array<float4>
      var regionsRadius : array<float>
      get_regions_in_radius_in_zone(ownerEid, transform[3], radius, zone, attractPosArray, regionsRadius, regionsDistSum)
      var playersAndBotsNumInRegion : array<int2>
      get_players_num_in_regions(attractPosArray, regionsRadius, playersAndBotsNumInRegion)

      for regionCenterAndDist, playersAndBotsInRegion in attractPosArray, playersAndBotsNumInRegion
        // Every player reduces distance on 50m, every bot - increases on 200m
        let playersFactor = float(playersAndBotsInRegion.x) * -50.0
        let botsFactor = float(playersAndBotsInRegion.y) * 400.0

        let newDist = max(0., regionCenterAndDist.w + playersFactor + botsFactor)
        regionsDistSum -= regionCenterAndDist.w - newDist
        regionCenterAndDist.w = newDist

      get_active_mattery_pos_in_radius_in_zone(transform[3], radius, zone, amDistSum, attractPosArray)
      get_item_extraction_pos_in_radius_in_zone(transform[3], radius, zone, extractionDistSum, attractPosArray)
      let distSum = regionsDistSum + amDistSum + extractionDistSum
      shuffle(attractPosArray)
      // there is a strong bias to choose the first point.
      // shuffling eliminates most of the impact that distance has
      // this works well enough for the current case

      for _ in range(tries)
        for posAndDist in attractPosArray
          if gfrnd() >= safediv(posAndDist.w, distSum)
            var isVisited = false
            for visitedReg in am_bot__visitedAttractRegions
              if length_sq(visitedReg.xz - posAndDist.xz) < 1.f
                isVisited = true
                break
            if isVisited && gfrnd() > 0.2
              continue
            *regionPosRef = posAndDist.xyz
            res = EBehResult.ER_SUCCESS
            return
    return res


[beh_node(name="isRegionCenter")]
class IsRegionCenter : BehNodeAdapter
  posParam : string
  @hidden posParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    var posParamRef = ownerEid |> get_Point3(posParam, posParamHash)
    if posParamRef == null
      logerr_once("{ownerEid}: isRegionCenter node can't find posParam '{posParam}:{posParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return EBehResult.ER_FAILED

    assume posParam2 = *posParamRef
    find_query() <| $ [es(REQUIRE=custom_region__name)] (transform : float3x4)
      if length_sq(posParam2.xz - transform[3].xz) < 1.f
        res = EBehResult.ER_SUCCESS
        return true
      return false
    return res


[beh_node(name="isNearAttractRegion")]
class IsNearAttractRegion : BehNodeAdapter
  posParam : string
  @hidden posParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    var posParamRef = ownerEid |> get_Point3(posParam, posParamHash)
    if posParamRef == null
      logerr_once("{ownerEid}: isNearAttractRegion node can't find posParam '{posParam}:{posParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return EBehResult.ER_FAILED

    query(ownerEid) <| $ [es] (transform aka owner_transform : float3x4)
      assume posParam2 = *posParamRef
      find_query() <| $ [es] (transform : float3x4)
        if length_sq(float2(posParam2.x, posParam2.z) - transform[3].xz) < 1.f
          let bboxDiag = 0.5 * (transform[0] + transform[1] + transform[2])
          var box = BBox3(transform[3] - bboxDiag, transform[3] + bboxDiag)
          bbox3_inflateXZ(box, 10.f)
          if box & owner_transform[3]
            res = EBehResult.ER_SUCCESS
            return true
        return false
    return res


[beh_node(name="isNearPos")]
class IsNearPos : BehNodeAdapter
  radius : float = 2.f
  posParam : string
  @hidden posParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    radius = datablock_getReal(data, "radius", radius)
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    var posParamRef = ownerEid |> get_Point3(posParam, posParamHash)
    if posParamRef == null
      logerr_once("{ownerEid}: isNearPos node can't find posParam '{posParam}:{posParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return EBehResult.ER_FAILED

    query(ownerEid) <| $ [es] (transform : float3x4)
      assume pos = *posParamRef
      if length_sq(pos.xz - transform[3].xz) < square(radius)
        res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="isVisitedAttractPos")]
class IsVisitedAttractPos : BehNodeAdapter
  posParam : string
  @hidden posParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)
    let ownerEid = beh_tree_eid(owner)
    if !(query(ownerEid) <| $ [es(REQUIRE=am_bot__visitedAttractRegions)] {})
      logerr("{ownerEid}: isVisitedAttractPos node requires am_bot__visitedAttractRegions")

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    let posParamRef = ownerEid |> get_Point3(posParam, posParamHash)
    if posParamRef == null
      logerr_once("{ownerEid}: isVisitedAttractPos node can't find posParam '{posParam}:{posParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return EBehResult.ER_FAILED

    query(ownerEid) <| $ [es] (var am_bot__visitedAttractRegions : Point3List&)
      query() <| $ [es(REQUIRE=artifact__extractable)] (transform : float3x4)
        assume am_pos = transform[3]
        for visitedPos in am_bot__visitedAttractRegions
          if length_sq(visitedPos.xz - am_pos.xz) < 1.f
            res = EBehResult.ER_SUCCESS
            return

      if res == EBehResult.ER_SUCCESS
        return

      query() <| $ [es] (am_core__moveTo : float3)
        assume am_pos = am_core__moveTo
        for visitedPos in am_bot__visitedAttractRegions
          if length_sq(visitedPos.xz - am_pos.xz) < 1.f
            res = EBehResult.ER_SUCCESS
            return

      if res == EBehResult.ER_SUCCESS
        return

      find_query() <| $ [es(REQUIRE=custom_region__name)] (transform : float3x4)
        for visitedPos in am_bot__visitedAttractRegions
          if length_sq(visitedPos.xz - transform[3].xz) < 1.f
            res = EBehResult.ER_SUCCESS
            return true
        return false
    return res


[beh_node(name="findSafePosAroundAttractPos")]
class FindSafePosAroundAttractPos : BehNodeAdapter
  posParam : int = -1
  radius : float = 2f
  tries : int = 5
  attractPos : string
  @hidden attractPosHash : uint

  def override loadFromBlk(var data : DataBlock) : void
    radius = data |> datablock_getReal("radius", radius)
    tries = data |> datablock_getInt("tries", tries)
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", "wishPosition"), float3())
    data |> load_ecs_param("attractPos", attractPos, attractPosHash, thisNode)

  def override update(dt : float) : EBehResult
    let ownerEid = beh_tree_eid(owner)
    let attractPosRef = ownerEid |> get_Point3(attractPos, attractPosHash)
    if attractPosRef == null
      logerr_once("{ownerEid}: findSafePosAroundAttractPos node can't find attractPos '{attractPos}:{attractPosHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return EBehResult.ER_FAILED

    var res = EBehResult.ER_FAILED
    var resPos : float3
    for _ in range(tries)
      if find_random_point_inside_circle(*attractPosRef, radius, 1., resPos)
        var triangle : NavMeshTriangle
        if get_triangle_by_pos(resPos, 2.f, triangle)
          var area : uint8
          get_poly_area(triangle.polyRef, area)
          if area == uint8(int(AMPolyArea.POLYAREA_WALKABLE))
            res = EBehResult.ER_SUCCESS
            owner.blackBoard |> set(posParam, resPos)
            break

    return res


[beh_node(name="findRandomNavmeshPointInRegionByEid")]
class FindRandomNavmeshPointInRegionByEid : BehNodeAdapter
  posParam : int = -1
  tries : int = 2
  radius : float = 2f
  regionParam : string
  @hidden regionParamHash : uint

  def override loadFromBlk(var data : DataBlock) : void
    tries = data |> datablock_getInt("tries", tries)
    radius = data |> datablock_getReal("radius", radius)
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", "wishPosition"), float3())
    data |> load_ecs_param("regionParam", regionParam, regionParamHash, thisNode)

  def override update(dt : float) : EBehResult
    let ownerEid = beh_tree_eid(owner)
    let regionParamRef = ownerEid |> get_Point3(regionParam, regionParamHash)
    if regionParamRef == null
      logerr_once("{ownerEid}: findRandomNavmeshPointInRegionByEid node can't find regionParam '{regionParam}:{regionParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return EBehResult.ER_FAILED

    var res = EBehResult.ER_FAILED
    find_query() <| $ [es] (custom_region__points : Point2List;
                            custom_region__triangulationIdxs : IntList;
                            transform aka region_transform : float3x4)
      assume regionPos = *regionParamRef
      if length_sq(regionPos.xz - transform[3].xz) < 1.f
        query(ownerEid) <| $ [es] (transform : float3x4)
          let randomPoint = get_region_pos_by_eid(custom_region__points, ownerEid)
          let foundPos = find_nav_point_around(transform[3], randomPoint, radius, tries) <| $(pos)
            let bboxDiag = 0.5 * (region_transform[0] + region_transform[1] + region_transform[2])
            let bbox = BBox3(region_transform[3] - bboxDiag, region_transform[3] + bboxDiag)
            return is_point_inside_region(pos, custom_region__points, custom_region__triangulationIdxs, bbox)

          if foundPos is pos
            res = EBehResult.ER_SUCCESS
            owner.blackBoard |> set(posParam, foundPos as pos)
        return true
      return false

    return res


[beh_node(name="appendVisitedPos")]
class AppendVisitedPos : BehNodeAdapter
  appendPos : string
  @hidden appendPosHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("appendPos", appendPos, appendPosHash, thisNode)
    let ownerEid = beh_tree_eid(owner)
    if !(query(ownerEid) <| $ [es(REQUIRE=am_bot__visitedAttractRegions)] {})
      logerr("{ownerEid}: appendVisitedPos node requires am_bot__visitedAttractRegions")

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    let appendPosRef = ownerEid |> get_Point3(appendPos, appendPosHash)
    if appendPosRef == null
      logerr_once("{ownerEid}: appendVisitedPos node can't find appendPos '{appendPos}:{appendPosHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return EBehResult.ER_FAILED

    query(ownerEid) <| $ [es] (var am_bot__visitedAttractRegions : Point3List&)
      res = EBehResult.ER_SUCCESS
      assume pos = *appendPosRef
      for visitedPos in am_bot__visitedAttractRegions
        if length_sq(visitedPos.xz - pos.xz) < 1.f
          return
      am_bot__visitedAttractRegions |> push(pos)
    return res


struct FindLootItemData
  distSq : float
  eid : EntityId


def loot_item_container_lower_bound(a : array<FindLootItemData>;
                                    dist_sq : float)
  var count = length(a)
  var first = 0
  while count > 0
    let step = count / 2
    let it = first + step
    if a[it].distSq < dist_sq
      first += step + 1
      count -= step + 1
    else
      count = step
  return first


def push_loot_item_sorted(var a : array<FindLootItemData>;
                          dist_sq : float;
                          eid : EntityId)
  let idx = loot_item_container_lower_bound(a, dist_sq)
  a |> push(FindLootItemData(distSq = dist_sq, eid = eid), idx)


[beh_node(name="findLoot")]
class FindLoot : BehNodeAdapter
  traceDist : float = 10.0
  maxItemsCount : int = 25
  lootTargetParam : int
  failOnSame : bool
  sameWeight : float
  maxPickupVolume : float
  ignoreLootTagHash : uint
  strictPathCheckDist : float = 10.0
  @hidden strictPathCheckDistSq : float
  extents : float3 = float3(0.5, FLT_MAX, 0.5)
  allowWeaponsWithoutAmmo : bool = false


  def override loadFromBlk(var data : DataBlock) : void
    traceDist = data |> datablock_getReal("traceDist", traceDist)
    maxItemsCount = data |> datablock_getInt("maxItemsCount", maxItemsCount)
    lootTargetParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "lootTargetParam", ""), 0)
    failOnSame = data |> datablock_getBool("failOnSame", failOnSame)
    allowWeaponsWithoutAmmo = data |> datablock_getBool("allowWeaponsWithoutAmmo", allowWeaponsWithoutAmmo)
    sameWeight = data |> datablock_getReal("sameWeight", sameWeight)
    maxPickupVolume = data |> datablock_getReal("maxPickupVolume", maxPickupVolume)
    let ignoreLootTag = data |> datablock_getStr("ignoreTag", "invisibleForAI")
    ignoreLootTagHash = ecs_hash(ignoreLootTag)
    strictPathCheckDist = data |> datablock_getReal("strictPathCheckDist", strictPathCheckDist)
    strictPathCheckDistSq = square(strictPathCheckDist)
    extents = data |> datablock_getPoint3("extents", extents)


  def checkItemToBeTarget(item_eid : EntityId;
                          all_found_items : array<FindLootItemData>;
                          item_pos : float3;
                          path_length_sq : float;
                          item_volume : float;
                          weap_template_name : das_string const?;
                          ammo_holder_id : int const?;
                          gun_props_id : int;
                          gun_ammo_holder_ids : IntList const?;
                          trace_dist : float;
                          current_target_eid : EntityId;
                          same_weight : float;
                          current_volume : int;
                          max_volume : int;
                          allow_weapons_without_ammo : bool;
                          var closest_dist_weight : float&;
                          var closest_eid : EntityId&;
                          var closest_pos : float3&)
    var distWeight = path_length_sq

    // Useful ammo is always our priority #1
    if ammo_holder_id != null
      distWeight -= square(trace_dist)

    if item_eid == current_target_eid
      distWeight -= square(same_weight)

    if distWeight >= closest_dist_weight
      return

    if weap_template_name != null
      var haveAmmo = gun_props_id >= 0
      if gun_props_id >= 0 && gun_ammo_holder_ids != null
        // First check if it has ammo in itself (godmode knowledge, but nonetheless good guess if it's on dead body)
        haveAmmo = (get_int(item_eid, "gun__ammo") ?? 0) > 0
        if !haveAmmo && !allow_weapons_without_ammo
          for potentialAmmoItem in all_found_items
            let itemAmmoPropsId = get_int(potentialAmmoItem.eid, "ammo_holder__id")
            if itemAmmoPropsId == null
              continue
            for matchingProps in *gun_ammo_holder_ids
              if matchingProps == *itemAmmoPropsId
                haveAmmo = true
                break
            if haveAmmo
              break
      else
        let weapType = get_ecs_string(item_eid, "item__weapType") ?? ""
        if weapType == "melee"
          return

      if !haveAmmo && !allow_weapons_without_ammo
        return
    // If it's not ammo and have volume - restrain it to half of our capacity (so to have more space for ammo!)
    elif ammo_holder_id == null && item_volume > 0.0 && current_volume > max_volume / 2
      return

    closest_dist_weight = distWeight
    closest_eid = item_eid
    closest_pos = item_pos


  def processLootItem(item_eid : EntityId;
                      agent_eid : EntityId;
                      agent_pos : float3;
                      agent_poly : dtPolyRef;
                      all_found_items : array<FindLootItemData>;
                      currentVolume : int;
                      maxVolume : int;
                      allow_weapons_without_ammo : bool;
                      var current_target_eid : EntityId&;
                      var current_target_processed : bool&;
                      var closest_dist_weight : float&;
                      var closest_eid : EntityId&;
                      var closest_pos : float3&)
    if !is_item_useful(agent_eid, item_eid)
      return
    query(item_eid) <| $ [es] (transform : float3x4;
                               item__weapTemplate : das_string const?;
                               gun__ammoHolderIds : IntList const?;
                               item__volume : float = 0.0;
                               ammo_holder__id : int const?;
                               gun__propsId : int = -1)
      if item__volume > 0.0 && maxPickupVolume > 0.0 && item__volume > maxPickupVolume
        let hasFreeSlot = is_can_pickup_item_in_weapon_slots(agent_eid, item_eid) || is_can_pickup_item_in_equipment_slots(agent_eid, item_eid)
        if !hasFreeSlot
          return

      let itemPos = navmesh_map_position(transform[3])
      var navMeshItemPos = itemPos
      var itemPoly : dtPolyRef
      if !project_to_nearest_navmesh_point(navMeshItemPos, extents, itemPoly)
        return

      if length_sq(navMeshItemPos - itemPos) > square(1.5) // Unreachable from navmesh item
        return

      // Calculate more relevant path length by navmesh, because streight distance
      // is not correct value to compare with (item can be located very close, but behind a long wall)
      var pathLength = -1.0
      using(agent_pos, itemPos, extents) <| $(var req : FindRequest#)
        req.includeFlags |= int(PolyFlag.POLYFLAG_GROUND | PolyFlag.POLYFLAG_OBSTACLE | PolyFlag.POLYFLAG_JUMP)
        req.maxJumpUpHeight = FLT_MAX
        req.startPoly = agent_poly
        req.endPoly = itemPoly
        pathLength = calc_approx_path_length(req, 1.5, 0.5)
      if pathLength < 0.0
        return
      let pathLengthSq = square(pathLength)

      checkItemToBeTarget(item_eid, all_found_items, itemPos, pathLengthSq, item__volume, item__weapTemplate,
                          ammo_holder__id, gun__propsId, gun__ammoHolderIds, traceDist,
                          current_target_eid, sameWeight, currentVolume, maxVolume, allow_weapons_without_ammo, closest_dist_weight, closest_eid, closest_pos)
      if current_target_eid == item_eid
        current_target_processed = true


  def override update(dt : float) : EBehResult
    var agent = beh_tree_entity_agent(*owner)
    if agent == null
      return EBehResult.ER_FAILED
    let agentEid = beh_tree_eid(owner)
    if !(get_bool(agentEid, "human__canPickupItems") ?? true)
      return EBehResult.ER_FAILED

    var navmeshMappingZone = INVALID_ENTITY_ID
    query(agentEid) <| $ [es] (position_mapping__lastZone : EntityId)
      navmeshMappingZone = position_mapping__lastZone
    let agentPos = navmesh_map_position_in_zone(agent?.pos ?? float3(), navmeshMappingZone)

    var agentPoly : dtPolyRef
    var navMeshAgentPos = agentPos
    if !project_to_nearest_navmesh_point(navMeshAgentPos, extents, agentPoly)
      return EBehResult.ER_FAILED

    var closestEid = INVALID_ENTITY_ID
    var closestPos = float3()
    var closestDistWeight = FLT_MAX

    var res = EBehResult.ER_FAILED
    query(agentEid) <| $ [es] (human_inventory__currentVolume : int;
                               human_inventory__maxVolumeInt : int;
                               militant_extra_inventories__backpackEid : EntityId = INVALID_ENTITY_ID)
      var maxVolume = human_inventory__maxVolumeInt
      var curVolume = human_inventory__currentVolume
      // if backpack has more free space than current inventory - use it
      query(militant_extra_inventories__backpackEid) <| $ [es] (human_inventory__currentVolume : int; human_inventory__maxVolumeInt : int)
        if maxVolume - curVolume < human_inventory__maxVolumeInt - human_inventory__currentVolume
          maxVolume = human_inventory__maxVolumeInt
          curVolume = human_inventory__currentVolume
      var currentTargetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(lootTargetParam)))
      var currentTargetProcessed = false

      let zone = get_current_moving_zone()
      let zoneRadSq = square(zone.radius)

      let bsphere = BSphere3(*agent |> entity_agent_getShootFromPos(STANCE_STAND), traceDist)
      gather_entities_in_grid(ecs_hash("loot"), bsphere, GridEntCheck.POS) <| $(intersections)
        var itemsSortedByDist : array<FindLootItemData>
        for it in intersections
          query(it) <| $ [es] (transform : float3x4)
            let itemPos = transform[3]
            let mappedItemPos = navmesh_map_position(transform[3])

            if distance_sq(itemPos, zone.pos) > zoneRadSq
              return

            if has(it, "", ignoreLootTagHash)
              return

            if !is_can_pickup_item(agentEid, it)
              return

            let distSq = distance_sq(mappedItemPos, agentPos)
            itemsSortedByDist |> push_loot_item_sorted(distSq, it)
        if length(itemsSortedByDist) > maxItemsCount
          itemsSortedByDist |> erase(maxItemsCount, length(itemsSortedByDist) - maxItemsCount)

        let timeTicks = DagorTime::ref_time_ticks()
        for itemData in itemsSortedByDist
          processLootItem(itemData.eid, agentEid, agentPos, agentPoly, itemsSortedByDist,
                          curVolume, maxVolume, allowWeaponsWithoutAmmo,
                          currentTargetEid, currentTargetProcessed,
                          closestDistWeight, closestEid, closestPos)

          if currentTargetProcessed
            // Early exit - we have processed the previous target item so there is no reason to check distant items
            break

          // TODO: Workaround fix for too heavy calc_approx_path_length calls
          //       Optimize calc_approx_path_length and probably remove this check
          if DagorTime::get_time_usec(timeTicks) >= 300 // 0.3ms
            break
        // If we already have some current target item and it is unprocessed
        // (for example this item is already out of the search area) - process it,
        // because it still can have higher priority than new items
        if currentTargetEid != INVALID_ENTITY_ID && !currentTargetProcessed && length(intersections) > 0
          processLootItem(currentTargetEid, agentEid, agentPos, agentPoly, itemsSortedByDist,
                          curVolume, maxVolume, allowWeaponsWithoutAmmo,
                          currentTargetEid, currentTargetProcessed,
                          closestDistWeight, closestEid, closestPos)

      if !closestEid || (failOnSame && closestEid == currentTargetEid)
        res = EBehResult.ER_FAILED
        return
      owner.blackBoard |> set(lootTargetParam, int(uint(closestEid)))
      res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="findPosInTm")]
class FindPosInTm : BehNodeAdapter
  posParam : int = -1
  tmParam : string
  @hidden tmParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "posParam", "wishPosition"), float3())
    data |> load_ecs_param("tmParam", tmParam, tmParamHash, thisNode)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let eid = beh_tree_eid(owner)
    let tm = eid |> get_TMatrix(tmParam, tmParamHash)
    if tm == null
      logerr("No tmParam component '{tmParam}' in <{eid}>({getEntityTemplateName(eid)})")
      return EBehResult.ER_FAILED

    query(eid) <| $ [es] (transform : float3x4)
      var attempts = 4
      var resPath = FindPathResult.FPR_FAILED
      var firstPoly = 0ul
      using() <| $(var path_corridor : dtPathCorridor)
        path_corridor |> init_path_corridor()
        while attempts-- > 0
          var point = (*tm)[3] + (*tm)[0] * rnd_float(-0.5, 0.5) + (*tm)[1] * rnd_float(-0.5, 0.5) + (*tm)[2] * rnd_float(-0.5, 0.5)
          var endRef : dtPolyRef
          if project_to_nearest_navmesh_point(point, float3(3), endRef)
            let extents = float3(.5, FLT_MAX, .5)
            using(transform[3], point, extents) <| $(var inp : CorridorInput#)
              inp.startPoly = firstPoly
              inp.targetPoly = endRef
              inp.includeFlags |= int(PolyFlag.POLYFLAG_JUMP)
              resPath = path_corridor |> set_path_corridor(inp, null)
              firstPoly = path_corridor.firstPoly
            if resPath == FindPathResult.FPR_FULL
              owner.blackBoard |> set(posParam, point)
              res = EBehResult.ER_SUCCESS
              break
    return res


[beh_node(name="setBlind")]
class SetBlind : BehNodeAdapter
  blindnessTimeEndParam : int = -1
  duration : float2 = float2(1f)

  def override loadFromBlk(var data : DataBlock) : void
    blindnessTimeEndParam = owner.blackBoard |> get_or_create("blindness.timeEnd", 0f)
    duration = data |> datablock_getPoint2("duration", duration)

  def override update(dt : float) : EBehResult
    owner.blackBoard |> set(blindnessTimeEndParam, get_sync_time() + rnd_float(duration.x, duration.y))
    return EBehResult.ER_SUCCESS


[beh_node(name="isItemAm")]
class isItemAm : BehNodeAdapter
  targetParam : int = -1

  def override loadFromBlk(var data : DataBlock)
    targetParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetParam", ""), 0)

  def override update(dt : float) : EBehResult
    let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetParam)))
    return has(targetEid, "item__am") ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="gatherResource")]
class GatherResource : BehNodeAdapter
  targetParam : int = -1

  def override loadFromBlk(var data : DataBlock)
    targetParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetParam", ""), 0)

  def override init()
    send_net_event(beh_tree_eid(owner), CmdGathererToggle(isOn = true))

  def override update(dt : float) : EBehResult
    let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetParam)))
    if targetEid == INVALID_ENTITY_ID
      return EBehResult.ER_FAILED

    return !doesEntityExist(targetEid) ? EBehResult.ER_SUCCESS : EBehResult.ER_RUNNING

  def override exit()
    send_net_event(beh_tree_eid(owner), CmdGathererToggle(isOn = false))


[beh_node(name="pickupItemEntity")]
class PickupItemEntity : BehNodeAdapter
  targetParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    targetParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetParam", ""), 0)

  def override update(dt : float) : EBehResult
    let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetParam)))
    if targetEid == INVALID_ENTITY_ID || !doesEntityExist(targetEid)
      return EBehResult.ER_FAILED

    sendEvent(beh_tree_eid(owner), RequestItemPickup(itemEid = targetEid))
    return EBehResult.ER_SUCCESS


[beh_node(name="findInteractableWithLoot")]
class FindInteractableWithLoot : BehNodeAdapter
  radius : float
  lootTargetParam : int
  extents : float3 = float3(0.5, FLT_MAX, 0.5)

  def override loadFromBlk(var data : DataBlock) : void
    radius = data |> datablock_getReal("radius", radius)
    lootTargetParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "lootTargetParam", ""), 0)
    extents = data |> datablock_getPoint3("extents", extents)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED

    var agent = beh_tree_entity_agent(*owner)
    if agent == null
      return res
    let agentEid = beh_tree_eid(owner)
    let agentPos = agent?.pos ?? float3()

    var canPickup = true
    query(agentEid) <| $ [es] (human__canPickupItems : bool = true)
      canPickup = human__canPickupItems
    if !canPickup
      return res

    var closestEid = INVALID_ENTITY_ID
    var closestDistSq = FLT_MAX

    let currentTargetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(lootTargetParam)))
    var currentTargetProcessed = false

    let zone = get_current_moving_zone()
    let zoneRadSq = square(zone.radius)

    let bsphere = BSphere3(*agent |> entity_agent_getShootFromPos(STANCE_STAND), radius)
    gather_entities_in_grid(fixed_array(ecs_hash("interactable"), ecs_hash("loot")), bsphere, GridEntCheck.POS) <| $(intersections)
      for it in intersections
        query(it) <| $ [es] (transform : float3x4;
                             isAlive : bool = false;
                             inventory__humanOwnerEid : EntityId = INVALID_ENTITY_ID;
                             locked__isLocked : bool = false;
                             itemContainer : EidList)
          var canLootFrom = true
          if isAlive
            canLootFrom = false

          query(inventory__humanOwnerEid) <| $ [es] (isAlive : bool)
            if isAlive
              canLootFrom = false

          if locked__isLocked
            canLootFrom = false

          if !canLootFrom
            return

          // check if we have enough capacity
          var canTakeSmth = false
          for item in itemContainer
            if is_item_hidden_for_player_by_hero(item, agentEid)
              continue

            canTakeSmth = get_inventory_for_item_by_volume(agentEid, item) != INVALID_ENTITY_ID
            if canTakeSmth
              break
          if !canTakeSmth
            return

          let inventoryPos = transform[3]

          if distance_sq(inventoryPos, zone.pos) > zoneRadSq
            return

          let distSq = distance_sq(inventoryPos, agentPos)

          if closestDistSq < distSq
            return

          // don't calc navdist cause it works too long and has problems with useDist
          closestEid = it
          closestDistSq = distSq

          if currentTargetEid == closestEid
            currentTargetProcessed = true
        if currentTargetProcessed
          break
    if closestEid != INVALID_ENTITY_ID
      res = EBehResult.ER_SUCCESS
      owner.blackBoard |> set(lootTargetParam, int(uint(closestEid)))
    return res


[beh_node(name="openInteractableWithLoot")]
class OpenInteractableWithLoot : BehNodeAdapter
  targetParam : int

  def override loadFromBlk(var data : DataBlock) : void
    targetParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetParam", ""), 0)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED

    let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetParam)))
    if targetEid == INVALID_ENTITY_ID
      return res

    query(targetEid) <| $ [es] (openable_ri__isOpened : bool = true)
      if openable_ri__isOpened
        res = EBehResult.ER_SUCCESS
      else
        res = EBehResult.ER_RUNNING
        sendEvent(beh_tree_eid(owner), HumanUseObjectRequest(objectEid = targetEid))
    return res


[beh_node(name="lootFromInteractable")]
class LootFromInteractable : BehNodeAdapter
  targetParam : int

  def override loadFromBlk(var data : DataBlock) : void
    targetParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetParam", ""), 0)

  def try_move_in_pouch(item : EntityId)
    var success = false
    let agentEid = beh_tree_eid(owner)
    query(item) <| $ [es] (item__volume : float)
      query(agentEid) <| $ [es] (human_inventory__currentVolume : int;
                                 human_inventory__maxVolumeInt : int)
        if human_inventory__currentVolume + convert_volume_to_int(item__volume) <= human_inventory__maxVolumeInt
          send_net_event(agentEid, CmdMoveItemFromInventoryToInventory(itemEid = item, toInventoryEid = agentEid))
          success = true
    return success

  def try_move_in_backpack(item : EntityId)
    var success = false
    let agentEid = beh_tree_eid(owner)
    query(item) <| $ [es] (item__volume : float)
      query(agentEid) <| $ [es] (inventories_owner__inventoryEids : EidList)
        for inventoryEid in inventories_owner__inventoryEids
          if inventoryEid == agentEid
            continue
          query(inventoryEid) <| $ [es] (human_inventory__currentVolume : int;
                                         human_inventory__maxVolumeInt : int)
            if human_inventory__currentVolume + convert_volume_to_int(item__volume) <= human_inventory__maxVolumeInt
              send_net_event(agentEid, CmdMoveItemFromInventoryToInventory(itemEid = item, toInventoryEid = inventoryEid))
              success = true
    return success

  def take_item(item : EntityId)
    if is_item_hidden_for_player_by_hero(item, beh_tree_eid(owner))
      return false

    var success = false
    query(item) <| $ [es] (gunAttachable__slotName : das_string const?;
                           item__filterType : das_string const?;
                           item__weapTemplate : das_string const?;
                           item__lootType : das_string const?)
      let isMagazine = gunAttachable__slotName == null ? false : string(*gunAttachable__slotName) == "magazine"
      let isMedkit = item__filterType != null && *item__filterType == "medicines"
      let isGun = item__weapTemplate != null
      let isGrenade = item__lootType == null ? false : string(*item__lootType) == "grenade"
      if isMedkit || isMagazine || isGun || isGrenade
        if try_move_in_pouch(item) || try_move_in_backpack(item)
          success = true
      else
        if try_move_in_backpack(item) || try_move_in_pouch(item)
          success = true
    return success

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED

    let interEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetParam)))

    query(interEid) <| $ [es] (itemContainer : EidList)
      for item in itemContainer
        if take_item(item)
          res = EBehResult.ER_SUCCESS
          return
    return res


[beh_node(name="useEntity")]
class UseEntity : BehNodeAdapter
  targetParam : int

  def override loadFromBlk(var data : DataBlock) : void
    targetParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "targetParam", ""), 0)

  def override update(dt : float) : EBehResult
    let targetEid = EntityId(uint(owner.blackBoard |> datablock_getInt(targetParam)))
    let agentEid = beh_tree_eid(owner)
    sendEvent(agentEid, HumanUseObjectRequest(objectEid = targetEid))
    return doesEntityExist(targetEid) ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="tryOpenDoor")]
class TryOpenDoor : BehNodeAdapter
  pushAgentAway : bool = true

  def override loadFromBlk(var data : DataBlock) : void
    pushAgentAway = datablock_getBool(data, "pushAgentAway", pushAgentAway)

  def override update(dt : float) : EBehResult
    var success = false
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (transform aka a_transform : float3x4; door_obstacle_handler__immediateDoor : EntityId)
      query(door_obstacle_handler__immediateDoor) <| $ [es] (ri_extra : RiExtraComponent;
                                                             transform aka d_transform : float3x4;
                                                             door_operations__openedAngle : float;
                                                             rendinst_axis_rotation__targetAngle : float)
        if abs(rendinst_axis_rotation__targetAngle - door_operations__openedAngle) > 5.0
          success = true
          sendEvent(door_obstacle_handler__immediateDoor, CmdUse(requesterEid = agentEid))

          if pushAgentAway
            let riType = handle_to_ri_type(ri_extra.handle)
            let riCollres = get_ri_gen_extra_collres(int(riType))
            if riCollres == null
              return
            let door_box = BBox3(riCollres.vFullBBox)
            let transformPos = d_transform[3]
            let transformDir = d_transform[0]
            let doorSize = door_box.width
            let doorEnd = transformPos + transformDir * (max(doorSize.x, doorSize.z))
            var pushVec = normalize(a_transform[3] - doorEnd)
            let grav = get_grav_dir(a_transform[3])
            pushVec -= grav * dot(pushVec, grav)
            pushVec -= grav * 0.2
            pushVec = normalize(pushVec)
            sendEvent(agentEid, CmdPushPhys(vel = pushVec * 4.0, push_immunity = 0.0))

    return success ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="findObstaclesAlongsidePathMapped")]
class FindObstaclesAlongsidePathMapped : BehNodeAdapter

  def override update(dt : float) : EBehResult
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (position_mapping__lastZone : EntityId;
                               walker_agent__standShootLocalPos : float3;
                               transform : float3x4;
                               var walker_agent : EntityAgent;
                               obstacle_avoider__horBuffer : float = 2.0;
                               obstacle_avoider__vertBuffer : float = 0.5;
                               obstacle_avoider__maxPathDst : float = 5.0;
                               obstacle_avoider__vehicleSearchRadius : float = 15.0;
                               obstacle_avoider__riExtraObstacleLimit : int = 15;
                               obstacle_avoider__escapeOffset : float = 0.4;
                               obstacle_avoider__avoidTriggers : bool = false;
                               var path_corridor__corners : Point3List;
                               var agent_obstacles : AgentObstacles)
      clear(agent_obstacles.obstacles)
      clear(walker_agent.obstacles)
      clear(path_corridor__corners)
      get_agent_path(walker_agent) <| $(path)
        for item in path
          path_corridor__corners |> push(item)
      let box = setup_obstacle_bbox_from_path(path_corridor__corners,
                                              transform[3],
                                              walker_agent__standShootLocalPos.y,
                                              obstacle_avoider__horBuffer,
                                              obstacle_avoider__vertBuffer,
                                              obstacle_avoider__maxPathDst)
      if box.isempty || length(path_corridor__corners) == 0
        return
      let destination = path_corridor__corners[length(path_corridor__corners) - 1]
      find_obstacles_and_map(position_mapping__lastZone,
                            agentEid,
                            box,
                            transform[3],
                            transform[0],
                            destination,
                            obstacle_avoider__escapeOffset,
                            obstacle_avoider__vehicleSearchRadius,
                            obstacle_avoider__riExtraObstacleLimit,
                            obstacle_avoider__avoidTriggers,
                            agent_obstacles,
                            true)
      for oex in agent_obstacles.obstacles
        var o = agent_add_obstacle(walker_agent)
        o.center = oex.center
        for s in oex.segments
          o.segments |> push(s)
    return EBehResult.ER_SUCCESS