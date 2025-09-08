require ecs
require pathfinder
require active_matter.game.es.navmesh_nearest_pos_common

[es(tag=server, on_appear, on_event=EventLevelLoaded)]
def init_navmesh_nearest_points(evt : Event; transform : float3x4;
                                navmesh__nearestPosRadius : float;
                                nav_binding__navMeshPos : float3 const?;
                                nav_binding__inaccessible : bool const?;
                                var navmesh__potentialNearestPos : Point3List&)
  if nav_binding__inaccessible != null && *nav_binding__inaccessible
    return
  let pos = nav_binding__navMeshPos != null ? *nav_binding__navMeshPos : transform[3]
  init_navmesh_nearest_positions(pos, navmesh__nearestPosRadius, navmesh__potentialNearestPos)

