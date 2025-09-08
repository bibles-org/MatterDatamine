options no_aot

require ecs
require DagorConsole
require DagorDebug3D
require Dacoll
require DagorMath
require math.base
require danetlibs.weaponry_hit_fx.render.falling_piece_common

let ZERO_POINT = float3(0.0, 0.0, 0.0)

[console_cmd(name="falling_piece.spawn")]
def console_falling_piece_spawn(effect_template : string = "flamethrower_flame_stream_effect")
  var tracePos : float3
  var traceDir : float3

  let shouldSpawn = find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if !camera__active
      return false
    traceDir = transform[2]
    tracePos = transform[3]
    return true

  if !shouldSpawn
    return

  var len = 4000f
  var norm : float3

  if !traceray_normalized(tracePos, traceDir, len, norm, ETF_ALL)
    return

  let intersectPos = tracePos + traceDir * len
  spawn_falling_piece(effect_template, 10.0, 1.0, intersectPos, norm) <| $ [unused_argument(init)] (init)
    pass

[console_cmd(name="falling_piece.debug")]
def falling_piece_debug()
  let found = find_query() <| $ [es(REQUIRE=falling_piece_debug)] (eid : EntityId)
    destroyEntity(eid)
    return true

  if !found
    createEntity("falling_piece_debug")

[es(tag=dev, tag=render, no_order, REQUIRE=falling_piece_debug)]
def falling_piece_debug_draw_es(evt : UpdateStageInfoRenderDebug)
  begin_draw_cached_debug_lines(true, true, false)

  query() <| $ [es] (eid : EntityId; transform : float3x4; falling_piece__debug_radius : float)
    let templateName = getEntityTemplateName(eid)
    let fragmentColor = E3DCOLOR(0xFFFFFFFF)
    set_cached_debug_lines_wtm(transform)
    draw_cached_debug_sphere(ZERO_POINT, falling_piece__debug_radius, fragmentColor, 8)
    add_debug_text_mark(transform[3], templateName, -1, 0f, fragmentColor)

  set_cached_debug_lines_wtm(IDENT_TM)
  end_draw_cached_debug_lines()