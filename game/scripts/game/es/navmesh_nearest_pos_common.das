module navmesh_nearest_pos_common shared
require ecs
require pathfinder
require danetlibs.pathfinder.main.pathfinder_common


def init_navmesh_nearest_positions(pos : float3; radius : float; var navmesh__potentialNearestPos : Point3List&)
  query_navmesh_projections(pos, float3(radius), /*points num*/8) <| $(points)
    navmesh__potentialNearestPos |> clear()
    for p in points
      navmesh__potentialNearestPos |> push(p)

def next_navmesh_nearest_pos(var navmesh__nearestPos : float3&; var navmesh__hasNearestPos : bool&;
                             var navmesh__potentialNearestPos : Point3List&) : bool
  if navmesh__hasNearestPos || length(navmesh__potentialNearestPos) == 0
    return navmesh__hasNearestPos
  let nextPos = navmesh__potentialNearestPos[0]
  navmesh__potentialNearestPos |> erase(0)

  var limit = 3
  var valid = false
  find_query() <| $ [es(REQUIRE=respbase)] (transform : float3x4)
    let extents = float3(.5, FLT_MAX, .5)
    using(transform[3], nextPos, extents) <| $(var req : FindRequest#)
      valid = check_path(req, extents.x, extents.x)
      limit -= 1
    return valid || limit <= 0

  if valid
    navmesh__nearestPos = nextPos
    navmesh__hasNearestPos = true
    navmesh__potentialNearestPos |> clear()
  return navmesh__hasNearestPos