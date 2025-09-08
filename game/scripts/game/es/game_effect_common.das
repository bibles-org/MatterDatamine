module game_effect_common shared
require ecs
require Grid
require GridCollision
require CollisionTraces
require Dacoll
require Daphys
require DagorMath
require math.base
require vehicle
require game.es.vehicle.vehicle_seats_common

def adjust_entity_spawn_position(var pos : float3&; radius : float; iters : int; errorMargin : float)
  var dpos = DPoint3(pos)
  let fakeQuat = quat(0.f, 0.f, 0.f, 1.f)
  let iMoi = DPoint3(0.lf, 0.lf, 0.lf)
  let mask = int(PhysLayer.EPL_ALL) & ~int(PhysLayer.EPL_CHARACTER)
  var totalPenetration : float
  for _ in range(iters)
    totalPenetration = 0.0
    test_sphere_collision_world(dpos, radius, -1, PhysLayer.EPL_DEFAULT, mask) <| $(contacts : array<CollisionContactData>#)
      for contact in contacts
        if contact.depth < 0.0
          totalPenetration += -contact.depth
      resolve_penetration(dpos, fakeQuat, contacts, 0.1lf, iMoi, 1lf, true, 1)
    if totalPenetration < radius * errorMargin
      pos = float3(dpos)
      return true
  pos = float3(dpos)
  return false

def adjust_entity_spawn_position(var source_tm : float3x4; radius, height : float; mat_id : int; iters : int; errorMargin : float)
  let fakeQuat = quat(0.f, 0.f, 0.f, 1.f)
  let iMoi = DPoint3(0.lf, 0.lf, 0.lf)
  let mask = int(PhysLayer.EPL_ALL) & ~int(PhysLayer.EPL_CHARACTER)
  var totalPenetration : float
  for _ in range(iters)
    totalPenetration = 0.0
    test_capsule_collision_world(source_tm, radius, height, -1, PhysLayer.EPL_DEFAULT, mask) <| $(contacts : array<CollisionContactData>#)
      for contact in contacts
        if contact.depth < 0.0
          totalPenetration += -contact.depth
      var dpos = DPoint3(source_tm[3])
      resolve_penetration(dpos, fakeQuat, contacts, 0.1lf, iMoi, 1lf, true, 1)
      source_tm[3] = float3(dpos)
    if totalPenetration < radius * errorMargin
      //additional test, because contacts lie
      var castRes = ShapeQueryOutput()
      let p1 = source_tm[3] - source_tm[1] * height
      let p2 = source_tm[3] + source_tm[1] * height
      if sphere_cast(p1, p2, radius, castRes, mat_id)
        return false
      return true
  return false

def for_each_human_in_effect_radius(origin : float3; radius : float; ignore_eids : EidList const?; subexpr : block<(eid : EntityId) : void>)
  let radiusSq = square(radius)
  for_each_entity_in_grid(ecs_hash("humans"), BSphere3(origin, radius), GridEntCheck.BOUNDING) <| $(humanEid : EntityId)
    query(humanEid) <| $ [es(REQUIRE=human)] (isAlive : bool; hitpoints__shellDmgTraceTolerance : float = 0.2)
      if !preliminary_check(humanEid, ignore_eids, isAlive)
        return
      if !is_within_effect_radius(humanEid, origin, radiusSq, hitpoints__shellDmgTraceTolerance)
        return
      invoke(subexpr, humanEid)

def for_nearest_human_in_effect_radius(origin : float3; radius : float; ignore_eids : EidList const?; subexpr : block<(eid : EntityId) : void>)
  var bestMatch : EntityId
  let radiusSq = square(radius)
  var bestDistanceSq = 2f * radiusSq
  for_each_entity_in_grid(ecs_hash("humans"), BSphere3(origin, radius), GridEntCheck.BOUNDING) <| $(humanEid : EntityId)
    query(humanEid) <| $ [es(REQUIRE=human)] (isAlive : bool; hitpoints__shellDmgTraceTolerance : float = 0.2)
      if !preliminary_check(humanEid, ignore_eids, isAlive)
        return
      let distSqFromEffect = calculate_distance_sq_from_effect(humanEid, origin, hitpoints__shellDmgTraceTolerance)
      if distSqFromEffect > radiusSq || distSqFromEffect > bestDistanceSq
        return
      bestDistanceSq = distSqFromEffect
      bestMatch = humanEid
  if bestDistanceSq <= radiusSq
    invoke(subexpr, bestMatch)


def private is_within_effect_radius(eid : EntityId; center : float3; radius_sq : float; tolerance : float = 0.2)
  return calculate_distance_sq_from_effect(eid, center, tolerance) <= radius_sq


def private calculate_distance_sq_from_effect(eid : EntityId; center : float3; tolerance : float = 0.2)
  var nearestDistance_sq = FLT_MAX
  trace_to_collision_nodes(center, eid, SortIntersections.NO, tolerance) <| $(intersections : array<IntersectedEntity>#)
    for intersection in intersections
      nearestDistance_sq = min(nearestDistance_sq, distance_sq(intersection.pos, center))

  return nearestDistance_sq


def private preliminary_check(eid : EntityId;  ignore_eids : EidList const?; isAlive : bool)
  if !isAlive
    return false
  if ignore_eids != null
    for ieid in *ignore_eids
      if ieid == eid
        return false
  return true


def get_hero_offender(offender_eid : EntityId)
  let maxInertialKillTime = 4.0
  let driver = get_last_vehicle_driver_possessed_by_player(offender_eid, maxInertialKillTime)
  return driver != INVALID_ENTITY_ID ? driver : offender_eid
