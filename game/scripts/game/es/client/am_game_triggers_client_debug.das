options no_aot
require ecs
require ecs.safe
require ecs.soa_template
require ecs.ecs_template
require game.utils.hero
require math.base
require DagorConsole
require DagorDebug3D
require DagorSystem
require game.es.use_query_params_common


[ecs_template]
struct game_trigger_debug_draw
  game_trigger__debugDraw : bool = false


[console_cmd(name="game_trigger.debug_draw")]
def game_trigger_debug_draw_cmd(draw : bool = true)
  let tmpl = "game_trigger_debug_draw"
  addSubTemplate(get_controlled_hero(), tmpl) <| $(var init)
    set(init, "game_trigger__debugDraw", draw)


[es(tag=render, tag=dev, no_order)]
def game_trigger_debug_es(evt : UpdateStageInfoRenderDebug;
                          game_trigger__debugDraw : bool)
  if !game_trigger__debugDraw
    return
  query() <| $ [es(REQUIRE=watchedByPlr)] (human_use_object__useMinMaxDist : float2)
    // Draw game trigger sources
    query() <| $ [es(REQUIRE=usableObject)] (transform : float3x4;
                                             use_object__enabled : bool;
                                             use_object__offset : float3;
                                             use_object__obbMin, use_object__obbMax : float3 const?;
                                             item_in_world : Tag const?;
                                             game_interactable_object__eventTrigger : string)
      let color = use_object__enabled ? E3DCOLOR(0xFF00F7FF) : E3DCOLOR(0xFF969696)

      let interactPos = transform[3] + rotate(transform, use_object__offset)
      let useBBox = use_object__obbMin != null && use_object__obbMax != null
      if useBBox && item_in_world == null
        var vec = *use_object__obbMax - *use_object__obbMin
        vec[0] = sign(vec[0])
        vec[1] = sign(vec[1])
        vec[2] = sign(vec[2])
        let boxMin = BBox3(*use_object__obbMin - vec * human_use_object__useMinMaxDist.x, *use_object__obbMax + vec * human_use_object__useMinMaxDist.x)
        draw_debug_box_buffered(boxMin, transform, color, 1)
      else
        draw_debug_sphere_buffered(interactPos, human_use_object__useMinMaxDist.x, color, 36, 1)
      add_debug_text_mark(interactPos, game_interactable_object__eventTrigger, -1, 0.0, color)
