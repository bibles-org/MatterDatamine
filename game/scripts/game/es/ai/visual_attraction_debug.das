options no_aot
require ecs
require DagorDebug3D
require DagorMath
require DagorConsole

[console_cmd(name="ai.visual_attractive_places")]
def toggle_visual_attract_draw(val = true)
  query() <| $ [es(REQUIRE=visual_attract_point__radius)] (eid : EntityId)
    if val
      addSubTemplate(eid, "visual_attract_point_debug")
    else
      removeSubTemplate(eid, "visual_attract_point_debug")

[es(no_order, tag=(render, dev), REQUIRE=visual_attract_point__debugDraw)]
def visual_attract_draw(act : UpdateStageInfoRenderDebug;
                        transform : float3x4;
                        visual_attract_point__radius : float)
  begin_draw_cached_debug_lines(false, false, false)
  draw_cached_debug_sphere(transform[3], visual_attract_point__radius, E3DCOLOR(0xFF0000FF), 24)
  end_draw_cached_debug_lines()

