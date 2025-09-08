require ecs
require pathfinder
require active_matter.game.utils.poly_area
require game.events.events_active_matter
require DagorSystem
require math.base


[es(on_event=EventLevelLoaded)]
def disable_to_high_polygons(evt : Event)
  query() <| $ [es] (water__level : float)
    mark_polygons_upper(water__level + 400., uint8(int(AMPolyArea.POLYAREA_UNWALKABLE)))


[es(on_appear)]
def navmesh_phys_look_dir_init(evt : Event;
                               transform : float3x4;
                               var navmesh_phys__wishLookDir : float3&)
  navmesh_phys__wishLookDir = normalize(transform[0])


[es(tag=server, on_appear, on_event=EventRetriggerEntity, REQUIRE=navmesh_isle_marker)]
def init_navmesh_isle_marker_on_appear(evt : Event;
                                       eid : EntityId;
                                       transform : float3x4;
                                       var navmesh_isle_marker__origin : float3&;
                                       navmesh_isle_marker__syncWithZone : bool)
  navmesh_isle_marker__origin = transform[3]
  if !navmesh_isle_marker__syncWithZone
    find_query() <| $ [es] (level__levelLoaded : bool; var level__retriggerEids : EidList)
      if !level__levelLoaded
        level__retriggerEids |> push(eid)
      else
        mark_navmesh_islands(eid)
      return true


[es(tag=server)]
def init_init_navmesh_isle_marker_on_zone_appear(evt : EventMovingZoneCreated;
                                                 eid : EntityId;
                                                 navmesh_isle_marker__syncWithZone : bool;
                                                 var navmesh_isle_marker__radius : float&;
                                                 var navmesh_isle_marker__origin : float3&)
  if navmesh_isle_marker__syncWithZone
    // EventMovingZoneCreated is cast after level loaded, so no such checks are performed
    print("NMESH INIT: zone appears")
    query(evt.eid) <| $ [es] (moving_zone__sourceRadius : float;
                              moving_zone__sourcePos : float3)
      navmesh_isle_marker__radius = moving_zone__sourceRadius + navmesh_isle_marker__radius
      navmesh_isle_marker__origin = moving_zone__sourcePos
      mark_navmesh_islands(eid)


def mark_navmesh_islands(navmesh_isle_marker_eid : EntityId)
  query(navmesh_isle_marker_eid) <| $ [es] (transform : float3x4;
                                            navmesh_isle_marker__expectedNumTriangles : int;
                                            navmesh_isle_marker__radius : float;
                                            navmesh_isle_marker__origin : float3)
    print("NMESH INIT: marking polygons with {uint8(int(AMPolyArea.POLYAREA_WALKABLE_ISLE))} radius: {navmesh_isle_marker__radius}")
    var countMarked = 0
    var countTotal = 0
    var area : uint8
    for_each_nmesh_poly() <| $(poly : dtPolyRef)
      get_poly_area(poly, area)
      countTotal++
      if area == uint8(int(AMPolyArea.POLYAREA_WALKABLE))
        set_poly_area(poly, uint8(int(AMPolyArea.POLYAREA_WALKABLE_ISLE)))
        countMarked++

    print("NMESH INIT: marking polygons end. WALKABLE: {countMarked} / {countTotal}")
    var ref : dtPolyRef
    let extents = float3(0.1, 200.0, 0.1)
    var p = transform[3]
    countMarked = 0
    if project_to_nearest_navmesh_point(p, extents, ref)
      var visited : table<dtPolyRef>
      var newFrontier : table<dtPolyRef>
      var frontier <- { ref }
      let maxRadiusSq = square(navmesh_isle_marker__radius)
      var depthLeft = 1000
      while depthLeft-- > 0
        for f in keys(frontier)
          visited.insert(f)
          get_poly_area(f, area)
          if area == uint8(int(AMPolyArea.POLYAREA_WALKABLE_ISLE))
            set_poly_area(f, uint8(int(AMPolyArea.POLYAREA_WALKABLE)))
            countMarked++
          var polyTriangle : NavMeshTriangle
          get_triangle_by_poly(f, polyTriangle)
          if distance_sq(polyTriangle.p0, navmesh_isle_marker__origin) > maxRadiusSq
            continue
          for_each_linked_poly(f) <| $(linkedPolyRef)
            if !key_exists(visited, linkedPolyRef) && !key_exists(frontier, linkedPolyRef)
              newFrontier.insert(linkedPolyRef)
        delete frontier
        frontier <- newFrontier
        clear(newFrontier)
      print("NMESH INIT: polygons floodfill end. WALKABLE: {countMarked}/{length(visited)}")
      assume expectation = navmesh_isle_marker__expectedNumTriangles
      if expectation > 0 && (expectation * 4 < countMarked || countMarked * 4 < expectation)
        logerr("Navmesh island marker is wrongly positioned. Expected {expectation} walkable triangles, got {countMarked}.")
      destroyEntity(navmesh_isle_marker_eid)
    else
      logerr("Navmesh island marker is too far from any navmesh tiles. [{p}]")


[es(REQUIRE=navmesh_isle_marker, on_disappear)]
def mark_additional_walkable_areas(evt : Event)
  query() <| $ [es(REQUIRE=additional_walkable_area_marker)] (eid : EntityId; transform : float3x4; sphere_zone__radius : float)
    var ref : dtPolyRef
    let extents = float3(0.1, 200.0, 0.1)
    var p = transform[3]
    if project_to_nearest_navmesh_point(p, extents, ref)
      var visited : table<dtPolyRef>
      var newFrontier : table<dtPolyRef>
      var frontier <- { ref }
      let maxRadiusSq = square(sphere_zone__radius)
      var depthLeft = 1000
      var area : uint8
      while depthLeft-- > 0
        for f in keys(frontier)
          visited.insert(f)
          get_poly_area(f, area)
          if area == uint8(int(AMPolyArea.POLYAREA_WALKABLE_ISLE))
            set_poly_area(f, uint8(int(AMPolyArea.POLYAREA_WALKABLE)))
          elif area == uint8(int(AMPolyArea.POLYAREA_WALKABLE))
            continue
          var polyTriangle : NavMeshTriangle
          get_triangle_by_poly(f, polyTriangle)
          if distance_sq(polyTriangle.p0, transform[3]) > maxRadiusSq
            continue
          for_each_linked_poly(f) <| $(linkedPolyRef)
            if !key_exists(visited, linkedPolyRef) && !key_exists(frontier, linkedPolyRef)
              newFrontier.insert(linkedPolyRef)
        delete frontier
        frontier <- newFrontier
        clear(newFrontier)
    destroyEntity(eid)
  broadcastEvent(EventNavmeshIslandsMarked())