options no_aot
require ecs
require DagorDebug3D
require DagorMath
require math.base


[es(tag=(dev, render), no_order, REQUIRE=(daeditor__selected, objective_static_target__tag))]
def quest_target_geometry_debug_entity(info : UpdateStageInfoRenderDebug;
                                       transform : float3x4;
                                       quest_target_geometry_sphere__radius  = 0f)
  if quest_target_geometry_sphere__radius > 0f
    draw_debug_sphere_buffered(transform[3], quest_target_geometry_sphere__radius, E3DCOLOR(0xFFFF0000), 12, 1)
  else
    draw_debug_box_buffered(IDENT_BBOX, transform, E3DCOLOR(0xFFFF0000), 1)