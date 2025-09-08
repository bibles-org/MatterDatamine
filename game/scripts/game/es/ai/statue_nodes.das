options always_export_initializer = true

require app
require ecs
require net
require ecs.common
require strings
require DagorSystem
require BehNodes
require DagorDataBlock
require DagorRandom
require Dacoll
require DngDm
require AnimV20
require GeomNodeTree
require pathfinder
require math.base
require math.random
require DagorMath
require Grid
require CollRes
require debug.logerr_once
require game.events.events_active_matter
require game.events.events_game
require DagorDebug3D
require game.es.stalker_statue_common


[beh_node(name="statueFindTarget")]
class StatueFindTarget : BehNodeAdapter
  targetParam : string
  @hidden targetParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("targetParam", targetParam, targetParamHash, thisNode)

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (transform aka s_transform : float3x4;
                               stalker_statue__searchRadius : float;
                               stalker_statue__origin : float3x4;
                               stalker_statue__chaseRadius : float2;
                               var stalker_statue__chaseIdx : int&)
      let limitByStatueSq = max(distance_sq(stalker_statue__origin[3], s_transform[3]), square(stalker_statue__chaseRadius.x))
      let originLimitDstSq = stalker_statue__chaseIdx == 0 ? limitByStatueSq : square(stalker_statue__chaseRadius.y)
      var bestTarget = INVALID_ENTITY_ID
      var bestDstSq = FLT_MAX
      var bestDstToOriginSq = FLT_MAX
      query() <| $ [es(REQUIRE=stalkerStatueTarget, REQUIRE_NOT=(stalkerStatue_Not_Target, deadEntity))
          ] (eid : EntityId; transform aka t_transform : float3x4)
        let dstSq = distance_sq(t_transform[3], s_transform[3])
        if dstSq < bestDstSq
          let dstToOriginSq = distance_sq(stalker_statue__origin[3], t_transform[3])
          if originLimitDstSq > dstToOriginSq
            bestDstSq = dstSq
            bestTarget = eid
            bestDstToOriginSq = dstToOriginSq
      if bestDstSq > square(stalker_statue__searchRadius)
        bestTarget = INVALID_ENTITY_ID

      if bestTarget != INVALID_ENTITY_ID
        //hysteresis
        if bestDstToOriginSq > square(stalker_statue__chaseRadius.y)
          //Don't target anything further from the origin then itself
          stalker_statue__chaseIdx = 0
        elif bestDstToOriginSq < square(stalker_statue__chaseRadius.x)
          stalker_statue__chaseIdx = 1

      var targetPosRef = ownerEid |> getRW_Eid(targetParam, targetParamHash)
      if targetPosRef == null
        logerr_once("{ownerEid}<{getEntityTemplateName(ownerEid)}>: StatueFindTarget unable to find component '{targetParam}:{targetParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
        return
      *targetPosRef = bestTarget
      result = bestTarget == INVALID_ENTITY_ID ? EBehResult.ER_FAILED : EBehResult.ER_SUCCESS
    return result


class StatueMove : BehNodeAdapter
  stopDist : float2 = float2(1, 1)
  debug_lastPathLen : float = 0f

  def override loadFromBlk(var data : DataBlock)
    stopDist = data |> datablock_getPoint2("stopDist", stopDist)

  def abstract getTargetPos(eid : EntityId; var res : float3&) : bool

  def override init()
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (var stalker_statue__accumulatedTime : float&)
      stalker_statue__accumulatedTime = .0

  [unused_argument(dt)] def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    var shouldExitNode = false
    query(ownerEid) <| $ [es] (stalker_statue__moveInterval : float2;
                               stalker_statue__moveIntervalSmall : float2;
                               stalker_statue__traceDstThresholdsSq : float4;
                               stalker_statue__maxVisionDot : float;
                               stalker_statue__zoomVisionDstMulti : float;
                               stalker_statue__zoomVisionDotMulti : float;
                               stalker_statue__highPrecisionDot : float;
                               stalker_statue__medPrecisionDot : float;
                               stalker_statue__traceBudget : int;
                               stalker_statue__boundingPoints : Point3List;
                               stalker_statue__maxAccumulatedTime : float;
                               stalker_statue__speed : float;
                               stalker_statue__checkVision : bool;
                               collres : CollisionResource;
                               var stalker_statue__lastCoveredPath : Point3List;
                               var stalker_statue__consequtiveFails : int&;
                               var stalker_statue__nextMoveAt : float&;
                               var transform : float3x4;
                               var stalker_statue__accumulatedTime : float&)
      var targetPos : float3
      let time = get_sync_time()
      if time > stalker_statue__nextMoveAt
        clear(stalker_statue__lastCoveredPath)
        var nextDt : float
        if stalker_statue__consequtiveFails > 5
          stalker_statue__consequtiveFails = 0
          nextDt = rnd_float(stalker_statue__moveIntervalSmall) //more careful movement
        else
          nextDt = rnd_float(stalker_statue__moveInterval)
        stalker_statue__nextMoveAt = time + nextDt

        if !test_statue_visible(transform,
                                stalker_statue__traceDstThresholdsSq,
                                stalker_statue__zoomVisionDstMulti,
                                stalker_statue__zoomVisionDotMulti,
                                stalker_statue__medPrecisionDot, //not so important, since the statue is going to disappear instead of appear.
                                stalker_statue__traceBudget,
                                stalker_statue__maxVisionDot,
                                stalker_statue__boundingPoints,
                                stalker_statue__checkVision)
          let distanceToCover = stalker_statue__speed * min(nextDt + stalker_statue__accumulatedTime, stalker_statue__maxAccumulatedTime)
          if !self->getTargetPos(ownerEid, targetPos)
            shouldExitNode = true
          else
            let (success, resultingTm, path) = get_next_statue_tm(transform, targetPos, distanceToCover, stopDist.x)
            if !success
              return
            var statueMoved = false
            if !test_statue_visible(resultingTm,
                                    stalker_statue__traceDstThresholdsSq,
                                    stalker_statue__zoomVisionDstMulti,
                                    stalker_statue__zoomVisionDotMulti,
                                    stalker_statue__highPrecisionDot,
                                    stalker_statue__traceBudget,
                                    stalker_statue__maxVisionDot,
                                    stalker_statue__boundingPoints,
                                    stalker_statue__checkVision)
              var valid = true
              var box = BBox3(collres.vFullBBox)
              bbox3_inflateXZ(box, 0.2)
              box = resultingTm * box
              for_each_entity_in_grid(ecs_hash("humans"), box, GridEntCheck.POS) <| $(that_eid : EntityId)
                valid &&= ownerEid == that_eid || has(that_eid, "deadEntity")
              if valid
                statueMoved = true
                stalker_statue__lastCoveredPath |> push(transform[3])
                for p in path
                  stalker_statue__lastCoveredPath |> push(p)
                let usedUpTime = distance(resultingTm[3], transform[3]) / stalker_statue__speed
                send_net_event(ownerEid, EventStatueMove(pos = resultingTm[3], look = resultingTm[0].xz, duration = usedUpTime))
                stalker_statue__accumulatedTime = 0.0
                transform = resultingTm
              //else
              //  draw_debug_circle_buffered(resultingTm[3] + meter * 0.2, meter, 0.5, ACBLUE, 4, 100)
            //else
            //  draw_debug_circle_buffered(resultingTm[3] + meter * 0.2, meter, 0.5, ACRED, 4, 100)
            if !statueMoved
              stalker_statue__consequtiveFails++
              if stalker_statue__accumulatedTime < stalker_statue__maxAccumulatedTime
                stalker_statue__accumulatedTime += nextDt
              else
                stalker_statue__accumulatedTime = .0 //reset it once in a while to increase options
      if shouldExitNode
        result = EBehResult.ER_FAILED
      elif distance_sq(targetPos, transform[3]) < square(stopDist.y)
        result = EBehResult.ER_SUCCESS
      else
        result = EBehResult.ER_RUNNING
    return result


def get_next_statue_tm(cur_tm : float3x4; target_pos : float3; distance_covered, stop_distance : float)
  var coveredPath : array<float3>
  var resTm = IDENT_TM
  var result = false
  let extents = float3(stop_distance, 10.0, stop_distance)
  var from = cur_tm[3]
  var to = target_pos
  project_to_nearest_navmesh_point(from, extents)
  project_to_nearest_navmesh_point(to, extents)
  using(from, to, extents) <| $(var req : FindRequest#)
    req.includeFlags |= int(PolyFlag.POLYFLAG_JUMP)
    req.maxJumpUpHeight = distance_covered
    find_path(req, 2.0, 0.01) <| $(path)

      // Path exists, it's full, it's not an infinite loop
      let pathSuccess = length(path) < 2000 && length(path) > 0 && distance_sq(path[length(path) - 1], target_pos) <= stop_distance * 1.2
      if !pathSuccess
        // The path is unhelpful, jump towards the target.
        // Use the next path step or simply jump in the direction of the target
        var forcedVec = target_pos - cur_tm[3]
        if length(path) > 1
          let nextStepV = path[1] - path[0]
          if length_sq(nextStepV) > .05
            forcedVec = nextStepV
        var forcedPoint = cur_tm[3] + normalize(forcedVec) * distance_covered
        if project_to_nearest_navmesh_point(forcedPoint, extents)
          if distance_sq(forcedPoint, target_pos) < square(stop_distance)
            forcedPoint = rnd_nav_point_around_target(target_pos, stop_distance)
          coveredPath |> push(forcedPoint)
          resTm = tm_to_target(forcedPoint, target_pos)
          result = true
        return
      //for pp in path
      //  draw_debug_sphere_buffered(pp, 0.3, ACWHITE, 4, 100)

      //Jump along the path for however long the budget allows
      var budgetLeft = distance_covered
      var pos = cur_tm[3]
      for p in path
        let dst = distance(pos, p)
        if dst > budgetLeft
          let moveVec = normalize(p - pos)
          var resPos = pos + moveVec * budgetLeft
          if distance(target_pos, resPos) < stop_distance
            resPos -= moveVec * min(stop_distance, budgetLeft)
          result = true
          resTm = tm_to_target(resPos, target_pos)
          return
        else
          budgetLeft -= dst
          let toTargetDst = distance(target_pos, p)
          if toTargetDst < stop_distance
            var resPos = p
            let moveVec = normalize(p - pos)
            resPos -= moveVec * (stop_distance - toTargetDst)
            result = true
            resTm = tm_to_target(resPos, target_pos)
            return
          coveredPath |> push(p)
          //draw_debug_sphere_buffered(p, 0.3, ACYELLOW, 4, 100)
          pos = p
  if result //Lower the statue onto collision
    result = false
    var norm : float3
    let traceFrom = resTm[3] + resTm[1] * 0.5
    let dir = -resTm[1]
    var t = 2.0
    if traceray_normalized(traceFrom, dir, t, norm)
      result = true
      resTm[3] = traceFrom + dir * t
  coveredPath |> push(resTm[3])
  //draw_debug_sphere_buffered(resTm[3], 0.3, ACORANGE, 4, 1100)
  return result, resTm, coveredPath


def tm_to_target(pos, target_pos)
  var tm = IDENT_TM
  let diff = target_pos - pos
  tm[0] = normalize(diff - tm[1] * (diff * tm[1]))
  tm[2] = cross(tm[0], tm[1])
  tm[3] = pos
  return tm


def rnd_nav_point_around_target(target_pos : float3; stop_distance : float)
  var s, c : float
  sincos(gfrnd() * 2.0 * PI, s, c)
  var pos = target_pos + float3(1, 0, 0) * s * stop_distance + float3(0, 0, 1) * c * stop_distance
  project_to_nearest_navmesh_point(pos, float3(stop_distance))
  return pos


[beh_node(name="statueGoToEntity")]
class StatueGoToEntity : StatueMove
  targetParam : string
  @hidden targetParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    StatueMove`loadFromBlk(self, data)
    data |> load_ecs_param("targetParam", targetParam, targetParamHash, thisNode)

  def override getTargetPos(eid : EntityId; var res : float3&) : bool
    let targetPosRef = eid |> get_Eid(targetParam, targetParamHash)
    if targetPosRef == null
      logerr_once("{eid}: StatueGoToEntity can't find target eid '{targetParam}:{targetParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return false
    var success = false
    query(*targetPosRef) <| $ [es] (transform : float3x4)
      success = true
      res = transform[3]
    return success


[beh_node(name="statueGoToOrigin")]
class StatueGoToOrigin : StatueMove

  def override getTargetPos(eid : EntityId; var res : float3&) : bool
    var success = false
    query(eid) <| $ [es] (stalker_statue__origin : float3x4)
      res = stalker_statue__origin[3]
      success = true
    return success

  def override update(dt : float) : EBehResult
    let result = StatueMove`update(self, dt)
    if result == EBehResult.ER_SUCCESS
      let ownerEid = beh_tree_eid(owner)
      query(ownerEid) <| $ [es] (stalker_statue__origin : float3x4; var transform : float3x4)
        transform = stalker_statue__origin
    return result


[beh_node(name="statueAttack")]
class StatueAttack : BehNodeAdapter
  targetParam : string
  @hidden targetParamHash : uint
  startedAt : float
  eventSent : bool

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("targetParam", targetParam, targetParamHash, thisNode)

  def override init()
    startedAt = get_sync_time()
    eventSent = false

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    let targetRef = ownerEid |> get_Eid(targetParam, targetParamHash)
    if targetRef == null
      logerr_once("{ownerEid}: StatueGoToEntity can't find target eid '{targetParam}:{targetParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return result

    query(ownerEid) <| $ [es] (transform aka s_transform : float3x4;
                               stalker_statue__damage : float2;
                               stalker_statue__attackDelay : float;
                               stalker_statue__pushStrength : float = 1.0;
                               stalker_statue__hitPos : float3)
      if !eventSent
        eventSent = true
        send_net_event(ownerEid, EventStatueAttacked())
      if get_sync_time() - startedAt >= stalker_statue__attackDelay
        query(*targetRef) <| $ [es] (ai_target_node__nodeId : int; animchar : AnimcharBaseComponent)
          var targetTm : float3x4
          *animchar.nodeTree |> geomtree_getNodeWtmScalar(ai_target_node__nodeId, targetTm)
          let hitFromPos = s_transform * stalker_statue__hitPos
          let dir = normalize(targetTm[3] - hitFromPos)
          let t = distance(targetTm[3], hitFromPos)
          if !rayhit_normalized(hitFromPos, dir, t, ETF_ALL, -1)
            let dmg = rnd_float(stalker_statue__damage)
            let dd = DamageDesc(DamageType.DM_MELEE, dmg, targetTm[3], hitFromPos)
            damage_entity(*targetRef, ownerEid, dd)
            sendEvent(*targetRef, CmdPushPhys(vel = dir * stalker_statue__pushStrength, push_immunity = 0.0))
            result = EBehResult.ER_SUCCESS
      else
        result = EBehResult.ER_RUNNING
    return result


[beh_node(name="statueTurnToEntity")]
class StatueTurnToEntity : BehNodeAdapter
  targetParam : string
  @hidden targetParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("targetParam", targetParam, targetParamHash, thisNode)

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    let targetRef = ownerEid |> get_Eid(targetParam, targetParamHash)
    if targetRef == null
      logerr_once("{ownerEid}: StatueTurnToEntity can't find target eid '{targetParam}:{targetParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return result

    query(ownerEid) <| $ [es] (var transform aka s_transform : float3x4)
      query(*targetRef) <| $ [es] (transform aka t_transform : float3x4)
        s_transform = tm_to_target(s_transform[3], t_transform[3])
        send_net_event(ownerEid, EventStatueMove(pos = s_transform[3], look = s_transform[0].xz, duration = .0))
        result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="statueIsVisible")]
class StatueIsVisible : BehNodeAdapter

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (transform : float3x4;
                               stalker_statue__traceDstThresholdsSq : float4;
                               stalker_statue__zoomVisionDstMulti : float;
                               stalker_statue__zoomVisionDotMulti : float;
                               stalker_statue__maxVisionDot : float;
                               stalker_statue__highPrecisionDot : float;
                               stalker_statue__traceBudget : int;
                               stalker_statue__boundingPoints : Point3List;
                               stalker_statue__checkVision : bool)
      if test_statue_visible(transform,
                                stalker_statue__traceDstThresholdsSq,
                                stalker_statue__zoomVisionDstMulti,
                                stalker_statue__zoomVisionDotMulti,
                                stalker_statue__highPrecisionDot,
                                stalker_statue__traceBudget,
                                stalker_statue__maxVisionDot,
                                stalker_statue__boundingPoints,
                                stalker_statue__checkVision)
        result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="statueSendAttackImminent")]
class StatueSendAttackImminent : BehNodeAdapter

  def override update(dt : float) : EBehResult
    send_net_event(beh_tree_eid(owner), EventStatueAttackImminent())
    return EBehResult.ER_SUCCESS