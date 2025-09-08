module wandering_core_common shared
require ecs
require ecs.common
require app
require math.base
require math.random
require DagorMath
require Grid
require game.es.am_debug_draw_common

def pos_to_grid_cell(pos : float3; grid_min : float3; cell_size : float; size_x)
  let relPos = pos - grid_min
  let x = int(floor(relPos.x / cell_size))
  let z = int(floor(relPos.z / cell_size))
  return z * size_x + x


def grid_cell_to_pos(idx : int; y : float; grid_min : float3; cell_size : float; size_x : int)
  let z = idx / size_x
  let x = idx % size_x
  let posX = grid_min.x + (float(x) + 0.5) * cell_size
  let posZ = grid_min.z + (float(z) + 0.5) * cell_size
  return float3(posX, y, posZ)


def wandering_core_time_dependent_seed(eid : EntityId; time : float)
  return int(float(uint(eid) % 1000u) + time * (0.5 + eid_frnd(eid)))


def init_curiosity_cell(core_eid : EntityId)
  var success = false
  query(core_eid) <| $ [es] (transform : float3x4;
                             curious_core__distanceWeight : float;
                             curious_core__gridCellSize : float;
                             curious_core__defaultWeight : float;
                             curious_core__amWeight : float;
                             curious_core__gridSizeX : int;
                             curious_core__gridMin : float3;
                             curious_core__gridMax : float3;
                             curious_core__grid : FloatList;
                             var curious_core__curiosityCell : int&)
    var weights : array<float>
    for cell, i in curious_core__grid, iter_range(curious_core__grid)
      let pos = grid_cell_to_pos(i, transform[3].y, curious_core__gridMin, curious_core__gridCellSize, curious_core__gridSizeX)
      var v = distance(pos, transform[3]) * curious_core__distanceWeight / curious_core__gridCellSize
      v += cell
      weights |> push(-v + curious_core__defaultWeight)
    let bbox = BBox3(curious_core__gridMin, curious_core__gridMax)
    let hashes = fixed_array(ecs_hash("humans"), ecs_hash("interactable"), ecs_hash("humans"))
    for h in hashes
      add_weight_from_am_source(weights,
                                h,
                                bbox, curious_core__gridMin,
                                curious_core__gridCellSize,
                                curious_core__gridSizeX,
                                curious_core__amWeight)
    let debugDraw = find_query() <| $ [es] (dev_draw__wanderingCore : bool)
      return dev_draw__wanderingCore
    var hasPositive = false
    for cell, i in weights, iter_range(weights)
      if cell < .0
        cell = .0
      else
        hasPositive = true
      if debugDraw
        let cellPos = grid_cell_to_pos(i, transform[3].y, curious_core__gridMin, curious_core__gridCellSize, curious_core__gridSizeX)
        let color = cell > .0 ? ACYELLOW : ACGRAY
        draw_debug_text_mark_buffered(cellPos, "{int(ceil(cell))}", 200, color)

    if hasPositive
      var seed = wandering_core_time_dependent_seed(core_eid, get_sync_time() + 10.0)
      curious_core__curiosityCell = choose_weight(seed, weights)
      let p = grid_cell_to_pos(curious_core__curiosityCell, transform[3].y, curious_core__gridMin, curious_core__gridCellSize, curious_core__gridSizeX)
      if debugDraw
        draw_debug_sphere_buffered(p, 2.0, ACWHITE, 24, 1000)
        draw_debug_line_buffered(p, p + float3(0, 100, 0), ACWHITE, 1000)
      success = true
  return success


def private add_weight_from_am_source(var weights : array<float>;
                                      grid_hash : uint;
                                      bbox : BBox3;
                                      grid_min : float3;
                                      cell_size : float;
                                      size_x : int;
                                      mult : float)
  for_each_entity_in_grid(grid_hash, bbox, GridEntCheck.POS) <| $(eid : EntityId)
    query(eid) <| $ [es(REQUIRE=chargesWanderingCore)] (transform : float3x4;
                                                        am_storage__value : int = 0;
                                                        item__count : int = 0;
                                                        wandering_core_am_equivalent__value = 0)
      let am = am_storage__value + item__count + wandering_core_am_equivalent__value
      if am > 0
        let idx = pos_to_grid_cell(transform[3], grid_min, cell_size, size_x)
        if idx >= 0 && idx < length(weights)
          weights[idx] += float(am) * mult


def find_nearest_waypoint(pos : float3; waypoints : Point3List; waypoints_transform : float3x4; local_space : bool)
  var bestIdx = -1
  var bestDstSq = FLT_MAX
  for wp, wpIdx in waypoints, iter_range(waypoints)
    let p = local_space ? waypoints_transform * wp : wp
    let dstSq = distance_sq(p, pos)
    if dstSq < bestDstSq
      bestDstSq = dstSq
      bestIdx = wpIdx
  return sqrt(bestDstSq), bestIdx