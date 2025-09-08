options no_aot
require ecs
require math.base
require DagorMath
require DagorDebug3D


[es(tag=render, no_order, REQUIRE=daeditor__selected)]
def trigger_trap_debug(evt : UpdateStageInfoRenderDebug;
                       transform : float3x4;
                       trigger_trap__affectRadius : float)
  draw_debug_sphere_buffered(transform[3], trigger_trap__affectRadius, E3DCOLOR(0xFFFFFF00), 12, 1)


[es(tag=render, no_order, REQUIRE=daeditor__selected)]
def sphere_trigger_trap_debug(evt : UpdateStageInfoRenderDebug;
                              transform : float3x4;
                              sphere_trigger_trap__triggerRadius : float)
  draw_debug_sphere_buffered(transform[3], sphere_trigger_trap__triggerRadius, E3DCOLOR(0xFFFF0000), 12, 1)