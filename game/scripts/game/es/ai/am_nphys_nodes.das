options always_export_initializer = true
require ecs
require ecs.safe
require app
require math.base
require DagorDataBlock
require DagorRandom
require DagorSystem
require BehNodes
require pathfinder
require Grid
require Dacoll
require DagorMath
require level
require game.es.level_common
require game.es.custom_region_common
require active_matter.game.es.navmesh_nearest_pos_common
require game.es.ai.attract_point_common
require game.es.ecs_common
require danetlibs.pathfinder.main.pathfinder_common
require game.es.moving_zone_common
require debug.logerr_once
require NavmeshMapping
require game.es.ai.agent_position_mapping_common


[beh_node(name="patroller")] // patroller_ai template
class Patroller : BehNodeAdapter

  def override loadFromBlk(var data : DataBlock)
    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(patroller__radius, patroller__maxWaypoints, patroller__aroundPos, patroller__waypoints, patroller__currentWaypointUpdateAt, patroller__currentWaypointUpdateInterval, patroller__currentWaypointIdx, patroller__currentWaypoint))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> Patroller requires patroller.radius, patroller.maxWaypoints, patroller.aroundPos, patroller.waypoints, patroller.currentWaypointIdx and patroller.currentWaypoint fields")


  [unused_argument(pos)] def isValidPos(pos : float3) { return true; }

  def findPossibleWaypoint(around : float3; radius : float; var pos : float3&) : bool
    return find_random_point_inside_circle(around, radius, 1., pos)


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

      let reqMorePoints = patroller__currentWaypointIdx - length(patroller__waypoints) + 1
      if reqMorePoints > 0
        for _ in range(reqMorePoints)
          var pos : float3
          if self->findPossibleWaypoint(patroller__aroundPos, patroller__radius, pos) && self->isValidPos(pos)
            patroller__waypoints |> push(pos)

      if patroller__currentWaypointIdx >= length(patroller__waypoints)
        if length(patroller__waypoints) == 0
          return // no way, restart
        patroller__currentWaypointIdx = 0

      patroller__currentWaypoint = patroller__waypoints[patroller__currentWaypointIdx]
      patroller__currentWaypointUpdateAt = curTime + patroller__currentWaypointUpdateInterval
      res = EBehResult.ER_SUCCESS

    return res


[beh_node(name="indoorPatroller")] // patroller_ai template
class IndoorPatroller : Patroller

  def override isValidPos(pos : float3)
    return level_common::is_pos_indoor(pos)


[beh_node(name="clampedPatroller")] // patroller_ai template
class ClampedPatroller : Patroller

  def override isValidPos(pos : float3)
    var validPos = false
    query(beh_tree_eid(owner)) <| $ [es] (clamped_patroller__yRange : float2)
      if pos.y >= clamped_patroller__yRange.x && pos.y <= clamped_patroller__yRange.y
        validPos = true
    return validPos


[beh_node(name="outdoorPatroller")] // patroller_ai template
class OutdoorPatroller : Patroller

  def override isValidPos(pos : float3)
    return !level_common::is_pos_indoor(pos)


[beh_node(name="flyingSwarmPatroller")]
class FlyingSwarmPatroller : Patroller
  def override findPossibleWaypoint(around : float3; radius : float; var pos : float3&) : bool
    let angle = rnd_float(0f, 2.0 * PI)
    var s, c : float
    sincos(angle, s, c)
    pos = around + float3(c * radius, 0.0, s * radius)
    return true

  def override isValidPos(pos : float3)
    return !level_common::is_pos_indoor(pos)



[beh_node(name="getAttractionPosition")] // get_attract_position_ai template
class GetAttractionPosition : BehNodeAdapter

  def override loadFromBlk(var data : DataBlock)
    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(attract_point__searchRadius, attract_point__checkPath, attract_point__eid, attract_point__distanceTime, attract_point__targetPos))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> GetAttractionPosition requires attract_point.searchRadius, attract_point.checkPath, attract_point.eid, attract_point.distanceTime and attract_point.targetPos fields")

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (attract_point__eid : EntityId)
      if attract_point__eid != INVALID_ENTITY_ID
        res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="spawnAttractPoint")] // spawn_attract_point_ai template
class SpawnAttractPoint : BehNodeAdapter

  def override loadFromBlk(var data : DataBlock)
    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(spawn_attract_point__growDuration, spawn_attract_point__currentGrowDuration, spawn_attract_point__currentTimeLeft, spawn_attract_point__currentPointEid))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> SpawnAttractPoint requires spawn_attract_point.growDuration, spawn_attract_point.currentGrowDuration, spawn_attract_point.currentTimeLeft and spawn_attract_point.currentPointEid fields")

  def override init() : void
    query(beh_tree_eid(owner)) <| $ [es] (spawn_attract_point__growDuration : float2;
                                          var spawn_attract_point__currentGrowDuration : float&;
                                          var spawn_attract_point__currentTimeLeft : float&;
                                          var spawn_attract_point__currentPointEid : EntityId&)
      spawn_attract_point__currentPointEid = INVALID_ENTITY_ID
      spawn_attract_point__currentGrowDuration = rnd_float(spawn_attract_point__growDuration.x, spawn_attract_point__growDuration.y)
      spawn_attract_point__currentTimeLeft = spawn_attract_point__currentGrowDuration

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let eid = beh_tree_eid(owner)
    query(eid) <| $ [es] (transform : float3x4;
                          spawn_attract_point__power : float2;
                          spawn_attract_point__ttl : float2;
                          spawn_attract_point__currentGrowDuration : float;
                          var spawn_attract_point__currentTimeLeft : float&;
                          var spawn_attract_point__currentPointEid : EntityId&;
                          spawn_attract_point__attractPointTemplate : string = "shrinkable_attract_point";
                          spawn_attract_point__magnitudeThreshold = 2f;
                          spawn_attract_point__distanceThreshold = 2f)
      spawn_attract_point__currentTimeLeft -= dt

      let progress = saturate(1.f - safediv(spawn_attract_point__currentTimeLeft, spawn_attract_point__currentGrowDuration))
      let currentMagnitude = lerp(spawn_attract_point__power.x, spawn_attract_point__power.y, progress)
      let currentTtl = lerp(spawn_attract_point__ttl.x, spawn_attract_point__ttl.y, progress)

      if spawn_attract_point__currentPointEid != INVALID_ENTITY_ID
        query(spawn_attract_point__currentPointEid) <| $ [es] (var attract_point__magnitude, game_effect__destroyAt : float&)
          attract_point__magnitude = currentMagnitude
          game_effect__destroyAt = get_sync_time() + currentTtl

      else
        let agentPos = transform[3]
        var found = false
        let bsphere = BSphere3(agentPos, spawn_attract_point__distanceThreshold)
        find_entity_in_grid(ecs_hash("attract_point"), bsphere, GridEntCheck.POS) <| $(attractEid : EntityId)
          query(attractEid) <| $ [es] (attract_point__ownerEid : EntityId; attract_point__magnitude : float; var game_effect__destroyAt : float?)
            if attract_point__ownerEid == eid && abs(attract_point__magnitude - currentMagnitude) < spawn_attract_point__magnitudeThreshold
              spawn_attract_point__currentPointEid = attractEid
              if game_effect__destroyAt != null
                *game_effect__destroyAt = max(*game_effect__destroyAt, currentTtl + get_sync_time())
              found = true
          return found

        if !found
          spawn_attract_point__currentPointEid = createEntity(spawn_attract_point__attractPointTemplate) <| $(ini)
            var tm : float3x4 = IDENT_TM
            tm[3] = agentPos
            ini |> set("transform", tm)
            ini |> set("attract_point__magnitude", currentMagnitude)
            ini |> set("game_effect__timeToDestroy", currentTtl)
            ini |> set("attract_point__ownerEid", eid)

      res = spawn_attract_point__currentTimeLeft <= 0f ? EBehResult.ER_SUCCESS : EBehResult.ER_RUNNING

    return res


[beh_node(name="getReactionOffender")] // get_reaction_offender_ai template
class GetReactionOffender : BehNodeAdapter

  def override loadFromBlk(var data : DataBlock)
    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(agent_dangers__lastHitReactionTime, agent_dangers__lastHitReactionOffenderEid, agent_dangers__lastBulletReactionTime, agent_dangers__lastBulletReactionOffenderEid, agent_dangers__lastReactionOffender))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> GetReactionOffender requires agent_dangers.lastHitReactionTime, agent_dangers.lastHitReactionOffenderEid, agent_dangers.lastBulletReactionTime, agent_dangers.lastBulletReactionOffenderEid and agent_dangers.lastReactionOffender fields")

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (agent_dangers__lastHitReactionTime : float;
                                          agent_dangers__lastHitReactionOffenderEid : EntityId;
                                          agent_dangers__lastBulletReactionTime : float;
                                          agent_dangers__lastBulletReactionOffenderEid : EntityId;
                                          var agent_dangers__lastReactionOffender : EntityId&;
                                          agent_dangers__offenderReactionTime : float = 2f)

      agent_dangers__lastReactionOffender = INVALID_ENTITY_ID
      let curTime = get_sync_time()

      if (agent_dangers__lastHitReactionOffenderEid != INVALID_ENTITY_ID
          && curTime - agent_dangers__lastHitReactionTime <= agent_dangers__offenderReactionTime)
        agent_dangers__lastReactionOffender = agent_dangers__lastHitReactionOffenderEid
        res = EBehResult.ER_SUCCESS
        return

      if (agent_dangers__lastBulletReactionOffenderEid != INVALID_ENTITY_ID
            && curTime - agent_dangers__lastBulletReactionTime <= agent_dangers__offenderReactionTime)
        agent_dangers__lastReactionOffender = agent_dangers__lastBulletReactionOffenderEid
        res = EBehResult.ER_SUCCESS

    return res


[beh_node(name="getVisibleAttractionPosition")] // get_visible_attract_position_ai template
class GetVisibleAttractionPosition : BehNodeAdapter

  def override loadFromBlk(var data : DataBlock)
    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(visual_attract__points, visual_attract__nearestEid, visual_attract__nearestNavPos))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> GetVisibleAttractionPosition requires visual_attract.points, visual_attract.nearestEid and visual_attract.nearestNavPos fields")

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (visual_attract__points : Array;
                                          var visual_attract__nearestEid : EntityId&;
                                          var visual_attract__nearestNavPos : float3&)
      if length(visual_attract__points) == 0
        return

      var visiblePoints : array<Object const?>
      for it in visual_attract__points
        let data = it as Object
        if data?.visible ?? false
          visiblePoints |> push(data)

      if visiblePoints |> empty()
        return

      let resData = visiblePoints[grnd() % length(visiblePoints)]
      var navPos = resData?.pos ?? float3()
      if project_to_nearest_navmesh_point(navPos, float3(0.5))
        visual_attract__nearestEid = resData?.eid ?? INVALID_ENTITY_ID
        visual_attract__nearestNavPos = navPos
        res = EBehResult.ER_SUCCESS

    return res


[beh_node(name="wakeupSleepyhead")] // sleepyhead template
class WakeupSleepyhead : BehNodeAdapter
  wakeupTime : float = 15f

  def override loadFromBlk(var data : DataBlock)
    wakeupTime = data |> datablock_getReal("wakeupTime", wakeupTime)
    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(sleep_mode__isSleeping, sleep_mode__nextUpdateAt))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> WakeupSleepyhead requires sleep_mode.isSleeping and sleep_mode.nextUpdateAt fields")

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es(REQUIRE_NOT=sleep_mode_wakeup_forbidden)] (var sleep_mode__isSleeping : bool&;
                                                                                   var sleep_mode__nextUpdateAt : float&)
      sleep_mode__isSleeping = false
      sleep_mode__nextUpdateAt = max(sleep_mode__nextUpdateAt, get_sync_time() + wakeupTime)
      res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="sleepModeGoSleep")]
class SleepModeGoSleep : BehNodeAdapter
  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (sleep_mode__preparingForSleepTemplateServer : das_string const?;
                               var sleep_mode__isSleeping : bool&)
      if sleep_mode__preparingForSleepTemplateServer != null && *sleep_mode__preparingForSleepTemplateServer != ""
        addSubTemplate(ownerEid, string(*sleep_mode__preparingForSleepTemplateServer))
      else
        sleep_mode__isSleeping = true
      res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="nMeshfindInsideZonePos")]
class NMeshfindInsideZonePos : BehNodeAdapter
  posParam : string
  posParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let eid = beh_tree_eid(owner)
    var resPos : float3
    let zone = get_target_moving_zone()
    if find_random_point_around_circle(zone.pos, zone.radius, resPos)
      res = EBehResult.ER_SUCCESS
      if !eid |> has(posParam, posParamHash)
        logerr_once("{eid}: entity without output param '{posParam}:{posParamHash}' / {*thisNode |> beh_node_hierarchy_name(true)}")
      setOptional(eid, posParam, posParamHash, resPos)
    return res


[beh_node(name="nFindAttractPosition")]
class NFindAttractPosition : BehNodeAdapter
  radius : float = 30f
  navRadius : float = 3f
  posParam : string
  posParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)
    radius = data |> datablock_getReal("radius", radius)
    navRadius = data |> datablock_getReal("navRadius", navRadius)

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    var result = EBehResult.ER_FAILED
    query(eid) <| $ [es] (transform : float3x4; var attract_position__eid : EntityId&)
      let res = get_nearest_attract_point(eid, transform[3], 0ul, radius, false)
      if res is pos
        if !eid |> has(posParam, posParamHash)
          logerr_once("{eid}: entity without output param '{posParam}:{posParamHash}' / {*thisNode |> beh_node_hierarchy_name(true)}")
        else
          attract_position__eid = (res as pos).eid
          var resPos = (res as pos).targetPos
          let mappingZone = navmesh_mapping_find_best_zone_for_position(resPos)
          var mappedResPos = navmesh_map_position_in_zone(resPos, mappingZone)
          project_to_nearest_navmesh_point(mappedResPos, navRadius)
          resPos = navmesh_unmap_position_in_zone(mappedResPos, mappingZone)
          validate_gameplay_position(resPos) <| $()
            return <- "mappedResPos={mappedResPos}, mappingZone={mappingZone}"

          setOptional(eid, posParam, posParamHash, resPos)
          result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="nMeshFindPointInRegion")]
class NMeshFindPointInRegion : BehNodeAdapter
  posParam : string
  @hidden posParamHash : uint
  regionParam : int = -1
  tries : int = 2
  radius : float = 2f

  def override loadFromBlk(var data : DataBlock) : void
    tries = data |> datablock_getInt("tries", tries)
    radius = data |> datablock_getReal("radius", radius)
    regionParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "regionParam", ""), "")
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)

  def override update(dt : float) : EBehResult
    var agentPos : float3
    let eid = beh_tree_eid(owner)
    let hasPos = query(eid) <| $ [es] (transform : float3x4)
      agentPos = transform[3]
    if !hasPos
      return EBehResult.ER_FAILED

    var res = EBehResult.ER_FAILED
    let regionName = owner.blackBoard |> datablock_getStr(regionParam)
    in_region_with_name(regionName) <| $ [unused_argument(a2, a3)] (points, a2, a3)
      let randomPoint2D = points[rnd_int(0, length(points))] // border points usually are outside from any buildings
      let randomPoint = float3(randomPoint2D.x, traceht_lmesh(randomPoint2D), randomPoint2D.y)
      let foundPos = find_nav_point_around(agentPos, randomPoint, radius, tries) <| $ [unused_argument(pos)] (pos)
        return true

      if foundPos is pos
        res = EBehResult.ER_SUCCESS
        if !has(eid, posParam, posParamHash)
          logerr_once("{eid}: entity without output param '{posParam}:{posParamHash}' / {*thisNode |> beh_node_hierarchy_name(true)}")
        setOptional(eid, posParam, posParamHash, foundPos as pos)
        return
      elif distance_sq(agentPos, randomPoint) < square(50.f) // finding pos at long distances fails regularly, so it's pointless to report
        logerr_once("{eid}: agent '{getEntityTemplateName(eid)}' at {agentPos} unable to find pos in region '{regionName}' around {randomPoint} in radius {radius}")

    return res