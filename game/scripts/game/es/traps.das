require ecs
require ecs.common
require app
require DagorMath
require DngDm
require AnimV20
require Grid
require math.base
require math.random
require game.events.events_game
require game.events.events_active_matter
require net
require game.utils.team
require game.events.events
require game.es.system_common
require vehicle
require game.es.grav_zones_common
require game.events.vehicle_events
require game.es.trigger_phys_push_common
require game.es.loud_noise_common
require game.es.traps_common
require game.es.human.human_force_anim_common
require active_matter.game.es.moving_zone_common
require game.es.dm_common
require DngActor
require DngHuman
require Dacoll
require NetPropsRegistry
require BehNodes
require DngPhysObj
require DagorSystem
require GeomNodeTree
require daslib/array_boost
require pathfinder


[es(tag=server, on_appear, REQUIRE_NOT=nphys__disabled)]
def trigger_trap_activator_init(evt : Event;
                                eid : EntityId;
                                trigger_trap_activator__interval : float;
                                var trigger_trap_activator__updateAt : float&)
  trigger_trap_activator__updateAt = trigger_trap_activator__interval * eid_frnd(eid)


[es(tag=server, no_order, REQUIRE_NOT=(deadEntity, nphys__disabled))]
def trigger_trap_activator_update(act : ParallelUpdateFrameDelayed;
                                  eid : EntityId;
                                  animchar : AnimcharBaseComponent const?;
                                  possessedByPlr : EntityId = INVALID_ENTITY_ID;
                                  am_militant_bot : Tag const?;
                                  transform aka hero_transform : float3x4;
                                  trigger_trap_activator__mask : uint;
                                  trigger_trap_activator__radius = 1.5;
                                  trigger_trap_activator__interval : float;
                                  trigger_trap_activator__traceNodes : IntList const?;
                                  var trigger_trap_activator__updateAt : float&)
  if trigger_trap_activator__updateAt < act.curTime
    trigger_trap_activator__updateAt = act.curTime + trigger_trap_activator__interval

    let sphere = BSphere3(hero_transform[3], trigger_trap_activator__radius)
    let isBot = am_militant_bot != null
    for_each_entity_in_grid(ecs_hash("traceable_spheres"), sphere, GridEntCheck.POS) <| $(trap_eid : EntityId)
      query(trap_eid) <| $ [es] (var trigger_trap__triggered : bool&;
                                 transform aka trap_transform : float3x4;
                                 team aka trap_team : int = -1;
                                 trigger_trap__triggerPoint = float3(.0, 0.25, .0);
                                 trigger_trap__radius : float = FLT_MAX;
                                 trigger_trap__allowBots : bool = true;
                                 trigger_trap__ignoreTraceRay : bool = false;
                                 trigger_trap__mask : uint;
                                 trigger_trap__ignoreMask : uint = 0u)
        var isFriendlyTrap = false
        query(possessedByPlr) <| $[es] (team aka player_team : int)
          if player_team == trap_team
            isFriendlyTrap = true
        if isFriendlyTrap
          return
        if !trigger_trap__allowBots && isBot
          return
        if (!trigger_trap__triggered
            && (trigger_trap__mask & trigger_trap_activator__mask) != 0u
            && (trigger_trap__ignoreMask & trigger_trap_activator__mask) == 0u)
          if (trigger_trap__radius > trigger_trap_activator__radius ||
          distance_sq(trap_transform[3], hero_transform[3]) < square(trigger_trap__radius))
            var pointsToCheck : array<float3>
            if trigger_trap_activator__traceNodes != null && animchar != null
              for ni in *trigger_trap_activator__traceNodes
                var nodeWtm : float3x4
                *animchar.nodeTree |> geomtree_getNodeWtmScalar(ni, nodeWtm)
                pointsToCheck |> push(nodeWtm[3])
            else
              pointsToCheck |> push(hero_transform[3])
            let trapPoints = fixed_array(trap_transform * trigger_trap__triggerPoint, trap_transform[3])
            for p1 in pointsToCheck
              for p2 in trapPoints
                let vec = p1 - p2
                let t = length(vec)
                let dir = vec * safeinv(t)
                if trigger_trap__ignoreTraceRay || !rayhit_normalized(p2, dir, t, ETF_DEFAULT, -1)
                  trigger_trap__triggered = true
                  sendEvent(trap_eid, EventTrapTrigger(activatorEid = eid))
                  return


[es(tag=server)]
def trap_trigger_notify_activator(evt : EventTrapTrigger;
                                  eid : EntityId)
  send_net_event(evt.activatorEid, EventTrapTriggerNotify(trapEid = eid))


[es(tag=server)]
def trap_trigger_apply_affects_on_trigger(evt : EventTrapTrigger;
                                          eid : EntityId;
                                          transform aka trap_transform : float3x4;
                                          trigger_trap__addSubTemplateOnTrigger : string = "server_destroy_now";
                                          trigger_trap__affectRadius : float = .0;
                                          trigger_trap__humanAffectTemplates : StringList const?;
                                          trigger_trap__affectTemplates : StringList const?)
  if trigger_trap__humanAffectTemplates != null
    for_each_entity_in_grid(ecs_hash("humans"),
                            BSphere3(trap_transform[3], trigger_trap__affectRadius), GridEntCheck.BOUNDING) <| $(humanEid : EntityId)
      for affectTemplate in *trigger_trap__humanAffectTemplates
        createEntity(string(affectTemplate)) <| $(var init : ComponentsInitializer)
          init |> set("game_effect__attachedTo", humanEid)
  if trigger_trap__affectTemplates != null
    for t in *trigger_trap__affectTemplates
      createEntity(string(t)) <| $(var init : ComponentsInitializer)
        init |> set("transform", trap_transform)
        init |> set("trigger_activator", evt.activatorEid)

  if !empty(trigger_trap__addSubTemplateOnTrigger)
    addSubTemplate(eid, trigger_trap__addSubTemplateOnTrigger)

  //We might need to disable other traps if several were triggered on the same frame
  broadcastEventImmediate(EventTrapIsTriggered(trapEid = eid))



[es(tag=server, REQUIRE=(anomaly_trap, trap_triggerable_by_projectile))]
def anomaly_trap_projectile_hit(evt : ProjectileHitInvulnerableNotification;
                                eid : EntityId;
                                var trigger_trap__triggered : bool&)
  if trigger_trap__triggered == false
    sendEvent(eid, EventTrapTrigger(activatorEid = INVALID_ENTITY_ID))
    trigger_trap__triggered = true


[es(tag=gameClient, on_appear)]
def frog_trap_init_anim_on_appear(evt : Event;
                                  game_effect__attachedTo : EntityId;
                                  var frog_trap_effect__startAnimStateId : int&;
                                  var frog_trap_effect__flyUpAnimStateId : int&;
                                  var frog_trap_effect__flyDownAnimStateId : int&;
                                  var frog_trap_effect__landAnimStateId : int&)
  query(game_effect__attachedTo) <| $ [es] (animchar : AnimcharBaseComponent)
    assume animGraph = *animchar.animGraph
    frog_trap_effect__startAnimStateId = animGraph |> anim_graph_getStateIdx("blastoff_transition_to_up")
    frog_trap_effect__flyUpAnimStateId = animGraph |> anim_graph_getStateIdx("blastoff_up")
    frog_trap_effect__flyDownAnimStateId = animGraph |> anim_graph_getStateIdx("blastoff_falling")
    frog_trap_effect__landAnimStateId = animGraph |> anim_graph_getStateIdx("blastoff_wakeup")


[es(after=(human_anim_es, force_anim_state_es))]
def frog_trap_animation_affect(info : ParallelUpdateFrameDelayed;
                               eid : EntityId;
                               game_effect__attachedTo : EntityId;
                               frog_trap_effect__startAnimStateId : int;
                               frog_trap_effect__flyUpAnimStateId : int;
                               frog_trap_effect__flyDownAnimStateId : int;
                               frog_trap_effect__landAnimStateId : int;
                               frog_trap_effect__startAnimTime : float;
                               frog_trap_effect__landAnimTime : float;
                               var frog_trap_effect__state : int&;
                               var frog_trap_effect__changeStateAtTime : float&)
  assume currentState = human_net_phys.phys.currentState
  query(game_effect__attachedTo) <| $ [es] (human_net_phys : HumanActor)
    if frog_trap_effect__state == -1
      frog_trap_effect__state = 0
      frog_trap_effect__changeStateAtTime = info.curTime + frog_trap_effect__startAnimTime
    // start anim
    if frog_trap_effect__state == 0
      send_change_anim_state_event_safe(game_effect__attachedTo, frog_trap_effect__startAnimStateId)
      if info.curTime >= frog_trap_effect__changeStateAtTime
        frog_trap_effect__state = 1
    // fly up anim
    if frog_trap_effect__state == 1
      send_change_anim_state_event_safe(game_effect__attachedTo, frog_trap_effect__flyUpAnimStateId)
      if dot(currentState.velocity, currentState.vertDirection) <= 0.0
        frog_trap_effect__state = 2
    // fly down anim
    if frog_trap_effect__state == 2
      send_change_anim_state_event_safe(game_effect__attachedTo, frog_trap_effect__flyDownAnimStateId)
      let isInAir = (uint(currentState.isInAirHistory) & 1u) != 0u
      // early exit if human hit the water
      let isSwimming = human_phys_state_get_is_swimming(currentState)
      if isSwimming && is_server()
        destroyEntity(eid)
      // wait for landing
      if !isInAir
        frog_trap_effect__state = 3
        frog_trap_effect__changeStateAtTime = info.curTime + frog_trap_effect__landAnimTime
    // land anim
    if frog_trap_effect__state == 3
      if info.curTime < frog_trap_effect__changeStateAtTime
        send_change_anim_state_event_safe(game_effect__attachedTo, frog_trap_effect__landAnimStateId)
      // Animation is disabled as soon as the timer runs out to avoid static pose\looping anim.
      // But the afffect itself may only be deleted by the server
      elif is_server()
        destroyEntity(eid)


[es(tag=server, REQUIRE=frog_trap)]
def frog_trap_trigger(evt : EventTrapTrigger;
                      transform aka trap_transform : float3x4;
                      trigger_trap__affectRadius : float;
                      frog_trap__pushAffectTemplate : string;
                      frog_trap__pushAffectMinDistancePercent : float;
                      frog_trap__forceCenterYOffset : float = 0.0;
                      frog_trap__pushPitch : float = 60.0;
                      frog_trap__pushSpeed : float = 20.0;
                      frog_trap__pushDistancePower : float = 0.5;
                      frog_trap__pushDistancePowerScaleLimits : float2 = float2(0.75, 1.0);
                      frog_trap__pushEnemyEffectTemplateTtl : float = 2.5;
                      frog_trap__pushImmunityAmount : float = 2.0;
                      frog_trap__pushHitTagPowerMult : float = 0.5;
                      frog_trap__pushAiDistancePowerMult : float = 2.0;
                      frog_trap__vehiclePointOffset : float3 = float3(0.0, -1.65, 0.0);
                      frog_trap__vehicleEnergyScale : float = 7000.0;
                      frog_trap__vehicle_damage__kineticEnergyDmgMult : float = 0.035;
                      frog_trap__vehicle_damage__bodyDamageMult : float = 0.7;
                      frog_trap__vehicle_damage__transmissionDamageMult : float = 0.125;
                      frog_trap__vehicle_damage__engineDamageMult : float = 0.1)
  assume pitch = frog_trap__pushPitch
  assume speed = frog_trap__pushSpeed
  assume distancePower = frog_trap__pushDistancePower
  assume distancePowerScaleLimits = frog_trap__pushDistancePowerScaleLimits
  assume enemyEffectTemplateTtl = frog_trap__pushEnemyEffectTemplateTtl
  assume immunityAmount = frog_trap__pushImmunityAmount
  assume hitTagPowerMult = frog_trap__pushHitTagPowerMult
  assume aiDistancePowerMult = frog_trap__pushAiDistancePowerMult
  assume radius = trigger_trap__affectRadius
  let radiusSq = square(trigger_trap__affectRadius)
  let pushForceCenter = trap_transform[3] + transform[1] * frog_trap__forceCenterYOffset

  var quatRes : quat
  euler_to_quat(0.0, deg_to_rad(pitch), 0.0, quatRes)

  let minSqDistToApplyFlyAffect = square(frog_trap__pushAffectMinDistancePercent * trigger_trap__affectRadius)

  for_each_entity_in_grid(ecs_hash("humans"),
                          BSphere3(trap_transform[3], trigger_trap__affectRadius),
                          GridEntCheck.BOUNDING) <| $(humanEid : EntityId)
    query(humanEid) <| $ [es(REQUIRE=human_net_phys)] (transform aka human_transform : float3x4;
                                                       team : int = int(TEAM_UNASSIGNED);
                                                       beh_tree__enabled : bool = false;
                                                       game_effect__invisible : bool = false;
                                                       isInVehicle : bool = false;
                                                       flying_creature : Tag const?;
                                                       var trap_logger__lastTrapActivationTime : float&)
      if isInVehicle
        return

      trap_logger__lastTrapActivationTime := get_sync_time()
      if flying_creature == null && distance_sq(human_transform[3], pushForceCenter) < minSqDistToApplyFlyAffect
        createEntity(frog_trap__pushAffectTemplate) <| $(var init : ComponentsInitializer)
          init |> set("game_effect__attachedTo", humanEid)
      push_human_around(human_transform, pushForceCenter,
                        humanEid,
                        /*main_actor_eid*/ INVALID_ENTITY_ID,
                        quatRes,
                        trigger_trap__affectRadius, speed, distancePower,
                        distancePowerScaleLimits,
                        null,
                        enemyEffectTemplateTtl,
                        immunityAmount, hitTagPowerMult, aiDistancePowerMult,
                        /*enemy_damage*/ 0.0,
                        team,
                        beh_tree__enabled, game_effect__invisible)


  query() <| $ [es(REQUIRE=npysPushable)] (eid aka nphys_eid : EntityId;
                                           transform aka nphys_transform : float3x4;
                                           team : int = int(TEAM_UNASSIGNED);
                                           beh_tree__enabled : bool = false;
                                           isInVehicle : bool = false;
                                           game_effect__invisible : bool = false)
    if isInVehicle
      return

    push_human_around(nphys_transform, pushForceCenter,
                      nphys_eid, /*main_actor_eid*/ INVALID_ENTITY_ID,
                      quatRes,
                      radius, speed, distancePower,
                      distancePowerScaleLimits,
                      null,
                      enemyEffectTemplateTtl,
                      immunityAmount, hitTagPowerMult, aiDistancePowerMult,
                      /*enemy_damage*/ 0.0,
                      team,
                      beh_tree__enabled, game_effect__invisible)

  query() <| $ [es(REQUIRE=phys_obj_net_phys)] (eid aka phys_obj_eid : EntityId;
                                                transform aka phys_obj_transform : float3x4)
    let dir = phys_obj_transform[3] - pushForceCenter
    if length_sq(dir) < radiusSq
      push_entity(phys_obj_eid, false, dir, quatRes, radius, speed,
                  distancePower, distancePowerScaleLimits,
                  null, enemyEffectTemplateTtl,
                  immunityAmount, 0.0, aiDistancePowerMult)

  query() <| $ [es] (eid aka vehicle_eid : EntityId;
                     transform aka vehicle_transform : float3x4;
                     vehicle_net_phys : VehiclePhysActor)
    let dir = vehicle_transform[3] - pushForceCenter

    if length_sq(dir) < radiusSq && empty(vehicle_net_phys.phys.explosionDamageImpulses)
      var originateTm = trap_transform
      originateTm[3] = trap_transform * frog_trap__vehiclePointOffset
      let pushDir = normalize(vehicle_transform[3] - originateTm[3])
      let energyScale = cvt(length(dir), 0.0, radius, frog_trap__vehicleEnergyScale, 0.0)
      let energyScaledDir = pushDir * energyScale
      let arm = vehicle_transform[3] - normalize(dir)
      sendEvent(vehicle_eid, CmdVehiclePushPhys(energyScaledDir = energyScaledDir, arm = arm, duration = 0.0))

      let damageToVehicle = max(0.0, energyScale * frog_trap__vehicle_damage__kineticEnergyDmgMult)

      deal_damage_to_transmission(vehicle_eid, vehicle_eid, damageToVehicle * frog_trap__vehicle_damage__transmissionDamageMult)
      deal_damage_to_body(vehicle_eid, vehicle_eid, damageToVehicle * frog_trap__vehicle_damage__bodyDamageMult)
      deal_damage_to_engine(vehicle_eid, vehicle_eid, damageToVehicle * frog_trap__vehicle_damage__engineDamageMult)


[es(tag=server)]
def trap_trigger_noise_on_trigger(evt : EventTrapTrigger;
                                  transform aka trap_transform : float3x4;
                                  loud_noise__radius : float;
                                  loud_noise__noiseValue : float)
  create_loud_noise_at(trap_transform[3], loud_noise__radius, loud_noise__noiseValue, "trap")


def mark_entities_around(trigger_eid : EntityId;
                         pos : float3;
                         radius : float;
                         grid_name : string;
                         required_tag : string;
                         mark_template : string)

  if mark_template == ""
    return

  let gridHash = ecs_hash(grid_name)
  let sphere = BSphere3(pos, radius)
  let requiredTagHash = ecs_hash(required_tag)

  for_each_entity_in_grid(gridHash, sphere, GridEntCheck.POS) <| $(entity_eid : EntityId)
    if entity_eid == trigger_eid
      return

    if required_tag != "" && has(entity_eid, required_tag, requiredTagHash)
      addSubTemplate(entity_eid, mark_template)


[es(tag=server)]
def trigger_trap_mark_entities_around_on_trigger(evt : EventTrapTrigger;
                                                 eid aka trigger_eid : EntityId;
                                                 transform aka trigger_transform : float3x4;
                                                 trigger_trap_mark_entities_around_on_trigger__radius : float;
                                                 trigger_trap_mark_entities_around_on_trigger__gridName : string;
                                                 trigger_trap_mark_entities_around_on_trigger__requiredTag : string;
                                                 trigger_trap_mark_entities_around_on_trigger__markTemplate : string)
  mark_entities_around(trigger_eid, trigger_transform[3],
                       trigger_trap_mark_entities_around_on_trigger__radius,
                       trigger_trap_mark_entities_around_on_trigger__gridName,
                       trigger_trap_mark_entities_around_on_trigger__requiredTag,
                       trigger_trap_mark_entities_around_on_trigger__markTemplate)


[es(tag=server, on_disappear)]
def mark_entities_around_on_disappear(evt : Event;
                                      eid aka trigger_eid : EntityId;
                                      transform aka trigger_transform : float3x4;
                                      mark_entities_around_on_disappear__radius : float;
                                      mark_entities_around_on_disappear__gridName : string;
                                      mark_entities_around_on_disappear__requiredTag : string;
                                      mark_entities_around_on_disappear__markTemplate : string)
  mark_entities_around(trigger_eid, trigger_transform[3],
                       mark_entities_around_on_disappear__radius,
                       mark_entities_around_on_disappear__gridName,
                       mark_entities_around_on_disappear__requiredTag,
                       mark_entities_around_on_disappear__markTemplate)


[es(tag=server)]
def teleport_trap_trigger(evt : EventTrapTrigger;
                          transform aka trap_transform : float3x4;
                          trigger_trap__affectRadius : float;
                          teleport_trap__affectTemplate : string;
                          teleport_trap__physObjAffectTemplate : string;
                          teleport_trap__centerOffset : float3;
                          team aka trap_team : int = -1)
  let center = trap_transform * teleport_trap__centerOffset
  let grids = fixed_array(ecs_hash("humans"), ecs_hash("projectile_phys"))
  for_each_entity_in_grid(grids,
                          BSphere3(trap_transform[3], trigger_trap__affectRadius), GridEntCheck.BOUNDING) <| $(object_eid : EntityId)
    var isFriendlyTrap = false
    query(object_eid) <| $ [es] (possessedByPlr : EntityId)
      query(possessedByPlr) <| $ [es] (team aka player_team : int)
        if player_team == trap_team
          isFriendlyTrap = true
    if isFriendlyTrap
      return
    var affectTemplate = teleport_trap__affectTemplate
    if has(object_eid, "phys_obj_net_phys")
      affectTemplate = teleport_trap__physObjAffectTemplate

    createEntity(affectTemplate) <| $(var init : ComponentsInitializer)
      init |> set("game_effect__attachedTo", object_eid)
      init |> set("teleport_trap_affect__center", center)
    query(object_eid) <| $ [es] (var trap_logger__lastTrapActivationTime : float&)
      trap_logger__lastTrapActivationTime := get_sync_time()


[es(on_appear)]
def teleport_trap_affect_init(evt : Event;
                              var teleport_trap_affect__appearedAt : float&)
  teleport_trap_affect__appearedAt = get_sync_time()


[es(tag=server, on_appear)]
def teleport_trap_affect_init_server(evt : Event;
                                     game_effect__attachedTo : EntityId;
                                     teleport_trap_affect__limitToZone : bool = false;
                                     teleport_trap_affect__center : float3;
                                     teleport_trap_affect__radiusRng : float2;
                                     teleport_trap_affect__heightRng : float2;
                                     var teleport_trap_affect__teleportTm : float3x4)
  let gravDir = get_grav_dir(teleport_trap_affect__center)
  var gravTm = build_grav_tm(teleport_trap_affect__center, gravDir)
  var q : quat
  euler_to_quat(gfrnd() * TWOPI, 0.0, 0.0, q)
  var rotTm : float3x4
  make_tm(q, rotTm)
  gravTm = gravTm * rotTm

  var haveCollision = true
  var attempts = 5
  while haveCollision && (--attempts > 0)
    let ringPoint = rnd_point_on_ring(teleport_trap_affect__radiusRng.x,
                                      teleport_trap_affect__radiusRng.y)

    let height = rnd_float(teleport_trap_affect__heightRng)
    let ringOffset = gravTm[0] * ringPoint.x + gravTm[1] * height + gravTm[2] * ringPoint.y
    var p = teleport_trap_affect__center + ringOffset
    gravTm[3] = p
    let r = length(ringOffset)
    if project_to_nearest_navmesh_point(p, float3(r, r, r))
      gravTm[3] = p

    dacoll_use_box_collision() <| $(var coll : CollisionObject)
      var testTm = IDENT_TM
      testTm[3] = gravTm[3]
      dacoll_set_collision_object_tm(coll, testTm)
      haveCollision = test_collision_ri(coll, IDENT_BBOX)

    if !haveCollision && teleport_trap_affect__limitToZone
      let zone = get_current_moving_zone()
      if !inside_zone(zone, p)
        haveCollision = true

  if !haveCollision
    teleport_trap_affect__teleportTm = gravTm
  else
    query(game_effect__attachedTo) <| $ [es] (transform aka actor_transform : float3x4)
      teleport_trap_affect__teleportTm = actor_transform
      teleport_trap_affect__teleportTm[3] += teleport_trap_affect__teleportTm[1] * rnd_float(teleport_trap_affect__heightRng)


def process_teleport(eid aka actor_eid : EntityId;
                     target_tm : float3x4;
                     has_human_phys : bool;
                     has_phys_obj_phys : bool;
                     var actor_transform : float3x4)
  send_net_event(actor_eid, EntityWillBeTeleported(fromTm = actor_transform, toTm = target_tm))

  if has_human_phys
    teleport_phys_actor(actor_eid, target_tm)
    actor_transform = target_tm
  elif has_phys_obj_phys

    query(actor_eid) <| $ [es] (var phys_obj_net_phys : PhysObjActor)
      assume state = phys_obj_net_phys.phys.currentState

      let down = get_grav_dir(target_tm[3])

      let fakeBounceSpeed = 2.75 // TODO: rework to remove the magic from the code
      state.velocity = -down * fakeBounceSpeed

    teleport_phys_actor(actor_eid, target_tm)
    actor_transform = target_tm
  else
    query(actor_eid) <| $ [es] (var nphys_pushable__unlockMovementAt : float&;
                                var nphys_pushable__prevElevation : float&;
                                var nphys_pushable__elevation : float&;
                                var loc_snapshots__blink : bool&;
                                var beh_tree : BehaviourTree;
                                nphys_pushable__lockDuration : float)
      loc_snapshots__blink = true
      nphys_pushable__unlockMovementAt = get_sync_time() + nphys_pushable__lockDuration
      nphys_pushable__elevation = distance(actor_transform[3], target_tm[3])
      nphys_pushable__prevElevation = nphys_pushable__elevation
      actor_transform = target_tm
      beh_tree_reset(beh_tree)


[es(before=send_transform_snapshots_es)]
def teleport_trap_affect_update(act : UpdateStageInfoAct;
                                teleport_trap_affect__appearedAt : float;
                                game_effect__attachedTo : EntityId;
                                teleport_trap_affect__shadowRealmTime : float;
                                teleport_trap_affect__teleportTime : float;
                                teleport_trap_affect__pullPower : float;
                                teleport_trap_affect__pullStopDistance : float = 0.5;
                                teleport_trap_affect__center : float3;
                                var teleport_trap_affect__state : int&)
  if teleport_trap_affect__state == int(TeleportTrapAffectState.TELEPORT)
    return

  if act.curTime >= teleport_trap_affect__appearedAt + teleport_trap_affect__teleportTime
    teleport_trap_affect__state = int(TeleportTrapAffectState.TELEPORT)
  elif act.curTime >= teleport_trap_affect__appearedAt + teleport_trap_affect__shadowRealmTime
    teleport_trap_affect__state = int(TeleportTrapAffectState.SHADOW_REALM)

  query(game_effect__attachedTo) <| $ [es] (var human_net_phys : HumanActor)
    assume humanState = human_net_phys.phys.currentState
    if teleport_trap_affect__state == int(TeleportTrapAffectState.PULL)

      let toPortal = teleport_trap_affect__center - float3(humanState.location.P)
      let distanceToPortal = length(toPortal)

      if distanceToPortal >= teleport_trap_affect__pullStopDistance
        let toPortalDir = toPortal / distanceToPortal
        humanState.velocity = toPortalDir * teleport_trap_affect__pullPower * min_30_fps_dt(act.dt)
      else
        humanState.velocity = float3(0.0)

    elif teleport_trap_affect__state == int(TeleportTrapAffectState.SHADOW_REALM)
      humanState.velocity = float3(0.0)


[es(tag=server, track=teleport_trap_affect__state)]
def teleport_trap_affect_track_state_server(evt : Event;
                                            game_effect__attachedTo : EntityId;
                                            teleport_trap_affect__state : int;
                                            teleport_trap_affect__teleportTm : float3x4;
                                            teleport_trap_affect__shodowRealmEffectHuman : string;
                                            teleport_trap_affect__shodowRealmEffectMonster : string;
                                            var teleport_trap_affect__shadowRealmSubEffect : EntityId&)
  query(game_effect__attachedTo) <| $ [es] (var transform aka actor_transform : float3x4;
                                            human_net_phys : HumanActor const?;
                                            phys_obj_net_phys : PhysObjActor const?)
    assume hasHumanPhys = human_net_phys != null
    assume hasPhysObjPhys = phys_obj_net_phys != null
    assume shadowRealmEffectName = hasHumanPhys ? teleport_trap_affect__shodowRealmEffectHuman : teleport_trap_affect__shodowRealmEffectMonster
    if teleport_trap_affect__state == int(TeleportTrapAffectState.SHADOW_REALM)
      teleport_trap_affect__shadowRealmSubEffect = createEntity(shadowRealmEffectName) <| $(var init)
        init |> set("game_effect__attachedTo", game_effect__attachedTo)
    elif teleport_trap_affect__state == int(TeleportTrapAffectState.TELEPORT)
      destroyEntity(teleport_trap_affect__shadowRealmSubEffect)
      process_teleport(game_effect__attachedTo, teleport_trap_affect__teleportTm,
                       hasHumanPhys, hasPhysObjPhys, actor_transform)


[es(tag=server)]
def trigger_traps_on_shell_exploded(evt : EventShellExplodedServer;
                                    shell__owner : EntityId;
                                    shell__shell_id__shell_id, shell__shell_id__damage_id, shell__shell_id__ballistics_id : int;
                                    shell__damageRadiusMult  = 1.0)
  let radius = get_shell_max_radius(shell__shell_id__shell_id,
                                    shell__shell_id__damage_id,
                                    shell__shell_id__ballistics_id) * shell__damageRadiusMult
  if radius <= 0.0
    return
  trigger_traps_in_radius(evt.pos, radius, shell__owner)


def trigger_traps_in_radius(pos : float3;
                            radius : float;
                            offender : EntityId)
  for_each_entity_in_grid(ecs_hash("traceable_spheres"), BSphere3(pos, radius), GridEntCheck.POS) <| $(trap_eid : EntityId)
    query(trap_eid) <| $ [es(REQUIRE=trap_triggerable_by_projectile)] (var trigger_trap__triggered : bool&)
      sendEvent(trap_eid, EventTrapTrigger(activatorEid = offender))
      trigger_trap__triggered = true


[es(tag=server, on_appear)]
def trigger_trap_reset_on_appear(evt : Event;
                                 trigger_trap_reset__timeToReset : float;
                                 var trigger_trap_reset__resetAt : float&)
  trigger_trap_reset__resetAt = get_sync_time() + trigger_trap_reset__timeToReset


[es(tag=server, no_order)]
def trigger_trap_reset_update(act : UpdateStageInfoAct;
                              eid : EntityId;
                              trigger_trap_reset__resetAt : float;
                              trigger_trap__addSubTemplateOnTrigger : string;
                              var trigger_trap__triggered : bool&)
  if act.curTime >= trigger_trap_reset__resetAt
    trigger_trap__triggered = false
    removeSubTemplate(eid, trigger_trap__addSubTemplateOnTrigger)


enum TrapTriggerMask
  NONE
  MONSTER
  HUMAN
  HOUND


[es(on_appear)]
def init_trap_activator_mask(evt : Event;
                             eid : EntityId;
                             var trigger_trap_activator__mask : uint&;
                             @shared_comp trigger_trap_activator__maskItems : StringList)
  tags_to_mask(trigger_trap_activator__maskItems, trigger_trap_activator__mask, eid)


[es(on_appear)]
def init_trap_mask(evt : Event;
                   eid : EntityId;
                   var trigger_trap__mask : uint&;
                   @shared_comp trigger_trap__maskItems : StringList)
  tags_to_mask(trigger_trap__maskItems, trigger_trap__mask, eid)


[es(on_appear)]
def init_trap_ignore_mask(evt : Event;
                          eid : EntityId;
                          trigger_trap__ignoreMaskItems : StringList;
                          var trigger_trap__ignoreMask : uint&)
  tags_to_mask(trigger_trap__ignoreMaskItems, trigger_trap__ignoreMask, eid)


def tags_to_mask(tags : StringList; var mask : uint&; error_report_eid : EntityId = INVALID_ENTITY_ID)
  mask = 0u
  for t in tags
    var success = false
    for e in each_enum(TrapTriggerMask.NONE)
      if "{e}" == t
        success = true
        if int(e) > 0
          mask = mask | uint(1 << (int(e) - 1))
        break
    if !success
      logerr("Bad trap tag '{t}' in {getEntityTemplateName(error_report_eid)}. Doesn't match any of TrapTriggerMask.")


[es(on_appear)]
def init_trigger_trap_activator_nodes(evt : Event;
                                      eid : EntityId;
                                      animchar : AnimcharBaseComponent;
                                      @shared_comp trigger_trap_activator__traceNodeNames : StringList;
                                      var trigger_trap_activator__traceNodes : IntList)

  for nn in trigger_trap_activator__traceNodeNames
    let nodeIdx = geomtree_findNodeIndex(*animchar.nodeTree, string(nn))
    if nodeIdx < 0
      logerr("Undefined trap activator node: {nn} in ({eid})<{getEntityTemplateName(eid)}>")
      continue
    trigger_trap_activator__traceNodes |> push(nodeIdx)