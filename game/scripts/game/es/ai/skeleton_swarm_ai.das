require ecs
require ecs.safe
require walkerai
require DagorMath
require active_matter.game.es.skeleton_swarm_state_common
require pathfinder


[es(tag=server, no_order, REQUIRE=skeletonSwarmUtilVars)]
def skeleton_swarm_util_vars(act : UpdateStageInfoAct; agent_dangers : AgentDangers;
                             visual_attract__points : Array;
                             walker_agent__targetEid, attract_point__eid : EntityId;
                             skeleton_swarm__aiState : int;
                             attract_point__ratio : float;
                             sleep_mode__isSleeping : bool;
                             var util_vars__isSleeping : bool&;
                             var util_vars__inSkeletonState : bool&;
                             var util_vars__visibleTargets, util_vars__offenderHitCoef : float&;
                             var util_vars__lastBulletReactionCoef, util_vars__visibleAttractPoints : float&;
                             var util_vars__ready : bool&;
                             var util_vars__attractPointRatio, sleep_mode__nextUpdateAt : float&;
                             agent_dangers__lastHitReactionTime = 0f;
                             agent_dangers__lastBulletReactionTime = 0f;
                             zone_patroller__currentAggroMult = 1f)
  if util_vars__ready
    return

  util_vars__inSkeletonState = skeleton_swarm__aiState == int(SkeletonSwarmAiState.SKELETON_STAND)
  util_vars__isSleeping = sleep_mode__isSleeping

  util_vars__visibleTargets = 0f
  util_vars__attractPointRatio = 0f
  util_vars__visibleAttractPoints = 0f

  if !util_vars__isSleeping
    let minDanger = safediv(0.1f, zone_patroller__currentAggroMult)
    for target in agent_dangers.dangers
      // use alertness, dangerMeter is 0 for untracable targets
      if target.eid == walker_agent__targetEid && target.alertness > minDanger
        util_vars__visibleTargets += 1f
        continue
      if target.traceable && target.dangerMeter >= minDanger
        query(target.eid) <| $ [es] (transform : float3x4)
          var targetPos = transform[3]
          if project_to_nearest_navmesh_point(targetPos, float3(2)) // melee attack distance
            util_vars__visibleTargets += 1f

    // start attract ratio from 0.5 to beat gotohome node
    util_vars__attractPointRatio = attract_point__eid != INVALID_ENTITY_ID ? 0.5 + attract_point__ratio : 0f

    for it in visual_attract__points
      if (it as Object)?.visible ?? false
        util_vars__visibleAttractPoints += 1f

    util_vars__lastBulletReactionCoef = agent_dangers__lastBulletReactionTime > 0. ? 5. / (1. + (act.curTime - agent_dangers__lastBulletReactionTime)) : 0f

    let hasAnyDisaster = (util_vars__visibleTargets > 0f || util_vars__attractPointRatio > 0.
                          || util_vars__visibleAttractPoints > 0. || agent_dangers__lastBulletReactionTime > 1.)

    if hasAnyDisaster
      sleep_mode__nextUpdateAt = max(sleep_mode__nextUpdateAt, act.curTime + 1f)

  util_vars__offenderHitCoef = agent_dangers__lastHitReactionTime > 0f ? 10f / (1f + (act.curTime - agent_dangers__lastHitReactionTime)) : 0f

  util_vars__ready = true
