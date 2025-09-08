require ecs
require level
require Dacoll
require DagorMath
require math.base
require pathfinder
require DagorRandom
require active_matter.game.es.regions_common
require game.events.events_active_matter


def swarm_find_next_waypoint(pos : float3;
                             horzDir : float2;
                             max_angle : float;
                             step_size, height : float;
                             out_region_offset : float)
  var resPos : float3
  let angle = rnd_float(-max_angle, max_angle)
  var randRotate = float2()
  sincos(angle, randRotate.y, randRotate.x)
  let resDir = float2(horzDir.x * randRotate.x - horzDir.y * randRotate.y, horzDir.x * randRotate.y + horzDir.y * randRotate.x)
  resPos = pos + float3(resDir.x, 0.f, resDir.y) * step_size

  var fieldForce = float2(0.f)
  query() <| $ [es] (transform : float3x4)
    let bboxDiag = 0.5 * (transform[0] + transform[1] + transform[2])
    var bbox = BBox3(transform[3] - bboxDiag, transform[3] + bboxDiag)
    bbox3_inflateXZ(bbox, out_region_offset)
    if bbox & resPos
      let resCenterDir = (resPos - bbox.center).xz
      let forceModule = 1.f - safediv(length_sq(resCenterDir), length_sq((bbox.boxMax - bbox.center).xz))
      fieldForce += normalize(resCenterDir) * forceModule

  let resDirWithDeflection = normalize(resDir + fieldForce)
  resPos = pos + float3(resDirWithDeflection.x, 0.f, resDirWithDeflection.y) * step_size

  let resPosXZ = resPos.xz
  let resHeight = traceht_lmesh(resPosXZ) + height
  resPos.y = resHeight
  return resPos


def swarm_find_retire_point(pos, zone_center : float3; zone_radius, offset, height : float)
  var posDir = pos - zone_center
  posDir.y = 0.f
  let posDist = length(posDir)
  let dir = normalize(posDir)
  let dist = dir * (zone_radius - posDist + offset)
  var resPos = pos + dist
  let resPosXZ = resPos.xz
  let resHeight = traceht_lmesh(resPosXZ) + height
  resPos.y = resHeight
  return resPos


[es(tag=server, on_appear)]
def patrolling_swarm_on_appear(evt : Event;
                               swarm_cluster__hivePos : float3;
                               var patrolling_swarm__targetWaypoint : float3&)
  patrolling_swarm__targetWaypoint = swarm_cluster__hivePos


[es(tag=server, on_event=EventOnMovingZoneStarted, REQUIRE=moving_zone__targetPos)]
def patrolling_swarm_retire(evt : Event;
                            sphere_zone__radius : float;
                            transform aka zone_transform : float3x4)
  var swarmToRetire = INVALID_ENTITY_ID
  var distSqToZoneCenter = 0.f
  query() <| $ [es(REQUIRE=am_bees_solo_swarm)] (eid : EntityId; transform aka swarm_transform : float3x4; swarm__retired : bool)
    let curDistSq = distance_sq(swarm_transform[3], zone_transform[3])
    if !swarm__retired && curDistSq > distSqToZoneCenter
      swarmToRetire = eid
      distSqToZoneCenter = curDistSq
  query(swarmToRetire) <| $ [es] (transform aka swarm_transform : float3x4;
                                  patrolling_swarm__destroyDistFromZoneBorder : float;
                                  patrolling_swarm__height : float;
                                  swarm_cluster__hivePos : float3;
                                  var swarm__retired : bool&;
                                  var patrolling_swarm__velocity : float3&;
                                  var patrolling_swarm__targetWaypoint : float3&)
    swarm__retired = true
    patrolling_swarm__targetWaypoint = swarm_find_retire_point(swarm_transform[3], zone_transform[3], sphere_zone__radius,
      patrolling_swarm__destroyDistFromZoneBorder, patrolling_swarm__height)
    patrolling_swarm__velocity = normalize(patrolling_swarm__targetWaypoint - swarm_cluster__hivePos)


[es(tag=server, no_order)]
def patrolling_swarm_destroy_on_retire(act : ParallelUpdateFrameDelayed;
                                       eid : EntityId;
                                       swarm__retired : bool;
                                       swarm_cluster__hivePos : float3;
                                       patrolling_swarm__targetWaypoint : float3)
  if swarm__retired && distance_sq(swarm_cluster__hivePos, patrolling_swarm__targetWaypoint) < square(1f)
    destroyEntity(eid)


[es(tag=server, no_order)]
def patrolling_swarm_move_to_next_waypoint(act : ParallelUpdateFrameDelayed;
                                           swarm_cluster__isWandering : bool;
                                           swarm__retired : bool;
                                           patrolling_swarm__patrollingSpeed : float;
                                           patrolling_swarm__height : float;
                                           transform aka swarm_transform : float3x4;
                                           patrolling_swarm__maxStep : float;
                                           patrolling_swarm__maxDeflectionAngle : float;
                                           patrolling_swarm__outOfRegionOffset : float;
                                           patrolling_swarm__inZoneMultiplier : float;
                                           var patrolling_swarm__velocity : float3&;
                                           var swarm_cluster__hivePos : float3&;
                                           var patrolling_swarm__targetWaypoint : float3&)
  if !swarm_cluster__isWandering
    swarm_cluster__hivePos = swarm_transform[3]
    patrolling_swarm__targetWaypoint = swarm_transform[3]
    return
  if !swarm__retired && distance_sq(swarm_cluster__hivePos, patrolling_swarm__targetWaypoint) < square(1f)
    find_query() <| $ [es(REQUIRE=moving_zone__targetPos)] (sphere_zone__radius : float;
                                                            transform aka zone_transform : float3x4)
      let velModSq = length_sq(patrolling_swarm__velocity.xz)
      let rand = rnd_float(-1.f, 1.f)
      let signY = rnd_int(0, 1) * 2 - 1
      var dir = (velModSq > FLT_MIN || velModSq < -FLT_MIN) ? patrolling_swarm__velocity.xz : float2(rand, float(signY) * sqrt(1.f - square(rand)))
      let centerDir = (zone_transform[3] - swarm_transform[3]).xz
      let centerDist = length(centerDir)
      let distToZoneBorder = sphere_zone__radius - centerDist
      var angle = patrolling_swarm__maxDeflectionAngle
      if distToZoneBorder < FLT_MIN
        angle /= 2.f
        dir = normalize(centerDir)
      else
        if centerDist > sphere_zone__radius * patrolling_swarm__inZoneMultiplier
          let forceModule = safediv(sphere_zone__radius * (1.f - patrolling_swarm__inZoneMultiplier), sphere_zone__radius - centerDist)
          let fieldForce = normalize(centerDir) * forceModule
          dir += fieldForce
        dir = normalize(dir)
      patrolling_swarm__targetWaypoint = swarm_find_next_waypoint(swarm_cluster__hivePos, dir, angle,
        patrolling_swarm__maxStep, patrolling_swarm__height, patrolling_swarm__outOfRegionOffset)
      return true
  else
    swarm_cluster__hivePos += patrolling_swarm__velocity * patrolling_swarm__patrollingSpeed * act.dt
  patrolling_swarm__velocity = normalize(patrolling_swarm__targetWaypoint - swarm_cluster__hivePos)
