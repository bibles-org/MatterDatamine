module custom_region_common shared
require ecs
require Dacoll
require DagorMath
require math.random


def private point_sign(p1, p2, p3 : float2)
  return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)


def is_point_inside_triangle(point, a, b, c : float2)
  let d1 = point_sign(point, a, b)
  let d2 = point_sign(point, b, c)
  let d3 = point_sign(point, c, a)

  let hasNeg = (d1 < 0.0) || (d2 < 0.0) || (d3 < 0.0)
  let hasPos = (d1 > 0.0) || (d2 > 0.0) || (d3 > 0.0)

  return !(hasNeg && hasPos)


def is_point_inside_region(point : float3; points : Point2List; indicies : IntList; bbox : BBox3) : bool
  if !(bbox & point)
    return false
  let point2D = point.xz
  let indiciesLen = length(indicies) / 3
  for i in range(indiciesLen)
    if is_point_inside_triangle(point2D, points[indicies[i * 3]], points[indicies[i * 3 + 1]], points[indicies[i * 3 + 2]])
      return true
  return false


struct RegionCommonData
  center : float3
  area : float
  bbox : BBox3 = BBox3()


def in_region_with_name(region_name : string; cb : block<(points : Point2List; indicies : IntList; commonData : RegionCommonData) : void>)
  find_query() <| $ [es] (custom_region__name : string;
                          custom_region__points : Point2List;
                          custom_region__triangulationIdxs : IntList;
                          custom_region__area : float;
                          transform : float3x4)
    if region_name == custom_region__name
      let bboxDiag = 0.5 * (transform[0] + transform[1] + transform[2])
      let regionCommonData = RegionCommonData(
        center = transform[3],
        area = custom_region__area,
        bbox = BBox3(transform[3] - bboxDiag, transform[3] + bboxDiag)
      )
      cb |> invoke(custom_region__points, custom_region__triangulationIdxs, regionCommonData)
      return true
    return false


def random_point_in_region(points : Point2List; indices : IntList) : float3
  let trianglesCount = length(indices) / 3
  let triangleIdx = rnd_int(0, trianglesCount - 1)
  let a = points[indices[triangleIdx * 3]]
  let b = points[indices[triangleIdx * 3 + 1]]
  let c = points[indices[triangleIdx * 3 + 2]]
  let point = get_random_point_in_triangle(
    float3(a.x, 0.0, a.y),
    float3(b.x, 0.0, b.y),
    float3(c.x, 0.0, c.y)
  )
  let point2D = point.xz
  return float3(point.x, traceht_lmesh(point2D), point.z)
