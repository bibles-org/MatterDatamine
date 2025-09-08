require ecs
require game.es.human.human_use_object_common
require game.events.events
require math.base
require DngCamera
require game.utils.team
require zones
require AnimV20
require GeomNodeTree
require DngWeapon
require DngHuman
require DagorMath
require DagorMathUtils
require Grid
require RendInst
require CollRes
require Dacoll
require GridCollision
require CollisionTraces
require CapsuleApproximation
require game.es.use_query_params_common
require game.es.use_object_common
require game.es.trace_common


struct DoorData
  eid : EntityId
  handle : uint64
  score : float
  dir : float3
  lookAt : bool


def get_cam_itm()
  return get_cur_cam_entity() |> get_TMatrix("transform") ?? IDENT_TM


[es(REQUIRE=hero, after=(hero_human_use_stationary_gun_object_es, hero_human_pre_use_object_es), before=hero_human_final_use_object_sync)]
def hero_human_use_door_object_es(info : UpdateStageInfoAct;
                                  eid : EntityId;
                                  human_use_object__useMinMaxDist : float2;
                                  human_use_object__findDoorRadius : float = 5.0;
                                  human_use_object__doorLimitCosine : float = 0.8;
                                  human_use_object__lockDoorUse : bool = false;
                                  human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                                  var human_use_object__selectedObject : EntityId&;
                                  var human_use_object__lookAtSelected : bool&)
  // We have something better already
  if human_use_object__selectedObject != INVALID_ENTITY_ID || human_use_object__lockDoorUse
    return

  let attachedToGun = human_attached_gun__attachedGunEid != INVALID_ENTITY_ID
  if attachedToGun
    return

  let params = get_use_query_params(eid)
  if !params.canUse
    return
  let traceDir = params.dir
  let tracePos = params.pos

  let traceEnd = tracePos + traceDir * human_use_object__findDoorRadius

  let doorsSphereRadius = human_use_object__findDoorRadius * 0.5
  let doorsSpherePos = tracePos + traceDir * doorsSphereRadius
  let doorsSphere = BSphere3(doorsSpherePos, doorsSphereRadius)
  var doorsData : array<DoorData>
  for_each_entity_in_grid(ecs_hash("doors"), doorsSphere, GridEntCheck.POS) <| $(doorEid : EntityId)
    query(doorEid) <| $ [es(REQUIRE=isDoor, REQUIRE_NOT=interactable__heroEid)] (ri_extra : RiExtraComponent;
                                                                                 use_object__enabled : bool = true; //interactable doors are handled by use_object logic
                                                                                 door_operations__useAimTmForTrace : bool = false)
      if !use_object__enabled
        return
      let riType = int(handle_to_ri_type(ri_extra.handle))
      let collRes = get_rigen_extra_coll_res(riType)
      if collRes == null
        return
      var tm : float3x4
      get_rigen_extra_matrix(ri_extra.handle, tm)

      var wbox = collRes.vFullBBox
      bbox3f_init(wbox, mat44f(tm), collRes.vFullBBox)
      let minDistSq = v_distance_sq_to_bbox(wbox.bmin, wbox.bmax, float4(tracePos, 1.0))
      if minDistSq > square(human_use_object__useMinMaxDist.x)
        return
      let boxCenter = (collRes.vFullBBox.bmin + collRes.vFullBBox.bmax).xyz * 0.5
      let center = tm * boxCenter
      let dir = center - tracePos
      let dot = dot(normalize(dir), traceDir)
      let lookAt = v_test_segment_box_intersection(tracePos, traceEnd, wbox) != 0
      if dot < human_use_object__doorLimitCosine && !lookAt
        return
      let score = 1.0 - dot
      doorsData |> push(
        DoorData(eid = doorEid,
                    handle = ri_extra.handle,
                    score = score,
                    dir = door_operations__useAimTmForTrace ? traceDir * human_use_object__useMinMaxDist.x : dir,
                    lookAt = lookAt))

    sort(doorsData) <| $(a; b)
      return a.score < b.score

    using() <| $(var riDesc : RendInstDesc#)
      for data in doorsData
        let dir = data.dir
        let dirLen = length(dir)
        let dirNormalized = dir * safeinv(dirLen)
        var t = dirLen
        var pmid : int
        var norm : float3
        traceray_normalized(tracePos, dirNormalized, t, pmid, norm, ETF_RI, riDesc, -1)
        if riDesc.isValid && riDesc.isRiExtra && riDesc.riExtraHandle != data.handle
          riDesc |> invalidate()
          continue

        human_use_object__selectedObject = data.eid
        human_use_object__lookAtSelected = data.lookAt
        return


def is_vehicle_has_free_player_seats(vehicle_eid : EntityId;
                                     player_eid : EntityId)
  var seatFound = false
  query(vehicle_eid) <| $ [es] (vehicle_seats__seatEids : EidList)
    for seatEid in vehicle_seats__seatEids
      query(seatEid) <| $ [es] (seats_order__canPlaceManually : bool = true;
                                seat__ownerEid : EntityId = INVALID_ENTITY_ID;
                                seat__playerEid : EntityId = INVALID_ENTITY_ID)
        if (seats_order__canPlaceManually && ((seat__ownerEid == INVALID_ENTITY_ID) || (seat__playerEid == player_eid) ||
            !(get_bool(seat__ownerEid, "isAlive") ?? true)))
          seatFound = true
      if seatFound
        break
  return seatFound


[es(REQUIRE=hero, after=(hero_human_use_door_object_es, hero_human_pre_use_object_es), before=hero_human_final_use_object_sync)]
def hero_human_use_vehicle_object_es(info : UpdateStageInfoAct;
                                     eid : EntityId;
                                     possessedByPlr : EntityId;
                                     human_weap__throwMode : bool;
                                     team aka team_human : int = TEAM_UNASSIGNED;
                                     human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                                     human_use_object__lockVehicleUse : bool = false;
                                     var human_use_object__selectedObject : EntityId&)
  if human_use_object__selectedObject != INVALID_ENTITY_ID
    return

  let canUseVehicles = !human_use_object__lockVehicleUse && human_attached_gun__attachedGunEid == INVALID_ENTITY_ID && !human_weap__throwMode
  if !canUseVehicles
    return

  let params = get_use_query_params(eid)
  let traceDir = params.dir
  let tracePos = params.pos
  let dist = params.dist.x
  let traceEnd = tracePos + traceDir * dist

  var bestDistSq = FLT_MAX
  for_each_entity_in_grid(ecs_hash("vehicles"), tracePos, traceDir, dist, 0.0, GridEntCheck.BOUNDING) <| $(vehicle : EntityId)
    query(vehicle) <| $ [es] (collres : CollisionResource;
                              transform : float3x4;
                              isAlive : bool = true;
                              vehicle_seats__restrictToTeam : int = TEAM_UNASSIGNED)
      if human_use_object__selectedObject != INVALID_ENTITY_ID
        return
      if !isAlive
        return
      if vehicle_seats__restrictToTeam != TEAM_UNASSIGNED && team_human != vehicle_seats__restrictToTeam
        return

      if !is_vehicle_has_free_player_seats(vehicle, possessedByPlr)
        return

      // This instead of collres to still interact with vehicle when looking through holes in the hull
      let bbox3 = transform * BBox3(collres.vFullBBox)
      let isIntersectingBbox = test_segment_box_intersection(tracePos, traceEnd, bbox3)
      if !isIntersectingBbox
        return

      let toCenter = transform[3] - tracePos
      let toCenterDist = length(toCenter)
      let toCenterNormalized = toCenter / toCenterDist

      // vehicles have animchar instead of RI, so are not visible in rayhit
      let traceReduceK = 0.9 // needed to more reliably hit nothing, as transform[3] is often placed directly on the ground
      let isVisible = !rayhit_normalized(tracePos, toCenterNormalized, toCenterDist * traceReduceK, ETF_DEFAULT, -1)
      if !isVisible
        return

      let distSq = distance_sq(transform[3], tracePos)
      if distSq < bestDistSq
        human_use_object__selectedObject = vehicle
        bestDistSq = distSq


[es(REQUIRE=hero, after=(hero_human_pre_use_object_es), before=hero_human_final_use_object_sync)]
def hero_human_use_downed_human_object_es(info : UpdateStageInfoAct;
                                          eid : EntityId;
                                          team aka team_hero : int;
                                          human_reviver__maxDistance : float2 = float2(0.0, 0.0);
                                          human_reviver__maxAngle : float = 45.0;
                                          var human_use_object__selectedObject : EntityId&)
  if human_use_object__selectedObject != INVALID_ENTITY_ID
    return
  let params = get_use_query_params(eid)
  let tracePos = params.pos
  find_query() <| $ [es] (eid : EntityId;
                          team : int;
                          transform : float3x4;
                          isDowned : bool;
                          isAlive : bool)
    if team != team_hero || !isDowned || !isAlive
      return false

    let offset = transform[3] - tracePos
    let dist = length(offset)
    let dir = offset * safeinv(dist)
    if dist > human_reviver__maxDistance.x
      return false

    if dot(params.dir, dir) < cos(deg_to_rad(human_reviver__maxAngle))
      return false
    var t = dist
    var norm : float3
    traceray_normalized(tracePos, dir, t, norm)
    if t - dist > FLT_EPSILON
      return false

    human_use_object__selectedObject = eid
    return true


[es(tag=gameClient, REQUIRE=hero, no_order)]
def hero_human_use_corpse_object_update_offsets(act : UpdateStageInfoAct;
                                                eid aka hero_eid : EntityId;
                                                hero_interactable_offset_update__updateInterval : float;
                                                hero_interactable_offset_update__iteractableRadius : float = 5.0;
                                                var hero_interactable_offset_update__updateAt : float&)
  let params = get_use_query_params(hero_eid)
  if !params.canUse
    return

  if act.curTime < hero_interactable_offset_update__updateAt
    return

  hero_interactable_offset_update__updateAt = act.curTime + hero_interactable_offset_update__updateInterval

  let boundingBox = BBox3(params.pos, hero_interactable_offset_update__iteractableRadius)

  let testPos = params.pos + params.dir * 0.5

  for_each_entity_in_grid(ecs_hash("interactable"), boundingBox, GridEntCheck.POS)  <| $(targetEid : EntityId)
    query(targetEid) <| $ [es(REQUIRE=(clientUsable, lootable_ragdoll_phys_obj))] (use_object__enabled : bool = true;
                                                                                   ragdoll_phys_obj__attachedTo : EntityId;
                                                                                   transform aka phys_obj_transform : float3x4;
                                                                                   var use_object__offset : float3&)
      if !use_object__enabled
        return

      query(ragdoll_phys_obj__attachedTo) <| $ [es] (@shared_comp capsule_approximation : CapsuleApproximation;
                                                     animchar aka corpse_animchar : AnimcharBaseComponent)
        var bestProjDot = -1.0
        var bestProjPoint : float3

        for data in capsule_approximation.capsuleDatas
          var tm : float3x4
          geomtree_getNodeWtmScalar(*corpse_animchar.nodeTree, int(data.nodeIndex), tm)
          let a = tm * data.a
          let b = tm * data.b
          let c = (a + b) * 0.5

          let dotA = dot(normalize(a - testPos), params.dir)
          if dotA > bestProjDot
            bestProjDot = dotA
            bestProjPoint = a

          let dotB = dot(normalize(b - testPos), params.dir)
          if dotB > bestProjDot
            bestProjDot = dotB
            bestProjPoint = b

          let dotC = dot(normalize(c - testPos), params.dir)
          if dotC > bestProjDot
            bestProjDot = dotC
            bestProjPoint = c

        use_object__offset = inverse(phys_obj_transform) * bestProjPoint


// TODO: Do we need this?
// [es(tag=gameClient, REQUIRE=hero,
//   before=(human_use_action_es, hero_human_use_vehicle_object_es),
//   after=hero_human_pre_use_object_es)]
// def hero_human_use_corpse_object_es(info : UpdateStageInfoAct;
//                                     eid : EntityId;
//                                     var human_use_object__selectedObject : EntityId&;
//                                     state_counter__disableUseContainers : int = 0)
//   if human_use_object__selectedObject != INVALID_ENTITY_ID || state_counter__disableUseContainers > 0
//     return
//   let intersectionRadius = 2.f
//   let params = get_use_query_params(eid)
//   if !params.canUse
//     return
//   let sphere = BSphere3(params.pos, intersectionRadius)
//   var bestScore = 0.85f // minIntersectionDot
//   for_each_entity_in_grid(ecs_hash("interactable"), sphere, GridEntCheck.POS) <| $(item_eid : EntityId)
//     if hero_human_use_object_strict_check(eid, item_eid)
//       query(item_eid) <| $ [es(REQUIRE=external_inventory_accesspoint)] (eid : EntityId;
//                                                                          itemContainer : EidList;
//                                                                          transform aka container_transform : float3x4)
//         if length(itemContainer) == 0
//           return
//         let containerPos = container_transform[3]
//         let dir = normalize(containerPos - params.pos)
//         let t = max(0.0, length(containerPos - params.pos) - 1e-2)
//         if dot(params.dir, dir) >= bestScore && !rayhit_normalized(params.pos, dir, t, ETF_DEFAULT, -1)
//           bestScore = dot(params.dir, dir)
//           human_use_object__selectedObject = eid


[es(tag=gameClient, REQUIRE=hero, before=human_use_action_es, after=hero_human_pre_use_object_es)]
def hero_human_use_am_es(info : UpdateStageInfoAct;
                         eid : EntityId;
                         resources_gatherer_hero__enabled : bool;
                         resources_gatherer__eid : EntityId;
                         animchar : AnimcharBaseComponent;
                         resources_gatherer_hero__nodeIdx : int;
                         var human_use_object__selectedObject : EntityId&;
                         var human_use_object__selectedObjectDot : float&)
  if !resources_gatherer_hero__enabled || (human_use_object__selectedObject != INVALID_ENTITY_ID && human_use_object__selectedObjectDot <= -1.0)
    return
  let params = get_use_query_params(eid)
  if !params.canUse
    return
  query(resources_gatherer__eid) <| $ [es] (resources_gatherer_device__range : float;
                                            resources_gatherer_device__coneAngleCos : float;
                                            resources_gatherer_device__pointBlankDist : float)
    var nodeTm : float3x4
    geomtree_getNodeWtmScalar(*animchar.nodeTree, resources_gatherer_hero__nodeIdx, nodeTm)
    let sphere = BSphere3(nodeTm[3], resources_gatherer_device__range)
    find_entity_in_grid(ecs_hash("loot"), sphere, GridEntCheck.POS) <| $(item_eid : EntityId)
      query(item_eid) <| $ [es(REQUIRE=item__am)] (eid : EntityId;
                                                   transform aka am_transform : float3x4;
                                                   server_transform aka am_server_transform : float3x4 const?;
                                                   am_pile__visualItemPosOffset : float3 = float3(0, 0, 0))
        let useServerTransform = (am_server_transform ?? IDENT_TM) != IDENT_TM
        let amTm = useServerTransform ? *am_server_transform : am_transform

        let amItemPos = amTm[3] + rotate(amTm, am_pile__visualItemPosOffset)

        let viewDot = dot(normalize(amItemPos - params.pos), params.dir)
        if viewDot < human_use_object__selectedObjectDot
          return

        let tracePos = nodeTm[3]
        let traceRay = amItemPos - tracePos
        let traceRayDist = length(traceRay)
        let traceRayDir = traceRay * safeinv(traceRayDist)

        let isRayAngleValid = dot(params.dir, traceRayDir) > resources_gatherer_device__coneAngleCos
        let isPointBlankDist = traceRayDist < resources_gatherer_device__pointBlankDist

        if (isRayAngleValid || isPointBlankDist) && !traceray_exclude_non_phys_collidable(tracePos, traceRayDir, traceRayDist, ETF_RI)
          human_use_object__selectedObject = eid
          human_use_object__selectedObjectDot = viewDot

      return false