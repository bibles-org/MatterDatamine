require ecs
require Dacoll
require CollRes
require Grid
require DagorMath
require DagorMathUtils
require game.es.use_query_params_common


[es(REQUIRE=hero, after=(hero_human_use_door_object_es, hero_human_pre_use_object_es), before=hero_human_final_use_object_sync)]
def hero_human_use_drone_es(info : UpdateStageInfoAct;
                            eid : EntityId;
                            human_weap__throwMode : bool;
                            human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                            human_use_object__lockVehicleUse : bool = false;
                            var human_use_object__selectedObject : EntityId&)
  if human_use_object__selectedObject != INVALID_ENTITY_ID
    return

  let canGetDrone = !human_use_object__lockVehicleUse && human_attached_gun__attachedGunEid == INVALID_ENTITY_ID && !human_weap__throwMode
  if !canGetDrone
    return

  let params = get_use_query_params(eid)
  let traceDir = params.dir
  let tracePos = params.pos
  let dist = params.dist.x
  let traceEnd = tracePos + traceDir * dist

  var bestDistSq = FLT_MAX
  for_each_entity_in_grid(ecs_hash("vehicles"), tracePos, traceDir, dist, 0.0, GridEntCheck.BOUNDING) <| $(droneEid : EntityId)
    query(droneEid) <| $ [es(REQUIRE=isDrone)] (collres : CollisionResource;
                                                transform : float3x4;
                                                isAlive : bool = true)
      if !isAlive
        return

      // This instead of collres to still interact with drone when looking through holes in the hull
      let bbox3 = transform * BBox3(collres.vFullBBox)
      let isIntersectingBbox = test_segment_box_intersection(tracePos, traceEnd, bbox3)
      if !isIntersectingBbox
        return

      let toCenter = transform[3] - tracePos
      let toCenterDist = length(toCenter)
      let toCenterNormalized = toCenter / toCenterDist

      // drone have animchar instead of RI, so are not visible in rayhit
      let traceReduceK = 0.9 // needed to more reliably hit nothing, as transform[3] is often placed directly on the ground
      let isVisible = !rayhit_normalized(tracePos, toCenterNormalized, toCenterDist * traceReduceK, ETF_DEFAULT, -1)
      if !isVisible
        return

      let distSq = distance_sq(transform[3], tracePos)
      if distSq < bestDistSq
        human_use_object__selectedObject = droneEid
        bestDistSq = distSq