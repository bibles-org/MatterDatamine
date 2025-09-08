options no_aot
require ecs
require ecs.safe
require ecs.ecs_template
require math
require math.base
require strings
require DagorMath
require DagorConsole
require DagorDebug3D
require walkerai


[ecs_template]
struct ai_target_visibility_debug_draw
  ai_target_visibility__debugDrawDist : float = 50.0


[console_cmd(name="ai_target_visibility.debug_draw")]
def ai_target_visibility_debug_draw_cmd(dist = 50.)
  let tmpl = "ai_target_visibility_debug_draw"
  let exists = find_query() <| $ [es] (eid : EntityId; var ai_target_visibility__debugDrawDist : float&)
    if ai_target_visibility__debugDrawDist == dist
      destroyEntity(eid)
    else
      ai_target_visibility__debugDrawDist = dist
    return true

  if !exists
    createEntity(tmpl) <| $(init)
      init |> set("ai_target_visibility__debugDrawDist", dist)


[es(tag=render, tag=dev, no_order)]
def ai_target_visibility_debug_es(evt : UpdateStageInfoRenderDebug;
                                  ai_target_visibility__debugDrawDist : float)

  find_query() <| $ [es] (camera__active : bool;
                          transform aka camera_transform : float3x4)
    if !camera__active
      return false

    let debugDrawDistSq = square(ai_target_visibility__debugDrawDist)

    query() <| $ [es(REQUIRE_NOT=deadEntity)] (ai_target : Target;
                                               transform aka ai_target_transform : float3x4;
                                               ai_target_visibility_controller__currentLight : float)
      let distSq = distance_sq(camera_transform[3], ai_target_transform[3])
      if distSq > debugDrawDistSq
        return

      let color = E3DCOLOR(0xFFAAFF00)

      let textPoint = ai_target_transform[3] + ai_target_transform[1] * 1.25

      var j = 0
      add_debug_text_mark(textPoint, "Light: {fmt(":.1f", ai_target_visibility_controller__currentLight * 100.0)}%", -1, float(j++), color)
      add_debug_text_mark(textPoint, "Total accuracy shift: {ai_target.accuracyShift}", -1, float(j++), color)

    return true