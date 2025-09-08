module am_core_warrior_common shared

require ecs
require math.base
require math.random
require math.linear
require DagorMath
require DagorRandom
require Dacoll
require pathfinder
require math.maybe_pos

enum CoreWarriorState
  IDLE
  CHARGE
  REST
  TRAVEL
  HIDING
  HIDDEN


def add_core_warrior_spawn_positions(origin : float3; radius, min_proximity : float; count, max_attempts : int; var existing_pos : array<float3>)
  let proximitySq = square(min_proximity)
  var attemptsLeft = max_attempts
  let targetCount = length(existing_pos) + count
  while length(existing_pos) < targetCount && attemptsLeft-- > 0
    let pos = try_get_core_warrior_pos(origin, radius, proximitySq, existing_pos)
    if pos is pos
      existing_pos |> push(pos as pos)


def try_get_core_warrior_pos(origin : float3; radius, min_proximity_sq : float; existing_pos : array<float3>) : MaybePos
  let offset = rnd_point_on_disk(radius)
  var pos = origin + float3(offset.x, 0.0, offset.y)
  if project_to_nearest_navmesh_point(pos, min_proximity_sq)
    var success = true
    for p in existing_pos
      if distance_sq(p, pos) < min_proximity_sq
        success = false
        break
    if success
      return MaybePos(pos)
  return MaybePos()


def get_segment_to_disk_intersection_dst(from, to, norm, anchor : float3)
  let d = dot(norm, anchor)
  if abs(dot(norm, to - from)) < FLT_EPSILON
    let intPoint = closest_pt_on_seg(anchor, from, to)
    return distance(anchor, intPoint)
  let t = (d - dot(norm, from)) / dot(norm, to - from)
  if t < 0.0 || t > 1.0
    return FLT_MAX
  let intPoint = from + (from - to) * t
  return distance(anchor, intPoint)


def find_core_warrior_straight_path(from, to : float3; var path : Point3List)
  clear(path)
  let delta = to - from
  let distanceSq = length_sq(delta)
  if distanceSq < 1e-3
    return
  let t = sqrt(distanceSq)
  let dir = delta / t
  if !rayhit_normalized(from, dir, t, ETF_ALL, -1)
    path |> push(to)

def find_core_warrior_arc_path(from, to : float3; var path : Point3List)
  clear(path)
  let pathLen = distance(from, to)
  let legLengthSq = square(min(pathLen * 0.2, 2.0))
  let heightRatio = rnd_float(0.3, 0.6)
  let interCount = 50
  let basisX = to - from
  let tmp = cross(basisX, float3(0, 1, 0))
  let basisY = normalize(cross(basisX, tmp)) * heightRatio * pathLen
  path |> push(from)
  for i in range(interCount - 1)
    let x = float(i + 1) / float(interCount)
    let y = 2.0 * x * x - 2.0 * x
    let pos = from + x * basisX + y * basisY
    let dstSq = distance_sq(path[length(path) - 1], pos)
    if dstSq > legLengthSq
      path |> push(pos)
  path |> push(to)
  path |> erase(0)
  var prev = from
  var success = true
  for p in path
    let delta = p - prev
    let distanceSq = length_sq(delta)
    if distanceSq >= 1e-3
      let t = sqrt(distanceSq)
      let dir = delta / t
      if rayhit_normalized(prev, dir, t, ETF_ALL, -1)
        success = false
        break
    prev = p
  if !success
    clear(path)