module use_object_common shared
require ecs
require ecs.common
require math.base
require RendInst
require Dacoll
require DagorMath
require DagorMathUtils
require game.es.use_query_params_common
require game.es.inventory_checks_common
require game.es.trace_common


def use_usable_object(var human_use_object__selectedObject : EntityId&;
                      var human_use_object__selectedObjectDot : float&;
                      var human_use_object__lookAtSelected : bool&;
                      entity_predicate : block<(e_eid : EntityId) : bool>)
  if human_use_object__selectedObject != INVALID_ENTITY_ID
    return
  find_query() <| $ [es] (client_usable_objects__usableEids : EidList;
                          client_usable_objects__usableEntityDots : FloatList)

    for eid, entityDot in client_usable_objects__usableEids, client_usable_objects__usableEntityDots
      if invoke(entity_predicate, eid)
        human_use_object__selectedObject = eid
        human_use_object__selectedObjectDot = entityDot
        human_use_object__lookAtSelected = true
        return true
    return true



def hero_human_use_object_strict_check(human_eid, object_eid : EntityId)
  var res = false
  query(human_eid) <| $ [es] (human_use_object__lastSelectedObject : EntityId;
                              human_use_object__currentInteractable : EntityId = INVALID_ENTITY_ID;
                              state_counter__disableUseContainers : int = 0)
    let params = get_use_query_params(human_eid)
    if !params.canUse
      res = false
      return
    query(object_eid) <| $ [es] (ri_extra : RiExtraComponent const?;
                                 ri_extra__handle : riex_handle_t const?;
                                 transform : float3x4;
                                 server_transform : float3x4 const?;
                                 use_object__interactingExtraUseDistance : float = 0.5;
                                 use_object__selectedScale = 1.0;
                                 use_object__minDot = -1.0;
                                 use_object__noTraceCheck : Tag const?;
                                 use_object__offset : float3 const?;
                                 use_object__overrideUseDistance : float const?;
                                 use_object__obbMin, use_object__obbMax : float3 const?;
                                 item_in_world : Tag const?;
                                 external_inventory_accesspoint : Tag const?;
                                 use_object__enabled  = true)
      if !use_object__enabled
        return

      if external_inventory_accesspoint != null && state_counter__disableUseContainers > 0
        return

      if item_in_world != null
        res = is_item_accessible_by_distance(human_eid, object_eid, params.pickupRemoveRad, params.pickupRemoveHeight)
        return

      assume object_transform = server_transform != null ? *server_transform : transform

      let isSelected = human_use_object__lastSelectedObject == object_eid
      let isInteractingNow = human_use_object__currentInteractable == object_eid
      let interactPoint = use_object__offset != null ? object_transform * (*use_object__offset) : object_transform[3]
      let tracePos = params.pos
      let lookNDir = params.dir
      var useDistance = use_object__overrideUseDistance ?? params.dist.x
      if isInteractingNow
        useDistance += use_object__interactingExtraUseDistance

      let useTrace = use_object__noTraceCheck == null
      let useBBox = use_object__obbMin != null && use_object__obbMax != null
      let hasRi = ri_extra != null || ri_extra__handle != null
      let scaleCollision = isSelected ? use_object__selectedScale : 1.

      // check obb if exists
      let invTm = useBBox || (useTrace && hasRi) ? inverse(object_transform) : object_transform
      var boxIntersection : float3
      if useBBox
        let from = invTm * tracePos
        let to = invTm * (tracePos + lookNDir * useDistance)
        let lbb = BBox3(*use_object__obbMin * scaleCollision, *use_object__obbMax * scaleCollision)
        var bt : float
        if does_line_intersect_box_side(lbb, from, to, bt) == -1
          return
        boxIntersection = lerp(from, to, float3(bt))

      // check use distance with radius
      elif distance_sq(interactPoint, tracePos) > square(useDistance * scaleCollision)
        return

      if !useTrace
        res = true
        return

      var norm : float3

      let traceEnd = useBBox ? object_transform * boxIntersection : interactPoint
      let traceDir = traceEnd - tracePos
      let traceDist = length(traceDir)
      let traceNDir = traceDir * safeinv(traceDist)
      let EXTRA_TRACE_OFFSET = 0.03 // 3 cm
      let safeTraceDist = traceDist - EXTRA_TRACE_OFFSET

      if dot(traceNDir, lookNDir) < use_object__minDot
        res = false
        return

      // closer than EXTRA_TRACE_OFFSET
      if safeTraceDist < FLT_EPSILON
        res = true
        return

      // no ri, use trace
      if !hasRi
        res = !traceray_exclude_non_phys_collidable(tracePos, traceNDir, safeTraceDist, ETF_DEFAULT, -1)
        return

      // yes ri, we have to touch it
      var t = safeTraceDist
      var pmid = -1
      var riDesc = RendInstDesc()
      let collides = t > 0.0 ? traceray_normalized(tracePos, traceNDir, t, pmid, norm, ETF_RI, riDesc, -1) : false
      let handle = ri_extra != null ? ri_extra.handle : ri_extra__handle ?? 0ul
      res = !collides || riDesc.riExtraHandle == handle

  return res


def hero_human_use_object_weak_check(human_eid, object_eid : EntityId; delta_dist : float = 0.f)
  var res = false
  let params = get_use_query_params(human_eid)
  if !params.canUse
    return false
  query(object_eid) <| $ [es] (transform : float3x4 const?;
                               server_transform : float3x4 const?;
                               use_object__offset : float3 const?;
                               use_object__obbMin, use_object__obbMax : float3 const?;
                               item_in_world : Tag const?;
                               item__humanOwnerEid = INVALID_ENTITY_ID;
                               use_object__selectedScale = 1.0;
                               use_object__enabled = true;
                               item__containerOwnerEid : EntityId = INVALID_ENTITY_ID)
    if !use_object__enabled
      return

    if item__humanOwnerEid == human_eid
      res = true
      return

    if item_in_world != null
      res = is_item_accessible_by_distance(human_eid, object_eid, params.pickupRemoveRad + delta_dist, params.pickupRemoveHeight + delta_dist)
      return

    if transform == null && server_transform == null
      return

    var object_transform : float3x4
    if (item__containerOwnerEid != INVALID_ENTITY_ID)
      query(item__containerOwnerEid) <| $ [es] (transform : float3x4; server_transform : float3x4 const?)
        object_transform = server_transform ?? transform
    else
      object_transform = server_transform != null ? *server_transform : *transform

    let interactPoint = use_object__offset != null ? object_transform * (*use_object__offset) : object_transform[3]
    let humanPos = params.pos
    let useDistance = params.dist.y + delta_dist
    let useBBox = use_object__obbMin != null && use_object__obbMax != null

    // check obb if exists
    if useBBox
      let invTm = inverse(object_transform)
      let point = invTm * humanPos
      var vec = *use_object__obbMax - *use_object__obbMin
      vec[0] = sign(vec[0])
      vec[1] = sign(vec[1])
      vec[2] = sign(vec[2])
      vec *= useDistance // increase the box with useDistance on each side
      var box : bbox3f
      box.bmin = float4(*use_object__obbMin - vec, 1.0)
      box.bmax = float4(*use_object__obbMax + vec, 1.0)
      res = bbox3f_test_pt_inside(box, point) == 1
    elif distance_sq(interactPoint, humanPos) <= square(useDistance * use_object__selectedScale)
      res = true
  return res