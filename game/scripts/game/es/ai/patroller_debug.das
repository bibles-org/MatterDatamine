options no_aot
require ecs
require math.color
require DagorDebug3D
require DagorConsole

[console_cmd(name="patroller.draw_waypoints")]
def set_patroller_draw_waypoints(value : bool = true)
  query() <| $ [es(REQUIRE=patroller__waypoints)] (eid : EntityId)
    if value
      addSubTemplate(eid, "patroller_walker_ai_debug")
    else
      removeSubTemplate(eid, "patroller_walker_ai_debug")


[es(tag=(render), REQUIRE=patroller__drawWaypoints, no_order)]
def patroller_draw_waypoints(act : UpdateStageInfoRenderDebug; eid : EntityId;
                             transform : float3x4;
                             patroller__currentWaypoint : float3;
                             patroller__waypoints : Point3List)
  if length(patroller__waypoints) == 0
    return
  var camPos : float3
  find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if camera__active
      camPos = transform[3]
    return camera__active
  begin_draw_cached_debug_lines(true, false, false)
  var seed = int(uint(eid))
  let color = rnd_color(seed)
  var begin = patroller__waypoints[0]
  for i, it in iter_range(patroller__waypoints), patroller__waypoints
    draw_cached_debug_line(begin, it, color)
    if distance_sq(camPos, it) < 225f
      add_debug_text_mark(it, "{i}", -1, 0f, color)
    begin = it

  draw_cached_debug_line(transform[3], patroller__currentWaypoint, color)
  end_draw_cached_debug_lines()