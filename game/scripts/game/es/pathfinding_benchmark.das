require ecs
require ecs.common
require pathfinder
require math.base
require DagorMath
require DagorRandom
require DagorSystem
require math.random
require game.es.level_common
require game.es.ai.agent_position_mapping_common

def wake_me_up_when_benchmark_prerequisites_are_loaded(eid : EntityId)
  var prereqLoaded = false
  find_query() <| $ [es] (var level__retriggerEids : EidList;
                          level__gameObjectsEntitiesCreated : bool;
                          level__navmeshIslandsMarked : bool;
                          level__movingZoneInited : bool;
                          level__levelLoaded : bool;
                          level__navmeshIslandsMarkerAppeared : bool)
    prereqLoaded = (level__gameObjectsEntitiesCreated &&
                    level__levelLoaded &&
                    level__movingZoneInited &&
                    level__navmeshIslandsMarked == level__navmeshIslandsMarkerAppeared)
    if !prereqLoaded
      level__retriggerEids |> push(eid)
    return true
  return !prereqLoaded


[es(tag=(server, dev), on_appear, on_event=EventRetriggerEntity)]
def init_pathfinding_benchmark(evt : Event;
                               eid : EntityId;
                               pathfinding_benchmark__pointsCount : int;
                               pathfinding_benchmark__agentCount : int;
                               var pathfinding_benchmark__seed : int&;
                               var pathfinding_benchmark__spawnsLeft : int&;
                               var pathfinding_benchmark__points : Point3List)
  if wake_me_up_when_benchmark_prerequisites_are_loaded(eid)
    return
  find_query() <| $ [es(REQUIRE=moving_zone__startEndTime)] (sphere_zone__radius : float; transform : float3x4)
    var tries = pathfinding_benchmark__pointsCount * 10
    while tries-- > 0 && length(pathfinding_benchmark__points) < pathfinding_benchmark__pointsCount
      let p2 = rnd_point_on_disk(pathfinding_benchmark__seed, sphere_zone__radius)
      var pos = float3(p2.x, .0, p2.y) + transform[3]
      if navmesh_mapping_find_best_zone_for_position(pos) != INVALID_ENTITY_ID
        continue
      var poly : dtPolyRef
      if project_to_nearest_navmesh_point(pos, float3(5, 100, 5), poly)
        if navmesh_mapping_find_best_zone_for_position(pos) != INVALID_ENTITY_ID
          continue
        if !is_polygon_accessible(poly)
          continue
        pathfinding_benchmark__points |> push(pos)
    return true
  if length(pathfinding_benchmark__points) == pathfinding_benchmark__pointsCount
    pathfinding_benchmark__spawnsLeft = pathfinding_benchmark__agentCount
  else
    logerr("Failed to find enough nav points for benchmark. {length(pathfinding_benchmark__points)} < {pathfinding_benchmark__pointsCount}")


[es(tag=(server, dev), no_order)]
def pathfinding_benchmark_update(act : UpdateStageInfoAct;
                                 pathfinding_benchmark__pointsPerAgent : int;
                                 pathfinding_benchmark__agentTemplate : string;
                                 pathfinding_benchmark__behTree : string;
                                 pathfinding_benchmark__points : Point3List;
                                 var pathfinding_benchmark__seed : int&;
                                 var pathfinding_benchmark__spawnsLeft : int&)
  if pathfinding_benchmark__spawnsLeft > 0
    pathfinding_benchmark__spawnsLeft--
    using() <| $(var list : Point3List)
      for _ in range(pathfinding_benchmark__pointsPerAgent)
        let idx = _rnd_int(pathfinding_benchmark__seed, 0, length(pathfinding_benchmark__points) - 1)
        list |> push(pathfinding_benchmark__points[idx])
      let finalTemplate = add_sub_template_name(pathfinding_benchmark__agentTemplate, "benchmarked_agent")
      createEntity(finalTemplate) <| $(init)
        var tm = IDENT_TM
        tm[3] = list[0]
        init |> set("transform", tm)
        init |> set("benchmarked_agent__points", list)
        init |> set("beh_tree__node", pathfinding_benchmark__behTree)
        init |> set("benchmarked_agent__targetPos", list[1])