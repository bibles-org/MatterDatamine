require app
require ecs
require ecs.safe
require walkerai
require math.base
require ecs.soa_template
require pathfinder
require DagorMath
require DagorSystem
require DagorRandom
require GridCollision
require Grid
require math.random
require game.es.monsters_common
require game.es.entity_mods_common
require game.events.events_game


[soa_def]
def find_index_in_invisible_man_target_data_list(list : InvisibleManTargetData_SOA; target : EntityId)
  for idx, id in range(length(list)), list
    if id.invisible_man_target_data__eid == target
      return idx
  return -1


def spawn_invisible_man(invisible_man_template : string;
                        target_eid : EntityId;
                        angle_range_spread : float2;
                        distance_range_spread : float2;
                        force_rage : bool)
  query(target_eid) <| $ [es] (transform aka target_transform : float3x4)
    let targetLookDir = target_transform[0]
    let targetPos = target_transform[3]
    let tries = 3
    var pos : float3
    var posGood = false
    for _ in range(tries)
      let baseAngle = atan2(-targetLookDir.z, -targetLookDir.x)
      let randAngle = rnd_float(baseAngle + angle_range_spread.x, baseAngle + angle_range_spread.y)
      var sine, cosine : float
      sincos(randAngle, sine, cosine)
      pos = targetPos + float3(cosine, 0.0, sine) * rnd_float(distance_range_spread.x, distance_range_spread.y)
      if project_to_nearest_navmesh_point(pos, 1.0)
        let extents = float3(1.0, FLT_MAX, 1.0)
        using(pos, targetPos, extents) <| $(var req : FindRequest#)
          if check_path(req, extents.x, extents.x)
            posGood = true
      if posGood
        break

    createEntity(invisible_man_template) <| $(var init : ComponentsInitializer)
      var tm = IDENT_TM
      tm[3] = pos
      set(init, "transform", tm)
      set(init, "invisible_man__mainEnemyEid", target_eid)

      if force_rage
        set(init, "invisible_man__inRage", true)
        set(init, "invisible_man__inRageVanishChance", 0.0)


[es(tag=server, on_appear, REQUIRE=possessedByPlr, REQUIRE_NOT=(encounter_guard))]
def invisible_man_manager_target_appear(evt : Event;
                                        eid : EntityId;
                                        transform : float3x4)
  find_query() <| $ [soa_blk, es] (invisible_man_manager__initialSpawnTime : float2;
                                   invisible_man_manager__inactivityCheckTime : float = 5.0;
                                   var invisible_man_target_data : InvisibleManTargetData_SOA)
    let initialSpawnTime = rnd_float(invisible_man_manager__initialSpawnTime)
    invisible_man_target_data |> push() <| InvisibleManTargetData(
          invisible_man_target_data__eid = eid,
          invisible_man_target_data__spawnTime = (get_sync_time() + initialSpawnTime),
          invisible_man_target_data__lastSpawnTime = get_sync_time(),
          invisible_man_target_data__inactivityCheckTime = (get_sync_time() + invisible_man_manager__inactivityCheckTime),
          invisible_man_target_data__lastMovementStartPos = transform[3],
          invisible_man_target_data__lastMovementTime = get_sync_time()
        )
    return true


[es(tag=server, on_disappear, on_event=EventEntityDied, REQUIRE=possessedByPlr)]
def invisible_man_manager_target_disappear(evt : Event;
                                           eid : EntityId)
  find_query() <| $ [soa_blk, es] (var invisible_man_target_data : InvisibleManTargetData_SOA)
    let index = find_index_in_invisible_man_target_data_list(invisible_man_target_data, eid)
    if index >= 0
      invisible_man_target_data |> erase(index)
    return true


[soa_es, es(tag=server, no_order)]
def invisible_man_manager_update(act : UpdateStageInfoAct;
                                 invisible_man_manager__spawnAngleRangeSpread : float2 = float2(-90, 90);
                                 invisible_man_manager__spawnDistanceRangeSpread : float2 = float2(1.0, 10.0);
                                 invisible_man_manager__requiredMovementDistanceSq : float = square(125.0);
                                 invisible_man_manager__spawnTime : float2;
                                 invisible_man_manager__noMovementPenaltyTime : float;
                                 invisible_man_manager__noMovementPenaltyKoef : float;
                                 invisible_man_manager__noAttackPenaltyTime : float;
                                 invisible_man_manager__noAttackPenaltyKoef : float;
                                 invisible_man_manager__noDangerPenaltyTime : float;
                                 invisible_man_manager__noDangerPenaltyKoef : float;
                                 invisible_man_manager__spawnPatterns : Array;
                                 invisible_man_manager__extraSpawnTimePerSpawnIndex : float = 30.0;
                                 invisible_man_manager__inactivityCheckTime : float = 5.0;
                                 invisible_man_manager__requiredEnemyDistance : float = 10.0;
                                 invisible_man_manager__maxSpawnCount : int = 3;
                                 invisible_man_manager__shootProtectionTime : float = 0.0;
                                 var invisible_man_target_data : InvisibleManTargetData_SOA)
  assume inactivityCheckTime = invisible_man_manager__inactivityCheckTime
  for targetData in invisible_man_target_data
    if act.curTime >= targetData.invisible_man_target_data__inactivityCheckTime
      query(targetData.invisible_man_target_data__eid) <| $ [es(REQUIRE_NOT=deadEntity)] (transform aka my_transform : float3x4;
                                                                                          team aka my_team : int;
                                                                                          human_weap__lastShotAtTime : float;
                                                                                          human_weap__lastMeleeAttackAtTime : float;
                                                                                          entity_mod_values : Object const?)
        let movementDistanceSq = distance_sq(targetData.invisible_man_target_data__lastMovementStartPos, transform[3])
        if movementDistanceSq >= invisible_man_manager__requiredMovementDistanceSq
          targetData.invisible_man_target_data__lastMovementStartPos = transform[3]
          targetData.invisible_man_target_data__lastMovementTime = act.curTime

        let bsphere = BSphere3(my_transform[3], invisible_man_manager__requiredEnemyDistance)
        let enemyEid = find_entity_in_grid(fixed_array(ecs_hash("humans"), ecs_hash("creatures")), bsphere, GridEntCheck.POS) <| $(objEid : EntityId)
          var result = false
          query(objEid) <| $ [es(REQUIRE_NOT=ai_target__autoGunTarget, REQUIRE=ai_target, REQUIRE_NOT=deadEntity)] (team aka target_team : int;
                                                                                                                    isAlive : bool = true)
            if my_team == target_team || !isAlive
              return
            result = true
          return result

        if enemyEid != INVALID_ENTITY_ID
          targetData.invisible_man_target_data__lastDangerTime = act.curTime

        let spawnFreqMult = entity_mod_values == null ? 1.0 : get_mod_value("invisbleManSpawnFreqMult", *entity_mod_values, 1.0)

        // Movement penalty
        if act.curTime - targetData.invisible_man_target_data__lastMovementTime >= invisible_man_manager__noMovementPenaltyTime
          targetData.invisible_man_target_data__spawnTime -= inactivityCheckTime * invisible_man_manager__noMovementPenaltyKoef * spawnFreqMult

        // Attack penalty
        let lastAttackAtTime = max(human_weap__lastShotAtTime, human_weap__lastMeleeAttackAtTime)
        if act.curTime - lastAttackAtTime >= invisible_man_manager__noAttackPenaltyTime
          targetData.invisible_man_target_data__spawnTime -= inactivityCheckTime * invisible_man_manager__noAttackPenaltyKoef * spawnFreqMult

        // No danger penalty
        if act.curTime - targetData.invisible_man_target_data__lastMovementTime >= invisible_man_manager__noDangerPenaltyTime
          targetData.invisible_man_target_data__spawnTime -= inactivityCheckTime * invisible_man_manager__noDangerPenaltyKoef * spawnFreqMult

      targetData.invisible_man_target_data__inactivityCheckTime = act.curTime + invisible_man_manager__inactivityCheckTime

    if act.curTime >= targetData.invisible_man_target_data__spawnTime

      var spawnAvailable = true
      var spawnFreqMult = 1.0
      query(targetData.invisible_man_target_data__eid) <| $ [es(REQUIRE_NOT=deadEntity)] (human_weap__lastShotAtTime : float;
                                                                                          entity_mod_values : Object const?)
        spawnFreqMult = entity_mod_values == null ? 1.0 : get_mod_value("invisbleManSpawnFreqMult", *entity_mod_values, 1.0)
        if (act.curTime - human_weap__lastShotAtTime) < invisible_man_manager__shootProtectionTime
          spawnAvailable = false

      if spawnAvailable
        let spawnCount = min(1 + targetData.invisible_man_target_data__spawnIndex, invisible_man_manager__maxSpawnCount)
        targetData.invisible_man_target_data__spawningCount += spawnCount
        targetData.invisible_man_target_data__lastSpawnTime = act.curTime
        let spawnIndex = ++targetData.invisible_man_target_data__spawnIndex
        let extraSpawnTimePerSpawnIndex = invisible_man_manager__extraSpawnTimePerSpawnIndex * float(spawnIndex)

        let spawnTime = rnd_float(invisible_man_manager__spawnTime)
        targetData.invisible_man_target_data__spawnTime = act.curTime + (spawnTime + extraSpawnTimePerSpawnIndex) / spawnFreqMult


    if targetData.invisible_man_target_data__spawningCount > 0 && length(invisible_man_manager__spawnPatterns) > 0
      let patternIdx = grnd() % length(invisible_man_manager__spawnPatterns)
      let spawnPattern = get_ecs_object(invisible_man_manager__spawnPatterns[patternIdx])
      let scaleParam = (*spawnPattern).scaleParam ?? ""
      let targetParam = (*spawnPattern).targetParam ?? ""
      let spawnTempl = (*spawnPattern).spawnTempl ?? ""
      if empty(scaleParam)
        let forceRage = (targetData.invisible_man_target_data__spawningCount > 1 ||
          targetData.invisible_man_target_data__spawnIndex > 3)
        spawn_invisible_man(
          spawnTempl, targetData.invisible_man_target_data__eid,
          float2(deg_to_rad(invisible_man_manager__spawnAngleRangeSpread.x),
                  deg_to_rad(invisible_man_manager__spawnAngleRangeSpread.y)),
          invisible_man_manager__spawnDistanceRangeSpread, forceRage)
        targetData.invisible_man_target_data__spawningCount--
      else
        targetData.invisible_man_target_data__spawningCount = 0
        createEntity(spawnTempl) <| $(var init)
          init |> set(scaleParam, targetData.invisible_man_target_data__spawningCount)
          init |> set(targetParam, targetData.invisible_man_target_data__eid)


def find_danger(var agent_dangers : AgentDangers; eid : EntityId)
  for i in iter_range(agent_dangers.dangers)
    if agent_dangers.dangers[i].eid == eid
      return i
  return -1


[es(tag=server, on_appear)]
def invisible_man_init(evt : Event;
                       invisible_man__type : int;
                       invisible_man__mainEnemyEid : EntityId;
                       invisible_man__mainEnemyChasingTime : float;
                       var invisible_man__vanishAt : float&;
                       var invisible_man__lastAttackTime : float&)
  if invisible_man__type == int(InvisibleManType.HUNTER) && doesEntityExist(invisible_man__mainEnemyEid)
    invisible_man__vanishAt = get_sync_time() + invisible_man__mainEnemyChasingTime

  invisible_man__lastAttackTime = get_sync_time()


[es(tag=server, track=invisible_man__inRage)]
def invisible_man_rage_vanish(evt : Event;
                              invisible_man__type : int;
                              invisible_man__inRage : bool;
                              invisible_man__inRageVanishChance : float;
                              invisible_man__inRageRetreatTime : float = 1.0;
                              var invisible_man__vanishAt : float&)
  if invisible_man__type == int(InvisibleManType.HUNTER)
    if invisible_man__inRage
      if gfrnd() <= invisible_man__inRageVanishChance
        invisible_man__vanishAt = get_sync_time() + invisible_man__inRageRetreatTime


[es(tag=server, on_appear, track=invisible_man__inRage)]
def invisible_man_rage_track(evt : Event;
                             invisible_man__inRage : bool;
                             var invisible_man__forceForwardAttack : bool&)
  if invisible_man__inRage
    invisible_man__forceForwardAttack = true


[es(tag=server, after=(ai_danger_update_alertness, ai_danger_trace_targets))]
def invisible_man_ai_update(act : UpdateStageInfoAct;
                            transform aka invisible_man_transform : float3x4;
                            hitpoints__hp : float;
                            hitpoints__maxHp : float;
                            hitpoints__timeFromLastDamage : float const?;
                            invisible_man__timeFromLastDamageToVanish : float;
                            invisible_man__rageHpRatio : float;
                            invisible_man__vanishAt : float;
                            invisible_man__lastAttackTime : float;
                            invisible_man__timeFromLastAttackToVanish : float;
                            invisible_man__type : int;
                            var invisible_man__forceVanish : bool&;
                            var agent_dangers : AgentDangers;
                            var invisible_man__mainEnemyEid : EntityId&;
                            var invisible_man__inRage : bool&;
                            var invisible_man__inRageVanishChance : float&;
                            var invisible_man__forceForwardAttack : bool&;
                            var invisible_man__forceForwardAttackAt : float&)
  if invisible_man__forceForwardAttackAt > 0.0 && act.curTime >= invisible_man__forceForwardAttackAt
    invisible_man__forceForwardAttackAt = 0.0
    invisible_man__forceForwardAttack = true

  if invisible_man__type == int(InvisibleManType.HUNTER)
    if invisible_man__vanishAt > 0.0 && act.curTime >= invisible_man__vanishAt
      invisible_man__forceVanish = true

    if hitpoints__timeFromLastDamage != null && *hitpoints__timeFromLastDamage >= invisible_man__timeFromLastDamageToVanish
      invisible_man__forceVanish = true

    let timeFromLastAttack = act.curTime - invisible_man__lastAttackTime
    if timeFromLastAttack >= invisible_man__timeFromLastAttackToVanish
      invisible_man__forceVanish = true
    elif timeFromLastAttack >= invisible_man__timeFromLastAttackToVanish * 0.5
      invisible_man__inRage = true
      invisible_man__inRageVanishChance = 0.0

  let hpRatio = safediv(hitpoints__hp, hitpoints__maxHp)

  if !invisible_man__inRage
    invisible_man__inRage = (hpRatio <= invisible_man__rageHpRatio)

  if !invisible_man__inRage
    var i = length(agent_dangers.dangers)
    while --i >= 0
      assume danger = agent_dangers.dangers[i]
      let isDowned = get_bool(danger.eid, "isDowned") ?? false
      if isDowned
        agent_dangers.dangers |> erase(i)

  if doesEntityExist(invisible_man__mainEnemyEid)
    if length(agent_dangers.dangers) == 0
      query(invisible_man__mainEnemyEid) <| $ [es] (isAlive : bool;
                                                    transform aka main_enemy_transform : float3x4;
                                                    another_dimension_visitor__inside : bool = false;
                                                    isDowned : bool = false)
        if !isAlive
          invisible_man__mainEnemyEid = INVALID_ENTITY_ID
          return
        if another_dimension_visitor__inside
          return

        if !isDowned
          using() <| $(var newDanger : Danger#)
            newDanger.eid = invisible_man__mainEnemyEid
            newDanger.inFrustumTime = -1.0
            newDanger.distance = distance(invisible_man_transform[3], main_enemy_transform[3])
            newDanger.alertness = 1000.0
            newDanger.dangerMeter = 5.0
            newDanger.noiseMeter = 5.0
            newDanger.traceable = true
            push_clone(agent_dangers.dangers, newDanger)
    else
      let dangerIndex = find_danger(agent_dangers, invisible_man__mainEnemyEid)
      if dangerIndex >= 0
        agent_dangers.dangers[dangerIndex].traceable = true


[es(tag=server, track=walker_agent__targetEid)]
def invisible_man_walker_agent_target_track(evt : Event;
                                            walker_agent__targetEid : EntityId;
                                            invisible_man__forceForwardAttackTime : float;
                                            invisible_man__inRage : bool;
                                            var invisible_man__forceForwardAttack : bool&;
                                            var invisible_man__forceForwardAttackAt : float&)
  if doesEntityExist(walker_agent__targetEid) && !invisible_man__inRage
    invisible_man__forceForwardAttack = false
    invisible_man__forceForwardAttackAt = get_sync_time() + invisible_man__forceForwardAttackTime


[es(tag=server, track=util_vars__inAttackState)]
def invisible_man_attack_state_changed(evt : Event;
                                       util_vars__inAttackState : bool;
                                       invisible_man__forceForwardAttackTime : float;
                                       invisible_man__inRage : bool;
                                       var invisible_man__forceForwardAttack : bool&;
                                       var invisible_man__forceForwardAttackAt : float&;
                                       var invisible_man__lastAttackTime : float&)
  if util_vars__inAttackState == false && !invisible_man__inRage
    invisible_man__forceForwardAttack = false
    invisible_man__forceForwardAttackAt = get_sync_time() + invisible_man__forceForwardAttackTime

    invisible_man__lastAttackTime = get_sync_time()


[es(tag=server, no_order, REQUIRE=invisibleManUtilVars)]
def invisible_man_util_vars(act : UpdateStageInfoAct;
                            agent_dangers : AgentDangers;
                            visual_attract__points : Array;
                            attract_point__eid : EntityId;
                            attract_point__ratio : float;
                            var util_vars__visibleTargets, util_vars__offenderHitCoef : float&;
                            var util_vars__lastBulletReactionCoef, util_vars__visibleAttractPoints : float&;
                            var util_vars__ready : bool&;
                            var util_vars__attractPointRatio : float&;
                            invisible_man__mainEnemyEid : EntityId;
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

  if util_vars__visibleTargets == 0f && doesEntityExist(invisible_man__mainEnemyEid)
    util_vars__visibleTargets = 1f

  util_vars__offenderHitCoef = agent_dangers__lastHitReactionTime > 0f ? 10f / (1f + (act.curTime - agent_dangers__lastHitReactionTime)) : 0f
  util_vars__lastBulletReactionCoef = agent_dangers__lastBulletReactionTime > 0f ? 5f / (1f + (act.curTime - agent_dangers__lastBulletReactionTime)) : 0f

  util_vars__visibleAttractPoints = 0f
  for it in visual_attract__points
    if (it as Object)?.visible ?? false
      util_vars__visibleAttractPoints += 1f

  // start attract ratio from 0.5 to beat gotohome node
  util_vars__attractPointRatio = attract_point__eid != INVALID_ENTITY_ID ? 0.5 + attract_point__ratio : 0f

  util_vars__ready = true


[es(tag=server, on_appear, track=another_dimension_visitor__inside)]
def invisible_man_track_another_dimension_state(evt : Event;
                                                eid aka invisible_man_eid : EntityId;
                                                another_dimension_visitor__inside : bool;
                                                var invisible_man__anotherDimensionAffectEid : EntityId&)
  destroyEntity(invisible_man__anotherDimensionAffectEid)

  var anotherDimensionAffectTemplateName = ""
  if another_dimension_visitor__inside
    anotherDimensionAffectTemplateName = "invisible_man_invisibility_affect"
  else
    anotherDimensionAffectTemplateName = "invisible_man_visibility_affect"

  invisible_man__anotherDimensionAffectEid = createEntity(anotherDimensionAffectTemplateName) <| $(var init : ComponentsInitializer)
    init |> set("game_effect__attachedTo", invisible_man_eid)
    init |> set("game_effect__ownerEid", invisible_man_eid)


[es(tag=(server, dev), REQUIRE=test_invisible_man_spawner)]
def test_invisible_man_spawner(evt : EventZoneEnter;
                               test_invisible_man_spawner__template : string;
                               test_invisible_man_spawner__spawnAngleRangeSpread : float2 = float2(-90, 90);
                               invisible_man_manager__spawnDistanceRangeSpread : float2 = float2(1.0, 5.0);
                               invisible_man_manager__forceRage : bool = false)
  spawn_invisible_man(
    test_invisible_man_spawner__template, evt.visitorEid,
    float2(deg_to_rad(test_invisible_man_spawner__spawnAngleRangeSpread.x),
            deg_to_rad(test_invisible_man_spawner__spawnAngleRangeSpread.y)),
    invisible_man_manager__spawnDistanceRangeSpread,
    invisible_man_manager__forceRage)