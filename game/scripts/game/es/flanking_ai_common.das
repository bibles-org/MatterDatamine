module flanking_ai_common

require ecs
require math
require math.base
require pathfinder
require DagorRandom
require DagorMath

def calc_turn_value(a, b : float3) : float//value changing linearly between 0 (no turn) and 4 (360 turn)
  let crossP = cross2d(a.xz, b.xz)
  let dotP = dot(a.xz, b.xz)
  return crossP >= .0 ? 1.0 - dotP : 3.0 + dotP


def get_slot_position(target_pos, flanking_ai__dir : float3; flanking_ai__radius : float; var resPoly : dtPolyRef&)
  var targetPos = target_pos
  var res = target_pos
  if project_to_nearest_navmesh_point(targetPos, float3(.0, 0.75, .0), resPoly)
    let slotPos = targetPos + flanking_ai__dir * flanking_ai__radius
    let extents = float3(0.5)
    using(targetPos, slotPos, extents) <| $(var req : FindRequest#)
      if move_along_surface(req)
        if distance(req.end, target_pos) < flanking_ai__radius * 1.2
          res = req.end
          resPoly = req.endPoly
  return res


def adjust_attack_direction(target_pos : float3;
                            preferred_direction : float3;
                            min_distance : float;
                            var flanking_ai_target__dirs : Point3List;
                            recursion_depth_left = 3)
  assume dir = preferred_direction
  var flankingDir = preferred_direction
  let numDirs = length(flanking_ai_target__dirs)
  var bestIdx = numDirs
  if numDirs == 0
    flankingDir = dir
  elif numDirs == 1
    flankingDir = dot(dir, flanking_ai_target__dirs[0]) > .0 ? dir * -1.0 : dir
  else
    var bestGap = .0
    var bestSumDir : float3
    for i in iter_range(flanking_ai_target__dirs)
      let k = (i + 1) % numDirs
      let gap = calc_turn_value(flanking_ai_target__dirs[i], flanking_ai_target__dirs[k])
      if gap > bestGap
        bestGap = gap
        let multi = gap > 2.0 ? -1.0 : 1.0
        bestSumDir = (flanking_ai_target__dirs[i] + flanking_ai_target__dirs[k]) * multi
        bestIdx = i + 1
    let dirLn = length(bestSumDir)
    if dirLn > .0
      flankingDir = bestSumDir / dirLn
    else
      flankingDir = dir
  //flanking_ai_target__dirs |> push(flankingDir, bestIdx) fails in aot. So here is a (dumb) workaround.
  flanking_ai_target__dirs |> push(float3())
  var i = length(flanking_ai_target__dirs) - 1
  while i-- > bestIdx
    flanking_ai_target__dirs[i] = flanking_ai_target__dirs[i - 1]
  flanking_ai_target__dirs[bestIdx] = flankingDir
  if recursion_depth_left > 0
    var poly : dtPolyRef
    let newPos = get_slot_position(target_pos, flankingDir, min_distance * 1.5, poly)
    if distance_sq(newPos, target_pos) < square(min_distance)
      return adjust_attack_direction(target_pos, preferred_direction, min_distance, flanking_ai_target__dirs, recursion_depth_left - 1)
  return flankingDir


def choose_attack_direction(agent_pos : float3; target_pos : float3; attack_from_side : bool; agent_eid : EntityId)
  let dir = normalize(agent_pos - target_pos)
  if !attack_from_side
    return dir
  let flankDirection = uint(agent_eid) % 2u == 0u ? float3(dir.z, 0.0, -dir.x) : float3(-dir.z, 0.0, dir.x)
  let q = quat(float3(0, 1, 0), (gfrnd() - 0.5))
  return normalize(q * flankDirection)


def has_direction(flanking_ai_target__dirs : Point3List; flanking_ai__dir : float3)
  for dir in flanking_ai_target__dirs
    if dot(flanking_ai__dir, dir) > 0.9999
      return true
  return false