module liana_anomaly_common shared
require math
require math.base
require DagorMath

struct Plane
  origin : float3
  side1 : float3
  side2 : float3
  norm : float3
  dimensions : float2
  neighbours : int[4]


let ROT_ORIGIN : float2[4] <- fixed_array<float2>(
    float2(0, 0),
    float2(1, 0),
    float2(1, 1),
    float2(0, 1)
)


def trace_vine(vine; color : E3DCOLOR; draw_joints : bool)
  for i in iter_range(vine)
    if draw_joints
      draw_debug_sphere_buffered(vine[i], 0.05, E3DCOLOR(0xff00ffff), 24, 1)
    if i == 0
      continue
    draw_debug_line_buffered(vine[i - 1], vine[i], color, 1)

def smooth_vine_split_acute_bends(var vine; min_dot : float)
  var i = 1
  while i < length(vine) - 1
    let a = vine[i] - vine[i - 1]
    let b = vine[i + 1] - vine[i]
    if dot(a, b) < min_dot
      vine |> push(vine[i - 1] + a * 0.5, i)
      vine |> push(vine[i + 1] + b * 0.5, i + 1)
      vine |> erase(i + 2)
      i++
    i++

def smooth_vine_equalize_legs(var vine : array<float3>; min_dot : float)
  for i in range(1, length(vine) - 1)
    let a = vine[i] - vine[i - 1]
    let b = vine[i] - vine[i + 1]
    let la = length(a)
    let lb = length(b)
    if la < 0.01 || lb < 0.01
      continue
    //if lenths are significanty different -> move vine[i] along the longer segment until they are equal
    let dotP = dot(a, -b) / la / lb
    if abs(la - lb) > 0.1 && dotP < min_dot
      let greater = max(la, lb)
      let lesser = min(la, lb)
      let subtractRatio = (square(greater) - square(lesser)) / 2.0 / (greater + lesser * dotP) / greater
      let subVec = (la > lb ? a : b) * subtractRatio
      vine[i] -= subVec


def get_neighbour_crisp(planes : array<Plane>; from_plane, to_neighbour : int)
  let from = (ROT_ORIGIN[to_neighbour].x * planes[from_plane].side1 * planes[from_plane].dimensions.x +
                    ROT_ORIGIN[to_neighbour].y * planes[from_plane].side2 * planes[from_plane].dimensions.y)
  let toIdx = (to_neighbour + 1) % length(ROT_ORIGIN)
  let to = (ROT_ORIGIN[toIdx].x * planes[from_plane].side1 * planes[from_plane].dimensions.x +
                    ROT_ORIGIN[toIdx].y * planes[from_plane].side2 * planes[from_plane].dimensions.y)
  return fixed_array<float3>(from, to)


def populate_planes(transform : float3x4; origin_offset : float3 = float3())
  var result : array<Plane>
  let origin = origin_offset + transform[3] - transform[0] * 0.5 - transform[1] * 0.5 - transform[2] * 0.5

  result |> emplace(Plane(side1 = transform[0], side2 = transform[2], origin = origin,
      neighbours <- fixed_array<int>(1, 2, 3, 4)))  // bot
  result |> emplace(Plane(side1 = transform[0], side2 = -transform[1], origin = origin + transform[1],
      neighbours <- fixed_array<int>(5, 2, 0, 4)))  // left side
  result |> emplace(Plane(side1 = transform[1], side2 = transform[2], origin = origin + transform[0],
      neighbours <- fixed_array<int>(1, 5, 3, 0)))  // fwd side
  result |> emplace(Plane(side1 = transform[1], side2 = -transform[0], origin = origin + transform[0] + transform[2],
      neighbours <- fixed_array<int>(2, 5, 4, 0)))  // right side
  result |> emplace(Plane(side1 = transform[1], side2 = -transform[2], origin = origin + transform[2],
      neighbours <- fixed_array<int>(3, 5, 1, 0)))  // back side
  result |> emplace(Plane(side1 = transform[2], side2 = transform[0], origin = origin + transform[1],
      neighbours <- fixed_array<int>(4, 3, 2, 1)))  // top
  for p in result
    p.norm = normalize(cross(p.side1, p.side2))
    p.dimensions = float2(length(p.side1), length(p.side2))
    p.side1 = normalize(p.side1)
    p.side2 = normalize(p.side2)
  return <- result