module agent_position_mapping_common shared

require ecs
require math.base
require math
require pathfinder
require game.es.level_common
require game.es.ecs_common
require NavmeshMapping public


def navmesh_mapping_is_zone_applicable(position : float3; zone_radius : float; inverse_zone_tm : float3x4)
  let localPos = inverse_zone_tm * position
  return length_sq(localPos) <= square(zone_radius)


// Forced variants ignore mapping zone radius
def navmesh_map_position_in_zone_forced(pos : float3; zone : EntityId)
  validate_gameplay_position(pos) <| $()
    return <- "zone={get_entity_info(zone)}"

  var res = pos
  query(zone) <| $ [es] (transform : float3x4; position_mapping__matrix : float3x4)
    let inverseTm = inverse(transform)
    let localPos = inverseTm * pos
    res = position_mapping__matrix * localPos
  return res


def navmesh_unmap_position_in_zone_forced(pos : float3; zone : EntityId)
  var res = pos
  query(zone) <| $ [es] (transform : float3x4; position_mapping__matrix : float3x4)
    let reverseInverseTm = inverse(position_mapping__matrix)
    let reversedLocalPos = reverseInverseTm * pos
    res = transform * reversedLocalPos
    validate_gameplay_position(res) <| $()
      return <- "pos={pos}, zone={get_entity_info(zone)}
transform={transform}
reverseInverseTm={reverseInverseTm}
position_mapping__matrix={position_mapping__matrix}"
  return res


def navmesh_mapping_find_best_zone_for_position(pos : float3)
  let isNegative = find_query() <| $ [es] (transform : float3x4; negative_position_mapping__radius : float)
    return distance_sq(pos, transform[3]) < square(negative_position_mapping__radius)
  if isNegative
    return INVALID_ENTITY_ID

  var minDistanceSq = FLT_MAX
  var zoneEid = INVALID_ENTITY_ID
  query() <| $ [es] (eid : EntityId; transform : float3x4; position_mapping__matrix : float3x4; position_mapping__radius : float)
    let inverseTm = inverse(transform)
    let localPos = inverseTm * pos
    if length_sq(localPos) <= square(position_mapping__radius)
      let potentialPos = position_mapping__matrix * localPos
      var navmeshMappedPos = potentialPos
      if project_to_nearest_navmesh_point(navmeshMappedPos, 0.5f)
        let distSq = distance_sq(navmeshMappedPos, potentialPos)
        if distSq < minDistanceSq
          minDistanceSq = distSq
          zoneEid = eid
  return zoneEid

def project_to_nearest_navmesh_point_with_navmesh_mapping(var pos : float3&;
                                                          extents : float3;
                                                          mapping_zone_eid : EntityId)
  if mapping_zone_eid == INVALID_ENTITY_ID
    return project_to_nearest_navmesh_point(pos, extents)
  var mappedPos = navmesh_map_position_in_zone(pos, mapping_zone_eid)
  if !project_to_nearest_navmesh_point(mappedPos, extents)
    return false
  pos = navmesh_unmap_position_in_zone(mappedPos, mapping_zone_eid)
  validate_gameplay_position(pos) <| $()
    return <- "mappedPos={mappedPos}, mapping_zone_eid={mapping_zone_eid}"
  return true


def project_to_nearest_navmesh_point_with_navmesh_mapping(var pos : float3&;
                                                          extents : float3)
  let mappingZone = navmesh_mapping_find_best_zone_for_position(pos)
  return project_to_nearest_navmesh_point_with_navmesh_mapping(pos, extents, mappingZone)


def project_to_nearest_navmesh_point_with_navmesh_mapping_and_check_accessibility(var pos : float3&;
                                                                                  extents : float3;
                                                                                  resp_base_radius : float = 500.0;
                                                                                  max_checks : int = 3)
  var copyPos = pos
  let mappingZone = navmesh_mapping_find_best_zone_for_position(copyPos)

  if project_to_nearest_navmesh_point_with_navmesh_mapping(copyPos, extents, mappingZone)
    // Additional check for accessibility for non-mapped navmesh areas
    // (at the moment we don't know how to find_path between mapped and non-mapped areas)
    if mappingZone != INVALID_ENTITY_ID || check_pos_accessibility(copyPos, resp_base_radius, max_checks)
      pos = copyPos
      return true

  return false


def navmesh_mapping_find_best_unmap_zone_for_position(mappedPos : float3)
  var minDistanceSq = FLT_MAX
  var zoneEid = INVALID_ENTITY_ID
  query() <| $ [es] (eid : EntityId; position_mapping__matrix : float3x4; position_mapping__radius : float)
    let inverseTm = inverse(position_mapping__matrix)
    let localPos = inverseTm * mappedPos
    if length_sq(localPos) <= square(position_mapping__radius)
      if length_sq(localPos) <= minDistanceSq
        minDistanceSq = length_sq(localPos)
        zoneEid = eid
  return zoneEid


def navmesh_update_position_mapping_state_on_get_target(eid : EntityId; var targetPos : float3&)
  var needToVisitTransitZone = false
  query(eid) <| $ [es] (position_mapping__isInTransitZone : bool;
                        position_mapping__intermediateWaypoint : float3;
                        nphys_position_mapping__didMapThisFrame : bool;
                        var path_corridor__forceUpdateThisFrame : bool&;
                        var position_mapping__isOnSphere : bool&;
                        var position_mapping__isGoalOnSphere : bool&)
    position_mapping__isGoalOnSphere = navmesh_is_position_in_mapping_zone_or_mapped(targetPos)
    needToVisitTransitZone = (position_mapping__isGoalOnSphere != position_mapping__isOnSphere)
    let curTargetPos = needToVisitTransitZone ? position_mapping__intermediateWaypoint : targetPos
    targetPos = nphys_position_mapping__didMapThisFrame ? navmesh_map_position(curTargetPos) : curTargetPos

    path_corridor__forceUpdateThisFrame = path_corridor__forceUpdateThisFrame || position_mapping__isInTransitZone
    if position_mapping__isInTransitZone && position_mapping__isGoalOnSphere != position_mapping__isOnSphere
      position_mapping__isOnSphere = position_mapping__isGoalOnSphere
  return needToVisitTransitZone
