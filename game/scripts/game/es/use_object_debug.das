options no_aot

require ecs
require strings
require math.base
require DagorConsole
require DagorDebug3D
require ecs.ecs_template
require game.es.use_query_params_common


[es(tag=(dev, render), no_order, REQUIRE=(daeditor__selected, usableObject))]
def use_object_radius_debug(info : UpdateStageInfoRenderDebug;
                            transform : float3x4;
                            use_object__obbMin, use_object__obbMax : float3 const?;
                            use_object__offset : float3 const?;
                            item_in_world : Tag const?)
  let interactPoint = use_object__offset != null ? transform * (*use_object__offset) : transform[3]
  let useBBox = use_object__obbMin != null && use_object__obbMax != null
  query() <| $ [es(REQUIRE=watchedByPlr)] (human_use_object__useMinMaxDist : float2)
    if useBBox && item_in_world == null
      var vec = *use_object__obbMax - *use_object__obbMin
      vec[0] = sign(vec[0])
      vec[1] = sign(vec[1])
      vec[2] = sign(vec[2])
      let boxMin = BBox3(*use_object__obbMin - vec * human_use_object__useMinMaxDist.x, *use_object__obbMax + vec * human_use_object__useMinMaxDist.x)
      draw_debug_box_buffered(boxMin, transform, E3DCOLOR(0xFFFF0000), 1)
    else
      draw_debug_sphere_buffered(interactPoint, human_use_object__useMinMaxDist.x, E3DCOLOR(0xFFFF0000), 12, 1)
