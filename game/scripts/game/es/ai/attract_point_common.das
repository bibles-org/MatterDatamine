module attract_point_common shared
require ecs
require math.base
require pathfinder
require DagorRandom
require DagorMath
require Grid
require math.maybe_pos public

struct AttractPos
  eid : EntityId
  distSq : float
  center : float3
  radiusSq : float
  targetPos : float3
  ratio : float


variant MaybeAttractPos
  pos : AttractPos
  invalid : bool

def calc_attract_point_ratio(mult : float; dist_sq : float)
  return 0.5 * mult / (dist_sq + 1.)

def get_nearest_attract_point(target_eid : EntityId; cur_pos : float3; cur_poly : dtPolyRef; radius : float; check_path : bool) : MaybeAttractPos
  var points : array<AttractPos>
  let bsphere = BSphere3(cur_pos, radius)
  var res = MaybeAttractPos(invalid = true)
  gather_entities_in_grid(ecs_hash("attract_point"), bsphere, GridEntCheck.POS) <| $(attract_points)
    for eid in attract_points
      query(eid) <| $ [es] (attract_point__ownerEid : EntityId; transform : float3x4; attract_point__magnitude : float; attractRatioMult = 1f)
        if attract_point__ownerEid == target_eid
          return
        let center = transform[3]
        let distSq = distance_sq(center, cur_pos)
        let radiusSq = square(radius * attract_point__magnitude)
        if distSq <= radiusSq
          let ratio = calc_attract_point_ratio(attractRatioMult, distSq)
          var idx = 0
          while idx < length(points)
            if points[idx].ratio < ratio
              break
            idx += 1
          points |> emplace(AttractPos(eid = eid, distSq = distSq, center = center, radiusSq = radiusSq, targetPos = center, ratio = ratio), idx)

  if length(points) == 0
    return res

  if !check_path
    return MaybeAttractPos(pos = points[0])

  using() <| $(var path_corridor : dtPathCorridor)
    path_corridor |> init_path_corridor()
    var tries = 2
    for point in points
      var pathSq = 0f
      var hasPath = FindPathResult.FPR_FAILED
      let extents = float3(.5, FLT_MAX, .5)
      using(cur_pos, point.center, extents) <| $(var inp : CorridorInput#)
        inp.startPoly = cur_poly
        hasPath = path_corridor |> set_path_corridor(inp, null)
      path_corridor |> find_corridor_corners(5) <| $(path)
        if length(path) > 1
          var begin = path[0]
          var foundNewResult = false
          for i in range(1, length(path))
            if !foundNewResult && abs(begin.y - point.center.y) < 1.2 // point on same surface
              let ratio = safediv(distance_sq(begin, point.center), point.radiusSq)
              if ratio <= 1f && gfrnd() < square(1f - ratio)
                foundNewResult = true
                point.targetPos = begin
                res = MaybeAttractPos(pos = point)
            pathSq += distance_sq(begin, path[i])
            if pathSq > point.radiusSq
              break
            begin = path[i]
      if hasPath == FindPathResult.FPR_FULL && pathSq <= point.radiusSq && res is pos
        return
      tries -= 1
      if tries <= 0
        break

  return res
