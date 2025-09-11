module nphys_nodes_common

require app // get_sync_time
require ecs
require DagorSystem
require BehNodes
require DagorDataBlock
require DagorRandom
require ecs.common
require pathfinder
require math.base
require math.ang
require math.linear
require DagorMath
require DagorMathUtils
require AnimV20
require debug.logerr_once
require strings
require Grid
require GridCollision
require walkerai
require DngWalkerai
require RendInst
require CollRes
require DngBehTree // required for ECS_DECLARE_BOXED_TYPE(dtPathCorridor);
require DagorDebug3D
require danetlibs.navmesh_phys.main.nphys_common
require danetlibs.navmesh_phys.main.nphys_find_obstacles_common
require danetlibs.navmesh_phys.main.nphys_jumplink_climb_common
require pathfinder
require DngHuman



let
  VECTOR_COMPARISON_ERROR = square(0.01)


def nmesh_move_over_jump_link_in_corridor(pos : float3;
                                          ctx : FindCornersResult#;
                                          var corners : Point3List&;
                                          var jumpEndPos : float3&;
                                          var corridor : dtPathCorridor&;
                                          var shouldJump : bool&;
                                          var overJumpLinkStart : bool&;
                                          var prevDstToEndSq : float&;
                                          navmesh_phys__climbJumpMaxDistSq : float)
  let cornersNum = min(length(corners), min(length(ctx.cornerFlags), length(ctx.cornerPolys)))
  if cornersNum < 2
    shouldJump = false
    overJumpLinkStart = false
    return
  var polyFlags = uint16(0)
  shouldJump = false
  for i in range(cornersNum - 1)
    if (length_sq(pos - corners[i + 1]) > navmesh_phys__climbJumpMaxDistSq && (i != 0 || i == 0 && !overJumpLinkStart && length_sq((corners[0] - pos).xz) > 0.25))
      break
    if ((int(ctx.cornerFlags[i]) & int(StraightPathFlags.DT_STRAIGHTPATH_OFFMESH_CONNECTION)) != 0
        && get_poly_flags(ctx.cornerPolys[i], polyFlags) && (int(polyFlags) & int(PolyFlag.POLYFLAG_JUMP)) != 0)
      shouldJump = true
      jumpEndPos = corners[i + 1]
      if i == 0 // is over jump link -> handle detour jump link related stuff
        overJumpLinkStart = true
        var startPoint, endPoint : float3
        startPoint = corners[0]
        endPoint = corners[1]

        let dstToEndSq = distance_sq(endPoint, pos)
        if dstToEndSq > prevDstToEndSq
          var endRefPolyFlags = uint16(0)
          get_poly_flags(ctx.cornerPolys[1], endRefPolyFlags)
          if (int(endRefPolyFlags) & int(PolyFlag.POLYFLAG_JUMP)) != 0
            // curRef is outside from any poly/jump, move forcibly to next path edge
            var nextEndPoint : float3
            if 2 < cornersNum
              nextEndPoint = corners[2]
              corners |> clear()
              corners |> push(nextEndPoint)
              jumpEndPos = nextEndPoint
            else
              shouldJump = false
              overJumpLinkStart = false
          else
            corners |> clear()
            shouldJump = false
            overJumpLinkStart = false
          var start_ref, end_ref : dtPolyRef
          let startPoly = ctx.cornerPolys[0]
          corridor_moveOverOffmeshConnection(corridor, startPoly, start_ref, end_ref, startPoint, endPoint)
        else
          prevDstToEndSq = dstToEndSq
          corners |> clear()
          corners |> push(endPoint)
          let dir = normalize((endPoint - startPoint).xz)
          let dist = (startPoint - pos).xz
          if dir.x * dist.x + dir.y * dist.y > 0.5 // we haven't reached start yet
            corners |> clear()
            corners |> push(startPoint)
            corners |> push(endPoint)
            overJumpLinkStart = false
            prevDstToEndSq = distance(pos, startPoint) + distance(startPoint, endPoint)
          if ctx.cornerPolys[0] == ctx.cornerPolys[1] // we're over final polygon - prune
            var start_ref, end_ref : dtPolyRef
            let startPoly = ctx.cornerPolys[0]
            corridor_moveOverOffmeshConnection(corridor, startPoly, start_ref, end_ref, startPoint, endPoint)
    break


def advance_path_corridor_ai(eid : EntityId; at_time : float; var path_corridor : dtPathCorridor; cur_pos, target_pos : float3;
                             cur_poly : dtPolyRef;
                             path_corridor_ai__corridorUpdateStep : float;
                             navmesh_phys__climbJumpMaxUpHeight : float;
                             nphys_pushable__unlockMovementAt : float;
                             var path_corridor_ai__corridorResult : int&;
                             var path_corridor_ai__nextCorridorUpdate : float&;
                             var path_corridor__corners : Point3List&;
                             var isPartial : bool&;
                             var path_corridor__isClimbing : bool?;
                             var path_corridor__overJumpLink : bool?;
                             var path_corridor__overJumpLinkStart : bool?;
                             var path_corridor__jumpLinkStart : float3?;
                             var path_corridor__jumpLinkEnd : float3?;
                             var path_corridor__prevDstToJLEndSq : float?;
                             var path_corridor__forceUpdateThisFrame : bool?;
                             navmesh_phys__climbJumpMaxDistSq : float;
                             navigation__areasCost : Point2List const?) : bool
  var retries = 2
  var res = false
  while !res && retries > 0
    retries -= 1
    let curTarget = path_corridor |> corridor_getTarget()
    let forceUpdate = path_corridor__forceUpdateThisFrame ?? false
    let reCorridor = at_time >= path_corridor_ai__nextCorridorUpdate || is_nan(curTarget) || distance_sq(curTarget, target_pos) > 0.25f || forceUpdate
    if reCorridor && !(path_corridor__isClimbing ?? false) && nphys_pushable__unlockMovementAt <= at_time || forceUpdate // do not update corridor while agent is in air
      if path_corridor__forceUpdateThisFrame != null
        *path_corridor__forceUpdateThisFrame = false
      let extents = float3(.5, FLT_MAX, .5)
      using(cur_pos, target_pos, extents) <| $(var inp : CorridorInput#)
        inp.startPoly = cur_poly
        if path_corridor__overJumpLink != null
          inp.includeFlags |= int(PolyFlag.POLYFLAG_JUMP)
        inp.maxJumpUpHeight = navmesh_phys__climbJumpMaxUpHeight
        if navigation__areasCost != null
          for it in *navigation__areasCost
            inp |> add_area_cost(uint8(it.x), it.y)
        path_corridor_ai__corridorResult = path_corridor |> set_path_corridor(inp, null) |> int()

      path_corridor_ai__nextCorridorUpdate = FLT_MAX
      if path_corridor_ai__corridorResult == int(FindPathResult.FPR_PARTIAL)
        isPartial = true
        path_corridor_ai__nextCorridorUpdate = at_time + path_corridor_ai__corridorUpdateStep

    if path_corridor_ai__corridorResult == int(FindPathResult.FPR_FAILED)
      return false

    let corridorPos = cur_pos
    if !(path_corridor__isClimbing ?? false)
      // disable corridor update while agent is in the air
      // overwise corridor update cuts last offmesh link and drop agent on ground
      path_corridor |> set_corridor_agent_position(cur_pos, null)

    if path_corridor_ai__corridorResult == int(FindPathResult.FPR_PARTIAL)
      isPartial = true

    find_corridor_corners(path_corridor, 5) <| $(corners; corners_res)
      let cornersNum = length(corners)
      if cornersNum == 0
        if reCorridor || path_corridor_ai__corridorResult != int(FindPathResult.FPR_PARTIAL)
          retries = 0
          res = path_corridor_ai__corridorResult == int(FindPathResult.FPR_FULL)
        return
      if (cornersNum == 1 && path_corridor_ai__corridorResult == int(FindPathResult.FPR_PARTIAL) &&
          (distance_sq(cur_pos, corners[0]) < 0.25f || distance_sq(target_pos, corners[0]) < 0.01f))
       // the result is partial. we must fail it at some point.
       // but sometimes even if the result is partial, the final corner is at target_pos. We won't be able to reach it, must fail
        path_corridor_ai__corridorResult = int(FindPathResult.FPR_FAILED)
        retries = 0
        return

      for it in corners
        path_corridor__corners |> push(it)
      if path_corridor__overJumpLink != null && path_corridor__overJumpLinkStart != null && path_corridor__prevDstToJLEndSq != null && nphys_pushable__unlockMovementAt <= at_time

        var jumpEndPos : float3
        nmesh_move_over_jump_link_in_corridor(corridorPos, corners_res, path_corridor__corners,
                                              jumpEndPos, path_corridor,
                                              *path_corridor__overJumpLink,
                                              *path_corridor__overJumpLinkStart,
                                              *path_corridor__prevDstToJLEndSq,
                                              navmesh_phys__climbJumpMaxDistSq)

        var resetClimbing = false
        if *path_corridor__overJumpLink
          let pathLen = length(path_corridor__corners)
          if path_corridor__jumpLinkEnd != null && *path_corridor__jumpLinkEnd != jumpEndPos
            resetClimbing = true
            if path_corridor__jumpLinkStart != null
              *path_corridor__jumpLinkStart = corridorPos
          if path_corridor__jumpLinkEnd != null
            if pathLen >= 1
              *path_corridor__jumpLinkEnd = jumpEndPos
            else
              logerr("{eid} path on jump link at {corridorPos} is too small `{path_corridor__corners}`")

          send_path_corridor_jump_link_start_end_changed_event(eid, *path_corridor__jumpLinkStart, *path_corridor__jumpLinkEnd)
        else
          resetClimbing = true
        if path_corridor__isClimbing != null && resetClimbing
          *path_corridor__isClimbing = false

      res = length(path_corridor__corners) > 0
  return res


def steer_obstacles(eid : EntityId; cur_pos, cur_dir : float3; agent_size : float)
  let box = BBox3(cur_pos, agent_size * 10f)
  var obstacleRes = float3(0f, 0f, 0f)
  for_each_entity_in_grid(fixed_array(ecs_hash("humans"), ecs_hash("vehicles")), box, GridEntCheck.BOUNDING) <| $(obstacleEid : EntityId; obstaclePos : float3)
    if obstacleEid != eid && !has(obstacleEid, "deadEntity")
      let dirToObstacle = obstaclePos - cur_pos
      if dot(dirToObstacle, cur_dir) > 0f
        let side = -(dirToObstacle - cur_dir * dot(cur_dir, dirToObstacle))
        let sideDistSq = length_sq(side)
        let minDist = agent_size
        if sideDistSq < minDist * minDist
          let sideDist = sqrt(sideDistSq)
          let avoidVec = side * safediv(minDist - sideDist, sideDist)
          obstacleRes += avoidVec
        let collideDist = 2f * agent_size
        let collidePower = cvt(length_sq(dirToObstacle), collideDist * collideDist, 0f, 0f, 0.6f)
        obstacleRes += -normalize(dirToObstacle) * collidePower
  return obstacleRes

def steer_sine(eid : EntityId; cur_dir : float3; time : float)
  let freq1 = eid_frnd(eid) * 2f + 3f
  let freq2 = eid_frnd(eid) * 2f + 5f
  let left = float3(-cur_dir.z, cur_dir.y, cur_dir.x)
  return left * sin(time * freq1) * sin(time * freq2) * 0.5

def steer_agent(eid : EntityId;
                cur_pos : float3;
                corner : float3;
                cur_time : float;
                agent_size : float;
                sine_factor : float)
  let cornerDir = normalize(corner - cur_pos)
  let obstacleSteering = steer_obstacles(eid, cur_pos, cornerDir, agent_size)
  let sineSteering = steer_sine(eid, cornerDir, cur_time) * sine_factor
  return normalize(cornerDir + obstacleSteering + sineSteering)


def steer_agent_with_velocity(eid : EntityId;
                              dt : float;
                              cur_pos : float3;
                              corner : float3;
                              agent_size : float;
                              rotationSpeeds : float4;
                              var wishDir : float3&)
  let cornerDir = normalize(corner - cur_pos)
  let obstacleSteering = steer_obstacles(eid, cur_pos, cornerDir, agent_size)
  let speed = cvt(length(corner - cur_pos), rotationSpeeds.x, rotationSpeeds.y, rotationSpeeds.z, rotationSpeeds.w)
  wishDir = move_to(wishDir, normalize(cornerDir + obstacleSteering), dt, speed)


def approach_look_dir(current_dir : float3; target_dir : float3; dt : float; approach_spd : float; approach_viscosity : float) : float3
  let currentAngles = dir_to_angles(current_dir)
  let targetAngles = renorm_ang(dir_to_angles(target_dir), currentAngles)

  var outVelocity = float2()
  let resultAngles = approach_vel(currentAngles, targetAngles, dt, approach_viscosity, outVelocity, 0f, approach_spd)
  return angles_to_dir(resultAngles)


def approach_look_dir_in_gravity(current_dir, target_dir, up_dir : float3; dt, approach_spd, approach_viscosity : float) : float3
  let currentAngles = basis_aware_dir_to_angles(current_dir, up_dir, target_dir)
  let targetAngles = float2() //because target_dir is used as basis it's 0. assuming target_dir is perp to up_dir, vert angle should be 0 too
  var outVelocity = float2()
  let resultAngles = approach_vel(currentAngles, targetAngles, dt, approach_viscosity, outVelocity, 0f, approach_spd)
  return basis_aware_angles_to_dir(resultAngles, up_dir, target_dir)



class AbstractNPhysCorridorMoveTo : BehNodeAdapter
  forceToWalk : bool = false
  @hidden curTime : float = 0f
  stopDist : float = 1f
  vertExtent : float = 1f
  slowDownCoeff : float = 0f
  lookInMoveDir : bool = true
  debug_lastPathLen : float = 0f

  def override init()
    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4;
                                          var stuck_detector__avgPos : float3&;
                                          var stuck_detector__value : float&)
      stuck_detector__avgPos = transform[3]
      stuck_detector__value = 0.0

  def override loadFromBlk(var data : DataBlock)
    forceToWalk = data |> datablock_getBool("forceToWalk", forceToWalk)
    stopDist = data |> datablock_getReal("stopDist", stopDist)
    vertExtent = data |> datablock_getReal("vertExtent", max(vertExtent, stopDist))
    slowDownCoeff = data |> datablock_getReal("slowDownCoeff", slowDownCoeff)
    lookInMoveDir = data |> datablock_getBool("lookInMoveDir", lookInMoveDir)

    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(path_corridor, navmesh_phys__wishWalkSpeed, path_corridor_ai__corridorUpdateStep, path_corridor_ai__corridorResult, path_corridor_ai__validCorridorTargetPos, path_corridor_ai__nextCorridorUpdate, navmesh_phys__wishWalkDir, navmesh_phys__wishLookDir))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> NPhysCorridorMoveToPos requires path_corridor, navmesh_phys__wishWalkSpeed, path_corridor_ai__corridorUpdateStep, path_corridor_ai__corridorResult, path_corridor_ai__validCorridorTargetPos, path_corridor_ai__nextCorridorUpdate, navmesh_phys__wishWalkDir, navmesh_phys__wishLookDir fields")

  def abstract getTargetPos(eid : EntityId; var res : float3&; var lost_target : bool&) : bool

  def abstract getCurrentPos(eid : EntityId; var res : float3&) : bool

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let eid = beh_tree_eid(owner)
    query(eid) <| $ [es] (path_corridor_ai__corridorUpdateStep : float;
                          var navmesh_phys__currentPoly : int64&;
                          navmesh_phys__steeringAgentSize : float = 0.2f;
                          navmesh_phys__steeringAgentSineFactor : float = 1.0;
                          nphys_pushable__unlockMovementAt : float = 0.0;
                          path_corridor__failsMax : int;
                          var path_corridor__isClimbing : bool?;
                          navmesh_phys__climbJumpMaxUpHeight : float = FLT_MAX;
                          var path_corridor__overJumpLink : bool?;
                          var path_corridor__overJumpLinkStart : bool?;
                          var path_corridor__jumpLinkStart : float3?;
                          var path_corridor__jumpLinkEnd : float3?;
                          var path_corridor__prevDstToJLEndSq : float?;
                          var path_corridor : dtPathCorridor;
                          var path_corridor__corners : Point3List&;
                          var navmesh_phys__wishWalkSpeed : float&;
                          var path_corridor_ai__corridorResult : int&;
                          var path_corridor_ai__nextCorridorUpdate : float&;
                          var navmesh_phys__wishWalkDir : float3&;
                          var navmesh_phys__wishLookDir : float3&;
                          var path_corridor__failsCount : int&;
                          var path_corridor_ai__validCorridorTargetPos : float3&;
                          var path_corridor__forceUpdateThisFrame : bool?;
                          var path_corridor__targetPos : float3?;
                          navmesh_phys__upDir : float3 = float3(0, 1, 0);
                          navigation__areasCost : Point2List const?;
                          navmesh_phys__climbJumpMaxDistSq : float = 1.0;
                          path_corridor_ai__slowDownCoef : float = 0.2;
                          navmesh_phys__rotationSpeed : float4 const?;
                          navmesh_phys__wishLookApproachViscosity = 0.1;
                          navmesh_phys__wishLookApproachSpd = 1f;
                          navmesh_phys__navLookAhead = 0.75f;
                          navmesh_phys__walkSpeedModifier = 0.5)
      path_corridor__corners |> clear()
      navmesh_phys__wishWalkSpeed = 0f
      var currentPos : float3
      var targetPos : float3
      var lostTarget : bool
      if !self->getTargetPos(eid, targetPos, lostTarget)
        return
      if !self->getCurrentPos(eid, currentPos)
        return
      if path_corridor__targetPos != null
        *path_corridor__targetPos = targetPos
      let targetDistSqThreshold = 0.04 // 0.2 m
      if distance_sq(path_corridor_ai__validCorridorTargetPos, targetPos) <= targetDistSqThreshold
        targetPos = path_corridor_ai__validCorridorTargetPos
      elif project_to_nearest_navmesh_point(targetPos, float3(stopDist, vertExtent, stopDist))
        path_corridor_ai__validCorridorTargetPos = targetPos
      else // invalid target pos
        // TODO: try to find new target pos
        // if !lostTarget
        //   logerr("{eid}: invalid target pos {targetPos}")
        return

      curTime += dt

      var isPartial = false
      if advance_path_corridor_ai(eid, get_sync_time(), path_corridor, currentPos, targetPos, dtPolyRef(navmesh_phys__currentPoly),
          path_corridor_ai__corridorUpdateStep, navmesh_phys__climbJumpMaxUpHeight, nphys_pushable__unlockMovementAt, path_corridor_ai__corridorResult,
          path_corridor_ai__nextCorridorUpdate, path_corridor__corners, isPartial, path_corridor__isClimbing,
          path_corridor__overJumpLink, path_corridor__overJumpLinkStart, path_corridor__jumpLinkStart, path_corridor__jumpLinkEnd,
          path_corridor__prevDstToJLEndSq,
          path_corridor__forceUpdateThisFrame, navmesh_phys__climbJumpMaxDistSq, navigation__areasCost)

        let dirToTarget = targetPos - currentPos
        let dirToTargetLen = length(dirToTarget)

        if length(path_corridor__corners) == 0
          res = dirToTargetLen > stopDist || isPartial || lostTarget ? EBehResult.ER_FAILED : EBehResult.ER_SUCCESS
          return

        var targetCorner = path_corridor__corners[0]

        if navmesh_phys__rotationSpeed != null
          steer_agent_with_velocity(eid, dt, currentPos, targetCorner, navmesh_phys__steeringAgentSize, *navmesh_phys__rotationSpeed, navmesh_phys__wishWalkDir)
        else
          let steeringMult = cvt(dirToTargetLen, 0., stopDist * 2.0 + 0.1, 0.2, 1.0)
          navmesh_phys__wishWalkDir = steer_agent(eid, currentPos, targetCorner, curTime, navmesh_phys__steeringAgentSize,
                                                  navmesh_phys__steeringAgentSineFactor * steeringMult)

        var lookDir = navmesh_phys__wishWalkDir
        var prevPos = currentPos
        var lookOffs = navmesh_phys__navLookAhead
        var pathLen = 0f
        for corner in path_corridor__corners
          let legDir = corner - prevPos
          let legDist = length(legDir)
          pathLen += legDist
          if lookOffs >= 0f && lookOffs < legDist
            lookDir = normalize(prevPos + legDir * safediv(lookOffs, legDist) - currentPos)
          lookOffs -= legDist
          prevPos = corner
        debug_lastPathLen = pathLen

        let overJumpLink = path_corridor__overJumpLink ?? false
        if overJumpLink
          navmesh_phys__currentPoly = int64(INVALID_POLY_REF)
          if path_corridor__jumpLinkEnd != null
            targetCorner = *path_corridor__jumpLinkEnd
        elif pathLen < stopDist && !isPartial
          if !lostTarget
            res = EBehResult.ER_SUCCESS
          return

        let slowDownC = slowDownCoeff > .0 ? slowDownCoeff : path_corridor_ai__slowDownCoef
        if lookInMoveDir
          let targetLookDir = normalize(lookDir - navmesh_phys__upDir * dot(lookDir, navmesh_phys__upDir))
          navmesh_phys__wishLookDir = approach_look_dir_in_gravity(navmesh_phys__wishLookDir, targetLookDir, navmesh_phys__upDir, dt,
            navmesh_phys__wishLookApproachSpd, navmesh_phys__wishLookApproachViscosity)
        navmesh_phys__wishWalkSpeed = (forceToWalk ? navmesh_phys__walkSpeedModifier : 1f) * saturate(dirToTargetLen * slowDownC)
        res = EBehResult.ER_RUNNING

      if path_corridor_ai__corridorResult == int(FindPathResult.FPR_FAILED)
        path_corridor__failsCount++
        if path_corridor__failsCount == path_corridor__failsMax
          logwarn("{eid}: {getEntityTemplateName(eid)} unable to find corridor path from {currentPos} to {targetPos}")
      elif path_corridor_ai__corridorResult == int(FindPathResult.FPR_FULL)
        if path_corridor__failsCount < path_corridor__failsMax //don't reset if this unit has reported an error
          path_corridor__failsCount = 0
    return res

  def override exit()
    query(beh_tree_eid(owner)) <| $ [es] (var navmesh_phys__wishWalkSpeed : float&; var path_corridor_ai__validCorridorTargetPos : float3&)
      navmesh_phys__wishWalkSpeed = 0f
      path_corridor_ai__validCorridorTargetPos = float3(-10e4)

  [unused_argument(children)] def override drawDebug(children : bool) : void
    query(beh_tree_eid(owner)) <| $ [es] (path_corridor : dtPathCorridor)
      begin_draw_cached_debug_lines(true, true, false)
      draw_corridor_path(path_corridor)
      end_draw_cached_debug_lines()


class NPhysCorridorMoveToPosBase : AbstractNPhysCorridorMoveTo
  posParam : string
  @hidden posParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    AbstractNPhysCorridorMoveTo`loadFromBlk(self, data)
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)

  [unused_argument(lost_target)] def override getTargetPos(agent_eid : EntityId; var res : float3 &; var lost_target : bool &) : bool
    let targetPosRef = agent_eid |> get_Point3(posParam, posParamHash)
    if targetPosRef == null
      logerr_once("{agent_eid}: nPhysCorridorMoveToPos unable to find target position '{posParam}:{posParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return false
    res = *targetPosRef
    return true

  def override getCurrentPos(agent_eid : EntityId; var res : float3&) : bool
    let hasComponent = query(agent_eid) <| $ [es] (navmesh_phys__currentPos : float3)
      res = navmesh_phys__currentPos
    return hasComponent


class NPhysCorridorMoveToTargetBase : AbstractNPhysCorridorMoveTo
  targetParam : string
  @hidden targetParamHash : uint
  lastTargetPos : float3
  loseInvisibleTarget : bool = false
  leading : float = .0

  def lostTarget(target_eid : EntityId) : bool
    if !loseInvisibleTarget
      return false
    var lost = false
    query(beh_tree_eid(owner)) <| $ [es] (agent_dangers : AgentDangers)
      lost = true
      for i in iter_range(agent_dangers.dangers)
        assume danger = agent_dangers.dangers[i]
        if danger.eid == target_eid && danger.traceable
          lost = false
          break
    return lost

  def override init()
    let agent_eid = beh_tree_eid(owner)
    let targetPosRef = agent_eid |> get_Eid(targetParam, targetParamHash)
    if targetPosRef != null
      query(*targetPosRef) <| $ [es] (transform : float3x4)
        lastTargetPos = transform[3]

  def override loadFromBlk(var data : DataBlock)
    AbstractNPhysCorridorMoveTo`loadFromBlk(self, data)
    data |> load_ecs_param("targetParam", targetParam, targetParamHash, thisNode)
    loseInvisibleTarget = data |> datablock_getBool("loseInvisibleTarget", loseInvisibleTarget)
    leading = data |> datablock_getReal("leading", leading)

  def override getTargetPos(agent_eid : EntityId; var res : float3&; var lost_target : bool&) : bool
    let targetPosRef = agent_eid |> get_Eid(targetParam, targetParamHash)
    if targetPosRef == null
      logerr_once("{agent_eid}: nPhysCorridorMoveToTarget can't find target eid '{targetParam}:{targetParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return false
    if self->lostTarget(*targetPosRef)
      lost_target = true
      res = lastTargetPos
      return true
    query(*targetPosRef) <| $ [es] (transform : float3x4; human_net_phys : HumanActor const?)
      lastTargetPos = transform[3]
      if human_net_phys != null
        lastTargetPos += human_net_phys.phys.currentState.velocity * leading
    res = lastTargetPos
    return true

  def override getCurrentPos(agent_eid : EntityId; var res : float3&) : bool
    let hasComponent = query(agent_eid) <| $ [es] (navmesh_phys__currentPos : float3)
      res = navmesh_phys__currentPos
    return hasComponent

  def override drawDebug(children : bool) : void
    AbstractNPhysCorridorMoveTo`drawDebug(self, children)
    draw_debug_sphere_buffered(lastTargetPos, 0.5, E3DCOLOR(0xFFFFFFFF), 12, 1)


class NPhysCorridorMoveToDirectionalTargetBase : NPhysCorridorMoveToTargetBase
  dist : float
  directionAngle : float
  angleRangeSpread : float2 = float2(-0.25 * PI, 0.25 * PI)

  def override loadFromBlk(var data : DataBlock)
    NPhysCorridorMoveToTargetBase`loadFromBlk(self, data)
    dist = data |> datablock_getReal("dist", 0f)
    directionAngle = data |> datablock_getReal("directionAngle", 0f) |> deg_to_rad()
    angleRangeSpread = data |> datablock_getPoint2("angleRangeSpread", float2(rad_to_deg(angleRangeSpread.x), rad_to_deg(angleRangeSpread.y)))
    angleRangeSpread = float2(deg_to_rad(angleRangeSpread.x), deg_to_rad(angleRangeSpread.y))

  def override getTargetPos(agent_eid : EntityId; var res : float3&; var lost_target : bool&) : bool
    let targetPosRef = agent_eid |> get_Eid(targetParam, targetParamHash)
    if targetPosRef == null
      logerr_once("{agent_eid}: nPhysCorridorMoveToDirectionalTarget can't find target eid '{targetParam}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return false
    if self->lostTarget(*targetPosRef)
      lost_target = true
      res = lastTargetPos
      return true
    query(*targetPosRef) <| $ [es] (transform : float3x4)
      lastTargetPos = transform[3]
      if dist > 0f
        let angle = rnd_float(directionAngle + angleRangeSpread.x, directionAngle + angleRangeSpread.y)
        var s, c : float
        sincos(angle, s, c)
        lastTargetPos += transform |> rotate <| float3(c * dist, 0f, s * dist)
    res = lastTargetPos
    return true

class AbstractNPhysLookAt : BehNodeAdapter
  stare = false
  [unused_argument(data)] def override loadFromBlk(var data : DataBlock)
    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(navmesh_phys__wishLookDir))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> AbstractNPhysLookAt requires navmesh_phys__wishLookDir fields {*thisNode |> beh_node_hierarchy_name(true)}")

  def abstract getTargetPos(eid : EntityId) : float3

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    let eid = beh_tree_eid(owner)
    query(eid) <| $ [es] (navmesh_phys__currentPos : float3;
                          transform : float3x4;
                          navmesh_phys__upDir : float3 = float3(0.0, 1.0, 0.0);
                          var navmesh_phys__wishLookDir : float3&;
                          agent_dangers__standShootPos : float3 const?;
                          walker_agent__standShootLocalPos = float3();
                          nphys__disabled : Tag const?;
                          navmesh_phys__wishLookApproachViscosity = 0.1;
                          navmesh_phys__wishLookApproachSpd = 1f)
      var curPos = nphys__disabled == null ? navmesh_phys__currentPos : transform[3]
      // navmesh_phys__currentPos is not updated when nphys__disabled.
      if agent_dangers__standShootPos != null
        curPos += navmesh_phys__upDir * walker_agent__standShootLocalPos.y
      let toPos = self->getTargetPos(eid)
      let dir = normalize(toPos - curPos)
      navmesh_phys__wishLookDir = approach_look_dir(navmesh_phys__wishLookDir, dir, dt,
        navmesh_phys__wishLookApproachSpd, navmesh_phys__wishLookApproachViscosity)
      res = !stare && length_sq(dir - navmesh_phys__wishLookDir) <= VECTOR_COMPARISON_ERROR ? EBehResult.ER_SUCCESS : EBehResult.ER_RUNNING
    return res


class NPhysLookAtPosBase : AbstractNPhysLookAt
  targetPos : float3

  def override loadFromBlk(var data : DataBlock)
    AbstractNPhysLookAt`loadFromBlk(self, data)
    data |> datablock_getPoint3("targetPos", float3())

  [unused_argument(eid)] def override getTargetPos(eid : EntityId)
    return targetPos


class NPhysLookAtDynPosBase : AbstractNPhysLookAt
  posParam : string
  @hidden posParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    AbstractNPhysLookAt`loadFromBlk(self, data)
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)

  def override getTargetPos(eid : EntityId)
    let targetPosRef = eid |> get_Point3(posParam, posParamHash)
    if targetPosRef == null
      logerr_once("{eid}: NPhysLookAtDynPos can't find target pos '{posParam}:{posParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
    return targetPosRef ?? float3()

class NPhysLookAtEntityBase : AbstractNPhysLookAt
  targetParam : string
  @hidden targetParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    AbstractNPhysLookAt`loadFromBlk(self, data)
    data |> load_ecs_param("targetParam", targetParam, targetParamHash, thisNode)

  def override getTargetPos(eid : EntityId)
    let targetPosRef = eid |> get_Eid(targetParam, targetParamHash)
    if targetPosRef == null
      logerr_once("{eid}: nPhysLookAtEntity can't find target eid '{targetParam}:{targetParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
    var res = float3()
    query(targetPosRef ?? eid) <| $ [es] (transform : float3x4; collres : CollisionResource const?; human_net_phys : HumanActor const?)
      if human_net_phys != null
        res = transform * human_net_phys.phys.ccdPos
      elif collres != null
        res = transform * collres.boundingBox.center
      else
        res = transform[3]
    return res


class NPhysLookAtRiBase : AbstractNPhysLookAt
  targetParam : string
  @hidden targetParamHash : uint
  heightTime : float = 0f

  def override loadFromBlk(var data : DataBlock)
    AbstractNPhysLookAt`loadFromBlk(self, data)
    data |> load_ecs_param("targetParam", targetParam, targetParamHash, thisNode)
    heightTime = data |> datablock_getReal("heightTime", heightTime)

  def override getTargetPos(eid : EntityId)
    let targetPosRef = eid |> get_Eid(targetParam, targetParamHash)
    if targetPosRef == null
      logerr_once("{eid}: nPhysLookAtRi can't find target eid '{targetParam}:{targetParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
    var res = float3()
    query(targetPosRef ?? eid) <| $ [es] (ri_extra : RiExtraComponent; transform : float3x4)
      let riType = handle_to_ri_type(ri_extra.handle)
      let riCollres = get_ri_gen_extra_collres(int(riType))
      if riCollres != null
        let min = riCollres.vFullBBox.bmin
        let max = riCollres.vFullBBox.bmax
        var pos = ((min + max) * 0.5).xyz
        pos.y = lerp(min.y, max.y, heightTime)
        res = transform * pos
      else
        res = transform[3]
    return res