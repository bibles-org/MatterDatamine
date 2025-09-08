module underground_zone_common shared
require ecs
require math.base

def is_in_underground_zone(pos : float3)
  var res = false
  find_query() <| $ [es(REQUIRE=underground_zone)] (transform : float3x4)
    if is_inside_tm(pos, transform)
      res = true
    return res
  return res