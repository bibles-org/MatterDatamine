require ecs
require ecs.safe
require app
require math.base
require math.random
require DagorRandom
require DagorMath
require Dacoll
require Grid
require DngDm
require game.es.grav_zones_common
require dm
require DngWalkerai
require DngNet
require BehNodes
require NavmeshMapping
require pathfinder
require debug.logerr_once
require game.events.events_game
require danetlibs.dm.dm_events
require danetlibs.navmesh_phys.main.nphys_common
require daslib/algorithm


[es(tag=server, no_order, REQUIRE_NOT=deadEntity)]
def trigger_fireflying_firefly(act : UpdateStageInfoAct;
                               firefly_disturber__radius : float;
                               firefly_disturber__interval : float;
                               transform aka disturber_transform : float3x4;
                               team : int;
                               human_anim__vehicleSelected = INVALID_ENTITY_ID;
                               var firefly_disturber__updateAt : float&)
  if firefly_disturber__updateAt < act.curTime
    firefly_disturber__updateAt = act.curTime + firefly_disturber__interval
    let isXenosTeam = find_query() <| $ [es(REQUIRE=xenos_team)] (team__id : int)
      return team__id == team
    if isXenosTeam
      return
    let disturberUpperPos = disturber_transform[3]
    let radius = human_anim__vehicleSelected != INVALID_ENTITY_ID ? firefly_disturber__radius + 3.0 : firefly_disturber__radius
    for_each_entity_in_grid(ecs_hash("creatures"), BSphere3(transform[3], radius), GridEntCheck.POS) <| $(eid : EntityId)
      query(eid) <| $ [es(REQUIRE_NOT=deadEntity, REQUIRE=firefly)] (transform aka trap_transform : float3x4;
                                                                     firefly__triggerRadius : float;
                                                                     firefly__explodeRadius : float;
                                                                     firefly__dropOnExplosion : Array;
                                                                     hitpoints__maxHp : float;
                                                                     nphys_levitating__elevation : float;
                                                                     spawnling__clusterEid : EntityId;
                                                                     navmesh_phys__immediateObstacleIdx : int;
                                                                     obstacle_avoider__escapeOffset : float = 0.4;
                                                                     navmesh_phys__upDir : float3 = float3(0, 1, 0);
                                                                     agent_obstacles : AgentObstacles)
        let fireflyPos = trap_transform[3] - navmesh_phys__upDir * nphys_levitating__elevation
        let dstToDisturber = min(distance_sq(fireflyPos, disturber_transform[3]), distance_sq(trap_transform[3], disturberUpperPos))
        let dstToVehicle = calc_dst_to_vehicle(trap_transform[3],
                                                human_anim__vehicleSelected,
                                                navmesh_phys__immediateObstacleIdx,
                                                obstacle_avoider__escapeOffset,
                                                agent_obstacles)
        let dst = min(dstToDisturber, dstToVehicle)
        if dst < square(firefly__triggerRadius)
          query(spawnling__clusterEid) <| $ [es] (firefly_cluster__triggeredUntil : float)
            if firefly_cluster__triggeredUntil < act.curTime || dst < square(firefly__explodeRadius)
              trigger_firefly_field(spawnling__clusterEid, trap_transform[3])
          if dst < square(firefly__explodeRadius)
            var norm : float3
            let from = disturber_transform[3] + disturber_transform[1] * 0.25
            let dir = normalize(trap_transform[3] - from)
            var t = distance(trap_transform[3], disturber_transform[3])
            if !traceray_normalized(from, dir, t, norm)
              let dmDesc = DamageDesc(DamageType.DM_UNKNOWN, hitpoints__maxHp, trap_transform[3])
              damage_entity(eid, eid, dmDesc)

              for preset in firefly__dropOnExplosion
                let obj = get_ecs_object(preset)
                let chance = (*obj).chance ?? .0
                let temp = (*obj).proto ?? ""
                if !empty(temp) && gfrnd() < chance
                  createEntity(temp) <| $(init)
                    init |> set("transform", get_grav_tm(trap_transform[3]))


def calc_dst_to_vehicle(pos : float3;
                        human_anim__vehicleSelected : EntityId;
                        navmesh_phys__immediateObstacleIdx : int;
                        obstacle_avoider__escapeOffset : float;
                        agent_obstacles : AgentObstacles)
  if (human_anim__vehicleSelected != INVALID_ENTITY_ID &&
    navmesh_phys__immediateObstacleIdx >= 0 &&
    navmesh_phys__immediateObstacleIdx < length(agent_obstacles.obstacles))
    if human_anim__vehicleSelected == agent_obstacles.obstacles[navmesh_phys__immediateObstacleIdx].eid
      var nearestPoint : float3
      return distance_to_obstacle_fast(pos, agent_obstacles.obstacles[navmesh_phys__immediateObstacleIdx], nearestPoint) + obstacle_avoider__escapeOffset
  return FLT_MAX


def trigger_firefly_field(field_eid : EntityId; trigger_pos : float3)
  let time = get_sync_time()
  query(field_eid) <| $ [es] (firefly_cluster__delayPerMeter : float;
                              firefly_cluster__minDelayDiff : float;
                              star_cluster__triggeredDuration : float;
                              var firefly_cluster__triggeredUntil : float&;
                              var firefly_cluster__triggerQueueEids : EidList;
                              var firefly_cluster__triggerQueueTimes : FloatList)
    if length(firefly_cluster__triggerQueueTimes) > 0
      return
    firefly_cluster__triggeredUntil = time + star_cluster__triggeredDuration
    query() <| $ [es] (eid, spawnling__clusterEid : EntityId;
                       transform : float3x4;
                       sleeping_trap : Tag const?;
                       firefly__lastTriggerAt : float;
                       spawnling__triggeredDuration : float;
                       var beh_tree : BehaviourTree)
      if field_eid == spawnling__clusterEid
        if sleeping_trap != null
          let dst = distance(trigger_pos, transform[3])
          let startAt = dst * firefly_cluster__delayPerMeter + time
          let insertionIndex = firefly_cluster__triggerQueueTimes |> lower_bound(startAt) <| $(x, y)
            return x > y
          firefly_cluster__triggerQueueEids |> push(eid, insertionIndex)
          firefly_cluster__triggerQueueTimes |> push(startAt, insertionIndex)
        elif time - firefly__lastTriggerAt > spawnling__triggeredDuration
          beh_tree_reset(beh_tree)
    var prev = .0
    for idx in iter_range(firefly_cluster__triggerQueueTimes)
      if firefly_cluster__triggerQueueTimes[idx] - prev < firefly_cluster__minDelayDiff
        firefly_cluster__triggerQueueTimes[idx] += firefly_cluster__minDelayDiff
      prev = firefly_cluster__triggerQueueTimes[idx]



[es(tag=server, no_order)]
def gradual_trigger_firefly_cluster(act : UpdateStageInfoAct;
                                    var firefly_cluster__triggerQueueEids : EidList;
                                    var firefly_cluster__triggerQueueTimes : FloatList)
  var i = length(firefly_cluster__triggerQueueEids)
  while i-- > 0
    if firefly_cluster__triggerQueueTimes[i] < act.curTime
      query(firefly_cluster__triggerQueueEids[i]) <| $ [es] (firefly__activeElevation : float;
                                                             firefly__sleepTemplate : string;
                                                             firefly__activeTemplate : string;
                                                             spawnling__triggeredDuration : float;
                                                             var firefly__lastTriggerAt : float&;
                                                             var nphys_levitating__prefferedElevation : float&;
                                                             var beh_tree__enabled : bool&;
                                                             var beh_tree : BehaviourTree;
                                                             sleeping_trap : Tag const?)
        if sleeping_trap == null
          if act.curTime - firefly__lastTriggerAt > spawnling__triggeredDuration
            beh_tree_reset(beh_tree)
        else
          remote_change_sub_template(firefly_cluster__triggerQueueEids[i], firefly__sleepTemplate, firefly__activeTemplate)
        beh_tree__enabled = true
        firefly__lastTriggerAt = act.curTime
        nphys_levitating__prefferedElevation = firefly__activeElevation
    else
      break
    erase(firefly_cluster__triggerQueueEids, i)
    erase(firefly_cluster__triggerQueueTimes, i)


[es(tag=server, track=hitpoints__hp)]
def trigger_firefly_field_on_dealth(evt : Event;
                                    hitpoints__hp : float;
                                    hitpoints__maxHp : float;
                                    spawnling__clusterEid : EntityId;
                                    transform : float3x4)
  if hitpoints__hp < hitpoints__maxHp
    trigger_firefly_field(spawnling__clusterEid, transform[3])


[es(tag=server, on_event=EventEntityDied)]
def trigger_firefly_on_death(evt : Event;
                             eid : EntityId;
                             firefly__explodeTemplate : string;
                             transform : float3x4)
  firefly_die(eid, firefly__explodeTemplate, transform)


[es(tag=server, before=beh_tree_update_es, REQUIRE_NOT=(sleeping_trap, deadEntity))]
def perform_firefly_delayed_death(act : UpdateStageInfoAct;
                                  eid : EntityId;
                                  firefly__deathAt : float;
                                  firefly__explodeTemplate : string;
                                  transform : float3x4)
  if firefly__deathAt > .0 && firefly__deathAt < act.curTime
    firefly_die(eid, firefly__explodeTemplate, transform)


def firefly_die(eid : EntityId; firefly__explodeTemplate : string; transform : float3x4)
  destroyEntity(eid)
  createEntity(firefly__explodeTemplate) <| $(init)
    init |> set("transform", transform)


[es(tag=server, on_appear)]
def init_firefly(evt : Event;
                 eid : EntityId;
                 transform : float3x4;
                 firefly__elevationRnd : float;
                 firefly__speedRnd : float;
                 firefly__accelRnd : float;
                 firefly__oscillationAmplitudeRnd : float;
                 firefly__oscillationFreqRnd : float;
                 var firefly__passiveElevation : float&;
                 var navmesh_phys__maxWalkSpeed : float&;
                 var navmesh_phys__acceleration : float&;
                 var firefly__activeElevation : float&;
                 var firefly__origin : float3&;
                 var firefly__oscillationAmplitude : float&;
                 var firefly__oscillationFreq : float&)
  var seed = int(uint(eid))
  firefly__origin = transform[3]
  navmesh_phys__maxWalkSpeed += rnd_float(-firefly__speedRnd, firefly__speedRnd)
  navmesh_phys__acceleration += rnd_float(-firefly__accelRnd, firefly__accelRnd)
  firefly__activeElevation += rnd_float(-firefly__elevationRnd, firefly__elevationRnd)
  firefly__passiveElevation += rnd_float(-firefly__elevationRnd, firefly__elevationRnd)
  firefly__oscillationAmplitude += _rnd_float(seed, -firefly__oscillationAmplitudeRnd, firefly__oscillationAmplitudeRnd)
  firefly__oscillationFreq += _rnd_float(seed, -firefly__oscillationFreqRnd, firefly__oscillationFreqRnd)


[es(tag=server, before=beh_tree_update_es, REQUIRE_NOT=(sleeping_trap, deadEntity))]
def set_firefly_elevation(act : UpdateStageInfoAct;
                          firefly__activeElevation : float;
                          firefly__passiveElevation : float;
                          walker_agent__targetEid : EntityId;
                          firefly__oscillationAmplitude : float;
                          firefly__oscillationFreq : float;
                          firefly__oscillationAmplitudePassiveMult : float;
                          var nphys_levitating__prefferedElevation : float&)
  let isPassive = walker_agent__targetEid == INVALID_ENTITY_ID
  nphys_levitating__prefferedElevation = isPassive ? firefly__passiveElevation : firefly__activeElevation
  let oscillationAmplitudeMult = isPassive ? firefly__oscillationAmplitudePassiveMult : 1.0
  let minElevation = 0.2
  let oscillationAmplitude = min(firefly__oscillationAmplitude * oscillationAmplitudeMult, nphys_levitating__prefferedElevation - minElevation)
  nphys_levitating__prefferedElevation += sin(act.curTime * firefly__oscillationFreq * PI * 2.0) * oscillationAmplitude


[es(tag=server, on_appear, REQUIRE=(sleeping_trap, firefly))]
def disable_behtree_when_sleeping_firefly(evt : Event; var beh_tree__enabled : bool&)
  beh_tree__enabled = false


[es(tag=server, track=hitpoints__hp)]
def firefly_update_scale_server(event : Event; firefly__minMaxScale : float2;
                                hitpoints__hp : float; hitpoints__maxHp : float; var firefly__scale : float&; var transform : float3x4&)
  firefly__scale = cvt(hitpoints__hp, hitpoints__maxHp, .0, firefly__minMaxScale.x, firefly__minMaxScale.y)
  var tm = transform
  tm[0] = normalize(tm[0])
  tm[1] = normalize(tm[1])
  tm[2] = normalize(tm[2])
  tm = tm * scale_tm(firefly__scale)
  transform = tm


[es(tag=server, REQUIRE=firefly__origin)]
def on_firefly_hit(evt : CmdApplyDamage;
                   eid : EntityId;
                   nphys_position_mapping__didMapThisFrame : bool = false;
                   nphys_position_mapping__oldUpDir : float3 = float3(0, 1, 0);
                   position_mapping__lastZone : EntityId = INVALID_ENTITY_ID;
                   firefly__dmgPushUp : float;
                   firefly__dmgPushStrength : float;
                   navmesh_phys__upDir : float3 = float3(0, 1, 0))
  var dir = evt.hitDir
  let upDir = nphys_position_mapping__didMapThisFrame ? nphys_position_mapping__oldUpDir : navmesh_phys__upDir
  let vertComponent = dot(dir, upDir)
  dir = dir - upDir * vertComponent + upDir * max(.0, vertComponent)
  var vel = (dir + upDir * firefly__dmgPushUp) * firefly__dmgPushStrength * evt.deltaHp
  if nphys_position_mapping__didMapThisFrame
    vel = navmesh_map_vector_in_zone(vel, position_mapping__lastZone)
  sendEvent(eid, CmdPushPhys(vel = vel, push_immunity = .0))


[es(tag=server, on_appear)]
def set_evelation_change_speed_on_activated_firely(evt : Event; firefly__elevationChangeSpeed : float2; var nphys_levitating__elevationChangeSpeed : float&)
  nphys_levitating__elevationChangeSpeed = firefly__elevationChangeSpeed.x


[es(tag=server, no_order)]
def set_evelation_change_speed_on_active_firely(act : UpdateStageInfoAct;
                                                firefly__elevationChangeSpeed : float2;
                                                firefly__elevationChangeSpeedTau : float;
                                                var nphys_levitating__elevationChangeSpeed : float&)
  nphys_levitating__elevationChangeSpeed = approach(nphys_levitating__elevationChangeSpeed, firefly__elevationChangeSpeed.y, act.dt, firefly__elevationChangeSpeedTau)


[es(tag=server)]
def damage_firefly_on_shell_exploded(evt : EventShellExplodedServer;
                                     shell__owner : EntityId = INVALID_ENTITY_ID;
                                     shell__shell_id__shell_id, shell__shell_id__damage_id, shell__shell_id__ballistics_id : int;
                                     shell__damageMult  = 1.0;
                                     shell__damageRadiusMult  = 1.0)
  let radius = get_shell_max_radius(shell__shell_id__shell_id,
                                    shell__shell_id__damage_id,
                                    shell__shell_id__ballistics_id) * shell__damageRadiusMult
  if radius <= 0f
    return
  let splash = get_shell_splash_params(shell__shell_id__damage_id, false)
  damage_fireflies_in_radius(evt.pos, splash, radius, shell__damageMult, shell__owner)


def damage_fireflies_in_radius(pos : float3; splash : SplashParams; radius, damage_mult : float; offender : EntityId)
  for_each_entity_in_grid(ecs_hash("creatures"), BSphere3(pos, radius), GridEntCheck.POS) <| $(eid : EntityId)
    query(eid) <| $ [es(REQUIRE_NOT=deadEntity, REQUIRE=firefly)] (transform : float3x4;
                                                                   hitpoints__shellSplashDmgMult : float;
                                                                   firefly__explosionPushStrength : float;
                                                                   firefly__dmgPushUp : float;
                                                                   firefly__explosionDeathRndDelay : float2;
                                                                   hitpoints__hp : float;
                                                                   navmesh_phys__upDir : float3 = float3(0, 1, 0);
                                                                   var firefly__deathAt : float&)
      let delta = transform[3] - pos
      let distanceToEpicenter = length(delta)
      let hitDir = delta * safeinv(distanceToEpicenter)
      var damage = splash.damage * damage_mult * hitpoints__shellSplashDmgMult
      damage *= cvt(distanceToEpicenter, splash.innerRadius, splash.outerRadius, 1.0, 0.0)
      let fullDamage = damage
      if damage >= hitpoints__hp
        damage = min(hitpoints__hp - 1.0, damage) // so it doesn't die but other effects can kill it ignoring firefly__deathAt
        firefly__deathAt = get_sync_time() + rnd_float(firefly__explosionDeathRndDelay)
      let vel = (hitDir + navmesh_phys__upDir * firefly__dmgPushUp) * firefly__explosionPushStrength * fullDamage
      sendEvent(eid, CmdPushPhys(vel = vel, push_immunity = .0))
      if damage > .0
        let dmDesc = DamageDesc(DamageType.DM_EXPLOSION, damage, pos)
        damage_entity(eid, offender, dmDesc)