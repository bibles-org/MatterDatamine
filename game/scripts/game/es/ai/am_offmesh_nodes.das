options always_export_initializer = true


require app
require ecs
require ecs.common
require strings
require game.es.ecs_common
require DagorSystem
require BehNodes
require DagorDataBlock
require DagorRandom
require Dacoll
require pathfinder
require math.base
require math.random
require DagorMath
require GamePhys
require DngNet
require debug.logerr_once
require danetlibs.pathfinder.main.pathfinder_common
require game.es.grav_zones_common
require game.es.am_nphys_common
require NavmeshMapping
require game.es.ai.agent_position_mapping_common
require active_matter.game.es.surface_crawler_common



let CLIMB_OFF_ROOF_OFFSET = 0.8

[beh_node(name="tryOpportunisticClimbing")]
class TryOpportunisticClimbing : BehNodeAdapter

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (walker_agent__targetEid : EntityId;
                                          transform aka from_transform : float3x4;
                                          var walker_agent__climbingFrom : float3&;
                                          var walker_agent__climbingTo : float3&)
      query(walker_agent__targetEid) <| $ [es] (transform aka to_transform : float3x4)
        var fromPos = from_transform[3]
        var toPos = to_transform[3]
        if project_to_nearest_navmesh_point(fromPos, float3(0.5, 1.0, 0.5))
          if project_to_nearest_navmesh_point(toPos, float3(0.5, 1.0, 0.5))
            using() <| $(var path_corridor : dtPathCorridor)
              path_corridor |> init_path_corridor()
              let extents = float3(.5, FLT_MAX, .5)
              let endRef : dtPolyRef
              var resPath = FindPathResult.FPR_FAILED
              using(toPos, fromPos, extents) <| $(var inp : CorridorInput#)
                inp.startPoly = 0ul
                inp.targetPoly = endRef
                inp.includeFlags |= int(PolyFlag.POLYFLAG_JUMP)
                resPath = path_corridor |> set_path_corridor(inp, null)
              if resPath != FindPathResult.FPR_FAILED

                path_corridor |> find_corridor_corners(10) <| $(corners)
                  if length(corners) > 0
                    var start, end : float3
                    if length(corners) > 1
                      start = corners[length(corners) - 2]
                      end = corners[length(corners) - 1]
                    else
                      start = toPos
                      end = corners[0]
                    let baseDir = normalize(end - start)
                    let angles <- fixed_array(.0, PI * 0.5, PI, PI * 1.5)
                    let up = float3(0, 1, 0)
                    for angle in angles
                      let q = quat(up, angle)
                      let dir = q * baseDir
                      var climbPos = end + dir * CLIMB_OFF_ROOF_OFFSET
                      var t = 5.0
                      //to avoid situations where navmesh is slightly below the surface of the roof and can be traced to from below freely
                      let belowRoofTraceCheck = 1.0
                      var norm : float3
                      if fromPos.y < climbPos.y
                        t += belowRoofTraceCheck
                        let traceFrom = climbPos + float3(.0, belowRoofTraceCheck, .0)
                        if traceray_normalized(traceFrom, float3(0, -1, 0), t, norm, ETF_ALL)
                          if t > 1.0 + belowRoofTraceCheck
                            var landingPos = traceFrom + float3(0, -1, 0) * t
                            if project_to_nearest_navmesh_point(landingPos, float3(0.5, 0.5, 0.5))
                              walker_agent__climbingFrom = landingPos
                              walker_agent__climbingTo = climbPos
                              result = EBehResult.ER_SUCCESS
                              break
                      else
                        t = fromPos.y - climbPos.y + 1.0
                        if !traceray_normalized(climbPos, float3(0, 1, 0), t, norm, ETF_ALL)
                          var landingPos = climbPos + float3(0, 1, 0) * (t - 1.0)
                          if project_to_nearest_navmesh_point(landingPos, float3(1.0, 0.5, 1.0))
                            if project_to_nearest_navmesh_point(climbPos, float3(0.5, 0.5, 0.5))
                              walker_agent__climbingFrom = landingPos
                              walker_agent__climbingTo = climbPos
                              result = EBehResult.ER_SUCCESS
                              break

    return result


[beh_node(name="performClimbing")]
class PerformClimbing : BehNodeAdapter
  gravityMod : float = 1.0

  def override init() : void
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (walker_agent__climbingFrom : float3;
                               walker_agent__climbingTo : float3;
                               walker_agent__climbingDuration : float;
                               var navmesh_phys__currentWalkVelocity : float3&;
                               var walker_agent__climbingStart : float&;
                               var walker_agent__climbingReach : float&;
                               var walker_agent__climbingFinish : float&)
      navmesh_phys__currentWalkVelocity = float3()
      walker_agent__climbingStart = get_sync_time()
      let dst = distance(walker_agent__climbingFrom, walker_agent__climbingTo)
      let climbTime = sqrt(2.0 * dst / gravity())
      walker_agent__climbingReach = walker_agent__climbingStart + climbTime
      if walker_agent__climbingTo.y > walker_agent__climbingFrom.y
        gravityMod = 1.0
        walker_agent__climbingFinish = walker_agent__climbingReach + walker_agent__climbingDuration
      else
        walker_agent__climbingFinish = walker_agent__climbingReach
        gravityMod = -1.0
      remote_add_sub_template(ownerEid, "agent_in_climbing") <| $(initializer)
        initializer |> set("agent_in_climbing__removeAt", walker_agent__climbingFinish)


  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (var transform : float3x4;
                               walker_agent__climbingFrom : float3;
                               walker_agent__climbingTo : float3;
                               walker_agent__climbingStart : float;
                               walker_agent__climbingReach : float;
                               walker_agent__climbingFinish : float;
                               var navmesh_phys__currentPoly : int64&;
                               var navmesh_phys__prevPos : float3&;
                               var navmesh_phys__currentPos : float3&)
      let time = get_sync_time()
      if time < walker_agent__climbingReach
        let deltaT = time - walker_agent__climbingStart
        let t = walker_agent__climbingReach - walker_agent__climbingStart
        let startingV = gravityMod > 0.0 ? gravity() * t : 0.0
        let coveredDst = startingV * deltaT - gravityMod * gravity() * deltaT * deltaT * 0.5
        let dir = normalize(walker_agent__climbingTo - walker_agent__climbingFrom)
        transform[3] = walker_agent__climbingFrom + dir * coveredDst
        result = EBehResult.ER_RUNNING
      elif time > walker_agent__climbingFinish
        result = EBehResult.ER_SUCCESS
        transform[3] = walker_agent__climbingTo
        navmesh_phys__prevPos = transform[3]
        navmesh_phys__currentPos = transform[3]
        var poly = INVALID_POLY_REF
        project_to_nearest_navmesh_point(navmesh_phys__currentPos, float3(CLIMB_OFF_ROOF_OFFSET), poly)
        navmesh_phys__currentPoly = int64(poly)

        validate_gameplay_position(transform[3]) <| $()
          return <- "ownerEid={get_entity_info(ownerEid)}
transform={transform}
walker_agent__climbingTo={walker_agent__climbingTo}
navmesh_phys__prevPos={navmesh_phys__prevPos}
navmesh_phys__currentPos={navmesh_phys__currentPos}"
      else
        result = EBehResult.ER_RUNNING
    return result

  def override exit()
    let ownerEid = beh_tree_eid(owner)
    remote_remove_sub_template(ownerEid, "agent_in_climbing")


def is_parabolic_jump_available(vy, dh : float)
  let g = gravity()
  let j = square(vy / g) - 2.0 * dh / g
  return j >= 0.0


def calc_parabolic_jump_duration(vy, dh : float) //assumes we reach the target when going down, past the summit
  let g = gravity()
  let j = square(vy / g) - 2.0 * dh / g
  if j < 0.0
    logerr("Impossible jump solution! vy={vy} dh={dh}")
    return 0.0
  return vy / g + sqrt(j)


def parabolic_jump_get_vx_from_vy(vy, dx, dh : float)
  let t = calc_parabolic_jump_duration(vy, dh)
  return safediv(dx, t)


def calc_parabolic_jump(from, to : float3; max_vert_speed, min_vert_speed : float; iters : int)
  let dHeight = to.y - from.y
  let horVec = x0z(to) - x0z(from)
  let dLength = length(horVec)
  var minVertSpeed = dHeight > .0 ? sqrt(2.0 * dHeight * gravity()) : .0
  // avoid trajectories that jump down at a very step angle,
  //they often fail on collision checks with the surface that the agent stand on
  minVertSpeed = max(min_vert_speed, minVertSpeed)
  if minVertSpeed > max_vert_speed
    return float3()
  var xyFrom = minVertSpeed
  var xyTo = max_vert_speed
  var vy = max_vert_speed
  var vx = parabolic_jump_get_vx_from_vy(vy, dLength, dHeight)
  var bestResult = square(vx) + square(vy)
  var itersLeft = iters
  while itersLeft-- > 0
    let newVy = (xyTo + xyFrom) * 0.5
    let newVx = parabolic_jump_get_vx_from_vy(newVy, dLength, dHeight)
    let newRes = square(newVx) + square(newVy)
    if newRes < bestResult
      bestResult = newRes
      vx = newVx
      vy = newVy
      xyTo = (xyTo + xyFrom) * 0.5
    else
      xyFrom = (xyTo + xyFrom) * 0.5
  return float3(.0, vy, .0) + horVec * vx * safeinv(dLength)


def calc_parabolic_jump_path(var path : array<float3>; from, to, velocity : float3; leg : float)
  clear(path)

  let vy = velocity.y
  let dh = to.y - from.y
  if !is_parabolic_jump_available(vy, dh)
    return

  let t = calc_parabolic_jump_duration(vy, dh)
  if t == 0.0
    return
  let dstSq = distance_sq(to, from)
  if dstSq < FLT_EPSILON
    return
  var prevPos = from
  path |> push(prevPos)
  let legSq = min(square(leg), dstSq / 2.9) //at least 3 segments
  let steps = clamp(int(dstSq / legSq * 4.0), 10, 100)
  for i in range(steps)
    let dt = float(i) * t / float(steps)
    let pos = get_parabolic_jump_pos_at(from, velocity, dt)
    if distance_sq(prevPos, pos) > legSq || i == steps - 1
      path |> push(pos)
      prevPos = pos


def get_parabolic_jump_pos_at(from, velocity : float3; t : float)
  return from + velocity * t - float3(.0, 0.5, .0) * gravity() * t * t


def trace_jump_path(path : array<float3>; radius : float; ccd_offset : float3)
  if length(path) < 2
    return true

  var prev = path[0] + ccd_offset
  for idx in range(1, length(path) - 1)
    let to = path[idx] + ccd_offset
    let vec = (to - prev)
    let t = length(vec)
    let dir = vec * safeinv(t)
    if rayhit_normalized(prev, dir, t, ETF_DEFAULT, -1)
      //draw_debug_line_buffered(prev, prev + dir * t, ACORANGE, 700)
      return false
    prev = to

  let SPHERE_CAST_MASK = int(PhysLayer.EPL_ALL) & ~(int(PhysLayer.EPL_CHARACTER) | int(PhysLayer.EPL_DEBRIS))
  prev = path[0] + ccd_offset
  for idx in range(1, length(path) - 1)
    let to = path[idx] + ccd_offset
    var queryOut = ShapeQueryOutput()
    if sphere_cast_ex(prev, to, radius, queryOut, -1, null, SPHERE_CAST_MASK)
      //draw_debug_tube_buffered(prev, to, radius, ACORANGE, 24, 10.0, 100)
      return false
    //else
    //  draw_debug_tube_buffered(prev, to, radius, ACWHITE, 24, 10.0, 100)
    prev = to
  return true


def get_nearest_reachable_pos(from, to : float3)
  var result = float3()
  using() <| $(var path_corridor : dtPathCorridor)
    path_corridor |> init_path_corridor()
    let extents = float3(.01, .01, .01)
    let endRef : dtPolyRef
    var resPath = FindPathResult.FPR_FAILED
    using(from, to, extents) <| $(var inp : CorridorInput#)
      inp.startPoly = 0ul
      inp.targetPoly = endRef
      inp.includeFlags |= int(PolyFlag.POLYFLAG_JUMP)
      resPath = path_corridor |> set_path_corridor(inp, null)
    if resPath != FindPathResult.FPR_FAILED
      path_corridor |> find_corridor_corners(10) <| $(corners)
        if length(corners) > 0
          result = corners[length(corners) - 1]
  return result



def find_off_mesh_spot_next_to_target(target_pos, from_pos : float3;
                                      delta_ver, delta_hor : float2;
                                      radius, angle_rnd, height, vis_height : float;
                                      attempts : int = 5;
                                      desired_count : int = 3)
  var result : array<float3>
  let up = -get_grav_dir(target_pos)
  let delta = normalize(from_pos - target_pos)
  let dir = delta - up * dot(delta, up)
  var attemptsLeft = attempts
  var prevAngle = FLT_MAX
  var firstAngle : float
  while attemptsLeft-- > 0
    var t = delta_hor.y + radius
    var norm : float3
    var traceFrom = target_pos + up * vis_height
    let angleD = angle_rnd * 2.0 / float(attempts)
    //Divide in equal sectors and rnd in each sector
    var angle : float
    let minAngleDiff = angle_rnd * 2.0 / float(attempts) / 6.0
    for _ in range(5)
      angle = -angle_rnd + float(attemptsLeft) * angleD + rnd_float(.0, angleD)
      let tooCloseToPrev = abs(angle - prevAngle) < minAngleDiff
      let tooCloseToFirst = attemptsLeft == 0 && attempts > 1 && abs(firstAngle + PI * 2.0 - angle) < minAngleDiff
      if !tooCloseToPrev && !tooCloseToFirst
        break
    prevAngle = angle
    if attemptsLeft == attempts - 1
      firstAngle = angle
    let q = quat(up, angle)
    let traceDir = normalize(q * dir)
    traceray_normalized(traceFrom, traceDir, t, norm, ETF_ALL)
    if t > delta_hor.x + radius * 2.0
      traceFrom = traceFrom + traceDir * (t - radius)
      var downT = vis_height - delta_ver.x
      if traceray_normalized(traceFrom, -up, downT, norm, ETF_ALL)
        if downT > vis_height - delta_ver.y
          let downmostPoint = traceFrom - up * downT
          var upT = -vis_height + delta_ver.y + height
          traceray_normalized(traceFrom, up, upT, norm, ETF_ALL)
          if upT > -vis_height + delta_ver.x + height && upT + downT > height
            result |> push(downmostPoint)
            if length(result) >= desired_count
              return <- result
  return <- result


class AbstractNPhysPrepareJumping : BehNodeAdapter

  def abstract getTargetPos(target_pos, agent_pos : float3) : array<float3>

  [unused_argument(dt)] def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (walker_agent__targetEid : EntityId;
                                          walker_agent__maxJumpSpeed : float;
                                          navmesh_phys__currentPos : float3;
                                          nphys__ccdOffset : float3;
                                          walker_agent__collisionEffectiveRadius = 0.5;
                                          var walker_agent__jumpVelociy : float3&;
                                          var walker_agent__climbingFrom : float3&;
                                          var walker_agent__climbingTo : float3&)
      query(walker_agent__targetEid) <| $ [es] (transform aka to_transform : float3x4)
        let toPoints <- getTargetPos(to_transform[3], navmesh_phys__currentPos)
        if length(toPoints) > 0
          let nearestToTarget = get_nearest_reachable_pos(navmesh_phys__currentPos, toPoints[0])
          var path : array<float3>
          var fromPoints : array<float3>
          fromPoints |> push(navmesh_phys__currentPos)
          fromPoints |> push(nearestToTarget)
          var moreRndFromPoints = 3
          var lTargetPos = toPoints[0]
          lTargetPos.y = navmesh_phys__currentPos.y
          let maxDst = walker_agent__maxJumpSpeed - max(.0, to_transform[3].y - navmesh_phys__currentPos.y)
          while moreRndFromPoints-- > 0
            let fromCandidate = find_reachable_nav_point_around(navmesh_phys__currentPos, lTargetPos, maxDst * rnd_float(0.1, 0.9), /*tries*/2) <| $ [unused_argument(_)] (_ : float3)
              return true
            if fromCandidate is pos
              fromPoints |> push(fromCandidate as pos)
          fromPoints |> sort() <| $(a, b)
            return distance_sq(a, navmesh_phys__currentPos) < distance_sq(b, navmesh_phys__currentPos)
          for from in fromPoints
            for i2 in iter_range(toPoints)
              // try to choose not the point inside target if possible
              let to = toPoints[length(toPoints) - i2 - 1]
              let fromToTargetCs = dot(normalize(to - from), normalize(to_transform[3] - to))
              if fromToTargetCs < -0.35 // ~20 degrees leeway
                continue // jumping through the target behind their back
              let velocity = calc_parabolic_jump(from, to, walker_agent__maxJumpSpeed, walker_agent__maxJumpSpeed * 0.05, 4)
              if length(velocity) < walker_agent__maxJumpSpeed && velocity != float3()
                calc_parabolic_jump_path(path, from, to, velocity, 1.0)
                if length(path) >= 2 && trace_jump_path(path, walker_agent__collisionEffectiveRadius, nphys__ccdOffset)
                  walker_agent__climbingFrom = from
                  walker_agent__climbingTo = to
                  walker_agent__jumpVelociy = velocity
                  result = EBehResult.ER_SUCCESS
                  return
    return result


[beh_node(name="nPhysPrepareJumpingBetweenNMeshIslands")]
class NPhysPrepareJumpingBetweenNMeshIslands : AbstractNPhysPrepareJumping

  def override getTargetPos(target_pos, agent_pos : float3) : array<float3>
    var out : array<float3>
    var pos = target_pos
    if project_to_nearest_navmesh_point(pos, float3(0.5, 1.0, 0.5))
      pos = get_nearest_reachable_pos(pos, agent_pos)
      out |> push(pos)
      var moreRndToPoints = 4
      let landingRadius = rnd_float(1.0, 2.5)
      while moreRndToPoints-- > 0
        let toCandidate = find_reachable_nav_point_around(pos, pos, landingRadius, /*tries*/3) <| $ [unused_argument(_)] (_ : float3)
          return true
        if toCandidate is pos
          out |> push(toCandidate as pos)
    return <- out


[beh_node(name="nPhysPrepareOffmeshJumping")]
class NPhysPrepareOffmeshJumping : AbstractNPhysPrepareJumping

  def override getTargetPos(target_pos, agent_pos : float3) : array<float3>
    return <- find_off_mesh_spot_next_to_target(target_pos, agent_pos, float2(-1.2, 0.5), float2(0.4, 1.1), 0.4, PI, 1.7, 1.3)


[beh_node(name="nPhysPrepareJumping")]
class NPhysPrepareJumping : AbstractNPhysPrepareJumping
  minMaxDistanceFromLandToTarget : float2
  numPoints : int = 4

  def override loadFromBlk(blk : DataBlock) : void
    minMaxDistanceFromLandToTarget = datablock_getPoint2(blk, "minMaxDistanceFromLandToTarget", float2(-1.0, -1.0))
    if minMaxDistanceFromLandToTarget.x < 0.0 || minMaxDistanceFromLandToTarget.y < 0.0
      error("nPhysPrepareJumping: minMaxDistanceFromLandToTarget is not set")

    numPoints = datablock_getInt(blk, "numPoints", numPoints)


  def override getTargetPos(target_pos, agent_pos : float3) : array<float3>
    var out : array<float3>

    query(beh_tree_eid(owner)) <| $ [es] (transform aka agent_transform : float3x4)
      let up = normalize(agent_transform[1])
      let forward = normalize(target_pos - agent_pos)
      let right = cross(up, forward)
      for _ in range(numPoints - 1)
        let fromTargetAngle = rnd_float(-PI, PI) / 2.0
        let fromTargetLandDist = rnd_float(minMaxDistanceFromLandToTarget.x, minMaxDistanceFromLandToTarget.y)
        var c, s : float
        sincos(fromTargetAngle, s, c)
        let fromTargetOffset = (right * c + up * s) * fromTargetLandDist
        var candidate = target_pos + fromTargetOffset
        if project_to_nearest_navmesh_point(candidate, 1.0)
          push(out, candidate)
    return <- out


[beh_node(name="isOffNavMesh")]
class IsOffNavMesh : BehNodeAdapter

  def override update(dt : float) : EBehResult
    return has(beh_tree_eid(owner), "agent_off_navmesh") ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED


[beh_node(name="performJumping")]
class PerformJumping : BehNodeAdapter

  def override init() : void
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (walker_agent__climbingFrom : float3;
                               walker_agent__climbingTo : float3;
                               walker_agent__jumpVelociy : float3;
                               var navmesh_phys__currentWalkVelocity : float3&;
                               var walker_agent__climbingStart : float&;
                               var walker_agent__climbingFinish : float&)
      navmesh_phys__currentWalkVelocity = float3()
      walker_agent__climbingStart = get_sync_time()
      let vy = walker_agent__jumpVelociy.y
      let dh = walker_agent__climbingTo.y - walker_agent__climbingFrom.y
      if is_parabolic_jump_available(vy, dh)
        walker_agent__climbingFinish = walker_agent__climbingStart + calc_parabolic_jump_duration(vy, dh)
      else
        walker_agent__climbingFinish = walker_agent__climbingStart

      remote_add_sub_template(ownerEid, "agent_in_climbing") <| $(initializer)
        initializer |> set("agent_in_climbing__removeAt", walker_agent__climbingFinish)


  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (var transform : float3x4;
                               walker_agent__climbingFrom : float3;
                               walker_agent__climbingTo : float3;
                               walker_agent__climbingStart : float;
                               walker_agent__climbingFinish : float;
                               walker_agent__jumpVelociy : float3;
                               var navmesh_phys__currentPoly : int64&;
                               var navmesh_phys__prevPos : float3&;
                               var navmesh_phys__currentPos : float3&)
      let time = get_sync_time()
      if walker_agent__climbingFinish == walker_agent__climbingStart
        result = EBehResult.ER_FAILED
      elif time < walker_agent__climbingFinish
        let deltaT = time - walker_agent__climbingStart
        transform[3] = get_parabolic_jump_pos_at(walker_agent__climbingFrom, walker_agent__jumpVelociy, deltaT)
        result = EBehResult.ER_RUNNING
      else
        result = EBehResult.ER_SUCCESS
        transform[3] = walker_agent__climbingTo
        navmesh_phys__prevPos = transform[3]
        navmesh_phys__currentPos = transform[3]
        var poly = INVALID_POLY_REF
        project_to_nearest_navmesh_point(navmesh_phys__currentPos, float3(0.15), poly)
        navmesh_phys__currentPoly = int64(poly)

      validate_gameplay_position(transform[3]) <| $()
        return <- "ownerEid={get_entity_info(ownerEid)}
transform={transform}
walker_agent__climbingTo={walker_agent__climbingTo}
navmesh_phys__prevPos={navmesh_phys__prevPos}
navmesh_phys__currentPos={navmesh_phys__currentPos}"
    return result

  def override exit()
    let ownerEid = beh_tree_eid(owner)
    remote_remove_sub_template(ownerEid, "agent_in_climbing")


[beh_node(name="performOffmeshJumping")]
class PerformOffmeshJumping : BehNodeAdapter

  def override init() : void
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (walker_agent__climbingFrom : float3;
                               walker_agent__climbingTo : float3;
                               walker_agent__jumpVelociy : float3;
                               var navmesh_phys__currentWalkVelocity : float3&;
                               var walker_agent__climbingStart : float&;
                               var walker_agent__climbingFinish : float&)
      navmesh_phys__currentWalkVelocity = float3()
      walker_agent__climbingStart = get_sync_time()
      let vy = walker_agent__jumpVelociy.y
      let dh = walker_agent__climbingTo.y - walker_agent__climbingFrom.y
      if is_parabolic_jump_available(vy, dh)
        walker_agent__climbingFinish = walker_agent__climbingStart + calc_parabolic_jump_duration(vy, dh)

        addSubTemplate(ownerEid, "agent_off_navmesh")
        addSubTemplate(ownerEid, "agent_in_climbing") <| $(initializer)
          initializer |> set("agent_in_climbing__removeAt", walker_agent__climbingFinish)
      else
        walker_agent__climbingFinish = walker_agent__climbingStart
        // Jump is unavailable - do hard bind to navmesh in current position
        nphys_teleport_to_position(ownerEid, walker_agent__climbingFrom)


  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (var transform : float3x4;
                               walker_agent__climbingFrom : float3;
                               walker_agent__climbingTo : float3;
                               walker_agent__climbingStart : float;
                               walker_agent__climbingFinish : float;
                               walker_agent__jumpVelociy : float3)
      let time = get_sync_time()
      if walker_agent__climbingFinish == walker_agent__climbingStart
        result = EBehResult.ER_FAILED
      elif time < walker_agent__climbingFinish
        let deltaT = time - walker_agent__climbingStart
        transform[3] = get_parabolic_jump_pos_at(walker_agent__climbingFrom, walker_agent__jumpVelociy, deltaT)
        result = EBehResult.ER_RUNNING
      else
        result = EBehResult.ER_SUCCESS
        transform[3] = walker_agent__climbingTo

      validate_gameplay_position(transform[3]) <| $()
        return <- "ownerEid={get_entity_info(ownerEid)}
transform={transform}
walker_agent__climbingTo={walker_agent__climbingTo}"
    return result

  def override exit()
    let ownerEid = beh_tree_eid(owner)
    removeSubTemplate(ownerEid, "agent_in_climbing")


[beh_node(name="jumpBackToNavmesh")]
class JumpBackToNavmesh : BehNodeAdapter

  def override init() : void
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (walker_agent__maxJumpSpeed : float;
                               var walker_agent__climbingTo : float3&;
                               var walker_agent__climbingFrom : float3&;
                               var walker_agent__jumpVelociy : float3&;
                               var walker_agent__climbingStart : float&;
                               var walker_agent__climbingFinish : float&)
      swap(walker_agent__climbingTo, walker_agent__climbingFrom)
      walker_agent__jumpVelociy = calc_parabolic_jump(walker_agent__climbingFrom,
                                                      walker_agent__climbingTo,
                                                      walker_agent__maxJumpSpeed,
                                                      walker_agent__maxJumpSpeed * 0.05, 4)
      walker_agent__climbingStart = get_sync_time()
      let vy = walker_agent__jumpVelociy.y
      let dh = walker_agent__climbingTo.y - walker_agent__climbingFrom.y
      if is_parabolic_jump_available(vy, dh)
        walker_agent__climbingFinish = walker_agent__climbingStart + calc_parabolic_jump_duration(vy, dh)

        addSubTemplate(ownerEid, "agent_in_climbing") <| $(initializer)
          initializer |> set("agent_in_climbing__removeAt", walker_agent__climbingFinish)
      else
        walker_agent__climbingFinish = walker_agent__climbingStart
        // Jump is unavailable - do hard bind to navmesh in current position
        nphys_teleport_to_position(ownerEid, walker_agent__climbingFrom)


  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (var transform : float3x4;
                               walker_agent__climbingFrom : float3;
                               walker_agent__climbingTo : float3;
                               walker_agent__climbingStart : float;
                               walker_agent__climbingFinish : float;
                               walker_agent__jumpVelociy : float3)
      let time = get_sync_time()
      if walker_agent__climbingFinish == walker_agent__climbingStart
        result = EBehResult.ER_FAILED
      elif time < walker_agent__climbingFinish
        let deltaT = time - walker_agent__climbingStart
        transform[3] = get_parabolic_jump_pos_at(walker_agent__climbingFrom, walker_agent__jumpVelociy, deltaT)
        result = EBehResult.ER_RUNNING
      else
        result = EBehResult.ER_SUCCESS
        transform[3] = walker_agent__climbingTo

      validate_gameplay_position(transform[3]) <| $()
        return <- "ownerEid={get_entity_info(ownerEid)}
transform={transform}
walker_agent__climbingTo={walker_agent__climbingTo}"
    return result

  def override exit()
    let ownerEid = beh_tree_eid(owner)
    removeSubTemplate(ownerEid, "agent_in_climbing")
    removeSubTemplate(ownerEid, "agent_off_navmesh")


[beh_node(name="performNavmeshShortcutJump")]
class PerformNavmeshShortcutJump : BehNodeAdapter

  def override init() : void
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (walker_agent__climbingFrom : float3;
                               walker_agent__climbingTo : float3;
                               walker_agent__jumpVelociy : float3;
                               var navmesh_phys__currentWalkVelocity : float3&;
                               var walker_agent__climbingStart : float&;
                               var walker_agent__climbingFinish : float&)
      navmesh_phys__currentWalkVelocity = float3()
      walker_agent__climbingStart = get_sync_time()
      let vy = walker_agent__jumpVelociy.y
      let dh = walker_agent__climbingTo.y - walker_agent__climbingFrom.y
      if is_parabolic_jump_available(vy, dh)
        walker_agent__climbingFinish = walker_agent__climbingStart + calc_parabolic_jump_duration(vy, dh)

        addSubTemplate(ownerEid, "agent_off_navmesh")
        addSubTemplate(ownerEid, "agent_in_climbing") <| $(initializer)
          initializer |> set("agent_in_climbing__removeAt", walker_agent__climbingFinish)
      else
        walker_agent__climbingFinish = walker_agent__climbingStart
        // Jump is unavailable - do hard bind to navmesh in current position
        nphys_teleport_to_position(ownerEid, walker_agent__climbingFrom)

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (var transform : float3x4;
                               navmesh_phys__upDir : float3;
                               walker_agent__climbingFrom : float3;
                               walker_agent__climbingTo : float3;
                               walker_agent__climbingStart : float;
                               walker_agent__climbingFinish : float;
                               nphys_levitating__elevation : float = 0.0;
                               walker_agent__jumpVelociy : float3;
                               var path_corridor__forceUpdateThisFrame : bool?;
                               var path_corridor__corners : Point3List)
      let time = get_sync_time()
      if walker_agent__climbingFinish == walker_agent__climbingStart
        result = EBehResult.ER_FAILED
      elif time < walker_agent__climbingFinish
        let deltaT = time - walker_agent__climbingStart
        let from = walker_agent__climbingFrom + navmesh_phys__upDir * nphys_levitating__elevation
        transform[3] = get_parabolic_jump_pos_at(from, walker_agent__jumpVelociy, deltaT)
        result = EBehResult.ER_RUNNING
      else
        result = EBehResult.ER_SUCCESS
        transform[3] = walker_agent__climbingTo + navmesh_phys__upDir * nphys_levitating__elevation
        nphys_teleport_to_position(ownerEid, walker_agent__climbingTo)
        clear(path_corridor__corners)
        if path_corridor__forceUpdateThisFrame != null
          *path_corridor__forceUpdateThisFrame = true

      validate_gameplay_position(transform[3]) <| $()
        return <- "ownerEid={get_entity_info(ownerEid)}
transform={transform}
walker_agent__climbingTo={walker_agent__climbingTo}"
    return result

  def override exit()
    let ownerEid = beh_tree_eid(owner)
    removeSubTemplate(ownerEid, "agent_in_climbing")
    removeSubTemplate(ownerEid, "agent_off_navmesh")


[beh_node(name="prepareNmeshShortcutJump")]
class PrepareNmeshShortcutJump : BehNodeAdapter
  aheadOfTime : float

  def override loadFromBlk(var data : DataBlock)
    aheadOfTime = data |> datablock_getReal("aheadOfTime", aheadOfTime)

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (nphys_levitating__elevation : float;
                               navmesh_phys__maxWalkSpeed : float;
                               navmesh_phys__currentPos : float3;
                               navmesh_phys__upDir : float3;
                               nmesh_shortcut_jump__maxDst : float;
                               walker_agent__maxJumpSpeed = 20.0;
                               nmesh_shortcut_jump__stopDst = 0.0;
                               walker_agent__collisionEffectiveRadius = 0.5;
                               nphys__ccdOffset : float3;
                               path_corridor__targetPos : float3;
                               var walker_agent__climbingFrom : float3&;
                               var walker_agent__climbingTo : float3&;
                               var walker_agent__jumpVelociy : float3&;
                               var path_corridor : dtPathCorridor;
                               var path_corridor__corners : Point3List)
      find_corridor_corners(path_corridor, 15) <| $(corners)
        if length(corners) > 0
          clear(path_corridor__corners)
          for c in corners
            path_corridor__corners |> push(c)
          let advanceDst = navmesh_phys__maxWalkSpeed * aheadOfTime
          let fromPos = find_point_on_path_at(navmesh_phys__currentPos, path_corridor__corners, advanceDst)
          if fromPos is invalid
            return
          let (from, to) = find_furthest_span_on_path(fromPos as pos,
                                                      path_corridor__targetPos,
                                                      path_corridor__corners,
                                                      nmesh_shortcut_jump__maxDst,
                                                      nmesh_shortcut_jump__stopDst)
          if to != float3() //Success
            let spanVec = to - from
            let spanLen = length(spanVec)
            let tries = min(3, int(spanLen / 2.0) + 1)
            var possiblePoint <- gen_puasson_points(from, spanVec * safeinv(spanLen), spanLen, tries)
            let nmeshPoints <- project_points(possiblePoint)
            let jumpNmeshFrom = fromPos as pos
            for p in nmeshPoints
              let velocity = calc_parabolic_jump(jumpNmeshFrom,
                                                  p,
                                                  walker_agent__maxJumpSpeed,
                                                  walker_agent__maxJumpSpeed * 0.05,
                                                  4)
              if length(velocity) < walker_agent__maxJumpSpeed && velocity != float3()
                var path : array<float3>
                calc_parabolic_jump_path(path, jumpNmeshFrom, p, velocity, 1.0)
                if length(path) >= 2
                  //var prev = path[0]
                  //for ppp in path
                  //  draw_debug_line_buffered(prev, ppp, ACBLUE, 500)
                  //  prev = ppp

                  let traceOffset = nphys__ccdOffset + navmesh_phys__upDir * nphys_levitating__elevation
                  let traceSuccess = trace_jump_path(path, walker_agent__collisionEffectiveRadius, traceOffset)
                  if traceSuccess
                    walker_agent__climbingFrom = jumpNmeshFrom
                    walker_agent__climbingTo = p
                    walker_agent__jumpVelociy = velocity
                    result = EBehResult.ER_SUCCESS
                    clear(path_corridor__corners)
                    return
                  elif abs(walker_agent__maxJumpSpeed - velocity.y) > 0.33 * walker_agent__maxJumpSpeed
                    //Try to find a higher jump to the same spot
                    let newMinVertVelocity = (walker_agent__maxJumpSpeed + 4.0 * velocity.y) * 0.2
                    let velocity2 = calc_parabolic_jump(jumpNmeshFrom,
                                                        p,
                                                        walker_agent__maxJumpSpeed,
                                                        newMinVertVelocity,
                                                        4)
                    //print("akiska min velocity: {pty(newMinVertVelocity)} (prev = {pty(velocity.y)}")
                    if length(velocity2) < walker_agent__maxJumpSpeed && velocity2 != float3()
                      clear(path)
                      calc_parabolic_jump_path(path, jumpNmeshFrom, p, velocity2, 0.5)
                      if length(path) >= 2
                        //prev = path[0]
                        //for ppp in path
                        //  draw_debug_line_buffered(prev, ppp, ACEMERALD, 500)
                        //  prev = ppp
                        let traceSuccess2 = trace_jump_path(path, walker_agent__collisionEffectiveRadius, traceOffset)
                        if traceSuccess2
                          walker_agent__climbingFrom = jumpNmeshFrom
                          walker_agent__climbingTo = p
                          walker_agent__jumpVelociy = velocity2
                          result = EBehResult.ER_SUCCESS
                          clear(path_corridor__corners)
                          return
    return result


def project_points(var points : array <float3>)
  var res : array<float3>
  for p in points
    if project_to_nearest_navmesh_point(p, float3(1.0, 10.0, 1.0))
      res |> push(p)
  return <- res


def gen_puasson_points(from, dir : float3; span_len : float; count : int)
  var res : array<float3>
  res |> push(from + dir * span_len)
  var left = count - 1
  while left-- > 0
    var bestPoint : float3
    var bestDstSq = .0
    var samples = 3
    while samples-- > 0
      let newPoint = from + dir * span_len * gfrnd()
      var dstSq = FLT_MAX
      for p in res
        dstSq = min(dstSq, distance_sq(newPoint, p))
      if dstSq > bestDstSq
        bestDstSq = dstSq
        bestPoint = newPoint
    res |> push(bestPoint)
  return <- res


//Tries not to jump closer than 0.5 max_dst, but may still do it sometimes
def find_furthest_span_on_path(pos, target : float3; corners : Point3List; max_dst, stop_dst : float)
  let maxDstSq = square(max_dst)
  let stopDstSq = square(stop_dst)
  var i = length(corners)
  var hasFoundSpanInRange = false
  while i-- > 0
    //Find the furthest corner within the distance
    if distance_sq(corners[i], pos) < maxDstSq
      hasFoundSpanInRange = true
      var p1Candidate : float3
      var p2Candidate : float3
      var spanIsValid = false

      if i < length(corners) - 1 //there is another corner which is outside the distance
        p1Candidate = corners[i]
        p2Candidate = calculate_segment_sphere_intersection(corners[i], corners[i + 1], pos, maxDstSq)
        spanIsValid = true
      else //We need to look at the previous points
        if i > 0 && distance_sq(corners[i - 1], pos) < maxDstSq //Both are within the distance
          p1Candidate = corners[i - 1]
          p2Candidate = corners[i]
          spanIsValid = true
        elif i == 0 //There is exactly 1 corner
          if distance_sq(corners[i], pos) > maxDstSq * 0.25 //the first corner is far enough away
            p1Candidate = normalize(corners[i] - pos) * max_dst * 0.5
            p2Candidate = corners[i]
            spanIsValid = true
          else //the first corner is too close, and it is the only corner, FAIL
            spanIsValid = false
        else //The previous corner is outside
          p1Candidate = calculate_segment_sphere_intersection(corners[i], corners[i - 1], pos, maxDstSq)
          p2Candidate = corners[i]
          spanIsValid = true

      if spanIsValid
        if distance_sq(p1Candidate, target) > stopDstSq && distance_sq(p2Candidate, target) > stopDstSq
          return (p1Candidate, p2Candidate)

  if !hasFoundSpanInRange && length(corners) > 0
    let p1Candidate = normalize(corners[0] - pos) * max_dst * 0.5
    let p2Candidate = normalize(corners[0] - pos) * max_dst
    if distance_sq(p1Candidate, target) > stopDstSq
      let p2DstSq = distance_sq(p2Candidate, target)
      if p2DstSq < stopDstSq
        let newP2 = target - normalize(target - p1Candidate) * stop_dst
        if distance_sq(newP2, pos) < distance_sq(p1Candidate, pos)
          return (float3(), float3())
        return (p1Candidate, newP2)
      return (p1Candidate, p2Candidate)

  return (float3(), float3())


//Assumes there is exactly one intersection and on of the points is within teh sphere
def calculate_segment_sphere_intersection(p1, p2, sphere_center : float3; sphere_radius_sq : float) : float3
  if distance_sq(p1, p2) < 0.0001
    return p2 //We don't care for such small discrepancy
  let vec = p2 - p1
  let toClosest = p1 - sphere_center

  let a = dot(vec, vec)
  let b = 2.0 * dot(toClosest, vec)
  let c = dot(toClosest, toClosest) - sphere_radius_sq
  let discriminant = b * b - 4.0 * a * c
  if discriminant < 0.0
    return p2 // This should never happen
  let t = (-b + sqrt(discriminant)) / (2.0 * a) //Positive root, we are certain there is exactly one intersection
  return p1 + t * vec// (0 < t < 1)


[beh_node(name="stopCrawl")]
class StopCrawl : BehNodeAdapter

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (surface_crawler__template : string;
                               surface_crawler__lookAhead : float2;
                               surface_crawler__lookDown : float3;
                               navmesh_phys__upDir : float3;
                               nphys_levitating__elevation : float = .0;
                               var path_corridor__forceUpdateThisFrame : bool&;
                               var transform : float3x4)
      var pos = transform[3]
      let extents = float3(surface_crawler__lookAhead.x, surface_crawler__lookDown.z, surface_crawler__lookAhead.x)
      if project_to_nearest_navmesh_point(pos, extents)
        removeSubTemplate(ownerEid, surface_crawler__template)
        nphys_teleport_to_position(ownerEid, pos)
        transform[3] = pos + navmesh_phys__upDir * nphys_levitating__elevation
        path_corridor__forceUpdateThisFrame = true
        result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="crawlOverSurface")]
class CrawlOverSurface : BehNodeAdapter

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (var transform : float3x4;
                               surface_crawler__lookDown : float3;
                               surface_crawler__lookAhead : float2 = float2(0.15, 0.4);
                               surface_crawler__curvePerSecond : float = 4.0;
                               surface_crawler__curvePerSecondRnd : float = 1.0;
                               surface_crawler__rndInfluence : float = 10.0;
                               surface_crawler__maxFrustration : int = 10;
                               surface_crawler__speed : float;
                               var surface_crawler__matId : int&;
                               var surface_crawler__frustration : int&;
                               var surface_crawler__seed : int&;
                               var surface_crawler__head : float3&;
                               var surface_crawler__dir : float3&;
                               var surface_crawler__norm : float3&;
                               var surface_crawler__active : bool&)
      let clampedDt = clamp(dt, .0, 0.2)
      surface_crawler_update(clampedDt,
                              surface_crawler__lookAhead,
                              surface_crawler__lookDown,
                              surface_crawler__curvePerSecond,
                              surface_crawler__curvePerSecondRnd,
                              surface_crawler__rndInfluence,
                              surface_crawler__speed,
                              surface_crawler__maxFrustration,
                              surface_crawler__frustration,
                              surface_crawler__seed,
                              surface_crawler__head,
                              surface_crawler__dir,
                              surface_crawler__norm,
                              surface_crawler__matId,
                              surface_crawler__active) <| $ [unused_argument(riDesc)] (riDesc : RendInstDesc){}
      transform[3] = surface_crawler__head
      transform[0] = surface_crawler__dir
      transform[1] = surface_crawler__norm
      transform[2] = cross(surface_crawler__norm, surface_crawler__dir)
      orthonormalize(transform)
      result = EBehResult.ER_RUNNING
    return result