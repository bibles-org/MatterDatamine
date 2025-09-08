module regions_common shared
require ecs
require level
require math
require math.base
require DagorMath
require game.es.custom_region_common


def get_region_bbox(region : SplineRegion; vertical_expand : float) : BBox3
  var res = BBox3()
  for it in region.border
    res |> bbox3_add(it)
  res |> bbox3_add(res.center + float3(0.0, -vertical_expand, 0.0))
  res |> bbox3_add(res.center + float3(0.0, vertical_expand, 0.0))
  return res


def generate_region_point_condense_to_center(center : float3; bbox : BBox3; points : Point2List; indices : IntList)
  let radiusSq = square(max(bbox.width.x, bbox.width.z))
  let point0 = random_point_in_region(points, indices)
  let distSq0 = distance_sq(center, point0)
  if distSq0 > radiusSq * square(0.33)
    let point1 = random_point_in_region(points, indices)
    let distSq1 = distance_sq(center, point1)
    if distSq1 > distSq0
      return point0
    elif distSq1 > radiusSq * square(0.67)
      let point2 = random_point_in_region(points, indices)
      let distSq2 = distance_sq(center, point2)
      if distSq2 > distSq1
        return point1
      else
        return point2
    else
      return point1
  return point0