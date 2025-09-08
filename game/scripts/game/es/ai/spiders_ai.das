require ecs
require ecs.safe
require walkerai
require math.base
require DagorMath
require GridCollision
require Grid


[es(tag=server, no_order, REQUIRE=spiderUtilVars)]
def spider_util_vars(act : UpdateStageInfoAct; agent_dangers : AgentDangers;
                     visual_attract__points : Array;
                     attract_point__eid : EntityId;
                     attract_point__ratio : float;
                     var util_vars__visibleTargets, util_vars__offenderHitCoef : float&;
                     var util_vars__lastBulletReactionCoef, util_vars__visibleAttractPoints : float&;
                     var util_vars__ready : bool&;
                     var util_vars__attractPointRatio : float&;
                     agent_dangers__lastHitReactionTime = 0f;
                     agent_dangers__lastBulletReactionTime = 0f;
                     zone_patroller__currentAggroMult = 1f)
  if util_vars__ready
    return

  let minDanger = safediv(0.1, zone_patroller__currentAggroMult)
  util_vars__visibleTargets = 0f
  for target in agent_dangers.dangers
    if target.traceable && target.dangerMeter >= minDanger
      util_vars__visibleTargets += 1f

  util_vars__offenderHitCoef = agent_dangers__lastHitReactionTime > 0f ? 10f / (1f + (act.curTime - agent_dangers__lastHitReactionTime)) : 0f
  util_vars__lastBulletReactionCoef = agent_dangers__lastBulletReactionTime > 0f ? 5f / (1f + (act.curTime - agent_dangers__lastBulletReactionTime)) : 0f

  util_vars__visibleAttractPoints = 0f
  for it in visual_attract__points
    if (it as Object)?.visible ?? false
      util_vars__visibleAttractPoints += 1f

  // start attract ratio from 0.5 to beat gotohome node
  util_vars__attractPointRatio = attract_point__eid != INVALID_ENTITY_ID ? 0.5 + attract_point__ratio : 0f

  util_vars__ready = true


[es(tag=server, before=spider_util_vars, REQUIRE=spidersOffensiveZone)]
def update_spiders_aggression(act : UpdateStageInfoAct; transform : float3x4;
                              offensive_zone__radius, offensive_zone__checkInterval : float;
                              var offensive_zone__nextCheck : float&; var offensive_zone__inside : EidList;
                              offensive_zone__maxAggressionNum = 14)
  if act.curTime < offensive_zone__nextCheck
    return
  offensive_zone__nextCheck = act.curTime + offensive_zone__checkInterval

  for it in offensive_zone__inside
    query(it) <| $ [es] (var util_vars__aggressionLevel : float&)
      util_vars__aggressionLevel = 0f
  offensive_zone__inside |> clear()

  var spidersAggression : array<float?>
  for_each_entity_in_grid(ecs_hash("humans"), BSphere3(transform[3], offensive_zone__radius), GridEntCheck.BOUNDING) <| $(spiderEid : EntityId)
    query(spiderEid) <| $ [es(REQUIRE=(spider, util_vars__aggressionLevel),
                              REQUIRE_NOT=(util_vars__personalAggression, deadEntity))] (var util_vars__aggressionLevel : float?)
      spidersAggression |> push(util_vars__aggressionLevel)
      offensive_zone__inside |> push(spiderEid)

  let agression = saturate(safediv(float(length(spidersAggression)), float(offensive_zone__maxAggressionNum)))
  for agro in spidersAggression
    *agro = agression


[es(tag=server, on_appear, REQUIRE=spiderUtilVars)]
def spider_master_init(evt : Event;
                       transform aka minion_transform : float3x4;
                       unit__masterDetectRadiusSq : float = square(3.0);
                       var unit__masterEid : EntityId&)
  var minDistSq = VERY_BIG_NUMBER
  query() <| $ [es(REQUIRE=spiderUtilVars, REQUIRE_NOT=unit__masterEid)] (eid : EntityId;
                                                                          transform aka master_transform : float3x4)
    let distSq = distance_sq(minion_transform[3], master_transform[3])
    if distSq <= unit__masterDetectRadiusSq && distSq < minDistSq
      minDistSq = distSq
      unit__masterEid = eid
