options no_aot
require ecs
require ecs.common
require app
require math.base
require pathfinder
require DagorSystem
require Dacoll
require DagorConsole
require DagorDebug3D
require game.events.events
require active_matter.game.es.navmesh_nearest_pos_common
require daslib/sort_boost


[es(tag=server, no_order)]
def update_poi_validator(evt : UpdateStageInfoAct; eid : EntityId;
                         poi_validator__poiEids : EidList;
                         var poi_validator__validPos : Point3List;
                         var poi_validator__validPosNext : Point3List;
                         var poi_validator__poiIndex : int&)
  var iterPerFrame = 1
  while iterPerFrame > 0
    if poi_validator__poiIndex >= length(poi_validator__poiEids)
      poi_validator__poiIndex = 0
      poi_validator__validPos := poi_validator__validPosNext
      clear(poi_validator__validPosNext)
      if length(poi_validator__validPos) == 0
        destroyEntity(eid)
        return
    let poiEid = poi_validator__poiEids[poi_validator__poiIndex]
    query(poiEid) <| $ [es] (poi__pos : float3; var poi__isValid : bool&; var poi__navPos : Point3List)
      if poi__isValid
        return
      iterPerFrame--
      qsort(poi_validator__validPos) <| $(lhs : float3; rhs : float3)
        return distance_sq(lhs, poi__pos) < distance_sq(rhs, poi__pos)
      for i in iter_range(poi_validator__validPos)
        if i > 10
          break
        let vp = poi_validator__validPos[i]
        for poip in poi__navPos
          var hasPath = false
          let extents = float3(0.1, FLT_MAX, 0.1)
          using(vp, poip, extents) <| $(var req : FindRequest#)
            let resPath = find_path(req, 1., 1.)
            if resPath == FindPathResult.FPR_FULL
              poi__isValid = true
              push(poi_validator__validPosNext, poip)
              clear(poi__navPos)
              push(poi__navPos, poip)
              hasPath = true
          if hasPath
            break
        if poi__isValid
          return
    poi_validator__poiIndex++
