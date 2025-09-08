require ecs
require ecs.safe
require app
require net
require CollRes
require DngNet
require DngDm
require math.base
require math.random
require Grid
require PhysVars
require DagorMath
require GridCollision
require AnimV20
require pathfinder
require game.es.changed_common
require game.es.ecs_common
require game.utils.team
require game.events.events_game
require danetlibs.dm.dm_events
require game.events.events_active_matter
require GridCollision
require CollisionTraces
require PhysMat
require Dacoll
require DngHuman
require DagorSystem
require GeomNodeTree
require game.es.flashlights.flashlight_common
require game.es.ai.agent_position_mapping_common


[es(on_appear)]
def changed_blink_on_appear(evt : Event;
                            changed__blinkTraceMat : string;
                            var changed__blinkTraceMatId : int&)
  changed__blinkTraceMatId = get_material_id(changed__blinkTraceMat)


[es(tag=server)]
def trigger_changeds_on_death(evt : EventEntityDied;
                              transform : float3x4;
                              agent_dangers__killTriggerRadius : float;
                              agent_dangers__killTriggerMaxCount : int)
  if evt.victimTeam != evt.offenderTeam && evt.offenderTeam != TEAM_UNASSIGNED
    trigger_changeds_around(agent_dangers__killTriggerRadius, transform[3], agent_dangers__killTriggerMaxCount)


[es(no_order, REQUIRE=agentInClimbing)]
def play_climb_animation(act : UpdateStageInfoAct;
                         anim_state__climbState : int;
                         walker_agent__climbingStart : float;
                         walker_agent__climbingFinish : float;
                         anim_state__climbProgressVarId : int;
                         var phys_vars : PhysVars?;
                         var anim_state__forceAnimStateId : int&)
  anim_state__forceAnimStateId = anim_state__climbState
  if phys_vars != null
    let time = cvt(act.curTime - walker_agent__climbingStart, 0.0, walker_agent__climbingFinish - walker_agent__climbingStart, 0.0, 1.0)
    *phys_vars |> setVar(anim_state__climbProgressVarId, time)


[es(tag=server, on_appear, REQUIRE=alarm__active)]
def awake_household_on_alarm(evt : Event; transform aka alarm_transform : float3x4)
  query() <| $ [es(REQUIRE=monster_gen__type)] (eid : EntityId; transform : float3x4)
    if is_inside_tm(alarm_transform[3], transform)
      query() <| $ [es(REQUIRE=sleeping_monster)] (generated_monster__genEid : EntityId)
        if generated_monster__genEid == eid
          sendEventImmediate(eid, CmdAwakeSleepingMonster(propadateCount = 0))


[es(tag=server, after=simple_hitpoints_apply_damage, REQUIRE=sleeping_monster, REQUIRE_NOT=deadEntity)]
def awake_sleeper_on_damaged(evt : CmdApplyDamage;
                             eid : EntityId; isAlive : bool;
                             sleeping_monster__propagateCount = 0;
                             hitpoints__hp : float)
  if hitpoints__hp > .0 && isAlive
    sendEventImmediate(eid, CmdAwakeSleepingMonster(propadateCount = sleeping_monster__propagateCount))



[es(tag=server, on_appear)]
def init_loud_noise_awake_threshold(evt : Event; var changed_loud_noise__awakeThreshold : float&; changed_loud_noise__awakeThresholdRnd : float2)
  changed_loud_noise__awakeThreshold = rnd_float(changed_loud_noise__awakeThresholdRnd)


def get_changed_to_human_ratio(pos : float3; radius : float)
  var changedCount, humanCount = 0
  for_each_entity_in_grid(ecs_hash("humans"), BSphere3(pos, radius), GridEntCheck.POS) <| $(eid : EntityId)
    query(eid) <| $ [es(REQUIRE_NOT=deadEntity, REQUIRE=changed)] (changed_loud_noise__awakened : bool const?; sleeping_monster : Tag const?)
      if ((changed_loud_noise__awakened != null && *changed_loud_noise__awakened) ||
        (changed_loud_noise__awakened == null && sleeping_monster != null))
        changedCount++
    query(eid) <| $ [es(REQUIRE_NOT=deadEntity, REQUIRE=human_net_phys)] ()
      humanCount++
  return humanCount > 0 ? float(changedCount) / float(humanCount) : 0.0


[es(tag=server, track=loud_noise__accumulatedNoise, REQUIRE_NOT=(deadEntity, loud_noise_block_awakening))]
def changed_loud_noise_es(evt : Event;
                          eid : EntityId;
                          transform : float3x4;
                          var loud_noise__accumulatedNoise : float&;
                          var loud_noise__noiseVelocity : float&;
                          changed_loud_noise__awakeThreshold : float;
                          changed_loud_noise__changedToHumanAwakeRatio : float = .0;
                          changed_loud_noise__changedToHumanAwakeRadius : float = .0;
                          sleeping_monster__propagateCount : int = 0)
  if changed_loud_noise__awakeThreshold < loud_noise__accumulatedNoise
    if changed_loud_noise__changedToHumanAwakeRatio != .0 && changed_loud_noise__changedToHumanAwakeRadius != .0
      let changedToHumanRatio = get_changed_to_human_ratio(transform[3], changed_loud_noise__changedToHumanAwakeRadius)
      if changedToHumanRatio >= changed_loud_noise__changedToHumanAwakeRatio
        loud_noise__accumulatedNoise = changed_loud_noise__awakeThreshold - 1.0
        loud_noise__noiseVelocity = min(loud_noise__noiseVelocity, changed_loud_noise__awakeThreshold)
        return
    sendEventImmediate(eid, CmdAwakeSleepingMonster(propadateCount = sleeping_monster__propagateCount))
    loud_noise__accumulatedNoise = .0
    loud_noise__noiseVelocity = .0


[es(tag=server)]
def mark_changed_on_awaken(evt : CmdAwakeSleepingMonster; var changed_loud_noise__awakened : bool&)
  changed_loud_noise__awakened = true


[es(tag=server, on_appear, REQUIRE=sleeping_monster)]
def unmark_changed_on_sleep(evt : Event; var changed_loud_noise__awakened : bool&)
  changed_loud_noise__awakened = false


[es(tag=server, on_appear, REQUIRE_NOT=sleeping_monster)]
def init_changed_blink_timer(evt : Event;
                             changed__blinkPeriod : float2;
                             changed__firstBlinkTimerOffset : float;
                             var changed__blinkAt : float&)
  changed__blinkAt = get_sync_time() + rnd_float(changed__blinkPeriod) + changed__firstBlinkTimerOffset


[es(tag=server)]
def reset_changed_blink_timer_on_awake(evt : CmdAwakeSleepingMonster;
                                       changed__blinkPeriod : float2;
                                       changed__firstBlinkTimerOffset : float;
                                       var changed__blinkAt : float&)
  changed__blinkAt = get_sync_time() + rnd_float(changed__blinkPeriod) + changed__firstBlinkTimerOffset


[es(tag=server)]
def changed_set_time_on_awake(evt : CmdAwakeSleepingMonster; var changed__awakenAt : float&)
  changed__awakenAt = get_sync_time()


[es(on_appear)]
def init_changed_loud_noise_anim(evt : Event;
                                 changed_loud_noise__thrillProgressVar : string;
                                 changed_loud_noise__thrillStateName : string;
                                 animchar : AnimcharBaseComponent;
                                 var phys_vars : PhysVars;
                                 var changed_loud_noise__thrillState : int&;
                                 var changed_loud_noise__thrillProgressVarId : int&)
  changed_loud_noise__thrillProgressVarId = registerVar(phys_vars, changed_loud_noise__thrillProgressVar, 0.0)
  let animGraph = animchar.animGraph
  if animGraph != null
    changed_loud_noise__thrillState = *animGraph |> anim_graph_getStateIdx(changed_loud_noise__thrillStateName)



[es(no_order, REQUIRE=(sleeping_monster, loud_noise_reaction__wasDisturbed), REQUIRE_NOT=deadEntity)]
def play_thrill_animation(act : UpdateStageInfoAct;
                          changed_loud_noise__thrillState : int;
                          loud_noise__accumulatedNoise : float;
                          changed_loud_noise__awakeThreshold : float;
                          changed_loud_noise__thrillProgressVarId : int;
                          animchar__visible : bool = true;
                          var changed_loud_noise__thrillAnimRatio : float&;
                          var phys_vars : PhysVars;
                          var anim_state__forceAnimStateId : int&)
  if !animchar__visible
    return

  if loud_noise__accumulatedNoise > .0 && anim_state__forceAnimStateId != changed_loud_noise__thrillState
    anim_state__forceAnimStateId = changed_loud_noise__thrillState
  elif changed_loud_noise__thrillAnimRatio == 0.0 && anim_state__forceAnimStateId != -1
    anim_state__forceAnimStateId = -1
  let targetRatio = loud_noise__accumulatedNoise / changed_loud_noise__awakeThreshold
  changed_loud_noise__thrillAnimRatio = approach(changed_loud_noise__thrillAnimRatio, targetRatio, act.dt, 0.1)
  phys_vars |> setVar(changed_loud_noise__thrillProgressVarId, changed_loud_noise__thrillAnimRatio)


[es(on_disappear, REQUIRE=(loud_noise_reaction__wasDisturbed), REQUIRE_NOT=deadEntity)]
def stop_thrill_animation(act : Event;
                          changed_loud_noise__thrillProgressVarId : int;
                          var changed_loud_noise__thrillAnimRatio : float&;
                          var phys_vars : PhysVars;
                          var anim_state__forceAnimStateId : int&)
  anim_state__forceAnimStateId = -1
  changed_loud_noise__thrillAnimRatio = 0.0
  phys_vars |> setVar(changed_loud_noise__thrillProgressVarId, .0)


[es(on_disappear, REQUIRE=(sleeping_monster))]
def cancel_thrill_animation(evt : Event;
                            var changed_loud_noise__thrillAnimRatio : float&;
                            var anim_state__forceAnimStateId : int&)
  anim_state__forceAnimStateId = -1
  changed_loud_noise__thrillAnimRatio = 0.0


[es(on_appear, REQUIRE=(sleeping_monster, deadEntity))]
def cancel_thrill_animation_on_death(evt : Event;
                                     eid : EntityId;
                                     sleeping_monster__template : string;
                                     var changed_loud_noise__thrillAnimRatio : float&;
                                     var anim_state__forceAnimStateId : int&)
  anim_state__forceAnimStateId = -1
  changed_loud_noise__thrillAnimRatio = 0.0
  removeSubTemplate(eid, sleeping_monster__template)


[es(tag=gameClient, on_appear, REQUIRE=deadEntity)]
def append_template_on_changed_death(evt : Event;
                                     eid : EntityId;
                                     changed_human__appendOnDeath : string)
  addSubTemplate(eid, changed_human__appendOnDeath)


[es(tag=(gameClient, server), after=unmap_nphys_navmesh_components, REQUIRE_NOT=(deadEntity, nphys__disabled))]
def simulate_snaphotblink_for_local_server_after(act : UpdateStageInfoAct;
                                                 eid : EntityId;
                                                 transform : float3x4;
                                                 navmesh_phys__currentPos : float3;
                                                 loc_snapshots__simulateBlinkPrevPos : float3;
                                                 var loc_snapshots__blink : bool&)
  if loc_snapshots__blink
    loc_snapshots__blink = false
    var prevTm := transform
    prevTm[3] = loc_snapshots__simulateBlinkPrevPos
    var curTm := transform
    curTm[3] = navmesh_phys__currentPos
    sendEvent(eid, EventSnapshotBlink(from = prevTm, to = curTm, dt = act.dt))


[es(tag=gameClient, on_appear, REQUIRE=(changed, sleeping_monster))]
def changed_sleeping_monster_appear_client(evt : Event;
                                           eid : EntityId)
  removeSubTemplate(eid, "changed_human_awaken_client")


[es(tag=gameClient, on_disappear, REQUIRE=(changed, sleeping_monster))]
def changed_sleeping_monster_disappear_client(evt : Event;
                                              eid : EntityId)
  addSubTemplate(eid, "changed_human_awaken_client")


[es(tag=gameClient, on_event=EventEntityRecreated, REQUIRE=changed, REQUIRE_NOT=sleeping_monster)]
def changed_recreated_client(evt : Event;
                             eid : EntityId)
  addSubTemplate(eid, "changed_human_awaken_client")


[es(tag=server, before=beh_tree_update_es, REQUIRE_NOT=nphys__disabled)]
def changed_allow_attack_from_sides(update : UpdateStageInfoAct;
                                    changed__checkForFlankingInterval : float;
                                    hitpoints__hp : float;
                                    hitpoints__maxHp : float;
                                    changed__flankingHpPercentTreshHold : float;
                                    var changed__checkForFlankingAt : float&;
                                    var flanking_ai__attackFromSide : bool&)
  if update.curTime < changed__checkForFlankingAt
    return
  changed__checkForFlankingAt = update.curTime + changed__checkForFlankingInterval

  let currentHpPercent = hitpoints__hp / hitpoints__maxHp * 100.0
  flanking_ai__attackFromSide = currentHpPercent < changed__flankingHpPercentTreshHold


[es(tag=server, before=loud_noise_update_es)]
def changed_react_to_flashlight(info : UpdateStageInfoAct;
                                light__max_radius : float;
                                attached_flashlight__loudNoiseMinCos : float;
                                attached_flashlight__actorEid : EntityId;
                                attached_flashlight__lightRayMaterialId : int;
                                attached_flashlight__isOn : bool;
                                attached_flashlight__loudNoiseUpdateInterval : float;
                                var attached_flashlight__loudNoiseUpdateAt : float&)
  if info.curTime < attached_flashlight__loudNoiseUpdateAt
    return
  attached_flashlight__loudNoiseUpdateAt = info.curTime + attached_flashlight__loudNoiseUpdateInterval
  if !attached_flashlight__isOn
    return
  var flashlights : array< tuple <from : float3; dir : float3; owner : EntityId> >
  query(attached_flashlight__actorEid) <| $ [es] (attaches_list : EidList;
                                                  animchar : AnimcharBaseComponent;
                                                  human_net_phys : HumanActor)
    for attachEid in attaches_list
      query(attachEid) <| $ [es] (flashlight_device__type : int;
                                  attached_flashlight_controller__nodeId : int)
        if flashlight_device__type != int(FlashlightType.DEFAULT)
          return
        var tm : float3x4
        *animchar.nodeTree |> geomtree_getNodeWtmScalar(attached_flashlight_controller__nodeId, tm)
        let lightDirection = normalize(human_net_phys.phys.appliedCT.wishLookDir)
        let from = tm[3]
        flashlights |> push(tuple(from, lightDirection, attached_flashlight__actorEid))

  query(attached_flashlight__actorEid) <| $ [es(REQUIRE=gun__melee)] (animchar : AnimcharBaseComponent;
                                                                      gun__owner : EntityId;
                                                                      weapon_flashlight_controller__nodeName : string)
    let nodeId = *animchar.nodeTree |> geomtree_findNodeIndex(weapon_flashlight_controller__nodeName)
    var flashlightTm : float3x4
    *animchar.nodeTree |> geomtree_getNodeWtmScalar(nodeId, flashlightTm)
    flashlights |> push(tuple(flashlightTm[3], flashlightTm[2], gun__owner))

  for flashlight in flashlights
    for_each_entity_in_grid(ecs_hash("humans"), BSphere3(flashlight.from, light__max_radius), GridEntCheck.POS) <| $(intersection : EntityId)
      if intersection == flashlight.owner
        return
      query(intersection) <| $ [es(REQUIRE_NOT=deadEntity)] (changed_loud_noise__awakeThreshold : float;
                                                             transform : float3x4;
                                                             changed_loud_noise__flashlightAgitationPercentPerSecond : float;
                                                             changed_loud_noise__flashlightAgitationPercent : float;
                                                             loud_noise__appendOnNoise : string = "";
                                                             var loud_noise__noiseVelocity : float&;
                                                             var loud_noise__accumulatedNoise : float&)
        var traceToPos = transform[3]
        let currentDir = normalize(traceToPos - flashlight.from)
        if dot(currentDir, flashlight.dir) < attached_flashlight__loudNoiseMinCos
          return
        traceToPos -= currentDir * 0.25
        let currentDist = distance(traceToPos, flashlight.from)
        let visible = !rayhit_normalized(flashlight.from, currentDir, currentDist, ETF_DEFAULT, attached_flashlight__lightRayMaterialId)
        if !visible
          return
        let maxAgitation = changed_loud_noise__awakeThreshold * changed_loud_noise__flashlightAgitationPercent / 100.
        if loud_noise__accumulatedNoise > maxAgitation
          return
        let addedAgitation = changed_loud_noise__awakeThreshold * changed_loud_noise__flashlightAgitationPercentPerSecond * attached_flashlight__loudNoiseUpdateInterval / 100.
        let delta = max(.0, min(addedAgitation, maxAgitation - loud_noise__accumulatedNoise))

        loud_noise__accumulatedNoise += delta
        loud_noise__noiseVelocity = max(loud_noise__noiseVelocity, .0)
        if !empty(loud_noise__appendOnNoise) && delta > .0
          send_net_event(intersection, EventAddNoiseSubtemplate())


[es(tag=server, on_appear, after=navmeshmapping_init)]
def changed_set_origin(evt : Event; eid : EntityId; position_mapping__isOnSphere : bool; var changed__origin : float3&; var transform : float3x4)
  let coordianteBefore = transform[3]
  var navPos = transform[3]
  var success = false
  if !position_mapping__isOnSphere
    success = project_to_nearest_navmesh_point(navPos, float3(2.0, 10.0, 2.0))
  else
    let mappingZone = navmesh_mapping_find_best_zone_for_position(coordianteBefore)
    navPos = navmesh_map_position_in_zone(coordianteBefore, mappingZone)
    success = project_to_nearest_navmesh_point(navPos, float3(2.0, 10.0, 2.0))
    navPos = navmesh_unmap_position_in_zone(navPos, mappingZone)
    validate_gameplay_position(navPos) <| $()
      return <- "coordianteBefore={coordianteBefore}, mappingZone={mappingZone}"
  transform[3] = navPos

  if !success
    logerr("Creature too far from navmesh. <{eid}>({getEntityTemplateName(eid)}). spawnedAt:[{coordianteBefore}]. No navmesh in sight.")
  elif distance_sq(coordianteBefore, transform[3]) > 5.0
    logerr("Creature too far from navmesh. <{eid}>({getEntityTemplateName(eid)}). spawnedAt:[{coordianteBefore}] dst:{distance(coordianteBefore, transform[3])}")
  changed__origin = transform[3]


[es(tag=server)]
def changed_set_out_of_origin_timeout_on_awaken(evt : CmdAwakeSleepingMonster; changed__agroOnAwakened : float; var changed__loseInterestAt : float&)
  changed__loseInterestAt = get_sync_time() + changed__agroOnAwakened


[es(tag=server, no_order, REQUIRE_NOT=(deadEntity, sleeping_monster))]
def changed_update_origin_timeout_on_damage(cmd : CmdApplyDamage;
                                            transform : float3x4;
                                            changed__origin : float3;
                                            changed__originRadius : float;
                                            changed__agroOnDamaged : float2;
                                            var changed__loseInterestAt : float&)
  let agro = cvt(distance(transform[3], changed__origin), .0, changed__originRadius, changed__agroOnDamaged.x, changed__agroOnDamaged.y)
  changed__loseInterestAt = max(changed__loseInterestAt, get_sync_time() + agro)


[es(tag=server, no_order, REQUIRE_NOT=(deadEntity), REQUIRE=human)]
def changed_update_origin_timeout_on_attack(cmd : CmdApplyDamage)
  query(cmd.offender) <| $ [es] (transform : float3x4;
                                 changed__origin : float3;
                                 changed__originRadius : float;
                                 changed__agroAddOnAttackPassed : float2;
                                 var changed__loseInterestAt : float&)
    let agro = cvt(distance(transform[3], changed__origin), .0, changed__originRadius, changed__agroAddOnAttackPassed.x, changed__agroAddOnAttackPassed.y)
    if agro > 0.0
      changed__loseInterestAt = max(changed__loseInterestAt, get_sync_time()) + agro


[es(tag=server, REQUIRE=sleeping_monster)]
def sleeping_monster_melee_silent_kill(evt : CmdApplyDamage;
                                       eid : EntityId;
                                       collres : CollisionResource;
                                       dm_parts__parts : Object)
  if evt.damageType == int(DamageType.DM_MELEE) || evt.damageType == int(DamageType.DM_BACKSTAB)
    if evt.collNodeId < 0
      return
    let collisionNode = collres_get_node(collres, evt.collNodeId)
    if collisionNode == null
      return
    let name = collisionNode |> collnode_get_name()
    let part = dm_parts__parts[name]
    if part != null
      let partObj = part ?as Object
      if partObj?["type"] ?? "" == "head"
        let dmgMult = partObj?.dmgMult ?? 1.0

        let extraSilentKillDamage = evt.deltaHp * (dmgMult - 1.0)
        if extraSilentKillDamage > 0.0
          let dmType = DamageType.DM_UNKNOWN // To avoid recursion
          let dmDesc = DamageDesc(dmType, extraSilentKillDamage, evt.hitPos, evt.hitDir, float3(), evt.shellId, evt.gunPropsId)
          damage_entity(eid, evt.offender, dmDesc)


[es(tag=server, after=simple_hitpoints_apply_damage)]
def enable_melee_blink_on_dmg(evt : CmdApplyDamage;
                              hitpoints__hp : float;
                              hitpoints__maxHp : float;
                              changed__blinkHalfHpChance : float;
                              changed__blinkQuarterHpChance : float;
                              var changed__meleeBlinkChance : float&)
  let hpPercentAfter = hitpoints__hp / hitpoints__maxHp
  let hpPercentBefore = (hitpoints__hp + evt.deltaHp) / hitpoints__maxHp
  if hpPercentAfter < 0.25f && hpPercentBefore >= 0.25f
    changed__meleeBlinkChance = changed__blinkQuarterHpChance
  elif hpPercentAfter < 0.5f && hpPercentBefore >= 0.5f
    changed__meleeBlinkChance = changed__blinkHalfHpChance


[es(tag=server, no_order, REQUIRE_NOT=(deadEntity, nphys__disabled))]
def human_steps_on_changed_es(act : ParallelUpdateFrameDelayed;
                              transform aka hero_transform : float3x4;
                              awake_changed__radius : float;
                              awake_changed__interval : float;
                              var awake_changed__updateAt : float&)
  if awake_changed__updateAt < act.curTime
    awake_changed__updateAt = act.curTime + awake_changed__interval

    let sphere = BSphere3(hero_transform[3], awake_changed__radius)
    for_each_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.POS) <| $(changed_eid : EntityId)
      query(changed_eid) <| $ [es(REQUIRE=sleeping_monster)] ()
        sendEventImmediate(changed_eid, CmdAwakeSleepingMonster(propadateCount = 0))


[es(tag=server)]
def changed_set_interest_time_on_target_acquired(evt : EventFlankingTargetAcquired;
                                                 changed__agroPerMeter : float;
                                                 var changed__loseInterestAt : float&)
  changed__loseInterestAt = max(get_sync_time(), changed__loseInterestAt) + evt.distance * changed__agroPerMeter