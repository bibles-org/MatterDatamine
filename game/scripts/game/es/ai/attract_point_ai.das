require app
require ecs
require ecs.common
require DagorMath
require game.es.ai.attract_point_common
require pathfinder


[es(tag=server, on_appear)]
def init_attract_point_watcher(evt : Event; eid : EntityId; attract_point__checkInterval : float;
                               var attract_point__nextCheck : float&)
  attract_point__nextCheck = get_sync_time() + attract_point__checkInterval * eid_frnd(eid)


[es(tag=server, after=init_attract_point_watcher, REQUIRE_NOT=sleeping_monster)]
def update_attract_point_watcher(act : UpdateStageInfoAct; eid : EntityId;
                                 attract_point__checkInterval : float;
                                 var attract_point__nextCheck : float&;
                                 transform : float3x4; attract_point__searchRadius : float;
                                 entity_mods__attractPointSearchRadiusMult : float = 1f;
                                 attract_point__checkPath : bool;
                                 navmesh_phys__currentPoly : int64 const?;
                                 var attract_point__eid : EntityId&;
                                 var attract_point__distanceTime : float&;
                                 var attract_point__targetPos : float3&;
                                 var attract_point__ratio : float&)
  if act.curTime < attract_point__nextCheck
    return
  attract_point__nextCheck = act.curTime + attract_point__checkInterval
  attract_point__eid = INVALID_ENTITY_ID

  let searchRadius = attract_point__searchRadius * entity_mods__attractPointSearchRadiusMult
  let point = get_nearest_attract_point(eid, transform[3], dtPolyRef(navmesh_phys__currentPoly ?? int64(INVALID_POLY_REF)), searchRadius, attract_point__checkPath)
  if point is pos
    let data = point as pos
    attract_point__eid = data.eid
    attract_point__targetPos = data.targetPos
    attract_point__distanceTime = safediv(sqrt(data.distSq), sqrt(data.radiusSq))
    attract_point__ratio = data.ratio