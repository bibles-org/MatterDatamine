require ecs
require DagorMath
require math.base
require game.es.moving_zone_common
require game.events.events_active_matter


def ray_intersect_sphere_dist(ray_start, ray_dir, sphere_center : float3; sphere_radius : float) : float // <0 if there is no intersection
  let dir = normalize(ray_dir)
  let p = ray_start - sphere_center
  let b = 2.0 * dot(p, dir)
  let c = dot(p, p) - sphere_radius * sphere_radius
  let d = b * b - 4.0 * c
  if d >= 0.0
    let sq = sqrt(d)
    let v0 = (-b - sq) * 0.5
    let v1 = (-b + sq) * 0.5
    return v0 >= 0.0 ? v0 : max(v0, v1)
  return -1.0


def scratch_sky_pos(var tm : float3x4; align_by_zone : bool; zone : MovingZone)
  let x0z = x0z(tm[3])
  let up = float3(0, 1, 0)
  let intersect = ray_intersect_sphere_dist(x0z, up, zone.pos, zone.radius)
  let pos = x0z + up * (intersect < 0. ? zone.radius : intersect)
  if align_by_zone
    let dir = normalize(zone.pos - pos)
    let q = dir_to_quat(dir)
    make_tm(q, tm)
    swap(tm[0], tm[1]) // effects always look UP, swap X and Y
  tm[3] = pos


[es(tag=render, no_order, REQUIRE=extraction_visual__scratchSkyEffect)]
def update_sky_scratch(act : ParallelUpdateFrameDelayed; extraction_visual__alignByZone : Tag const?; var transform : float3x4)
  transform |> scratch_sky_pos(extraction_visual__alignByZone != null, get_current_moving_zone())
