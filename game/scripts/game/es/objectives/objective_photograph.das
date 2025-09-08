require ecs
require app
require game.es.inventory_common
require game.events.events
require math.base
require DngNet
require DagorMath
require game.es.objectives.objective_common
require game.es.objectives.objective_utils_common
require game.es.use_query_params_common
require game.es.objectives_enums_common
require game.events.events_game
require DagorSystem
require game.events.events_active_matter
require active_matter.game.es.binoculars_common
require HumanPhys
require DngHuman
require Dacoll
require PhysMat
require DagorDebug3D
require debug.logerr_once


enum ReasonInterruptUsing : uint8
  NONE
  WRONG_PLACE
  NOT_IN_VIEW
  NO_ACTIVE_TARGETS


struct ResHandlingCameraUse
  closestZoneEid : EntityId
  targetEid : EntityId
  detectedTargetEid : EntityId
  objectiveEid : EntityId
  shouldInterrupt : bool
  reason : ReasonInterruptUsing
  traceRatio : float


def private is_hero_in_target_zone(hero_pos : float3;
                                   target_eids : EidList)
  var res = false
  var hasStandTarget = false
  for targetEid in target_eids
    query(targetEid) <| $ [es(REQUIRE=photographing_stand_target)] ()
      hasStandTarget = true
      res = is_point_in_objective_target_geometry(hero_pos, targetEid)
    if res
      return true
  return !hasStandTarget


def private get_closest_target_zone(hero_pos : float3;
                                    targets_eid : EidList)
  var resTargetEid = INVALID_ENTITY_ID
  var minDistSq = VERY_BIG_NUMBER
  for targetEid in targets_eid
    query(targetEid) <| $ [es(REQUIRE=photographing_stand_target)] (transform : float3x4)

      let distSq = distance_sq(transform[3], hero_pos)
      if distSq < minDistSq
        minDistSq = distSq
        resTargetEid = targetEid
  return resTargetEid


def private generate_trace_points(transform, normals : float3x4; hero_pos : float3; trace_density : float)
  var res <- array(transform[3])
  let sizes <- array(length(transform[0]), length(transform[1]), length(transform[2]))
  var minArea = 0.5
  for s in sizes
    minArea = min(minArea, square(s))

  let faceOrients <- array(1.0, -1.0)
  for orient in faceOrients
    for faceIdx in range(3)
      let normal = normals[faceIdx] * orient
      let faceCenter = transform[3] + normal * sizes[faceIdx] * 0.5
      let viewAngle = dot(normal, -normalize(faceCenter - hero_pos))

      // Skip faces that are facing away
      if viewAngle <= 0.0
        continue

      // Generate orthonormal basis for the face
      let uAxis = normals[(faceIdx + 1) % 3]
      let vAxis = normals[(faceIdx + 2) % 3]
      let uSize = sizes[(faceIdx + 1) % 3]
      let vSize = sizes[(faceIdx + 2) % 3]

      // Calculate the apparent area of the face from the hero's perspective
      let apparentArea = uSize * vSize * viewAngle
      if apparentArea < minArea
        continue

      let totalPoints = float(max(1, int(sqrt(apparentArea) * trace_density)))
      let aspectRatio = uSize / vSize
      let gridSizeX =  max(1, int(sqrt(totalPoints * aspectRatio)))
      let gridSizeY = max(1, int(sqrt(totalPoints / aspectRatio)))

      for i in range(gridSizeX)
        for j in range(gridSizeY)
          let u = gridSizeX > 1 ? (float(i) / float(gridSizeX - 1) - 0.5) * uSize : .0
          let v = gridSizeY > 1 ? (float(j) / float(gridSizeY - 1) - 0.5) * vSize : .0
          let point = faceCenter + u * uAxis + v * vAxis
          res |> push(point)

  return <- res

def private get_target_for_photo_in_view(hero_pos,
                                         hero_dir : float3;
                                         targets_eid,
                                         ignore_targets_eid : EidList;
                                         detect_mode : bool = false)
  var resTargetEid = INVALID_ENTITY_ID
  var traceRatio = .0
  var bestDot = -1f
  var minDot : float
  for targetEid in targets_eid
    if has_value(ignore_targets_eid, targetEid)
      continue
    query(targetEid) <| $ [es(REQUIRE=photographingTarget)] (transform : float3x4;
                                                             photographing_target__minDot : float;
                                                             photographing_target__detectDot : float)
      let thisMinDot = detect_mode ? photographing_target__detectDot : photographing_target__minDot

      let dirToTarget = normalize(transform[3] - hero_pos)
      let dot = dot(dirToTarget, hero_dir)
      if dot < thisMinDot
        return
      if dot >= bestDot
        bestDot = dot
        resTargetEid = targetEid
        minDot = photographing_target__detectDot
  if !detect_mode
    query(resTargetEid) <| $ [es] (transform, photographing_target__normals : float3x4;
                                   photographing_target__traceMinSuccesses : int;
                                   photographing_target__traceDensity : float;
                                   photographing_target__alwaysVisible : bool;
                                   photographing_target__debugTraces : bool)
      if photographing_target__alwaysVisible //to skip long traces
        return
      if distance_sq(hero_pos, transform[3]) > square(200.0)
        logerr_once("Photograph target is too far. Set alwaysVisible = true.")
        return
      if is_inside_tm(hero_pos, transform) //Always visible from inside
        return

      let tracePoints <- generate_trace_points(transform, photographing_target__normals, hero_pos, photographing_target__traceDensity)
      var successCount = 0
      let minSuccesses = min(length(tracePoints), photographing_target__traceMinSuccesses)
      if photographing_target__debugTraces
        for p in tracePoints
          draw_debug_sphere_buffered(p, 0.1, E3DCOLOR(0xffffffff), 1)
      let rayMatId = get_material_id("photocameraRay")
      var outMatId = PHYSMAT_INVALID
      var riDesc = RendInstDesc()
      for p in tracePoints
        let ray = p - hero_pos
        var t = length(ray)
        let traceDir = ray * safeinv(t)
        if dot(traceDir, hero_dir) < minDot
          continue
        var norm : float3
        if !traceray_normalized(hero_pos, traceDir, t, outMatId, norm, ETF_ALL, riDesc, rayMatId)
          successCount++
          if photographing_target__debugTraces
            draw_debug_line_buffered(hero_pos, p, E3DCOLOR(0xffffffff), 1)
            draw_debug_sphere_buffered(p, 0.15, E3DCOLOR(0xff00ff00), 1)
          if successCount >= minSuccesses
            break
        elif photographing_target__debugTraces
          draw_debug_sphere_buffered(p, 0.3, E3DCOLOR(0xff4444ff), 1)
          draw_debug_sphere_buffered(hero_pos + traceDir * t, 0.1, E3DCOLOR(0xff0000ff), 1)
      if successCount < minSuccesses
        resTargetEid = INVALID_ENTITY_ID
      traceRatio = safediv(float(successCount), float(minSuccesses))
  return resTargetEid, traceRatio


def private print_interrupt_reason(hero_eid : EntityId;
                                   reason : ReasonInterruptUsing)
  if reason == ReasonInterruptUsing.WRONG_PLACE
    send_net_event(hero_eid, ShowStatusTip(statusTip = "status_tip_photo_wrong_place"))
  elif reason == ReasonInterruptUsing.NOT_IN_VIEW
    send_net_event(hero_eid, ShowStatusTip(statusTip = "status_tip_photo_not_in_view"))
  else
    send_net_event(hero_eid, ShowStatusTip(statusTip = "status_tip_photo_no_active_targets"))


def private handle_camera_use(hero_eid : EntityId;
                              hero_pos : float3)
  var handlingRes = ResHandlingCameraUse(shouldInterrupt = false)
  var activePhotoObjectives : array<tuple<eid : EntityId; distance : float>>
  reserve(activePhotoObjectives, /*max allowed quests*/3)
  for_each_hero_active_objective(hero_eid) <| $(objective_eid : EntityId)
    query(objective_eid) <| $ [es(REQUIRE=objectivePhotograph)] (objective__staticTargetsList : EidList)
      for staticTargetEid in objective__staticTargetsList
        query(staticTargetEid) <| $ [es(REQUIRE=photographing_stand_target)] (transform : float3x4)
          push(activePhotoObjectives,  (objective_eid, distance(transform[3], hero_pos)))
  if empty(activePhotoObjectives)
    handlingRes.reason = ReasonInterruptUsing.NO_ACTIVE_TARGETS
    return handlingRes
  sort(activePhotoObjectives) <| $(a, b)
    return a.distance < b.distance
  let mostNearObjective = activePhotoObjectives[0].eid
  handlingRes.objectiveEid = mostNearObjective
  query(mostNearObjective) <| $ [es] (objective__staticTargetsList : EidList;
                                      objective_photograph__completedTargets : EidList)
    handlingRes.closestZoneEid = get_closest_target_zone(hero_pos, objective__staticTargetsList)
    if !is_hero_in_target_zone(hero_pos, objective__staticTargetsList)
      handlingRes.reason = ReasonInterruptUsing.WRONG_PLACE
      return
    let params = get_use_query_params(hero_eid)
    let (targetEid, traceRatio) = get_target_for_photo_in_view(params.pos, params.dir, objective__staticTargetsList,
                                                         objective_photograph__completedTargets, false)
    let (detectedTargetEid, _) = get_target_for_photo_in_view(params.pos, params.dir, objective__staticTargetsList,
                                                                 objective_photograph__completedTargets, true)
    handlingRes.detectedTargetEid = detectedTargetEid
    handlingRes.targetEid = targetEid
    handlingRes.traceRatio = traceRatio
    if handlingRes.targetEid == INVALID_ENTITY_ID
      handlingRes.reason = ReasonInterruptUsing.NOT_IN_VIEW
      return
    handlingRes.shouldInterrupt = false
  return handlingRes


[es(tag=gameClient, on_appear, no_order, REQUIRE=quest_camera_watching_affect)]
def quest_camera_watching_affect_update_client(act : UpdateStageInfoAct;
                                               game_effect__attachedTo : EntityId;
                                               var quest_camera_watching_affect__inPlace : bool&;
                                               var quest_camera_watching_affect__closestZoneEid : EntityId&;
                                               var quest_camera_watching_affect__targetEid : EntityId&;
                                               var quest_camera_watching_affect__detectedTargetEid : EntityId&;
                                               var quest_camera_watching_affect__targetInView : bool&;
                                               var quest_camera_watching_affect__traceRatio : float&)
  query(game_effect__attachedTo) <| $ [es(REQUIRE=watchedByPlr)] (isDowned : bool;
                                                                  transform aka actor_transform : float3x4)
    if isDowned
      return

    let handlingRes = handle_camera_use(game_effect__attachedTo, actor_transform[3])
    quest_camera_watching_affect__inPlace = (handlingRes.reason != ReasonInterruptUsing.WRONG_PLACE)
    quest_camera_watching_affect__closestZoneEid = handlingRes.closestZoneEid
    quest_camera_watching_affect__targetEid = handlingRes.targetEid
    quest_camera_watching_affect__detectedTargetEid = handlingRes.detectedTargetEid
    quest_camera_watching_affect__targetInView = (handlingRes.reason != ReasonInterruptUsing.NOT_IN_VIEW)
    quest_camera_watching_affect__traceRatio = handlingRes.traceRatio


[es(tag=server, no_order, REQUIRE=quest_camera_watching_affect)]
def quest_camera_watching_affect_update_server(act : UpdateStageInfoAct;
                                               game_effect__attachedTo : EntityId;
                                               quest_camera_watching_affect__interruptUseAt : float)
  if quest_camera_watching_affect__interruptUseAt > 0.0 && act.curTime >= quest_camera_watching_affect__interruptUseAt
    query(game_effect__attachedTo) <| $ [es] (var binoculars_controller__useState : int&)
      stop_binoculars_use(binoculars_controller__useState)


[es(tag=server, no_order)]
def objective_photograph_camera_shoot_track(act : UpdateStageInfoAct;
                                            game_effect__attachedTo : EntityId;
                                            quest_camera_watching_affect__interruptAfterShotDelay : float;
                                            var quest_camera_watching_affect__interruptUseAt : float&;
                                            var quest_camera_watching_affect__state : int&)
  if quest_camera_watching_affect__state == int(ObjectivePhotographAffectState.NONE)
    query(game_effect__attachedTo) <| $ [es] (human_net_phys : HumanActor;
                                              transform aka actor_transform : float3x4)
      assume ct = human_net_phys.phys.appliedCT
      if ct |> is_control_bit_set(HumanPhysControlType.HCT_SHOOT)
        let handlingRes = handle_camera_use(game_effect__attachedTo, actor_transform[3])
        if handlingRes.reason == ReasonInterruptUsing.NONE
          quest_camera_watching_affect__state = int(ObjectivePhotographAffectState.SHOOTED)

          send_net_event(game_effect__attachedTo, EventObjectivePhotographShot())

          quest_camera_watching_affect__interruptUseAt = get_sync_time() + quest_camera_watching_affect__interruptAfterShotDelay

          query(handlingRes.objectiveEid) <| $ [es] (var objective_photograph__completedTargets : EidList)
            push(objective_photograph__completedTargets, handlingRes.targetEid)
            do_progress_for_objective(handlingRes.objectiveEid)


[es(on_appear)]
def init_photograph_target_normals(evt : Event; transform : float3x4; var photographing_target__normals : float3x4)
  photographing_target__normals[0] = normalize(transform[0])
  photographing_target__normals[1] = normalize(transform[1])
  photographing_target__normals[2] = normalize(transform[2])