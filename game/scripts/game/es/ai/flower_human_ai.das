require ecs
require ecs.safe
require walkerai
require DagorMath
require pathfinder
require math.random
require Grid


[es(tag=server, no_order, REQUIRE=flowerHumanUtilVars)]
def flower_human_util_vars(act : UpdateStageInfoAct; agent_dangers : AgentDangers;
                           attract_point__eid, walker_agent__targetEid : EntityId;
                           attract_point__ratio : float;
                           sleep_mode__blindDistancesSq, sleep_mode__wakeupDistancesSq : float2;
                           sleep_mode__isSleeping, sleep_mode__triggered : bool;
                           visual_attract__points : Array;
                           var util_vars__isSleeping, util_vars__triggered : bool&;
                           var util_vars__visibleTargets, util_vars__offenderHitCoef, util_vars__attractPointRatio : float&;
                           var util_vars__visibleAttractPoints : float&;
                           var util_vars__ready : bool&;
                           var agent_dangers__blindDistanceSq, sleep_mode__nextUpdateAt : float&;
                           agent_dangers__lastHitReactionTime = 0f;
                           zone_patroller__currentAggroMult = 1f)
  if util_vars__ready
    return

  util_vars__isSleeping = sleep_mode__isSleeping
  util_vars__triggered = sleep_mode__triggered
  util_vars__visibleTargets = 0f
  util_vars__attractPointRatio = 0f
  util_vars__visibleAttractPoints = 0f

  if util_vars__isSleeping
    agent_dangers__blindDistanceSq = sleep_mode__blindDistancesSq.x
  else
    agent_dangers__blindDistanceSq = rnd_float(sleep_mode__wakeupDistancesSq)
    let minDanger = safediv(0.1, zone_patroller__currentAggroMult)
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

    // visual_attract.maxDist is too small and we can wake up with flashlights
    util_vars__visibleAttractPoints = 0f
    for it in visual_attract__points
      if (it as Object)?.visible ?? false
        util_vars__visibleAttractPoints += 1f

    let hasAnyDisaster = (util_vars__visibleTargets > 0. || util_vars__attractPointRatio > 0. || util_vars__visibleAttractPoints > 0.)
    if hasAnyDisaster
      agent_dangers__blindDistanceSq = sleep_mode__blindDistancesSq.y
      sleep_mode__nextUpdateAt = max(sleep_mode__nextUpdateAt, act.curTime + 1f)

  util_vars__offenderHitCoef = agent_dangers__lastHitReactionTime > 0f ? 10f / (1f + (act.curTime - agent_dangers__lastHitReactionTime)) : 0f

  util_vars__ready = true


[es(tag=server, before=beh_tree_update_es)]
def random_awake_on_human_approach(act : UpdateStageInfoAct;
                                   transform : float3x4;
                                   flowermen_random_awaker__awakeChance : float;
                                   flowermen_random_awaker__awakerRadius : float;
                                   flowermen_random_awaker__updatePeriod : float;
                                   var flowermen_random_awaker__nextUpdateAt : float&)
  if act.curTime < flowermen_random_awaker__nextUpdateAt
    return

  flowermen_random_awaker__nextUpdateAt = act.curTime + flowermen_random_awaker__updatePeriod

  for_each_entity_in_grid(ecs_hash("humans"), BSphere3(transform[3], flowermen_random_awaker__awakerRadius), GridEntCheck.BOUNDING) <| $(eid : EntityId)
    query(eid) <| $ [es(REQUIRE=flowerHuman, REQUIRE=flower_human_sleeping_server, REQUIRE_NOT=sleep_mode_wakeup_forbidden)] (sleep_mode__extraAwakeChance : float = 0.0;
                                                                                                                              var sleep_mode__isSleeping : bool&;
                                                                                                                              var sleep_mode__triggered : bool&;
                                                                                                                              var sleep_mode__triggerPoint : float3&)
      if gfrnd() > flowermen_random_awaker__awakeChance + sleep_mode__extraAwakeChance
        return

      sleep_mode__isSleeping = false
      sleep_mode__triggered = true
      sleep_mode__triggerPoint = transform[3]


[es(tag=netClient, on_appear, REQUIRE=flower_human_sleeping_server)]
def remove_flower_human_sleeping_server_from_client(evt : Event; eid : EntityId)
  removeSubTemplate(eid, "flower_human_sleeping_server")


[es(tag=netClient, on_appear, REQUIRE=flower_human_awake_server)]
def remove_flower_human_awake_server_from_client(evt : Event; eid : EntityId)
  removeSubTemplate(eid, "flower_human_awake_server")
