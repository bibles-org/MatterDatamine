options no_aot
require app
require ecs
require ecs.safe
require DagorConsole
require DagorDebug3D


def draw_transform_box(transform : float3x4; color : E3DCOLOR)
  let corner0 = transform * (float3(-0.5, -0.5, -0.5))
  begin_draw_cached_debug_lines(false, false, false)
  draw_cached_debug_box(corner0, transform[0], transform[1], transform[2], color)
  end_draw_cached_debug_lines()


[es(tag=render, no_order, REQUIRE=transform__debug_draw)]
def transform_debug_draw(evt : UpdateStageInfoRenderDebug;
                         transform : float3x4;
                         active : bool = true)
  draw_transform_box(transform, active ? E3DCOLOR(0x665EFF00) : E3DCOLOR(0xFFFF0E00))