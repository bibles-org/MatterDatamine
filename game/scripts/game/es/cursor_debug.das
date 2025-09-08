options no_aot
require app
require ecs
require ecs.common
require Dacoll
require DagorConsole
require DagorSystem
require DagorMath
require DagorDebug3D
require DagorDebug3DSolid
require game.es.net_console_macro


[es(tag=(dev, gameClient), no_order)]
def draw_cursor_tm(act : UpdateStageInfoAct; transform : float3x4; cursor_tm__color : E3DCOLOR)
  draw_debug_tm_buffered(transform, cursor_tm__color, 1)


[console_cmd(name="cursor.tm_set_p1")]
def console_tm_set_p1()
  query() <| $ [es] (cursor__pos : float3)
    query() <| $ [es] (cursor_tm__alpha : float; cursor_tm__p2 : float3; var cursor_tm__p1 : float3&; var transform : float3x4)
      cursor_tm__p1 = cursor__pos
      if cursor_tm__p2 != float3()
        set_tm_from_p1p2(transform, cursor_tm__p1, cursor_tm__p2, cursor_tm__alpha)


[console_cmd(name="cursor.tm_set_p2")]
def console_tm_set_p2()
  query() <| $ [es] (cursor__pos : float3)
    query() <| $ [es] (cursor_tm__alpha : float; cursor_tm__p1 : float3; var cursor_tm__p2 : float3&; var transform : float3x4)
      cursor_tm__p2 = cursor__pos
      if cursor_tm__p1 != float3()
        set_tm_from_p1p2(transform, cursor_tm__p1, cursor_tm__p2, cursor_tm__alpha)


def set_tm_from_p1p2(var tm : float3x4; p1, p2 : float3; alpha : float)
  tm[3] = (p1 + p2) * 0.5
  let up = float3(0, 1, 0)
  tm[1] = up * (p2.y - p1.y)
  let q = quat(up, PI * 0.5 - alpha)
  let flatVec = p2 - tm[1] - p1
  let ntm0 = normalize(q * flatVec)
  tm[0] = ntm0 * dot(flatVec, ntm0)
  let ntm2 = normalize(cross(tm[0], tm[1]))
  tm[2] = -ntm2 * dot(flatVec, ntm2)


[es(tag=(dev, gameClient), track=cursor_tm__alpha)]
def update_cursor_tm_on_alpha_change(evt : Event; cursor_tm__alpha : float; cursor_tm__p1, cursor_tm__p2 : float3; var transform : float3x4)
  if cursor_tm__p1 != float3() && cursor_tm__p2 != float3()
    set_tm_from_p1p2(transform, cursor_tm__p1, cursor_tm__p2, cursor_tm__alpha)


[console_cmd(name="cursor.toggle_3d_cursor")]
def console_toggle_3d_cursor()
  var hasCursor = false
  query() <| $ [es(REQUIRE=cursor__pos)] (var cursor__enabled : bool&)
    cursor__enabled = !cursor__enabled
    hasCursor = true
  if !hasCursor
    createEntity("cursor_3d")


[es(tag=(dev, gameClient), no_order)]
def debug_draw_3d_cursor(act : UpdateStageInfoAct; cursor__enabled : bool; var cursor__pos : float3&; cursor__camDst : float)
  if cursor__enabled
    let color = E3DCOLOR(0xffffffff)
    query() <| $ [es] (camera__active : bool; transform : float3x4)
      if camera__active
        cursor__pos = transform[3] + transform[2] * cursor__camDst
        draw_debug_sphere_buffered(cursor__pos, 0.3, color, 1)
    var norm : float3
    var t = 100.0
    if traceray_normalized(cursor__pos, float3(0, -1, 0), t, norm, ETF_ALL)
      let pos2 = cursor__pos + float3(0.0, -t, 0.0)
      draw_debug_line_buffered(cursor__pos, pos2, color, 1)
      if t > 2.0
        draw_debug_circle_buffered(cursor__pos + float3(0.0, -t + 2.0, 0.0), float3(0, 1, 0), 0.3, color, 3, 1)
      draw_debug_circle_buffered(cursor__pos + float3(0.0, -t + 0.05, 0.0), float3(0, 1, 0), 0.3, color, 3, 1)
    var i = .0
    while i < 8.0
      if i < t
        draw_debug_circle_buffered(cursor__pos - float3(0.0, i, 0.0), float3(0, 1, 0), 0.04, color, 3, 1)
      draw_debug_circle_buffered(cursor__pos + float3(0.0, i, 0.0), float3(0, 1, 0), 0.04, color, 3, 1)
      i += 1.0

    let pos2 = cursor__pos + float3(0.0, 5.0, 0.0)
    draw_debug_line_buffered(cursor__pos, pos2, color, 1)

    let borders <- fixed_array(2.0, 6.0)
    for b in borders
      let ax1 = float3(b, .0, .0)
      let ax2 = float3(.0, .0, b)
      let lineCol = E3DCOLOR(0x82cccccc)
      draw_debug_line_buffered(cursor__pos + ax1 + ax2, cursor__pos - ax1 + ax2, lineCol, 1)
      draw_debug_line_buffered(cursor__pos - ax1 + ax2, cursor__pos - ax1 - ax2, lineCol, 1)
      draw_debug_line_buffered(cursor__pos - ax1 - ax2, cursor__pos + ax1 - ax2, lineCol, 1)
      draw_debug_line_buffered(cursor__pos + ax1 - ax2, cursor__pos + ax1 + ax2, lineCol, 1)