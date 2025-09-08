require ecs
require DagorDebug3D
require DagorMath


def draw_box(transform : float3x4; color : E3DCOLOR)
  let corner0 = transform * (float3(-0.5, -0.5, -0.5))
  begin_draw_cached_debug_lines(false, false, false)
  draw_cached_debug_box(corner0, transform[0], transform[1], transform[2], color)
  end_draw_cached_debug_lines()


[es(tag=render, no_order, REQUIRE=box_anomaly__preview)]
def preview_box_anomaly(evt : UpdateStageInfoRenderDebug; transform : float3x4)
  draw_box(transform, E3DCOLOR(0x665EFF00))



[es(tag=render, after=preview_box_anomaly, REQUIRE=box_anomaly_effect__preview)]
def preview_box_anomaly_effect(evt : UpdateStageInfoRenderDebug; game_effect__attachedTo, anomaly_effect__ownerAnomalyEid : EntityId)
  if !has(game_effect__attachedTo, "hero")
    return
  query(anomaly_effect__ownerAnomalyEid) <| $ [es] (transform : float3x4)
    draw_box(transform, E3DCOLOR(0x88FF0000))
