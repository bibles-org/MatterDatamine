options no_aot
require ecs
require ecs.ecs_template
require math.base
require DagorDebug3D
require DagorConsole
require DagorSystem


[ecs_template]
struct dynamic_zone_mode_client_debug_draw
  dynamic_zone_mode_client_debug_draw : Tag


[console_cmd(name="dynamic_zone.debug_draw")]
def dynamic_zone_mode_debug_draw_cmd(dist = 3.0)
  let tmpl = "dynamic_zone_mode_client_debug_draw"
  let exists = find_query() <| $ [es(REQUIRE=dynamic_zone_mode_client_debug_draw)] (eid : EntityId)
    destroyEntity(eid)
    return true

  if !exists
    createEntity(tmpl)


[es(tag=render, tag=dev, no_order, REQUIRE=dynamic_zone_mode_client_debug_draw)]
def dynamic_zone_mode_debug_draw_es(evt : UpdateStageInfoRenderDebug)

  find_query() <| $ [es] (dynamic_zone_controller__shrinksPosAndRadius : Point4List;
                          dynamic_zone_controller__stormZoneEid : EntityId)
    for shrinkData in dynamic_zone_controller__shrinksPosAndRadius
      draw_debug_circle_buffered(shrinkData.xyz, float3(0, 1, 0), shrinkData.w, E3DCOLOR(0xFFFFFFFF), 100, 1)

    query(dynamic_zone_controller__stormZoneEid) <| $ [es] (transform aka zone_transform : float3x4;
                                                            sphere_zone__radius : float)
      draw_debug_circle_buffered(zone_transform[3], float3(0, 1, 0), sphere_zone__radius, E3DCOLOR(0xFF00FF00), 100, 1)

    return true

