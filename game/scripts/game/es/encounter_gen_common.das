module encounter_gen_common shared

require DagorRandom
require pathfinder
require math


def get_random_point_on_path(from, to : float3; var res_pos : float3&) : bool
  var res = false
  let extents = float3(10.5, FLT_MAX, 10.5)
  using(from, to, extents) <| $(var req : FindRequest#)
    let resPath = find_path(req, 10.0, 2.5) <| $(data)
      if length(data) > 1
        let legIdx = grnd() % length(data)
        res_pos = data[legIdx]
        res = true
    res = resPath != FindPathResult.FPR_FAILED && res
  return res
