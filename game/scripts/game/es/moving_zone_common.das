module moving_zone_common shared
require ecs
require Dacoll
require DagorRandom
require math
require math.base

let
  HUGE_ZONE_RADIUS = 10e8
  SAFE_ZONE_COEFF = 1.0

struct MovingZone
  pos : float3
  radius : float


def MovingZone()
  return <- MovingZone(uninitialized pos = float3(), radius = HUGE_ZONE_RADIUS)


def is_valid(zone : MovingZone)
  return zone.radius < HUGE_ZONE_RADIUS


def is_moving_zone_generated() : bool
  var res = false
  find_query() <| $ [es] (moving_zone__generated : bool)
    res = moving_zone__generated
    return true
  return res


 // generation param starts from 1, zero means all map
def get_moving_zone(generation : int) : MovingZone
  var res = MovingZone()
  if generation <= 0
    return res
  let idx = generation - 1
  find_query() <| $ [es] (moving_zone__generations : Array)
    if length(moving_zone__generations) > idx
      let data = get_ecs_object(moving_zone__generations[idx])
      res.pos = get_Point3(data, "pos") ?? res.pos
      res.radius = get_float(data, "radius") ?? res.radius
    return true
  return res


def get_moving_zone_generation() : int
  var res = 0
  find_query() <| $ [es] (moving_zone__generation : int)
    res = moving_zone__generation
    return true
  return res


def get_target_moving_zone() : MovingZone
  var res = MovingZone()
  find_query() <| $ [es] (moving_zone__targetRadius : float; moving_zone__targetPos : float3)
    res.pos = moving_zone__targetPos
    res.radius = moving_zone__targetRadius
    return true
  return res


def get_current_moving_zone() : MovingZone
  var res = MovingZone()
  find_query() <| $ [es(REQUIRE=moving_zone__targetPos)] (sphere_zone__radius : float; transform : float3x4)
    res.pos = transform[3]
    res.radius = sphere_zone__radius
    return true
  return res


def inside_zone(zone : MovingZone; pos : float3)
  return distance_sq(zone.pos, pos) < square(zone.radius)
