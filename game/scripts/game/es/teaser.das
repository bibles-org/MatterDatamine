require ecs
require app
require game.es.net_console_macro
require game.es.server_debug_common
require game.es.grav_zones_common
require game.events.events_active_matter
require game.events.events_game
require DagorSystem
require HumanPhys
require DngActor
require DngHuman
require DngWalkerai
require DngDm
require DagorMath
require math.base
require math.random
require dm
require game.es.repair_common
require game.es.ai.agent_position_mapping_common
require PhysVars
require AnimV20
require walkerai


enum TeaserBotPose
  STAND
  CROUCH
  CRAWL


[es(tag=server, on_appear)]
def teaser_bot_appear(evt : Event;
                      eid : EntityId;
                      transform : float3x4;
                      teaser_bot__originPose : int;
                      var walker_agent : EntityAgent;
                      var teaser_bot__originTransform : float3x4;
                      var teaser_bot__originTemplate : das_string;
                      var human_net_phys : HumanActor)

  walker_agent.phys.producedCT |> human_control_state_set_wish_look_dir(transform[0])
  walker_agent.phys.producedCT |> human_control_state_set_wish_shoot_dir(transform[0])

  teaser_bot__originTransform = transform
  teaser_bot__originTemplate := getEntityTemplateName(eid)

  assume ct = human_net_phys.phys.producedCT
  ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CROUCH, teaser_bot__originPose == int(TeaserBotPose.CROUCH))
  ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CRAWL, teaser_bot__originPose == int(TeaserBotPose.CRAWL))


[es(tag=server, on_disappear, REQUIRE=teaser_bot)]
def teaser_bot_disappear(evt : Event;
                         attaches_list : EidList)
  for attachEid in attaches_list
    destroyEntity(attachEid)


[es(tag=server, on_appear, track=beh_tree__enabled, after=teaser_bot_appear)]
def teaser_bot_track_beh_tree_enabled(evt : Event;
                                      eid : EntityId;
                                      beh_tree__enabled : bool;
                                      teaser_bot__originTransform : float3x4)
  if beh_tree__enabled
    teleport_phys_actor(eid, teaser_bot__originTransform)
  else
    find_query() <| $ [es] (teaser_director__hiddenBotTm : float3x4)
      teleport_phys_actor(eid, teaser_director__hiddenBotTm)
      return true


[es(tag=server, on_appear)]
def create_teaser_bot_player_appear(evt : Event;
                                    eid : EntityId;
                                    create_teaser_bot_player__playerTemplate : string;
                                    create_teaser_bot_player__playerRibbonColors : int2;
                                    team : int;
                                    var possessedByPlr : EntityId&)
  let plrEid = createEntity(create_teaser_bot_player__playerTemplate) <| $ [es] (var init : ComponentsInitializer)
    init |> set("ribbonColors", create_teaser_bot_player__playerRibbonColors)
    init |> set("possessed", eid)
    init |> set("team", team)
  possessedByPlr = plrEid


[es(tag=server, REQUIRE=teaser_episode)]
def teaser_go_to_episode(evt : CmdTeaserGoToEpisodeRequest;
                         teaser_episode__levelTime : float = -1.0;
                         transform aka episode_transform : float3x4)
  if teaser_episode__levelTime >= 0.0
    broadcast_net_event(CmdChangeSkiesTime(time = teaser_episode__levelTime))

  query() <| $ [es(REQUIRE=player, REQUIRE_NOT=playerIsBot)] (possessed : EntityId)
    teleport_phys_actor(possessed, episode_transform)


[es(tag=server, REQUIRE=teaser_episode)]
def teaser_reset_episode(evt : CmdTeaserResetEpisodeRequest;
                         teaser_episode__index : int)
  // Reset create entity points
  query() <| $ [es] (teaser_episode_create_entity_point__episodeIndex : int;
                     var teaser_episode_create_entity_point__triggered : bool&)
    if teaser_episode_create_entity_point__episodeIndex == teaser_episode__index
      teaser_episode_create_entity_point__triggered = false

  // Reset episode entities
  query() <| $ [es] (eid aka teaser_episode_entity_eid : EntityId;
                     teaser_episode_entity__episodeIndex : int;
                     teaser_episode_entity__initTransform : float3x4;
                     teaser_episode_entity__initTemplate : string)
    if teaser_episode_entity__episodeIndex == teaser_episode__index
      destroyEntity(teaser_episode_entity_eid)
      createEntity(teaser_episode_entity__initTemplate) <| $(var init : ComponentsInitializer)
        init |> set("transform", teaser_episode_entity__initTransform)
        init |> set("teaser_episode_entity__episodeIndex", teaser_episode_entity__episodeIndex)

  // Reset created entities
  query() <| $ [es] (eid aka teaser_episode_created_entity_eid : EntityId;
                     teaser_episode_created_entity__episodeIndex : int)
    if teaser_episode_created_entity__episodeIndex == teaser_episode__index
      destroyEntity(teaser_episode_created_entity_eid)

  // Reset triggers
  query() <| $ [es] (teaser_episode_trigger_zone__episodeIndex : int;
                     var teaser_episode_trigger_zone__triggered : bool&)
    if teaser_episode_trigger_zone__episodeIndex == teaser_episode__index
      teaser_episode_trigger_zone__triggered = false


  // Reset car
  query() <| $ [es] (eid aka car_eid : EntityId;
                     teaser_car__episodeIndex : int;
                     repairable__recoveryRatio : float;
                     teaser_car__initTransform : float3x4;
                     var damage_model : DamageModel;
                     var meta_parts_state : MetaPartsState&;
                     var fire_protection : FireProtection&;
                     var vehicle__fuel : float&;
                     var vehicle__maxFuel : float&)
    if teaser_car__episodeIndex == teaser_episode__index
      repair_vehicle(repairable__recoveryRatio, meta_parts_state, damage_model, fire_protection)
      vehicle__fuel = 70.0
      vehicle__maxFuel = 70.0
      teleport_phys_actor(car_eid, teaser_car__initTransform)


[es(tag=server, no_order)]
def teaser_episode_create_entity_point_update(act : UpdateStageInfoAct;
                                              transform aka teaser_episode_create_entity_point_transform : float3x4;
                                              teaser_episode_create_entity_point__template : string;
                                              teaser_episode_create_entity_point__episodeIndex : int;
                                              teaser_episode_create_entity_point__triggered : bool;
                                              var teaser_episode_create_entity_point__spawnTimer : float&)
  if !teaser_episode_create_entity_point__triggered
    return

  if teaser_episode_create_entity_point__spawnTimer >= 0.0
    teaser_episode_create_entity_point__spawnTimer -= act.dt

    if teaser_episode_create_entity_point__spawnTimer < 0.0
      createEntity("{teaser_episode_create_entity_point__template}+teaser_episode_created_entity") <| $(var init : ComponentsInitializer)
        init |> set("transform", teaser_episode_create_entity_point_transform)
        init |> set("teaser_episode_created_entity__episodeIndex", teaser_episode_create_entity_point__episodeIndex)


[es(tag=server, REQUIRE=teaser_episode)]
def teaser_episode_trigger(evt : CmdTeaserEpisodeTriggerRequest;
                           teaser_episode__index : int)
  // Trigger create entities
  query() <| $ [es] (teaser_episode_create_entity_point__episodeIndex : int;
                     teaser_episode_create_entity_point__triggerIndex : int;
                     teaser_episode_create_entity_point__delay : float2;
                     var teaser_episode_create_entity_point__spawnTimer : float&;
                     var teaser_episode_create_entity_point__triggered : bool&)
    if (teaser_episode_create_entity_point__episodeIndex == teaser_episode__index &&
        teaser_episode_create_entity_point__triggerIndex == evt.triggerIndex)
      teaser_episode_create_entity_point__spawnTimer = rnd_float(teaser_episode_create_entity_point__delay)
      teaser_episode_create_entity_point__triggered = true

  // Trigger episode bots
  query() <| $ [es] (teaser_episode_entity__episodeIndex : int;
                     teaser_episode_bot__triggerIndex : int;
                     var beh_tree__enabled : bool&)
    if (teaser_episode_entity__episodeIndex == teaser_episode__index &&
        teaser_episode_bot__triggerIndex == evt.triggerIndex)
      beh_tree__enabled = !beh_tree__enabled

  // Trigger awake
  query() <| $ [es] (eid aka awake_entity_eid : EntityId;
                     teaser_episode_entity__episodeIndex : int;
                     teaser_awake_on_trigger__triggerIndex : int)
    if (teaser_episode_entity__episodeIndex == teaser_episode__index &&
        teaser_awake_on_trigger__triggerIndex == evt.triggerIndex)
      sendEventImmediate(awake_entity_eid, CmdAwakeSleepingMonster(propadateCount = 0))

  // Final lookers
  query() <| $ [es(REQUIRE=final_euclid_changed_human_looker)] (eid aka looker_eid : EntityId;
                                                                final_euclid_changed_human_looker__episodeIndex : int;
                                                                final_euclid_changed_human_looker__trigger : int;
                                                                final_euclid_changed_human_looker__awakeDelay : float2)
    if (final_euclid_changed_human_looker__episodeIndex == teaser_episode__index &&
       final_euclid_changed_human_looker__trigger == evt.triggerIndex)
      addSubTemplate(looker_eid, "final_euclid_changed_human_looker_awake") <| $(var init : ComponentsInitializer)
        init |> set("final_euclid_changed_human_looker_awake__at", get_sync_time() + rnd_float(final_euclid_changed_human_looker__awakeDelay))


[es(tag=server, no_order)]
def final_euclid_changed_human_looker_awake(act : UpdateStageInfoAct;
                                            eid aka looker_eid : EntityId;
                                            final_euclid_changed_human_looker_awake__at : float;
                                            var navmesh_phys__walkSpeedMult : float&)
  if act.curTime >= final_euclid_changed_human_looker_awake__at
    removeSubTemplate(looker_eid, "final_euclid_changed_human_looker_awake")
    navmesh_phys__walkSpeedMult = 1.0


[es(tag=server, on_appear)]
def teaser_episode_entity_init(evt : Event;
                               transform : float3x4;
                               eid aka teaser_episode_entity_eid : EntityId;
                               var teaser_episode_entity__initTransform : float3x4;
                               var teaser_episode_entity__initTemplate : das_string)
  teaser_episode_entity__initTransform = transform
  teaser_episode_entity__initTemplate := getEntityTemplateName(teaser_episode_entity_eid)


[es(tag=server, REQUIRE=teaser_episode_trigger_zone)]
def teaser_episode_trigger_zone_enter(evt : EventZoneEnter;
                                      teaser_episode_trigger_zone__episodeIndex aka this_teaser_episode_trigger_zone__episodeIndex : int;
                                      teaser_episode_trigger_zone__triggerIndex aka this_teaser_episode_trigger_zone__triggerIndex : int;
                                      teaser_episode_trigger_zone__triggerAllZones : bool = false;
                                      var teaser_episode_trigger_zone__triggered : bool&)
  if teaser_episode_trigger_zone__triggered
    return

  find_query() <| $ [es] (eid aka teaser_episode_eid : EntityId;
                          teaser_episode__index : int)
    if teaser_episode_trigger_zone__episodeIndex != teaser_episode__index
      return false
    teaser_episode_trigger_zone__triggered = true
    send_net_event(teaser_episode_eid, CmdTeaserEpisodeTriggerRequest(triggerIndex = teaser_episode_trigger_zone__triggerIndex))

    if teaser_episode_trigger_zone__triggerAllZones
      query() <| $ [es] (teaser_episode_trigger_zone__episodeIndex aka other_teaser_episode_trigger_zone__episodeIndex : int;
                         teaser_episode_trigger_zone__triggerIndex aka other_teaser_episode_trigger_zone__triggerIndex : int;
                         var teaser_episode_trigger_zone__triggered aka other_teaser_episode_trigger_zone__triggered : bool&)
        if (other_teaser_episode_trigger_zone__episodeIndex == this_teaser_episode_trigger_zone__episodeIndex &&
           other_teaser_episode_trigger_zone__triggerIndex == this_teaser_episode_trigger_zone__triggerIndex)
          other_teaser_episode_trigger_zone__triggered = true


    return true


[es(on_appear, after=human_anim_phys_vars_init)]
def teaser_loading_ammo_actor_init(evt : Event;
                                   human_anim__loadingAmmoProgressVarId : int;
                                   human_anim__loadingAmmoTypeVarId : int;
                                   teaser_loading_ammo_actor__loadingAmmoType : string;
                                   var phys_vars : PhysVars)
  setVar(phys_vars, human_anim__loadingAmmoProgressVarId, 1.0)
  let loadingAmmoType = animV20_get_enum_value_by_name(teaser_loading_ammo_actor__loadingAmmoType)
  setVar(phys_vars, human_anim__loadingAmmoTypeVarId, float(loadingAmmoType))


[es(no_order)]
def teaser_loading_ammo_actor_update(act : ParallelUpdateFrameDelayed;
                                     human_anim__loadingAmmoProgressVarId : int;
                                     loading_ammo_controller__loadingAnimationStateLoopStart : float;
                                     teaser_loading_ammo_actor__speed : float;
                                     var teaser_loading_ammo_actor__progress : float&;
                                     var phys_vars : PhysVars)
  teaser_loading_ammo_actor__progress += act.dt * teaser_loading_ammo_actor__speed
  while teaser_loading_ammo_actor__progress >= 1.0
    teaser_loading_ammo_actor__progress -= 1.0

  setVar(phys_vars,
         human_anim__loadingAmmoProgressVarId,
         loading_ammo_controller__loadingAnimationStateLoopStart + teaser_loading_ammo_actor__progress)


[es(tag=server, on_appear, REQUIRE=teaser_episode_bot)]
def teaser_episode_bot_wander_init(evt : Event;
                                   transform aka bot_transform : float3x4;
                                   var human_net_phys : HumanActor;
                                   var beh_tree__blackboard__wanderTarget : float3&)

  var minSqDist = VERY_BIG_NUMBER
  beh_tree__blackboard__wanderTarget = float3(0.0)

  assume ct = human_net_phys.phys.producedCT
  ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CROUCH, false)
  ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CRAWL, false)

  query() <| $ [es(REQUIRE=teaser_wander_target)] (transform aka target_transform : float3x4)
    let sqDist = distance_sq(bot_transform[3], target_transform[3])
    if sqDist < minSqDist
      minSqDist = sqDist
      beh_tree__blackboard__wanderTarget = target_transform[3]


[es(tag=gameClient, on_appear, before=anim_phys_init_es)]
def teaser_tape_recorder_animation_appear(evt : Event;
                                          var phys_vars : PhysVars;
                                          var teaser_tape_recorder_animation__rotorVarId : int&)
  teaser_tape_recorder_animation__rotorVarId = registerVar(phys_vars, "spool_rotation", 0.0)


[es(tag=gameClient, no_order)]
def teaser_tape_recorder_animation_update(info : ParallelUpdateFrameDelayed;
                                          teaser_tape_recorder_animation__rotorVarId : int;
                                          teaser_tape_recorder_animation__rotorSpeed : float;
                                          var phys_vars : PhysVars)
  setVar(phys_vars, teaser_tape_recorder_animation__rotorVarId, info.curTime * -teaser_tape_recorder_animation__rotorSpeed)


[es(tag=server, on_appear)]
def teaser_car_init(evt : Event;
                    transform : float3x4;
                    var teaser_car__initTransform : float3x4)
  teaser_car__initTransform = transform


[es(tag=server, on_appear, REQUIRE=teaser_spider, after=npys_forced_anim_init)]
def teaser_spider_init(evt : Event;
                       animchar : AnimcharBaseComponent;
                       var anim_state__forceAnimStateId : int&)
  let animGraph = animchar.animGraph
  if animGraph != null
    anim_state__forceAnimStateId = *animGraph |> anim_graph_getStateIdx("idle")


[es(tag=server)]
def trigger_teaser_spiders(evt : CmdTeaserEpisodeTriggerRequest;
                           teaser_episode__index : int)
  query() <| $ [es] (animchar : AnimcharBaseComponent;
                     teaser_spider__episodeIndex : int;
                     var anim_state__forceAnimStateId : int&)
    if teaser_episode__index == teaser_spider__episodeIndex
      let animGraph = animchar.animGraph
      if animGraph != null
        if evt.triggerIndex == 1
          anim_state__forceAnimStateId = *animGraph |> anim_graph_getStateIdx("death")
        else
          anim_state__forceAnimStateId = *animGraph |> anim_graph_getStateIdx("idle")


[es(tag=server, REQUIRE=teaser_spider)]
def teaser_spider_death(evt : EventEntityDied;
                        animchar : AnimcharBaseComponent;
                        var anim_state__forceAnimStateId : int&)
  let animGraph = animchar.animGraph
  if animGraph != null
    anim_state__forceAnimStateId = *animGraph |> anim_graph_getStateIdx("death")


[es(tag=server)]
def reset_teaser_spiders(evt : CmdTeaserResetEpisodeRequest;
                         teaser_episode__index : int)
  query() <| $ [es] (teaser_spider__episodeIndex : int;
                     var transform : float3x4)
    if teaser_episode__index == teaser_spider__episodeIndex

      var tm : float3x4
      var horzOffsVec : float3
      sincos(rnd_float(0.0, TWOPI), horzOffsVec.z, horzOffsVec.x)
      tm[0] = rotate(transform, horzOffsVec)
      tm[1] = transform[1]
      tm[2] = cross(tm[0], tm[1])
      tm[3] = transform[3]

      transform = tm


// Workaround scale fix
[es(tag=gameClient, before=update_nphys_scale, REQUIRE=teaser_spider)]
def teaser_spider_render(act : UpdateStageInfoAct;
                         nPhys__animcharScale : float;
                         var transform : float3x4&)
  transform[0] = normalize(transform[0]) * nPhys__animcharScale
  transform[1] = normalize(transform[1]) * nPhys__animcharScale
  transform[2] = normalize(transform[2]) * nPhys__animcharScale


[es(tag=gameClient, after=update_nphys_scale)]
def teaser_invisible_mirror(act : UpdateStageInfoAct;
                            nPhys__animcharScaleMirror : bool;
                            var transform : float3x4&)
  let sign = nPhys__animcharScaleMirror ? -1.0 : 1.0
  transform[2] *= sign


[es(tag=server)]
def trigger_teaser_spider_walker(evt : CmdTeaserEpisodeTriggerRequest;
                                 teaser_episode__index : int)
  query() <| $ [es] (eid aka walker_eid : EntityId;
                     // animchar : AnimcharBaseComponent;
                     teaser_episode_entity__episodeIndex : int;
                     teaser_spider_walker__effectTemplate : string;
                     teaser_spider_walker__triggerIndex : int;
                     var teaser_spider_walker__effectEid : EntityId&)
    if teaser_episode__index == teaser_episode_entity__episodeIndex && evt.triggerIndex == teaser_spider_walker__triggerIndex
      if teaser_spider_walker__effectEid == INVALID_ENTITY_ID
        teaser_spider_walker__effectEid = createEntity(teaser_spider_walker__effectTemplate) <| $(var init : ComponentsInitializer)
          init |> set("game_effect__attachedTo", walker_eid)
      else
        destroyEntity(teaser_spider_walker__effectEid)
        teaser_spider_walker__effectEid = INVALID_ENTITY_ID


[es(tag=server, after=ai_danger_update_alertness, REQUIRE=final_euclid_changed_human)]
def final_euclid_changed_human_ai_update(act : UpdateStageInfoAct;
                                         transform aka changed_transform : float3x4;
                                         var walker_agent__targetEid : EntityId&;
                                         var walker_agent__targetPos : float3&;
                                         var navmesh_phys__wishLookDir : float3&;
                                         var navmesh_phys__currentLookDir : float3&;
                                         var agent_dangers : AgentDangers)
  agent_dangers.dangers |> clear()

  var closestEnemyId = INVALID_ENTITY_ID
  var closestEnemyDistSq = VERY_BIG_NUMBER

  query() <| $ [es(REQUIRE=player, REQUIRE_NOT=playerIsBot)] (possessed : EntityId)
    query(possessed) <| $ [es] (transform aka enemy_transform : float3x4)
      let distSq = distance_sq(changed_transform[3], enemy_transform[3])
      if distSq < closestEnemyDistSq
        closestEnemyId = possessed
        closestEnemyDistSq = distSq

  query(closestEnemyId) <| $ [es] (transform aka enemy_transform : float3x4)
    walker_agent__targetEid = closestEnemyId
    walker_agent__targetPos = enemy_transform[3] + enemy_transform[0] * 0.25 - enemy_transform[2] * 0.1

    let curPos = navmesh_map_position(changed_transform[3])
    let toPos = navmesh_map_position(walker_agent__targetPos)
    let toEnemy = toPos - curPos
    let toEnemyDist = length(toEnemy)
    if is_equal_float(toEnemyDist, 0.0)
      return

    if toEnemyDist <= 2.0
      let dir = toEnemy / toEnemyDist
      navmesh_phys__wishLookDir = dir
      navmesh_phys__currentLookDir = dir

    using() <| $(var newDanger : Danger#)
      newDanger.eid = closestEnemyId
      newDanger.inFrustumTime = -1.0
      newDanger.distance = 1.0
      newDanger.alertness = 1000.0
      newDanger.traceable = true
      push_clone(agent_dangers.dangers, newDanger)


[es(tag=server, on_appear)]
def teaser_invisible_man_looker_init(evt : Event;
                                     transform : float3x4;
                                     var teaser_invisible_man_looker__initTransform : float3x4)
  teaser_invisible_man_looker__initTransform = transform


[es(tag=server, on_appear)]
def final_euclid_changed_human_looker_jump_appear(evt : Event;
                                                  var final_euclid_changed_human_looker_jump_effect__dist : float&)
  find_query() <| $ [es] (final_euclid_teaser_params__jumpAimDist : float)
    final_euclid_changed_human_looker_jump_effect__dist = final_euclid_teaser_params__jumpAimDist
    return true


[es(tag=server, no_order)]
def final_euclid_changed_human_looker_jump_effect_timer(act : UpdateStageInfoAct;
                                                        eid : EntityId;
                                                        transform aka changed_transform : float3x4;
                                                        navmesh_phys__walkSpeedMult : float;
                                                        walker_agent__targetEid : EntityId;
                                                        final_euclid_changed_human_looker_jump_effect__dist : float;
                                                        var final_euclid_changed_human_looker_jump_effect__triggered : bool&)
  if navmesh_phys__walkSpeedMult <= 0.0
    return

  if final_euclid_changed_human_looker_jump_effect__triggered
    return

  query(walker_agent__targetEid) <| $ [es] (transform aka enemy_transform : float3x4)
    if distance(changed_transform[3], enemy_transform[3]) <= final_euclid_changed_human_looker_jump_effect__dist
      final_euclid_changed_human_looker_jump_effect__triggered = true
      createEntity("final_euclid_changed_human_looker_jump_effect") <| $(var init : ComponentsInitializer)
        init |> set("game_effect__attachedTo", eid)