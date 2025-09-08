require ecs
require ecs.common
require app
require walkerai
require game.utils.team
require math.base
require DagorRandom
require DagorMath
require Dacoll
require RendInst
require PhysMat
require CollRes
require AnimV20
require Grid
require game.es.entity_mods_common
require game.es.ai.ai_danger_common
require game.es.ai.walker_common
require game.es.truce_common
require SmokeOccluder
require DngHuman
require game.events.events_active_matter


struct TargetData
  eid : EntityId
  team : int
  isAlive : bool
  isDowned : bool
  isHidden : bool
  targetPos : float3
  stance : int
  truceId : int
  visibility : float

def TargetData(eid : EntityId; team : int; target : Target; stance : int; truce_id : int; visibility : float)
  return TargetData(eid = eid,
           team = team,
           isAlive = target.isAlive,
           isDowned = target.isDowned,
           isHidden = target.isHidden,
           targetPos = target.targetPos,
           stance = stance,
           truceId = truce_id,
           visibility = visibility)

def find_danger(var agent_dangers : AgentDangers; eid : EntityId)
  for i in iter_range(agent_dangers.dangers)
    if agent_dangers.dangers[i].eid == eid
      return i
  return -1

[es(tag=server, before=beh_tree_update_es, after=update_navmesh_ai_pos_dir)]
def ai_danger_update_alertness(act : UpdateStageInfoAct)
  var targets : table<uint; TargetData>
  query() <| $ [es(REQUIRE_NOT=(ai_target__autoGunTarget, deadEntity, ignored_ai_target))] (eid : EntityId;
                                                                                            ai_target : Target;
                                                                                            team : int;
                                                                                            human_net_phys : HumanActor const?;
                                                                                            another_dimension_visitor__inside : bool = false;
                                                                                            truce_id = TRUCE_UNASSIGNED;
                                                                                            ai_target_visibility_controller__currentLight : float = 1.0)
    if another_dimension_visitor__inside
      return
    var stance = STANCE_STAND
    if human_net_phys != null
      stance = determinate_stance(human_net_phys.phys.currentState)
    let visibility = ai_target_visibility_controller__currentLight
    var targetData = TargetData(eid, team, ai_target, stance, truce_id, visibility)
    targets.emplace(uint(eid), targetData)

  find_query() <| $ [es] (truce_controller__masks : UInt64List)
    query() <| $ [es(REQUIRE_NOT=(deadEntity, ai_danger_update_disabled))] (eid : EntityId;
                                                                            isAlive : bool; team : int;
                                                                            beh_tree__enabled : bool = true;
                                                                            isInVehicle : bool = false;
                                                                            var agent_dangers : AgentDangers;
                                                                            agent_dangers__standShootPos : float3;
                                                                            agent_dangers__standShootDir : float3;
                                                                            agent_dangers__maxDangerDist : float;
                                                                            var agent_dangers__nextDangersCheckTime : float&;
                                                                            alertness_calc__distCoef : float2;
                                                                            alertness_calc__inFrustumCoef : float2;
                                                                            alertness_calc__frustumCoef : float3;
                                                                            alertness_calc__frustumOffset : float2;
                                                                            alertness_calc__crouchCoef : float;
                                                                            alertness_calc__crawlCoef : float;
                                                                            alertness_calc__downedCoef : float;
                                                                            alertness_calc__inVehicleCoef : float;
                                                                            truce_id : int = -1;
                                                                            personal_enemies__enemies : EidList const?;
                                                                            agent_dangers__checkTimes = float2(0.3, 0.7);
                                                                            agent_dangers__frustumAngle = 40.;
                                                                            agent_dangers__blindDistanceSq = square(200.0);
                                                                            agent_dangers__blindDistanceSqTargetVisibilityMult = 0.15)

      if !isAlive || !beh_tree__enabled
        clear(agent_dangers.dangers)
        return
      if act.curTime < agent_dangers__nextDangersCheckTime
        return

      agent_dangers__nextDangersCheckTime = act.curTime + rnd_float(agent_dangers__checkTimes.x, agent_dangers__checkTimes.y)

      let frustumMinCos = cos(deg_to_rad(agent_dangers__frustumAngle))

      var i = length(agent_dangers.dangers)
      while --i >= 0
        assume danger = agent_dangers.dangers[i]
        if !(targets |> key_exists(uint(danger.eid)))
          agent_dangers.dangers |> erase(i)

      for target in values(targets)
        let dangerIdx = find_danger(agent_dangers, target.eid)
        if (!target.isAlive ||
            target.isHidden ||
            !is_hostile(truce_controller__masks, team, truce_id, personal_enemies__enemies, target.eid, target.team, target.truceId) ||
            target.eid == eid ||
            target.team == TEAM_UNASSIGNED)
          if dangerIdx >= 0
            erase(agent_dangers.dangers, dangerIdx)
          continue

        let targetDelta = target.targetPos - agent_dangers__standShootPos
        let distSq = length_sq(targetDelta)
        if distSq > agent_dangers__blindDistanceSq
          if dangerIdx >= 0
            erase(agent_dangers.dangers, dangerIdx)
          continue

        // Additional visibility check
        if target.visibility < 1.0
          let blindDistanceSqTargetVisibilityMult = cvt(target.visibility,
                                                  0.0, 1.0,
                                                  agent_dangers__blindDistanceSqTargetVisibilityMult, 1.0)
          if distSq > agent_dangers__blindDistanceSq * blindDistanceSqTargetVisibilityMult
            if dangerIdx >= 0
              erase(agent_dangers.dangers, dangerIdx)
            continue

        let dist = sqrt(distSq)
        let targetDir = targetDelta * safeinv(dist)
        let frustumCos = dot(targetDir, agent_dangers__standShootDir)
        let inFrustum = frustumCos >= frustumMinCos
        let inVehicleCoef = isInVehicle ? alertness_calc__inVehicleCoef : 1.
        let alertness = calc_target_alertness(dist, inFrustum, frustumCos, target.stance, target.isDowned,
                                              agent_dangers__maxDangerDist, alertness_calc__distCoef,
                                              alertness_calc__inFrustumCoef, alertness_calc__frustumCoef, alertness_calc__frustumOffset,
                                              alertness_calc__crouchCoef, alertness_calc__crawlCoef, alertness_calc__downedCoef,
                                              inVehicleCoef)
        if alertness <= 0.0
          if dangerIdx >= 0
            erase(agent_dangers.dangers, dangerIdx)
        else
          if dangerIdx >= 0
            assume danger = agent_dangers.dangers[dangerIdx]
            danger.distance = dist
            danger.alertness = alertness
            if !inFrustum
              danger.inFrustumTime = -1f
            elif danger.inFrustumTime < 0f
              danger.inFrustumTime = act.curTime
          else
            using() <| $(var newDanger : Danger#)
              newDanger.eid = target.eid
              newDanger.inFrustumTime = inFrustum ? act.curTime : -1.
              newDanger.distance = dist
              newDanger.alertness = alertness
              push_clone(agent_dangers.dangers, newDanger)
    return true


[es(tag=server, track=beh_tree__enabled)]
def reset_ai_danger_update_time_on_behtree_enabled(evt : Event; beh_tree__enabled : bool; var agent_dangers__nextDangersCheckTime : float&)
  if beh_tree__enabled
    agent_dangers__nextDangersCheckTime = 0.


[es(tag=server, on_appear)]
def ai_danger_update_time_init(evt : Event; eid : EntityId; agent_dangers__initialDangersTraceCheckTime : float = 1.0;
                               var agent_dangers__nextDangersTraceTime : float&)
  agent_dangers__nextDangersTraceTime = get_sync_time() + agent_dangers__initialDangersTraceCheckTime * eid_frnd(eid)


[es(on_appear)]
def danger_calc_ray_mat_init(evt : Event;
                             danger_calc__rayMat : string;
                             var danger_calc__rayMatId : int&)
  danger_calc__rayMatId = get_material_id(danger_calc__rayMat)

[es(tag=server, after=(ai_target_es, ai_target_transform_es))]
def ai_danger_trace_targets(act : UpdateStageInfoAct; eid : EntityId; isAlive : bool;
                            var agent_dangers : AgentDangers;
                            agent_dangers__standShootPos : float3;
                            beh_tree__enabled : bool = true;
                            var agent_dangers__nextDangersTraceTime : float&;
                            danger_calc__aiCoef : float2;
                            danger_calc__avoidBulletsNearTime : float;
                            danger_calc__lastShootCoef : float2;
                            danger_calc__noiseCoef : float2;
                            danger_calc__lastBulletNearbyCoef : float2;
                            danger_calc__rayMatId : int;
                            danger_calc__useRayMatForce : bool;
                            danger_calc__tooNearDistance : float;
                            attract_point__eid : EntityId;
                            danger_calc__magnitudeTreshhold : float;
                            danger_calc__observeAngleCosTreshhold : float;
                            human_net_phys__aimDir : float3 const?;
                            navmesh_phys__currentLookDir : float3 const?;
                            agent_dangers__nextDangersTraceCheckTime : float = 0.1f;
                            var human_stat_tracking__targetTracesCount : int?;
                            agent_dangers__minTraceableRatio : float = 3.7;
                            agent_dangers__retraceTargetsTime : float = 30f;
                            agent_dangers__maxDangerDist : float = 100f;
                            agent_dangers_calc__dangerMeterMult : float = 1f;
                            agent_dangers__hmapTraceOffset : float3 = float3(0., 0., 0.);
                            human_attached_gun__attachedGunEid = INVALID_ENTITY_ID;
                            human_weap__currentGunEid = INVALID_ENTITY_ID;
                            var human_stat_tracking__totalDangers : float?)
  if act.curTime < agent_dangers__nextDangersTraceTime
    return

  trace_agent_dangers(eid, isAlive, agent_dangers, agent_dangers__standShootPos, beh_tree__enabled, agent_dangers__nextDangersTraceTime,
                      danger_calc__aiCoef, danger_calc__avoidBulletsNearTime, danger_calc__lastShootCoef, danger_calc__noiseCoef,
                      danger_calc__lastBulletNearbyCoef, danger_calc__rayMatId, danger_calc__useRayMatForce, danger_calc__tooNearDistance,
                      attract_point__eid, danger_calc__magnitudeTreshhold, danger_calc__observeAngleCosTreshhold, human_net_phys__aimDir,
                      navmesh_phys__currentLookDir, agent_dangers__nextDangersTraceCheckTime, human_stat_tracking__targetTracesCount,
                      agent_dangers__minTraceableRatio, agent_dangers__retraceTargetsTime, agent_dangers__maxDangerDist,
                      agent_dangers_calc__dangerMeterMult, agent_dangers__hmapTraceOffset, human_attached_gun__attachedGunEid,
                      human_weap__currentGunEid, human_stat_tracking__totalDangers)


[es(tag=server, after=(ai_target_es, ai_target_transform_es))]
def trace_agent_dangers_by_event(evt : CmdTraceAgentDangers;
                                 eid : EntityId;
                                 isAlive : bool;
                                 var agent_dangers : AgentDangers;
                                 agent_dangers__standShootPos : float3;
                                 beh_tree__enabled : bool = true;
                                 var agent_dangers__nextDangersTraceTime : float&;
                                 danger_calc__aiCoef : float2;
                                 danger_calc__avoidBulletsNearTime : float;
                                 danger_calc__lastShootCoef : float2;
                                 danger_calc__noiseCoef : float2;
                                 danger_calc__lastBulletNearbyCoef : float2;
                                 danger_calc__rayMatId : int;
                                 danger_calc__useRayMatForce : bool;
                                 danger_calc__tooNearDistance : float;
                                 attract_point__eid : EntityId;
                                 danger_calc__magnitudeTreshhold : float;
                                 danger_calc__observeAngleCosTreshhold : float;
                                 human_net_phys__aimDir : float3 const?;
                                 navmesh_phys__currentLookDir : float3 const?;
                                 agent_dangers__nextDangersTraceCheckTime : float = 0.1f;
                                 var human_stat_tracking__targetTracesCount : int?;
                                 agent_dangers__minTraceableRatio : float = 3.7;
                                 agent_dangers__retraceTargetsTime : float = 30f;
                                 agent_dangers__maxDangerDist : float = 100f;
                                 agent_dangers_calc__dangerMeterMult : float = 1f;
                                 agent_dangers__hmapTraceOffset : float3 = float3(0., 0., 0.);
                                 human_attached_gun__attachedGunEid = INVALID_ENTITY_ID;
                                 human_weap__currentGunEid = INVALID_ENTITY_ID;
                                 var human_stat_tracking__totalDangers : float?)
  if evt.forceRetrace
    for i in iter_range(agent_dangers.dangers)
      assume danger = agent_dangers.dangers[i]
      danger.lastTraceTime = 0.0

  trace_agent_dangers(eid, isAlive, agent_dangers, agent_dangers__standShootPos, beh_tree__enabled, agent_dangers__nextDangersTraceTime,
                      danger_calc__aiCoef, danger_calc__avoidBulletsNearTime, danger_calc__lastShootCoef, danger_calc__noiseCoef,
                      danger_calc__lastBulletNearbyCoef, danger_calc__rayMatId, danger_calc__useRayMatForce, danger_calc__tooNearDistance,
                      attract_point__eid, danger_calc__magnitudeTreshhold, danger_calc__observeAngleCosTreshhold, human_net_phys__aimDir,
                      navmesh_phys__currentLookDir, agent_dangers__nextDangersTraceCheckTime, human_stat_tracking__targetTracesCount,
                      agent_dangers__minTraceableRatio, agent_dangers__retraceTargetsTime, agent_dangers__maxDangerDist,
                      agent_dangers_calc__dangerMeterMult, agent_dangers__hmapTraceOffset, human_attached_gun__attachedGunEid,
                      human_weap__currentGunEid, human_stat_tracking__totalDangers)