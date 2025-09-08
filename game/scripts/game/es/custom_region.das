require ecs
require level
require Dacoll
require DagorMath
require DagorSystem
require game.es.custom_region_common


[es(tag=server, on_appear, on_event=EventLevelLoaded)]
def calc_custom_region_base_params(evt : Event;
                                   custom_region__points : Point2List;
                                   var transform : float3x4&)
  if !is_level_loaded()
    return
  if length(custom_region__points) < 3
    logerr("[Custom Region] Can't create region with only <{length(custom_region__points)}> points. Min requirement is 3.")
    return

  var bbox = BBox3()
  for i in iter_range(custom_region__points)
    bbox |> bbox3_add(float3(custom_region__points[i].x, 0.0, custom_region__points[i].y))
  transform[0] = float3(bbox.width.x, 0.0, 0.0)
  transform[1] = float3(0.0, 100.0, 0.0)
  transform[2] = float3(0.0, 0.0, bbox.width.z)
  transform[3] = float3(bbox.center.x, traceht_lmesh(bbox.center), bbox.center.z)


[es(tag=server, on_appear, on_event=EventLevelLoaded, after=calc_custom_region_base_params)]
def calc_custom_region_extend_params(evt : Event;
                                     custom_region__points : Point2List;
                                     var custom_region__triangulationIdxs : IntList&;
                                     var custom_region__area : float&)
  if !is_level_loaded()
    return
  if length(custom_region__points) < 3
    return

  var points2D : array<float2>
  for point in custom_region__points
    points2D |> push(point)
  custom_region__triangulationIdxs |> clear()
  custom_region__area = 0.0
  triangulate_poly(points2D) <| $(idxs : int3)
    custom_region__triangulationIdxs |> push(idxs[0])
    custom_region__triangulationIdxs |> push(idxs[1])
    custom_region__triangulationIdxs |> push(idxs[2])
    let a = custom_region__points[idxs[0]]
    let b = custom_region__points[idxs[1]]
    let c = custom_region__points[idxs[2]]
    custom_region__area += 0.5 * abs(a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
