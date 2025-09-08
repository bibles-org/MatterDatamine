options no_aot
require strings
require math.color
require ecs
require ecs.safe
require ecs.soa_template
require ecs.ecs_template
require game.utils.hero
require math.base
require gameObject
require DagorConsole
require DagorDebug3D
require DagorSystem


[ecs_template]
struct navmesh_waypoints_debug_draw
  navmesh_waypoints__debugDrawDist : float = 200.0


[console_cmd(name="navmesh_waypoints.debug_draw")]
def navmesh_waypoints_debug_draw_cmd(dist = 200.0)
  let tmpl = "navmesh_waypoints_debug_draw"
  let exists = find_query() <| $ [es] (eid : EntityId; var navmesh_waypoints__debugDrawDist : float&)
    if navmesh_waypoints__debugDrawDist == dist
      destroyEntity(eid)
    else
      navmesh_waypoints__debugDrawDist = dist
    return true

  if !exists
    createEntity(tmpl) <| $(init)
      init |> set("navmesh_waypoints__debugDrawDist", dist)


def draw_waypoint(pos : float3;
                  index : int;
                  color : E3DCOLOR)
  draw_debug_sphere_buffered(pos, 0.1, color, 12, 1)
  add_debug_text_mark(pos, "{index}", -1, 0.0, color)


def draw_waypoint_path(waypoints : Point3List;
                       waypoints_transform : float3x4;
                       nodeColor : E3DCOLOR;
                       lineColor : E3DCOLOR;
                       looped : bool)
  if length(waypoints) == 0
    return

  let startPos = waypoints_transform * waypoints[0]
  let endPos = waypoints_transform * waypoints[length(waypoints) - 1]

  draw_waypoint(startPos, 0, nodeColor)

  for i in range(1, length(waypoints))
    let pos0 = waypoints_transform * waypoints[i - 1]
    let pos1 = waypoints_transform * waypoints[i]
    draw_waypoint(pos1, i, nodeColor)
    draw_debug_line_buffered(pos0, pos1, lineColor, 1)

  if looped
    draw_debug_line_buffered(endPos, startPos, lineColor, 1)


[es(tag=render, tag=dev, no_order)]
def navmesh_waypoints_debug_es(evt : UpdateStageInfoRenderDebug;
                               navmesh_waypoints__debugDrawDist : float)

  find_query() <| $ [es] (camera__active : bool;
                          transform aka camera_transform : float3x4)
    if !camera__active
      return false

    let drawDistSq = square(navmesh_waypoints__debugDrawDist)
    query() <| $ [es] (navmesh_waypoints__waypoints : Point3List;
                       navmesh_waypoints__projectedWaypoints : Point3List const?;
                       navmesh_waypoints__looped : bool;
                       navmesh_waypoints__localSpace : bool;
                       transform aka waypoints_transform : float3x4)
      let distToWaypointsSq = distance_sq(camera_transform[3], waypoints_transform[3])
      if distToWaypointsSq > drawDistSq
        return

      let posColorDefault = E3DCOLOR(0x78DADADA)
      draw_waypoint_path(navmesh_waypoints__waypoints, navmesh_waypoints__localSpace ? waypoints_transform : IDENT_TM,
                         posColorDefault, E3DCOLOR(0x6CFFFFFF), navmesh_waypoints__looped)

      if navmesh_waypoints__projectedWaypoints != null
        let posColorProjected = E3DCOLOR(0xFF6EB9FF)
        draw_waypoint_path(*navmesh_waypoints__projectedWaypoints, IDENT_TM,
                          posColorProjected, E3DCOLOR(0xFFBDDFFF), navmesh_waypoints__looped)

    return true

