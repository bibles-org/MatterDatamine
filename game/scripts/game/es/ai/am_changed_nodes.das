options always_export_initializer = true

require app
require ecs
require ecs.common
require strings
require DagorSystem
require BehNodes
require DagorDataBlock
require DagorRandom
require Dacoll
require Grid
require GridCollision
require pathfinder
require math.base
require math.random
require math.linear
require DagorMath
require game.utils.team
require walkerai
require debug.logerr_once
require game.es.changed_common
require game.es.ecs_common
require danetlibs.navmesh_phys.main.ai.nphys_nodes_common
require game.es.flanking_ai_common
require game.es.level_common
require game.es.grav_zones_common
require NavmeshMapping
require game.es.ai.agent_position_mapping_common
require game.events.events_active_matter
require DagorDebug3D


[beh_node(name="triggerChangedsAroundOnHit")]
class TriggerChangedsAroundOnHit : BehNodeAdapter

  def override update(dt : float) : EBehResult
    query(beh_tree_eid(owner)) <| $ [es] (transform aka this_transform : float3x4;
                                          agent_dangers__hitTriggerRadius : float;
                                          agent_dangers__hitTriggerCooldown : float;
                                          agent_dangers__hitTriggerMaxCount : int;
                                          agent_dangers__triggerDuration : float;
                                          var agent_dangers__triggeredUntil : float&;
                                          var agent_dangers__hitTriggerlastStamp : float&)
      let time = get_sync_time()
      if agent_dangers__hitTriggerlastStamp + agent_dangers__hitTriggerCooldown > time
        return
      agent_dangers__hitTriggerlastStamp = time
      trigger_changeds_around(agent_dangers__hitTriggerRadius, transform[3], agent_dangers__hitTriggerMaxCount)
      agent_dangers__triggeredUntil = get_sync_time() + agent_dangers__triggerDuration
    return EBehResult.ER_SUCCESS


[beh_node(name="findDangerInParent")]
class FindDangerInParent : BehNodeAdapter

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (generated_monster__genEid : EntityId;
                               team aka agent_team : int;
                               var walker_agent__targetEid : EntityId&;
                               agent_dangers : AgentDangers;
                               personal_enemies__enemies : EidList const?)
      var targetEid = INVALID_ENTITY_ID
      query(generated_monster__genEid) <| $ [es] (transform aka generator_transform : float3x4;
                                                  monster_gen__bboxMin : float3;
                                                  monster_gen__bboxMax : float3)
        var bestIdx = -1
        var bestAlertness = 0.0
        for_each_entity_in_grid(ecs_hash("humans"), BBox3(monster_gen__bboxMin, monster_gen__bboxMax), GridEntCheck.POS) <| $(eid : EntityId)
          query(eid) <| $ [es(REQUIRE_NOT=deadEntity)] (transform : float3x4; isAlive : bool; team aka danger_team : int)
            let isFriendly = is_teams_friendly(agent_team, danger_team) && !is_personal_enemy(personal_enemies__enemies, eid)
            if !isAlive || isFriendly || !is_inside_tm(transform[3], generator_transform)
              return
            let dangerIdx = find_danger_index(agent_dangers, eid)
            if dangerIdx != -1 && (bestIdx == -1 || agent_dangers.dangers[dangerIdx].alertness > bestAlertness)
              targetEid = eid
              bestIdx = dangerIdx
              bestAlertness = agent_dangers.dangers[dangerIdx].alertness
            elif targetEid == INVALID_ENTITY_ID
              targetEid = eid
      walker_agent__targetEid = targetEid
      result = targetEid != INVALID_ENTITY_ID ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED
    return result

def find_danger_index(agent_dangers : AgentDangers; eid : EntityId)
  for i in iter_range(agent_dangers.dangers)
    if agent_dangers.dangers[i].eid == eid
      return i
  return -1


[beh_node(name="findRndNavPosInParent")]
class FindRndNavPosInParent : BehNodeAdapter
  posParam : string
  @hidden posParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("posParam", posParam, posParamHash, thisNode)

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    var pos : float3
    query(ownerEid) <| $ [es] (generated_monster__genEid : EntityId)
      query(generated_monster__genEid) <| $ [es] (transform : float3x4)
        var attempts = 10
        while attempts-- > 0
          pos = navmesh_map_position(random_in_tm(transform))
          if project_to_nearest_navmesh_point(pos, float3(0.5))
            var targetPosRef = ownerEid |> getRW_Point3(posParam, posParamHash)
            if targetPosRef == null
              logerr_once("{ownerEid}<{getEntityTemplateName(ownerEid)}>: FindRndPosInParent unable to find target position '{posParam}:{posParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
              return
            *targetPosRef = pos
            result = EBehResult.ER_SUCCESS
            return
    return result




[beh_node(name="isInParent")]
class IsInParent : BehNodeAdapter

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (generated_monster__genEid : EntityId; transform aka monster_transform : float3x4)
      query(generated_monster__genEid) <| $ [es] (transform : float3x4)
        if is_inside_tm(monster_transform[3], transform)
          result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="checkDistanceToParent")]
class CheckDistanceToParent : BehNodeAdapter
  radiusParam : string
  @hidden radiusParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_ecs_param("radiusParam", radiusParam, radiusParamHash, thisNode)


  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let ownerEid = beh_tree_eid(owner)
    var radiusRef = ownerEid |> get_float(radiusParam, radiusParamHash)
    query(ownerEid) <| $ [es] (generated_monster__genEid : EntityId; transform aka monster_transform : float3x4)
      query(generated_monster__genEid) <| $ [es] (transform : float3x4)
        if radiusRef != null
          if point_to_tm_dst(monster_transform[3], transform) < *radiusRef
            result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="flankTarget")]
class FlankTarget : NPhysCorridorMoveToTargetBase
  useFlank : bool = true

  def override loadFromBlk(var data : DataBlock)
    NPhysCorridorMoveToTargetBase`loadFromBlk(self, data)
    useFlank = data |> datablock_getBool("useFlank", useFlank)

  def override init()
    NPhysCorridorMoveToTargetBase`init(self)
    if !useFlank
      return
    let agentEid = beh_tree_eid(owner)
    query(agentEid) <| $ [es] (navmesh_phys__currentPos : float3;
                               walker_agent__targetEid : EntityId;
                               flanking_ai__priority : int;
                               flanking_ai__minDistance : float;
                               flanking_ai__attackFromSide : bool;
                               var flanking_ai__dir : float3&;
                               var flanking_ai__lastTarget : EntityId&)
      if flanking_ai__priority == 0
        query(walker_agent__targetEid) <| $ [es] (var flanking_ai_target__dirs : Point3List)
          var targetPos : float3
          var localLostTarget : bool
          let didGetTargetPos = self->getTargetPos(agentEid, targetPos, localLostTarget)
          if (flanking_ai__lastTarget == walker_agent__targetEid &&
              !flanking_ai__attackFromSide &&
              has_direction(flanking_ai_target__dirs, flanking_ai__dir))
            return // use last direction
          var dir : float3
          if !didGetTargetPos
            var s, c : float
            sincos(gfrnd() * 2.0 * PI, s, c)
            dir = float3(s, 0.0, c)
          else
            dir = choose_attack_direction(navmesh_phys__currentPos, targetPos, flanking_ai__attackFromSide, agentEid)
          flanking_ai__dir = adjust_attack_direction(targetPos, dir, flanking_ai__minDistance, flanking_ai_target__dirs)
          flanking_ai__lastTarget = walker_agent__targetEid


  def override getTargetPos(agent_eid : EntityId; var res : float3&; var lost_target : bool&) : bool
    let targetPosRef = agent_eid |> get_Eid(targetParam, targetParamHash)
    if targetPosRef == null
      logerr_once("{agent_eid}: FlankTarget can't find target eid '{targetParam}:{targetParamHash}' {*thisNode |> beh_node_hierarchy_name(true)}")
      return false
    var lastTarget = INVALID_ENTITY_ID
    query(agent_eid) <| $ [es] (flanking_ai__lastTarget : EntityId)
      lastTarget = flanking_ai__lastTarget
    if lastTarget == INVALID_ENTITY_ID
      return false
    if self->lostTarget(*targetPosRef)
      lost_target = true
      res = lastTargetPos
      return true
    query(*targetPosRef) <| $ [es] (transform : float3x4)
      res = transform[3]
      let notFinalTarget = navmesh_update_position_mapping_state_on_get_target(agent_eid, res)
      // flanking
      if !notFinalTarget && useFlank
        query(agent_eid) <| $ [es] (flanking_ai__dir : float3;
                                    flanking_ai__radius : float)
          var poly : dtPolyRef
          res = get_slot_position(res, flanking_ai__dir, flanking_ai__radius, poly)

    return true


[beh_node(name="pursueTargetWithBlinks")]
class PursueTargetWithBlinks : FlankTarget
  def override update(dt : float) : EBehResult
    var res = AbstractNPhysCorridorMoveTo`update(self, dt)
    if res == EBehResult.ER_RUNNING
      let agent_eid = beh_tree_eid(owner)
      let targetPosRef = agent_eid |> get_Eid(targetParam, targetParamHash)
      if targetPosRef != null && *targetPosRef != INVALID_ENTITY_ID
        query(*targetPosRef) <| $ [es] (transform aka t_transform : float3x4; var flanking_ai_target__dirs : Point3List)
          query(agent_eid) <| $ [es] (transform aka a_transform : float3x4;
                                      changed__blinkDistance : float2;
                                      changed__blinkMinApproachDistance : float = 0.5;
                                      changed__meleeBlinkPeriod : float2;
                                      changed__meleeBlinkChance : float;
                                      changed__blinkPeriod : float2;
                                      changed__blinkFinisherMinDot : float;
                                      changed__blinkTraceMatId : int;
                                      flanking_ai__radius : float;
                                      flanking_ai__minDistance : float;
                                      isAlive : bool;
                                      position_mapping__lastZone : EntityId = INVALID_ENTITY_ID;
                                      flanking_ai__attackFromSide : bool;
                                      path_corridor__corners : Point3List;
                                      var flanking_ai__dir : float3&;
                                      var navmesh_phys__prevLookDir : float3&;
                                      var navmesh_phys__currentLookDir : float3&;
                                      var loc_snapshots__simulateBlinkPrevPos : float3&;
                                      var navmesh_phys__currentPos : float3&;
                                      var navmesh_phys__currentPoly : int64&;
                                      var loc_snapshots__blink : bool&;
                                      var changed__blinkAt : float&;
                                      var path_corridor__forceUpdateThisFrame : bool&)
            if !isAlive
              return
            let time = get_sync_time()
            if time > changed__blinkAt
              let dst = distance(a_transform[3], t_transform[3])
              if dst > changed__blinkMinApproachDistance
                var blinkDst = max(changed__blinkMinApproachDistance, rnd_float(changed__blinkDistance))
                var from = navmesh_phys__currentPos
                for p in path_corridor__corners
                  let alongLegDst = distance(from, p)
                  if alongLegDst >= blinkDst
                    let dir = normalize(p - from)
                    var pos = from + dir * blinkDst
                    var poly : dtPolyRef
                    if project_to_nearest_navmesh_point(pos, float3(1.0), poly)
                      let prevPosUnmapped = navmesh_unmap_position_in_zone(navmesh_phys__currentPos, position_mapping__lastZone)
                      let newPosUnmapped = navmesh_unmap_position_in_zone(pos, position_mapping__lastZone)
                      changed__blinkAt = time + rnd_float(changed__blinkPeriod)
                      if !traceray_blink(prevPosUnmapped, newPosUnmapped, a_transform, changed__blinkTraceMatId)
                        loc_snapshots__simulateBlinkPrevPos = prevPosUnmapped
                        validate_gameplay_position(loc_snapshots__simulateBlinkPrevPos) <| $()
                          return <- "navmesh_phys__currentPos={navmesh_phys__currentPos}, position_mapping__lastZone={position_mapping__lastZone}"
                        navmesh_phys__currentPos = pos
                        navmesh_phys__currentPoly = int64(poly)
                        loc_snapshots__blink = true
                    break
                  else
                    blinkDst -= alongLegDst
                    from = p
              elif changed__meleeBlinkChance > FLT_EPSILON && rnd_float(0.f, 1.f) < changed__meleeBlinkChance // Blink in close range
                var poly : dtPolyRef
                let mappedTargetPosition = navmesh_map_position(t_transform[3])
                flanking_ai__dir = choose_attack_direction(navmesh_phys__currentPos, mappedTargetPosition, flanking_ai__attackFromSide, agent_eid)
                flanking_ai__dir = adjust_attack_direction(mappedTargetPosition, flanking_ai__dir, flanking_ai__minDistance, flanking_ai_target__dirs)
                let pos = get_slot_position(mappedTargetPosition, flanking_ai__dir, flanking_ai__radius, poly)
                let mappedFlankDir = navmesh_map_direction(normalize(t_transform[3] - a_transform[3]), a_transform[3])
                if (dot(mappedFlankDir, flanking_ai__dir) > changed__blinkFinisherMinDot &&
                    distance_sq(pos, mappedTargetPosition) > square(flanking_ai__minDistance))
                  let prevPosUnmapped = navmesh_unmap_position_in_zone(navmesh_phys__currentPos, position_mapping__lastZone)
                  let newPosUnmapped = navmesh_unmap_position_in_zone(pos, position_mapping__lastZone)
                  changed__blinkAt = time + rnd_float(changed__meleeBlinkPeriod)
                  if !traceray_blink(prevPosUnmapped, newPosUnmapped, a_transform, changed__blinkTraceMatId)
                    loc_snapshots__simulateBlinkPrevPos = prevPosUnmapped
                    validate_gameplay_position(loc_snapshots__simulateBlinkPrevPos) <| $()
                      return <- "navmesh_phys__currentPos={navmesh_phys__currentPos}, position_mapping__lastZone={position_mapping__lastZone}"
                    navmesh_phys__currentPos = pos
                    navmesh_phys__currentPoly = int64(poly)
                    loc_snapshots__blink = true
                    path_corridor__forceUpdateThisFrame = true // Update path next frame
                    navmesh_phys__prevLookDir = navmesh_phys__currentLookDir
                    navmesh_phys__currentLookDir = normalize(mappedTargetPosition - navmesh_phys__currentPos)
      else
        res = EBehResult.ER_FAILED

    return res

  [unused_argument(children)] def override drawDebug(children : bool) : void
    AbstractNPhysCorridorMoveTo`drawDebug(self, children)
    query(beh_tree_eid(owner)) <| $ [es] (path_corridor : dtPathCorridor; transform : float3x4; position_mapping__lastZone : EntityId)
      if position_mapping__lastZone == INVALID_ENTITY_ID
        return
      path_corridor |> corridor_getPath() <| $(list)
        var previous = navmesh_unmap_position_in_zone(transform[3], position_mapping__lastZone)
        validate_gameplay_position(previous) <| $()
          return <- "transform={transform}, position_mapping__lastZone={position_mapping__lastZone}"
        for polyRef in list
          var triangle : NavMeshTriangle
          get_triangle_by_poly(polyRef, triangle)
          let center = navmesh_unmap_position_in_zone((triangle.p0 + triangle.p1 + triangle.p2) / 3.0, position_mapping__lastZone)
          validate_gameplay_position(center) <| $()
            return <- "triangle=<{triangle.p0}; {triangle.p1}; {triangle.p2}>, position_mapping__lastZone={position_mapping__lastZone}"
          draw_debug_line_buffered(previous, center, E3DCOLOR(0xffffffff), 1)
          previous = center


[beh_node(name="moveToPosWithBlinks")]
class MoveToPosWithBlinks : NPhysCorridorMoveToPosBase
  blinkPeriod : float2
  overrideBlinkPeriod : bool = false

  def override loadFromBlk(var data : DataBlock)
    NPhysCorridorMoveToPosBase`loadFromBlk(self, data)
    blinkPeriod = data |> datablock_getPoint2("blinkPeriod", blinkPeriod)
    overrideBlinkPeriod = blinkPeriod != float2()

  def override init()
    if !overrideBlinkPeriod
      return
    let agent_eid = beh_tree_eid(owner)
    query(agent_eid) <| $ [es] (var changed__blinkAt : float&)
      if changed__blinkAt - get_sync_time() > blinkPeriod.y
        changed__blinkAt = rnd_float(blinkPeriod)

  def override getTargetPos(agent_eid : EntityId; var res : float3&; var lost_target : bool&) : bool
    let success = NPhysCorridorMoveToPosBase`getTargetPos(self, agent_eid, res, lost_target)
    navmesh_update_position_mapping_state_on_get_target(agent_eid, res)
    return success

  def override update(dt : float) : EBehResult
    let res = AbstractNPhysCorridorMoveTo`update(self, dt)
    if res != EBehResult.ER_RUNNING
      return res
    let agent_eid = beh_tree_eid(owner)
    var targetPos : float3
    var localLostTarget : bool
    let didGetTargetPos = NPhysCorridorMoveToPosBase`getTargetPos(self, agent_eid, targetPos, localLostTarget)
    if !didGetTargetPos
      return res
    query(agent_eid) <| $ [es] (transform : float3x4;
                                changed__blinkDistance : float2;
                                changed__blinkPeriod : float2;
                                changed__blinkMinApproachDistance : float = 0.5;
                                changed__blinkTraceMatId : int;
                                isAlive : bool;
                                position_mapping__lastZone : EntityId = INVALID_ENTITY_ID;
                                path_corridor__corners : Point3List;
                                var loc_snapshots__simulateBlinkPrevPos : float3&;
                                var navmesh_phys__currentPos : float3&;
                                var navmesh_phys__currentPoly : int64&;
                                var loc_snapshots__blink : bool&;
                                var changed__blinkAt : float&;
                                var path_corridor__forceUpdateThisFrame : bool&)
      if !isAlive
        return
      let time = get_sync_time()
      if time > changed__blinkAt
        let dst = distance(transform[3], targetPos)
        if dst > changed__blinkMinApproachDistance
          var blinkDst = max(changed__blinkMinApproachDistance, rnd_float(changed__blinkDistance))
          var from = navmesh_phys__currentPos
          for p in path_corridor__corners
            let alongLegDst = distance(from, p)
            if alongLegDst >= blinkDst
              let dir = normalize(p - from)
              var pos = from + dir * blinkDst
              var poly : dtPolyRef
              if project_to_nearest_navmesh_point(pos, float3(1.0), poly)
                let prevPosUnmapped = navmesh_unmap_position_in_zone(navmesh_phys__currentPos, position_mapping__lastZone)
                let newPosUnmapped = navmesh_unmap_position_in_zone(pos, position_mapping__lastZone)
                changed__blinkAt = time + (overrideBlinkPeriod ? rnd_float(blinkPeriod) : rnd_float(changed__blinkPeriod))
                if !traceray_blink(prevPosUnmapped, newPosUnmapped, transform, changed__blinkTraceMatId)
                  loc_snapshots__simulateBlinkPrevPos = navmesh_unmap_position_in_zone(navmesh_phys__currentPos, position_mapping__lastZone)
                  validate_gameplay_position(loc_snapshots__simulateBlinkPrevPos) <| $()
                    return <- "navmesh_phys__currentPos={navmesh_phys__currentPos}, position_mapping__lastZone={position_mapping__lastZone}"
                  navmesh_phys__currentPos = pos
                  navmesh_phys__currentPoly = int64(poly)
                  loc_snapshots__blink = true
                  path_corridor__forceUpdateThisFrame = true // Update path next frame
              break
            else
              blinkDst -= alongLegDst
              from = p
    return res


[beh_node(name="findFlankableTarget")]
class FindFlankableTarget : BehNodeAdapter
  useLargeRadius : bool = false
  backupTargetParam : string
  @hidden backupTargetParamHash : uint
  minDanger : float = -1.0

  def override loadFromBlk(var data : DataBlock)
    useLargeRadius = data |> datablock_getBool("useLargeRadius", useLargeRadius)
    data |> load_optional_ecs_param("backupTarget", backupTargetParam, backupTargetParamHash)
    minDanger = data |> datablock_getReal("minDanger", minDanger)

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let agent_eid = beh_tree_eid(owner)

    // Force update agent_dangers
    sendEventImmediate(agent_eid, CmdTraceAgentDangers(forceRetrace = true))

    query(agent_eid) <| $ [es] (agent_dangers : AgentDangers;
                                transform aka e_transform : float3x4;
                                beh_tree__blackboard__enemyRadius : float;
                                beh_tree__blackboard__enemyRadiusTriggered = .0;
                                beh_tree__blackboard__enemyRadiusLarge = .0;
                                agent_dangers__triggeredUntil = .0;
                                flanking_ai__enabled : bool;
                                flanking_ai__maxCount : int;
                                var flanking_ai__priority : int&;
                                var walker_agent__prevTargetEid : EntityId?;
                                var walker_agent__targetEid : EntityId&)
      let time = get_sync_time()
      var radius = beh_tree__blackboard__enemyRadius
      if time < agent_dangers__triggeredUntil
        radius = max(radius, beh_tree__blackboard__enemyRadiusTriggered)
      if useLargeRadius
        radius = max(radius, beh_tree__blackboard__enemyRadiusLarge)
      var nearestDst = FLT_MAX
      var highestAlertness = 0.0
      var fewestCrowd = 99999
      var bestTargetFlanked = false
      var bestTarget = backupTargetParamHash != 0u ? get_Eid(agent_eid, backupTargetParam, backupTargetParamHash) ?? INVALID_ENTITY_ID : INVALID_ENTITY_ID
      for danger in agent_dangers.dangers
        if danger.distance < radius
          if danger.eid == walker_agent__targetEid && flanking_ai__priority == 0
            // already targeting this target
            result = EBehResult.ER_SUCCESS
            return
          if minDanger >= 0.0 && (danger.alertness < minDanger || !danger.traceable) && danger.distance > 10.0
            continue

          query(danger.eid) <| $ [es] (flanking_ai_target__count : int;
                                       flanking_ai_target__maxCount : int;
                                       flanking_ai_target__consideredFlankedCoef : float = 0.6)
            let isFlanked = flanking_ai_target__count >= int(float(flanking_ai_target__maxCount) * flanking_ai_target__consideredFlankedCoef)
            if !isFlanked
              if danger.alertness > highestAlertness || bestTargetFlanked
                nearestDst = danger.distance
                fewestCrowd = flanking_ai_target__count
                bestTarget = danger.eid
                highestAlertness = danger.alertness
                bestTargetFlanked = isFlanked
            elif flanking_ai_target__count < fewestCrowd || (flanking_ai_target__count == fewestCrowd && danger.alertness > highestAlertness)
              nearestDst = danger.distance
              fewestCrowd = flanking_ai_target__count
              bestTarget = danger.eid
              highestAlertness = danger.alertness
              bestTargetFlanked = isFlanked

      query(bestTarget) <| $ [es] (var flanking_ai_target__count : int&; flanking_ai_target__maxCount : int; isAlive : bool; transform aka t_transform : float3x4)
        if isAlive
          let dst = nearestDst == FLT_MAX ? distance(t_transform[3], e_transform[3]) : nearestDst
          if dst < radius
            let shouldWait = flanking_ai__enabled && flanking_ai_target__count >= min(flanking_ai_target__maxCount, flanking_ai__maxCount)
            flanking_ai__priority = shouldWait ? 1 : 0
            walker_agent__targetEid = bestTarget
            if walker_agent__prevTargetEid != null
              *walker_agent__prevTargetEid = bestTarget
            result = EBehResult.ER_SUCCESS
            sendEvent(agent_eid, EventFlankingTargetAcquired(targetEid = bestTarget, distance = dst, priority = flanking_ai__priority))
            if flanking_ai__priority == 0
              flanking_ai_target__count++
    return result


[beh_node(name="canFlankTarget")]
class CanFlankTarget : BehNodeAdapter
  targetParam : string
  @hidden targetParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    data |> load_optional_ecs_param("target", targetParam, targetParamHash)

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let agent_eid = beh_tree_eid(owner)
    query(agent_eid) <| $ [es] (flanking_ai__maxCount : int)
      let target = agent_eid |> get_Eid(targetParam, targetParamHash) ?? INVALID_ENTITY_ID
      query(target) <| $ [es] (flanking_ai_target__count, flanking_ai_target__maxCount : int)
        let maxCount = min(flanking_ai__maxCount, flanking_ai_target__maxCount)
        if maxCount > flanking_ai_target__count
          result = EBehResult.ER_SUCCESS
    return result