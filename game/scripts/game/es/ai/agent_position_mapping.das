require ecs
require DagorMath
require math.base
require game.es.ai.agent_position_mapping_common
require game.es.ai.agent_position_mapping_find_obstacles_common
require game.es.ecs_common
require RendInst
require strings
require DagorSystem
require NavmeshMapping
require pathfinder
require Grid
require GridCollision
require ecs.common
require app
require DngWalkerai
require game.es.grav_zones_common
require level
require Dacoll
require game.events.events_active_matter


[es(tag=server, before=beh_tree_update_es, parallel_for=8, REQUIRE=position_mapping, REQUIRE_NOT=(deadEntity, nphys__disabled))]
def navmeshmapping_update_agent_last_zone(update : UpdateStageInfoAct;
                                          transform aka walker_transform : float3x4;
                                          beh_tree__enabled : bool = true;
                                          var position_mapping__isOnSphere : bool&;
                                          var path_corridor__forceUpdateThisFrame : bool&;
                                          var position_mapping__lastZone : EntityId&)
  if !beh_tree__enabled
    return

  if !position_mapping__isOnSphere
    position_mapping__lastZone = INVALID_ENTITY_ID
    return
  let prevZone = position_mapping__lastZone
  position_mapping__lastZone = navmesh_mapping_find_best_zone_for_position(transform[3])
  if position_mapping__lastZone == INVALID_ENTITY_ID
    position_mapping__isOnSphere = false
  if prevZone != position_mapping__lastZone
    path_corridor__forceUpdateThisFrame = true


def choose_best_transit_zone(agent_transform : float3x4; var position_mapping__intermediateWaypoint : float3&)
  var minDistSq = FLT_MAX
  var zonePos = float3()
  query() <| $ [es(REQUIRE=position_mapping_transit_zone)] (position_mapping_transit_zone__groundPosition : float3)
    let thisZonePos = position_mapping_transit_zone__groundPosition
    let curDistSq = distance_sq(thisZonePos, agent_transform[3])
    if curDistSq < minDistSq
      minDistSq = distance_sq(thisZonePos, agent_transform[3])
      zonePos = thisZonePos

  if minDistSq < FLT_MAX
    position_mapping__intermediateWaypoint = zonePos


[es(tag=server, on_appear, after=init_navmesh_phys)]
def navmeshmapping_init(evt : Event;
                        eid : EntityId;
                        transform : float3x4;
                        position_mapping__intermediateWaypointUpdateInterval : float;
                        var position_mapping__intermediateWaypointUpdateAt : float&;
                        var position_mapping__intermediateWaypoint : float3&;
                        var position_mapping__isOnSphere : bool&)
  position_mapping__isOnSphere = navmesh_mapping_find_best_zone_for_position(transform[3]) != INVALID_ENTITY_ID
  choose_best_transit_zone(transform, position_mapping__intermediateWaypoint)
  position_mapping__intermediateWaypointUpdateAt = eid_frnd(eid) * position_mapping__intermediateWaypointUpdateInterval


[es(tag=server, on_appear, tag=server, after=init_navmesh_phys, REQUIRE=position_mapping)]
def navmeshmapping_init_prev_pos(evt : Event;
                                 eid : EntityId;
                                 navmesh_phys__currentPos : float3;
                                 var navmesh_phys__prevPos : float3&)
  validate_gameplay_position(navmesh_phys__currentPos) <| $()
    return <- "eid={get_entity_info(eid)}"
  navmesh_phys__prevPos = navmesh_phys__currentPos


[es(tag=server, before=beh_tree_update_es, REQUIRE_NOT=(deadEntity, nphys__disabled))]
def navmeshmapping_update_intermediate_waypoint(update : UpdateStageInfoAct;
                                                transform : float3x4;
                                                position_mapping__intermediateWaypointUpdateInterval : float;
                                                var position_mapping__intermediateWaypointUpdateAt : float&;
                                                var position_mapping__intermediateWaypoint : float3&)
  let curTime = get_sync_time()
  if curTime < position_mapping__intermediateWaypointUpdateAt
    return

  choose_best_transit_zone(transform, position_mapping__intermediateWaypoint)
  position_mapping__intermediateWaypointUpdateAt = curTime + position_mapping__intermediateWaypointUpdateInterval


[es(on_event=EventLevelLoaded)]
def generate_navmeshmapping_zones_from_ri(evt : Event; position_mapping_zones_generator__riPrefix : string; position_mapping_zones_generator__riSuffix : string)
  assume prefix = position_mapping_zones_generator__riPrefix
  assume suffix = position_mapping_zones_generator__riSuffix
  if empty(prefix) && empty(suffix)
    logerr("Empty RI prefix and suffix in generate_navmesh_mapping_zones")
    return
  let oldNumCallbacks = setMaxNumRiCollisionCb(500000u)
  // 1. Gather all 'to' places by ID
  var nameToTm : table<string; float3x4>
  query() <| $ [es(REQUIRE=position_mapping_to_area_marker)] (transform : float3x4; sphere_zone__radius : float)
    let box = BBox3(transform[3] - float3(sphere_zone__radius), transform[3] + float3(sphere_zone__radius))
    rendinst_foreachInBox(box, int(GatherRiTypeFlags.RiGenAndExtra)) <| $ [unused_argument(is_tm)] (desc : RendInstDesc; tm : float3x4; is_tm : bool)
      let resName = getRIGenResName(desc)
      let satisfiesPrefix = empty(prefix) || starts_with(resName, prefix)
      let satisfiesSuffix = empty(suffix) || ends_with(resName, suffix)
      if !satisfiesPrefix || !satisfiesSuffix
        return
      nameToTm.insert(resName, tm)

  // 2. For each 'from' place generate a mapping zone
  query() <| $ [es(REQUIRE=position_mapping_from_area_marker)] (transform : float3x4; sphere_zone__radius : float)
    let box = BBox3(transform[3] - float3(sphere_zone__radius), transform[3] + float3(sphere_zone__radius))
    rendinst_foreachInBox(box, int(GatherRiTypeFlags.RiGenAndExtra)) <| $ [unused_argument(is_tm)] (desc : RendInstDesc; tm : float3x4; is_tm : bool)
      let resName = getRIGenResName(desc)
      let satisfiesPrefix = empty(prefix) || starts_with(resName, prefix)
      let satisfiesSuffix = empty(suffix) || ends_with(resName, suffix)
      if !satisfiesPrefix || !satisfiesSuffix
        return

      if !key_exists(nameToTm, resName)
        logerr("Cannot create navmesh mapping zone for {resName} at {tm}: no mapping destination found")
        return

      let bSphere = getRIGenBBox(desc) |> BSphere3()
      let verticalScale = scale_tm(float3(1.0, 1.0, 1.0))
      createEntity("navigation_position_mapping") <| $(init)
        set(init, "transform", tm * verticalScale)
        set(init, "position_mapping__matrix", nameToTm.get_value(resName) * verticalScale)
        set(init, "position_mapping__radius", bSphere.r)
  setMaxNumRiCollisionCb(oldNumCallbacks)


[es(tag=server, REQUIRE=position_mapping, before=beh_tree_update_es, after=navmeshmapping_update_agent_last_zone, REQUIRE_NOT=(deadEntity, nphys__disabled))]
def map_nphys_navmesh_components(update : UpdateStageInfoAct;
                                 position_mapping__lastZone : EntityId;
                                 position_mapping__isOnSphere : bool;
                                 var navmesh_phys__currentPoly : int64&;
                                 var nphys_position_mapping__didMapThisFrame : bool&;
                                 var nphys_position_mapping__oldUpDir : float3&;
                                 var navmesh_phys__upDir : float3&;
                                 var navmesh_phys__currentLookDir : float3&;
                                 var navmesh_phys__prevLookDir : float3&;
                                 var navmesh_phys__wishLookDir : float3&;
                                 var navmesh_phys__wishWalkDir : float3&;
                                 var navmesh_phys__currentPos : float3&;
                                 var navmesh_phys__prevPos : float3&;
                                 var navmesh_phys__currentWalkVelocity : float3&)
  if !position_mapping__isOnSphere
    nphys_position_mapping__didMapThisFrame = false
    return
  nphys_position_mapping__oldUpDir = navmesh_phys__upDir
  navmesh_phys__upDir = float3(0.0, 1.0, 0.0)
  navmesh_phys__currentLookDir = navmesh_map_direction_in_zone(navmesh_phys__currentLookDir, navmesh_phys__currentPos, position_mapping__lastZone)
  navmesh_phys__prevLookDir = navmesh_map_direction_in_zone(navmesh_phys__prevLookDir, navmesh_phys__currentPos, position_mapping__lastZone)
  navmesh_phys__wishLookDir = navmesh_map_direction_in_zone(navmesh_phys__wishLookDir, navmesh_phys__currentPos, position_mapping__lastZone)
  navmesh_phys__wishWalkDir = navmesh_map_direction_in_zone(navmesh_phys__wishWalkDir, navmesh_phys__currentPos, position_mapping__lastZone)

  navmesh_phys__currentPos = navmesh_map_position_in_zone_forced(navmesh_phys__currentPos, position_mapping__lastZone)
  navmesh_phys__prevPos = navmesh_map_position_in_zone_forced(navmesh_phys__prevPos, position_mapping__lastZone)

  var poly : dtPolyRef
  var pos = navmesh_phys__currentPos
  if project_to_nearest_navmesh_point(pos, float3(1, 0.5, 1), poly)
    navmesh_phys__currentPoly = int64(poly)
  else
    navmesh_phys__currentPoly = int64(0)

  navmesh_phys__currentWalkVelocity = navmesh_map_vector_in_zone(navmesh_phys__currentWalkVelocity, position_mapping__lastZone)

  nphys_position_mapping__didMapThisFrame = true


[es(tag=server, REQUIRE=position_mapping, REQUIRE_NOT=(deadEntity, nphys__disabled), after=update_navmesh_phys, before=(navmesh_phys_update_gravity, animchar_walk_dir_update, move_navmesh_phys_lookdir, move_navmesh_phys_pos, update_nphys_levitation, navmesh_aligned_phys))]
def unmap_nphys_navmesh_components(update : UpdateStageInfoAct;
                                   eid : EntityId;
                                   nphys_position_mapping__oldUpDir : float3&;
                                   nphys_position_mapping__didMapThisFrame : bool;
                                   var position_mapping__lastZone : EntityId&;
                                   var navmesh_phys__currentPoly : int64&;
                                   var navmesh_phys__upDir : float3&;
                                   var navmesh_phys__currentLookDir : float3&;
                                   var navmesh_phys__prevLookDir : float3&;
                                   var navmesh_phys__wishLookDir : float3&;
                                   var navmesh_phys__wishWalkDir : float3&;
                                   var navmesh_phys__currentPos : float3&;
                                   var navmesh_phys__prevPos : float3&;
                                   var navmesh_phys__currentWalkVelocity : float3&)
  if !nphys_position_mapping__didMapThisFrame
    return

  // if during navmesh_phys updates we moved outside of the mapping zone, we need to choose a new one
  var isApplicable = false
  query(position_mapping__lastZone) <| $ [es] (position_mapping__matrix : float3x4; position_mapping__radius : float)
    isApplicable = navmesh_mapping_is_zone_applicable(navmesh_phys__currentPos, position_mapping__radius, inverse(position_mapping__matrix))
  if !isApplicable
    position_mapping__lastZone = navmesh_mapping_find_best_unmap_zone_for_position(navmesh_phys__currentPos)
    debug("needed to update last zone in unmap_nphys_navmesh_components at {navmesh_phys__currentPos} for <{eid}>")

  navmesh_phys__upDir = nphys_position_mapping__oldUpDir
  navmesh_phys__currentLookDir = navmesh_unmap_direction_in_zone(navmesh_phys__currentLookDir, navmesh_phys__currentPos, position_mapping__lastZone)
  navmesh_phys__prevLookDir = navmesh_unmap_direction_in_zone(navmesh_phys__prevLookDir, navmesh_phys__currentPos, position_mapping__lastZone)
  navmesh_phys__wishLookDir = navmesh_unmap_direction_in_zone(navmesh_phys__wishLookDir, navmesh_phys__currentPos, position_mapping__lastZone)
  navmesh_phys__wishWalkDir = navmesh_unmap_direction_in_zone(navmesh_phys__wishWalkDir, navmesh_phys__currentPos, position_mapping__lastZone)

  navmesh_phys__currentPos = navmesh_unmap_position_in_zone_forced(navmesh_phys__currentPos, position_mapping__lastZone)
  navmesh_phys__prevPos = navmesh_unmap_position_in_zone_forced(navmesh_phys__prevPos, position_mapping__lastZone)

  navmesh_phys__currentPoly = int64(0)
  navmesh_phys__currentWalkVelocity = navmesh_unmap_vector_in_zone(navmesh_phys__currentWalkVelocity, position_mapping__lastZone)


[es(tag=server, REQUIRE=position_mapping, before=unmap_nphys_navmesh_components, after=update_navmesh_phys,
  REQUIRE_NOT=(deadEntity, nphys__disabled, nmesh_phys_approach_navmesh_disabled))]
def nmesh_phys_approach_navmesh(update : UpdateStageInfoAct;
                                path_corridor__overJumpLink : bool;
                                nphys_position_mapping__nmeshApproachSpeed : float;
                                var navmesh_phys__currentPos : float3&)
  if path_corridor__overJumpLink
    return
  var nmeshPos = navmesh_phys__currentPos
  if project_to_nearest_navmesh_point(nmeshPos, 0.5)
    let vertDiff = (nmeshPos - navmesh_phys__currentPos).y
    if abs(vertDiff) > 0.1
      navmesh_phys__currentPos += float3(0.0, sign(vertDiff), 0.0) * min(nphys_position_mapping__nmeshApproachSpeed * update.dt, abs(vertDiff))


[es(tag=server, before=beh_tree_update_es, REQUIRE=position_mapping_transit_zone)]
def transit_zone_update(update : UpdateStageInfoAct; transform : float3x4; var position_mapping_transit_zone__visitors : EidList)
  var currentVisitors : array<EntityId>
  let bb = transform * BBox3(float3(-0.5), float3(0.5))
  for_each_entity_in_grid(ecs_hash("humans"), bb, GridEntCheck.BOUNDING) <| $(eid : EntityId)
    push(currentVisitors, eid)
    if has_value(position_mapping_transit_zone__visitors, eid)
      return

    // eid is not in last frame visitors -> just entered
    query(eid) <| $ [es] (var position_mapping__isInTransitZone : bool&)
      position_mapping__isInTransitZone = true

  for oldVisitor in position_mapping_transit_zone__visitors
    if !has_value(currentVisitors, oldVisitor)
      query(oldVisitor) <| $ [es] (var position_mapping__isInTransitZone : bool&)
        position_mapping__isInTransitZone = false

  clear(position_mapping_transit_zone__visitors)
  reserve(position_mapping_transit_zone__visitors, length(currentVisitors))
  for eid in currentVisitors
    push(position_mapping_transit_zone__visitors, eid)
  return


[es(on_appear, on_event=EventRetriggerEntity, on_event, tag=server)]
def transit_zone_init(evt : Event; eid : EntityId; transform aka transit_transform : float3x4; var position_mapping_transit_zone__groundPosition : float3&)
  if wake_me_up_when_gravzones_are_loaded(eid)
    return

  let foundBadZone = find_query() <| $ [es(REQUIRE=moving_zone__isInitialized)] (transform aka zone_transform : float3x4; sphere_zone__radius : float)
    return distance_sq(zone_transform[3], transit_transform[3]) > square(sphere_zone__radius) ? true : false

  if foundBadZone
    destroyEntity(eid)
    return

  let gravDir = get_grav_dir(transform[3])
  var height = 300.f
  var norm = float3()
  assume pos = position_mapping_transit_zone__groundPosition
  pos = transform[3]
  if traceray_normalized(pos, gravDir, height, norm, ETF_ALL)
    pos += height * gravDir


[es(tag=server, REQUIRE=position_mapping_transit_zone__groundPosition)]
def filter_transit_zones_on_moving_zone_created(evt : EventMovingZoneCreated;
                                                eid aka transit_eid : EntityId;
                                                transform aka transit_transform : float3x4)
  query(evt.eid) <| $ [es] (transform aka zone_transform : float3x4;
                            sphere_zone__radius : float)
    if distance_sq(zone_transform[3], transit_transform[3]) > square(sphere_zone__radius)
      destroyEntity(transit_eid)


[es(tag=server, before=navmeshmapping_update_agent_last_zone)]
def rescue_bots_from_mapped_navmesh(update : UpdateStageInfoAct;
                                    transform : float3x4;
                                    mapped_navmesh_rescue__interval : float;
                                    var mapped_navmesh_rescue__at : float&)
  let curTime = get_sync_time()
  if curTime < mapped_navmesh_rescue__at
    return
  mapped_navmesh_rescue__at = curTime + mapped_navmesh_rescue__interval

  let bb = transform * BBox3(float3(-0.5), float3(0.5))
  for_each_entity_in_grid(ecs_hash("humans"), bb, GridEntCheck.BOUNDING) <| $(eid : EntityId)
    if !has(eid, "navmeshPhys")
      return

    var didQuery = false
    query(eid) <| $ [es] (var position_mapping__isOnSphere : bool&; var transform aka bot_transform : float3x4&)
      didQuery = true
      position_mapping__isOnSphere = true
      let mappedPos = transform[3]
      transform[3] = navmesh_unmap_position(transform[3])
      validate_gameplay_position(transform[3]) <| $()
        return <- "mappedPos={mappedPos}"
      logwarn("rescued <{eid}> from mapped navmesh (teleported from {mappedPos} to {transform[3]})")
    if !didQuery
      logwarn("found <{eid}> ({getEntityTemplateName(eid)} on mapped navmesh. Don't know how to rescue, removing)")
      destroyEntity(eid)


[es(tag=server, REQUIRE=position_mapping,  REQUIRE_NOT=(deadEntity, nphys__disabled),
    after=map_nphys_navmesh_components, before=beh_tree_update_es)]
def nmesh_phys_update_obstacles_around_path(act : UpdateStageInfoAct;
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
    find_obstacles_and_map(eid, nphys_pushable__unlockMovementAt < act.curTime, destination)
