module stalker_statue_common

require ecs
require DagorMath
require math.base
require DagorDebug3D
require DngHuman
require AnimV20
require Dacoll
require GeomNodeTree
//require game.es.am_debug_draw_common

let tracesByStage = fixed_array(9999, 13, 10, 4 /*this is the relative cost, not the actual number of traces*/)

// OVERVIEW:
// The code checks if a statue is visible to one or more human actors in the scene.
// 1. Determine if statue falls within their field of view (test_statue_is_in_cone).
// 2. Depending on distance and angle, decide how many and which points to test.
// 3. If points are potentially visible, perform raycasts (is_point_visible_by_trace) to confirm.
// 4. Manage complexity and performance with thresholds (stalker_statue__traceDstThresholdsSq),
// arrays (tracesByStage), and a trace limit (traceBudget).
// The end result is a boolean indicating if the statue should be considered visible or not.

def test_statue_visible(statue_tm : float3x4;
                        stalker_statue__traceDstThresholdsSq : float4;
                        stalker_statue__zoomVisionDstMulti : float;
                        stalker_statue__zoomVisionDotMulti : float;
                        stalker_statue__highPrecisionDot : float;
                        stalker_statue__traceBudget : int;
                        stalker_statue__maxVisionDot : float;
                        stalker_statue__boundingPoints : Point3List;
                        stalker_statue__checkVision : bool)
  if !stalker_statue__checkVision
    return false
  var potentialTraces = 0
  var detailedChecksData : array<tuple<pos : float3; stage : int>>
  var result = false
  let zoomDstMultiSq = square(stalker_statue__zoomVisionDstMulti)
  let zoomHighPrecDot = 1.0 + (stalker_statue__highPrecisionDot - 1.0) * stalker_statue__zoomVisionDotMulti
  let zoomVisDot = 1.0 + (stalker_statue__maxVisionDot - 1.0) * stalker_statue__zoomVisionDotMulti
  find_query() <| $ [es(REQUIRE=heroForPlayer, REQUIRE_NOT=deadEntity)] (human_net_phys : HumanActor;
                                                                         transform : float3x4;
                                                                         animchar : AnimcharBaseComponent;
                                                                         human_net_phys__isZooming : bool;
                                                                         human_cam__camNodeId : int;
                                                                         am_militant_bot : Tag const?)
    let zoomMode = human_net_phys__isZooming && am_militant_bot == null
    let maxDstSq = stalker_statue__traceDstThresholdsSq.w * (zoomMode ? zoomDstMultiSq : 1.0)
    if distance_sq(transform[3], statue_tm[3]) < maxDstSq && human_cam__camNodeId > 0
      let wposRel = geomtree_getNodeWposRel(*animchar.nodeTree, human_cam__camNodeId)
      let wofs = geomtree_getWtmOfs(*animchar.nodeTree)
      let distancesSq = stalker_statue__traceDstThresholdsSq * (zoomMode ? zoomDstMultiSq : 1.0)
      let visDot = zoomMode ? zoomVisDot : stalker_statue__maxVisionDot
      let highPrecDot = zoomMode ? zoomHighPrecDot : stalker_statue__highPrecisionDot
      //Stages 0, 1, 2, 3 mean how close we are and how many checks are needed
      let (stage, visible) = test_statue_is_in_cone(wposRel + wofs,
                                                            human_net_phys.phys.currentState.headDir,
                                                            statue_tm,
                                                            visDot,
                                                            stalker_statue__boundingPoints,
                                                            distancesSq,
                                                            highPrecDot)
      //visual_log("stage: {stage} visible: {visible} dst:{(distance(wposRel + wofs, statue_tm[3]))} / {sqrt(maxDstSq)}")
      if visible
        potentialTraces += tracesByStage[stage]
        //Too many people see us, just assume we're visible to save on traces
        if potentialTraces > stalker_statue__traceBudget
          result = true
          return true
        detailedChecksData |> emplace((wposRel + wofs, stage))
    return false
  if result
    return result

  //At this point detailedChecksData has positions of everyone who has the statue within the cone
  //These are few people (may be 0). Now check vision with traces
  for datum in detailedChecksData
    //Assume stage 0 is impossible - instantly visible at stage 0
    let centerPoint = statue_tm * stalker_statue__boundingPoints[12]
    if is_point_visible_by_trace(datum.pos, centerPoint)
      return true
    if datum.stage < 3
      //check top points first, they have better chance of being visible
      let (p3, p4) = find_most_distant_points(datum.pos, statue_tm, stalker_statue__boundingPoints, 4, 8)
      if is_point_visible_by_trace(datum.pos, p3) || is_point_visible_by_trace(datum.pos, p4)
        return true
      let (p1, p2) = find_most_distant_points(datum.pos, statue_tm, stalker_statue__boundingPoints, 0, 4)
      if is_point_visible_by_trace(datum.pos, p1) || is_point_visible_by_trace(datum.pos, p2)
        return true
      if datum.stage < 2 //check additional intermediate points
        if is_point_visible_by_trace(datum.pos, (p3 + p4) * 0.5)
          return true
        if is_point_visible_by_trace(datum.pos, (p1 + p2) * 0.5)
          return true
        if distance_sq(p1, p3) > distance_sq(p1, p4)
          if is_point_visible_by_trace(datum.pos, (p1 + p4) * 0.5)
            return true
          if is_point_visible_by_trace(datum.pos, (p2 + p3) * 0.5)
            return true
        else
          if is_point_visible_by_trace(datum.pos, (p1 + p3) * 0.5)
            return true
          if is_point_visible_by_trace(datum.pos, (p2 + p4) * 0.5)
            return true
        if is_point_visible_by_trace(datum.pos, (centerPoint + p3) * 0.5)
          return true
        if is_point_visible_by_trace(datum.pos, (centerPoint + p4) * 0.5)
          return true
        if is_point_visible_by_trace(datum.pos, (centerPoint + p1) * 0.5)
          return true
        if is_point_visible_by_trace(datum.pos, (centerPoint + p2) * 0.5)
          return true
  return false


def is_point_visible_by_trace(from, to : float3) : bool
  var dir = to - from
  let t = length(dir)
  dir *= safeinv(t)
  //let res = !rayhit_normalized(from, dir, t, ETF_ALL, -1)
  //let color = res ? ACYELLOW : ACWHITE
  //draw_debug_line_buffered(from, to, color, 100)
  return !rayhit_normalized(from, dir, t, ETF_ALL, -1)

//a pair of points that are furthers apart from our current POV
def find_most_distant_points(from : float3; statue_tm : float3x4; list : Point3List; from_idx, to_idx : int)
  var r1, r2 : float3
  var bestDot = 2.0
  for i in range(from_idx, to_idx - 1)
    let p1 = statue_tm * list[i]
    let v1 = normalize(p1 - from)
    for k in range(from_idx + 1, to_idx)
      let p2 = statue_tm * list[k]
      let v2 = normalize(p2 - from)
      let d = dot(v1, v2)
      if d < bestDot
        bestDot = d
        r1 = p1
        r2 = p2
  return r1, r2


def private test_statue_is_in_cone(vision_pos, vision_dir : float3;
                                   statue_tm : float3x4;
                                   stalker_statue__maxVisionDot : float;
                                   stalker_statue__boundingPoints : Point3List;
                                   stalker_statue__traceDstThresholdsSq : float4;
                                   stalker_statue__highPrecisionDot : float)
  let dstSq = distance_sq(vision_pos, statue_tm[3])

  //Furthest stage
  if dstSq > stalker_statue__traceDstThresholdsSq.z
    let d = calc_dot(stalker_statue__boundingPoints[12], vision_pos, vision_dir, statue_tm)
    //if d > stalker_statue__maxVisionDot
    //  draw_debug_sphere_buffered(statue_tm * stalker_statue__boundingPoints[12], 0.1, ACBLUE, 100)
    return 3, d > stalker_statue__maxVisionDot

  //Stages 2, 3 (if the statue if in the center of our view then more traces are needed)
  elif dstSq > stalker_statue__traceDstThresholdsSq.x //.x sic!
    let centerDot = calc_dot(stalker_statue__boundingPoints[12], vision_pos, vision_dir, statue_tm)
    if centerDot > stalker_statue__highPrecisionDot
      //draw_debug_sphere_buffered(statue_tm * stalker_statue__boundingPoints[12], 0.1, ACBLUE, 100)
      return (dstSq > stalker_statue__traceDstThresholdsSq.y ? 1 : 0), true
    let stage = dstSq > stalker_statue__traceDstThresholdsSq.y ? 2 : 1
    for i in range(8)
      let d = calc_dot(stalker_statue__boundingPoints[i], vision_pos, vision_dir, statue_tm)
      if d > stalker_statue__maxVisionDot
        //draw_debug_sphere_buffered(statue_tm * stalker_statue__boundingPoints[i], 0.1, ACBLUE, 100)
        return stage, true
    return stage, false
  else //Nearest stage
    for i in range(12)
      let d = calc_dot(stalker_statue__boundingPoints[i], vision_pos, vision_dir, statue_tm)
      if d > stalker_statue__maxVisionDot
        //draw_debug_sphere_buffered(statue_tm * stalker_statue__boundingPoints[i], 0.1, ACBLUE, 100)
        return 0, true
    return 0, false


def private calc_dot(test_point, vision_pos, vision_dir : float3; statue_tm : float3x4)
  let testPoint = statue_tm * test_point
  let testDir = normalize(testPoint - vision_pos)
  return dot(testDir, vision_dir)