options no_aot
require ecs
require DagorConsole
require DagorDebug3D


[console_cmd(name="am.drawFlyingSwarmMovePath")]
def drawFlyingSwarmMovePath()
  let isDrawing = find_query() <| $ [es(REQUIRE=am_draw_flying_swarm_move_path)] ()
    return true
  query() <| $ [es(REQUIRE=swarm_cluster__targetPos)] (eid : EntityId)
    if isDrawing
      removeSubTemplate(eid, "am_draw_flying_swarm_move_path")
    else
      addSubTemplate(eid, "am_draw_flying_swarm_move_path")


[es(tag=gameClient, REQUIRE=am_draw_flying_swarm_move_path, no_order)]
def drawingFlyingSwarmMovePath(act : UpdateStageInfoAct; swarm_cluster__targetPos : float3; transform : float3x4; radius : float)
  draw_debug_line_buffered(transform[3], swarm_cluster__targetPos, E3DCOLOR(0xFF0000FF), 1)
  draw_debug_sphere_buffered(transform[3], radius, E3DCOLOR(0xFFFFA600), 12, 1)
