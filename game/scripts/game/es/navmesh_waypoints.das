require ecs
require pathfinder
require math.base


[es(tag=server, track=navmesh_waypoints__localSpace)]
def navmesh_waypoints_track_local_space(evt : Event;
                                        transform aka waypoints_transform : float3x4;
                                        navmesh_waypoints__localSpace : bool;
                                        var navmesh_waypoints__waypoints : Point3List)
  if navmesh_waypoints__localSpace
    let inverseTm = inverse(waypoints_transform)
    for waypoint in navmesh_waypoints__waypoints
      waypoint = inverseTm * waypoint
  else
    for waypoint in navmesh_waypoints__waypoints
      waypoint = waypoints_transform * waypoint


[es(tag=server, on_appear, track=(navmesh_waypoints__waypoints), on_event=(CmdTeleportEntity, EventLevelLoaded))]
def projected_navmesh_waypoints_update(evt : Event;
                                       transform aka waypoints_transform : float3x4;
                                       navmesh_waypoints__waypoints : Point3List;
                                       navmesh_waypoints__localSpace : bool;
                                       navmesh_waypoints__projectionExtents : float3;
                                       var navmesh_waypoints__boundingRadius : float&;
                                       var navmesh_waypoints__center : float3&;
                                       var navmesh_waypoints__projectedWaypoints : Point3List&)
  navmesh_waypoints__projectedWaypoints |> resize(length(navmesh_waypoints__waypoints))
  navmesh_waypoints__center = float3()
  for localWaypoint, projectedWaypoint in navmesh_waypoints__waypoints, navmesh_waypoints__projectedWaypoints
    var pos = localWaypoint
    if navmesh_waypoints__localSpace
      pos = waypoints_transform * pos
    navmesh_waypoints__center += pos
    project_to_nearest_navmesh_point(pos, navmesh_waypoints__projectionExtents)
    projectedWaypoint = pos
  if length(navmesh_waypoints__waypoints) > 0
    navmesh_waypoints__center /= float(length(navmesh_waypoints__waypoints))
    for localWaypoint in navmesh_waypoints__waypoints
      var pos = localWaypoint
      if navmesh_waypoints__localSpace
        pos = waypoints_transform * pos
      navmesh_waypoints__boundingRadius = max(navmesh_waypoints__boundingRadius, distance_sq(pos, navmesh_waypoints__center))
    navmesh_waypoints__boundingRadius = sqrt(navmesh_waypoints__boundingRadius)

