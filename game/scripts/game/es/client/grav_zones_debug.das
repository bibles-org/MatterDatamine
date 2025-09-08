options no_aot
require ecs
require DagorDebug3D
require DagorRandom
require DagorMath
require math.base
require game.es.grav_zones_common


def get_random_circle_point(var seed : int&) : float2
  let t = 2.0 * PI * _frnd(seed)
  let u = _frnd(seed) + _frnd(seed)
  let r = u > 1.0 ? 2.0 - u : u
  return float2(r * cos(t), r * sin(t))


def draw_grav_sphere_zones()
  query() <| $ [es] (eid : EntityId;
                     transform : float3x4;
                     grav_zone__outerRadius : float;
                     grav_zone__innerRadius : float;
                     grav_zone__type : int)
    set_cached_debug_lines_wtm(transform)
    var seed = int(uint(eid))
    for i in range(250)
      let pt = get_random_circle_point(seed)
      let vertComp = sqrt(1.0 - length_sq(pt))
      let normBotPos = float3(pt.x, -vertComp, pt.y)
      let normTopPos = float3(pt.x, +vertComp, pt.y)
      let inBotPos = normBotPos * grav_zone__innerRadius
      let inTopPos = normTopPos * grav_zone__innerRadius
      let outBotPos = normBotPos * grav_zone__outerRadius
      let outTopPos = normTopPos * grav_zone__outerRadius

      if grav_zone__type == int(GravityZoneType.LINEAR)
        draw_cached_debug_line(inBotPos, inTopPos, E3DCOLOR(0x400000ff))
        draw_cached_debug_line(outBotPos, outTopPos, E3DCOLOR(0x4000ffff))
      elif grav_zone__type == int(GravityZoneType.RADIAL) || grav_zone__type == int(GravityZoneType.RADIAL_INVERTED)
        let centerPos = float3(0.0)
        let inPos = i % 2 == 0 ? inBotPos : inTopPos
        let outPos = i % 2 == 0 ? outBotPos : outTopPos
        draw_cached_debug_line(centerPos, inPos, E3DCOLOR(0x400000ff))
        draw_cached_debug_line(outPos, centerPos, E3DCOLOR(0x4000ffff))

    set_cached_debug_lines_wtm(IDENT_TM)
    draw_cached_debug_sphere(transform[3], grav_zone__innerRadius, E3DCOLOR(0xC30000FF), 24)
    draw_cached_debug_sphere(transform[3], grav_zone__outerRadius, E3DCOLOR(0xC300FFFF), 24)


def draw_grav_box_zones()
  find_query() <| $ [es] (camera__active : bool;
                          transform aka camera_transform : float3x4)
    if !camera__active
      return false

    query() <| $ [es] (transform aka grav_zone_transform : float3x4;
                       grav_zone__itm : float3x4;
                       gravity_zone__boxSize : float3;
                       grav_zone__precalcScale : float3;
                       grav_zone__boxBorderX : float2;
                       grav_zone__boxBorderY : float2;
                       grav_zone__boxBorderZ : float2;
                       grav_zone__type : int)
      if distance_sq(grav_zone_transform[3], camera_transform[3]) > square(100.0)
        return

      let boxHalfSize = gravity_zone__boxSize * 0.5
      let box = BBox3(-boxHalfSize, boxHalfSize)
      draw_debug_box_buffered(box, grav_zone_transform, E3DCOLOR(0xC300FFFF), 1)
      let topLS = float3(grav_zone__boxBorderX.y, grav_zone__boxBorderY.y, grav_zone__boxBorderZ.y) / grav_zone__precalcScale
      let botLS = float3(grav_zone__boxBorderX.x, grav_zone__boxBorderY.x, grav_zone__boxBorderZ.x) / grav_zone__precalcScale

      let innerBox = BBox3(-boxHalfSize + botLS, boxHalfSize - topLS)
      draw_debug_box_buffered(innerBox, grav_zone_transform, E3DCOLOR(0xC3B7FF00), 1)

      set_cached_debug_lines_wtm(grav_zone_transform)

      if grav_zone__type == int(GravityZoneType.LINEAR)
        let distancePerLine = float2(0.2) / grav_zone__precalcScale.xz
        let linesCount = clamp(int2(ceili(safediv(gravity_zone__boxSize.x, distancePerLine.x)),
                                    ceili(safediv(gravity_zone__boxSize.z, distancePerLine.y))),
                              int2(4),
                              int2(100))
        let linesStep = float2(gravity_zone__boxSize.x / float(linesCount.x),
                              gravity_zone__boxSize.z / float(linesCount.y))

        for i in range(linesCount.x)
          for j in range(linesCount.y)
            let relOfs = float2(i, j) * linesStep - float2(boxHalfSize.x, boxHalfSize.z)
            let botPos = float3(relOfs.x, -boxHalfSize.y + FLT_EPSILON, relOfs.y)
            let k =  min(safediv(gravity_zone__boxSize * 0.5 - botPos, topLS), safediv(gravity_zone__boxSize * 0.5 + botPos, botLS), float3(1.f))
            let wt = k.x * k.y * k.z
            var topPos = float3(0.0)
            if wt >= 1.f
              topPos = float3(relOfs.x, boxHalfSize.y, relOfs.y)
              draw_cached_debug_line(topPos, botPos, E3DCOLOR(0x400059FF))
            else
              let up = float3(0, 1, 0)
              let boxGrav = normalize(grav_zone_transform[1])
              let rotAxis = normalize(cross(up, boxGrav))
              let dir = slerp(dir_and_up_to_quat(up, rotAxis), dir_and_up_to_quat(boxGrav, rotAxis), wt) |> quat_get_forward()
              topPos = botPos + rotate(grav_zone__itm, dir)
              draw_cached_debug_line(topPos, botPos, E3DCOLOR(0xFFFF0000))

      elif grav_zone__type == int(GravityZoneType.RADIAL)
        let center = float3()
        let corners = fixed_array(
          float3(boxHalfSize.x, boxHalfSize.y, boxHalfSize.z),
          float3(-boxHalfSize.x, boxHalfSize.y, boxHalfSize.z),
          float3(boxHalfSize.x, -boxHalfSize.y, boxHalfSize.z),
          float3(boxHalfSize.x, boxHalfSize.y, -boxHalfSize.z),
          float3(-boxHalfSize.x, -boxHalfSize.y, boxHalfSize.z),
          float3(boxHalfSize.x, -boxHalfSize.y, -boxHalfSize.z),
          float3(-boxHalfSize.x, boxHalfSize.y, -boxHalfSize.z),
          float3(-boxHalfSize.x, -boxHalfSize.y, -boxHalfSize.z))

        for corner in corners
          draw_cached_debug_line(corner, center, E3DCOLOR(0x400059FF))

      set_cached_debug_lines_wtm(IDENT_TM)
    return true


def draw_grav_cylindric_zones()
  query() <| $ [es] (transform : float3x4;
                     grav_zone__length, grav_zone__radius : float)
    let sectors = 12
    draw_debug_circle_buffered(transform[3] - transform[2] * grav_zone__length, transform[2], grav_zone__radius,
      E3DCOLOR(0xC300FFFF), sectors, 1)
    draw_debug_circle_buffered(transform[3] + transform[2] * grav_zone__length, transform[2], grav_zone__radius,
      E3DCOLOR(0xC300FFFF), sectors, 1)
    for i in range(sectors)
      let q = quat(transform[2], float(i) * TWOPI / float(sectors))
      let a = transform[3] + q * transform[1] * grav_zone__radius - transform[2] * grav_zone__length
      let b = transform[3] + q * transform[1] * grav_zone__radius + transform[2] * grav_zone__length
      draw_debug_line_buffered(a, b, E3DCOLOR(0xC300FFFF), 1)


def draw_all_grav_zones()
  begin_draw_cached_debug_lines(true, true, false)
  draw_grav_sphere_zones()
  draw_grav_box_zones()
  draw_grav_cylindric_zones()
  end_draw_cached_debug_lines()


[es(no_order, REQUIRE=(daeditor__selected, grav_zone__outerRadius))]
def debug_grav_sphere(info : UpdateStageInfoRenderDebug)
  draw_all_grav_zones()


[es(no_order, REQUIRE=(daeditor__selected, gravity_zone__boxSize))]
def debug_grav_box(info : UpdateStageInfoRenderDebug)
  draw_all_grav_zones()


[es(no_order, REQUIRE=(daeditor__selected, grav_zone__radius))]
def debug_grav_cylinder(info : UpdateStageInfoRenderDebug)
  draw_all_grav_zones()
