require app
require ecs
require ecs.safe
require ecs.soa_template
require game.events.events
require game.events.events_game
require game.events.events
require danetlibs.weapons.melee_events
require game.es.tweening_common
require game.es.am_encounter_jump_quest_common
require math.base
require math.random
require math.easing
require game.es.concussion_common
require game.es.trace_common
require Grid
require GridCollision
require DngDm
require CollisionTraces
require DagorMath
require DagorRandom
require CollRes
require Dacoll
require AnimV20
require GeomNodeTree
require DaWeaponProps
require EntityActions


[es(tag=server, on_disappear)]
def encounter_jump_quest_am_core_disappear(evt : Event;
                                           am_core__protectiveSphereEid : EntityId;
                                           am_core__protectiveShellEid : EntityId;
                                           encounter_jump_quest_core_ai__projectileEids : EidList)
  destroyEntity(am_core__protectiveSphereEid)
  destroyEntity(am_core__protectiveShellEid)
  for eid in encounter_jump_quest_core_ai__projectileEids
    destroyEntity(eid)


[es(REQUIRE=encounter_jump_quest_core, track=isAlive)]
def encounter_jump_quest_am_core_enter_protective_mode(evt : Event;
                                                       isAlive : bool;
                                                       var am_core__protectiveSphereEnabled : bool&)
  am_core__protectiveSphereEnabled = isAlive


[soa_es, es(tag=server, REQUIRE=encounter_jump_quest_core, track=isAlive)]
def encounter_jump_quest_am_core_track_alive_server(evt : Event;
                                                    eid : EntityId;
                                                    isAlive : bool;
                                                    transform aka core_transform : float3x4;
                                                    encounter_jump_quest_core__earthshakeTemplate : string;
                                                    encounter_jump_quest_core__epicenterRadius : float;
                                                    encounter_jump_quest_core__concussionAffect : string;
                                                    var am_core__fragmentsLimit : int&)
  if isAlive
    return

  sendEvent(eid, EventDropLootRequest())

  // Emulate default am core behavior
  am_core__fragmentsLimit = am_core__fragmentsLimit == 0 ? -1 : 0

  find_query() <| $ [soa_blk, es] (encounter_jump_quest__coreEid : EntityId;
                                   encounter_jump_quest__pathRendinsts : Array;
                                   encounter_jump_quest__topPlatformRendinsts : Array;
                                   encounter_jump_quest__decorRendinsts : Array;
                                   encounter_jump_quest__nodes : EncounterJumpQuestNode_SOA;
                                   encounter_jump_quest__recoveringDelay : float2;
                                   var encounter_jump_quest__recoverAt : float&)
    if eid != encounter_jump_quest__coreEid
      return false
    demolish_jump_nodes_tree(encounter_jump_quest__pathRendinsts,
                             encounter_jump_quest__topPlatformRendinsts,
                             encounter_jump_quest__decorRendinsts,
                             encounter_jump_quest__coreEid,
                             encounter_jump_quest__nodes,
                             encounter_jump_quest__recoveringDelay,
                             encounter_jump_quest__recoverAt)
    return true

  if encounter_jump_quest_core__earthshakeTemplate != ""
    createEntity(encounter_jump_quest_core__earthshakeTemplate) <| $(var init : ComponentsInitializer)
      var tm = IDENT_TM
      tm[3] = core_transform[3]
      init |> set("transform", tm)

  let epicenterRadius = encounter_jump_quest_core__epicenterRadius
  for_each_entity_in_grid(ecs_hash("humans"), BSphere3(core_transform[3], epicenterRadius), GridEntCheck.POS) <| $ [unused_argument(pos)] (human_eid : EntityId; pos : float3)
    query(human_eid) <| $ [es(REQUIRE=human)] (eid : EntityId)
      enable_concussion_affect(eid, encounter_jump_quest_core__concussionAffect)


def generate_encounter_jump_quest_core_projectile_idle_speed(speed_rng : float2)
  return rnd_float(speed_rng) * float2(rnd_sign(), rnd_sign())


[es(tag=server, on_appear)]
def encounter_jump_quest_core_ai_init(evt : Event;
                                      eid : EntityId;
                                      transform : float3x4;
                                      encounter_jump_quest_core_ai__projectileTemplate : string;
                                      encounter_jump_quest_core_ai__projectileCountRng : int2;
                                      var encounter_jump_quest_core_ai__projectileEids : EidList)

  if encounter_jump_quest_core_ai__projectileTemplate != ""
    for _ in range(rnd_int(encounter_jump_quest_core_ai__projectileCountRng))
      let projectileEid = createEntity(encounter_jump_quest_core_ai__projectileTemplate) <| $(var init)
        let dir = rnd_dir3()
        let pos = transform[3] + dir * rnd_float(1.5, 2.5)
        var tm : float3x4
        make_tm(dir_to_quat(dir), pos, tm)
        set(init, "transform", tm)
        set(init, "encounter_jump_quest_core_projectile__dir", dir)
        set(init, "encounter_jump_quest_core_projectile__owner", eid)
        set(init, "encounter_jump_quest_core_projectile__state", int(EncounterJumpQuestCoreProjectileState.MOVE_TO_IDLE_ORBIT))
        set(init, "encounter_jump_quest_core_projectile__idleTheta", gfrnd() * TWOPI)
        set(init, "encounter_jump_quest_core_projectile__idlePhi", gfrnd() * TWOPI)
      encounter_jump_quest_core_ai__projectileEids |> push(projectileEid)


[soa_def]
def find_index_in_encounter_jump_quest_enemy_data_list(list : EncounterJumpQuestEnemy_SOA; target : EntityId)
  for idx, id in range(length(list)), list
    if id.encounter_jump_quest_core_ai__enemies__eid == target
      return idx
  return -1


[soa_es, es(tag=server, no_order)]
def encounter_jump_quest_core_ai_update(act : UpdateStageInfoAct;
                                        isAlive : bool;
                                        transform aka core_transform : float3x4;
                                        encounter_jump_quest_core_ai__updateInterval : float;
                                        encounter_jump_quest_core_ai__blindZoneRadiusSq : float;
                                        encounter_jump_quest_core_ai__alarmRadius : float;
                                        encounter_jump_quest_core_ai__protectiveRadiusSq : float;
                                        encounter_jump_quest_core_ai__projectileEids : EidList;
                                        encounter_jump_quest_core_ai__alarmTimePerProjectile : float;
                                        encounter_jump_quest_core_ai__maxProjectilesCountPerEnemy : int;
                                        var enemies : EncounterJumpQuestEnemy_SOA;
                                        var encounter_jump_quest_core_ai__nextUpdateAt : float&)
  if act.curTime < encounter_jump_quest_core_ai__nextUpdateAt
    return

  if !isAlive
    return

  assume alarmRadius = encounter_jump_quest_core_ai__alarmRadius

  let enemiesCount = length(enemies)
  if enemiesCount > 0
    let alarmRadiusSq = square(alarmRadius)
    for i in range(enemiesCount)
      let inverseIdx = enemiesCount - i - 1
      var removeEnemy = true
      query(enemies[inverseIdx].encounter_jump_quest_core_ai__enemies__eid) <| $ [es] (transform aka enemy_transform : float3x4)
        let distanceToEnemySq = distance_sq(core_transform[3], enemy_transform[3])
        if distanceToEnemySq < encounter_jump_quest_core_ai__blindZoneRadiusSq
          return

        if distanceToEnemySq < encounter_jump_quest_core_ai__protectiveRadiusSq
          removeEnemy = false

          if distanceToEnemySq < alarmRadiusSq
            enemies[inverseIdx].encounter_jump_quest_core_ai__enemies__alarmTime += encounter_jump_quest_core_ai__updateInterval
          else
            enemies[inverseIdx].encounter_jump_quest_core_ai__enemies__alarmTime -= 1.5 * encounter_jump_quest_core_ai__updateInterval
            if enemies[inverseIdx].encounter_jump_quest_core_ai__enemies__alarmTime <= 0.0
              removeEnemy = true
      if removeEnemy

        for projectileEid in encounter_jump_quest_core_ai__projectileEids
          query(projectileEid) <| $ [es] (var encounter_jump_quest_core_projectile__enemyEid : EntityId&;
                                          var encounter_jump_quest_core_projectile__state : int&)
            if encounter_jump_quest_core_projectile__enemyEid == enemies[inverseIdx].encounter_jump_quest_core_ai__enemies__eid
              encounter_jump_quest_core_projectile__enemyEid = INVALID_ENTITY_ID
              encounter_jump_quest_core_projectile__state = int(EncounterJumpQuestCoreProjectileState.MOVE_TO_IDLE_ORBIT)

        enemies |> erase(inverseIdx)

  for_each_entity_in_grid(ecs_hash("humans"), BSphere3(core_transform[3], alarmRadius), GridEntCheck.BOUNDING) <| $(enemy_eid : EntityId)
    query(enemy_eid) <| $ [es(REQUIRE_NOT=deadEntity, REQUIRE=(ai_target, human_net_phys))] (isAlive : bool)
      if !isAlive
        return
      let idx = find_index_in_encounter_jump_quest_enemy_data_list(enemies, enemy_eid)
      if idx < 0
        enemies |> push() <| EncounterJumpQuestEnemy(
          encounter_jump_quest_core_ai__enemies__eid = enemy_eid)


  for enemy in enemies
    var projectilesTrackingEnemyCount = 0
    for projectileEid in encounter_jump_quest_core_ai__projectileEids
      query(projectileEid) <| $ [es] (encounter_jump_quest_core_projectile__enemyEid : EntityId;
                                      encounter_jump_quest_core_projectile__state : int)
        if encounter_jump_quest_core_projectile__state == int(EncounterJumpQuestCoreProjectileState.IDLE)
          return
        if encounter_jump_quest_core_projectile__enemyEid == enemy.encounter_jump_quest_core_ai__enemies__eid
          ++projectilesTrackingEnemyCount

    let projectilesTrackingEnemyRequired = min(encounter_jump_quest_core_ai__maxProjectilesCountPerEnemy,
      ceili(enemy.encounter_jump_quest_core_ai__enemies__alarmTime / encounter_jump_quest_core_ai__alarmTimePerProjectile))

    for _ in range(projectilesTrackingEnemyRequired - projectilesTrackingEnemyCount)
      var projectileSet = false
      for projectileEid in encounter_jump_quest_core_ai__projectileEids
        query(projectileEid) <| $ [es] (var encounter_jump_quest_core_projectile__enemyEid : EntityId&;
                                        var encounter_jump_quest_core_projectile__state : int&)
          if encounter_jump_quest_core_projectile__state == int(EncounterJumpQuestCoreProjectileState.IDLE)
            encounter_jump_quest_core_projectile__enemyEid = enemy.encounter_jump_quest_core_ai__enemies__eid
            encounter_jump_quest_core_projectile__state = int(EncounterJumpQuestCoreProjectileState.TRACKING_ENEMY)
            projectileSet = true
        if projectileSet
          break
      if !projectileSet
        break

  encounter_jump_quest_core_ai__nextUpdateAt = act.curTime + encounter_jump_quest_core_ai__updateInterval


[soa_es, es(tag=server, track=isAlive)]
def encounter_jump_quest_core_ai_alive_track(evt : Event;
                                             isAlive : bool;
                                             encounter_jump_quest_core_ai__projectileEids : EidList)
  for projectileEid in encounter_jump_quest_core_ai__projectileEids
    query(projectileEid) <| $ [es] (var encounter_jump_quest_core_projectile__state : int&)
      encounter_jump_quest_core_projectile__state = (isAlive ? int(EncounterJumpQuestCoreProjectileState.MOVE_TO_IDLE_ORBIT)
                                                             : int(EncounterJumpQuestCoreProjectileState.MOVE_INSIDE_CORE))


[es(tag=server, on_appear)]
def encounter_jump_quest_core_projectile_idle_init(evt : Event;
                                                   encounter_jump_quest_core_projectile__idleSpeedRng : float2;
                                                   var encounter_jump_quest_core_projectile__currentIdleSpeed : float2&;
                                                   var encounter_jump_quest_core_projectile__targetIdleSpeed : float2&)
  assume idleSpeedRng = encounter_jump_quest_core_projectile__idleSpeedRng
  encounter_jump_quest_core_projectile__currentIdleSpeed = generate_encounter_jump_quest_core_projectile_idle_speed(idleSpeedRng)
  encounter_jump_quest_core_projectile__targetIdleSpeed = generate_encounter_jump_quest_core_projectile_idle_speed(idleSpeedRng)


def get_encounter_jump_quest_core_projectile_idle_point(core_pos : float3;
                                                        orbit_radius : float;
                                                        theta : float;
                                                        phi : float)
  var sinTheta : float
  var cosTheta : float
  sincos(theta, sinTheta, cosTheta)

  var sinPhi : float
  var cosPhi : float
  sincos(phi, sinPhi, cosPhi)

  return core_pos + orbit_radius * float3(cosTheta * cosPhi, sinTheta, cosTheta * sinPhi)


def randomize_tracking_enemy_position(core_pos : float3;
                                      enemy_pos : float3;
                                      radius_min : float;
                                      radius_max : float)
  let coreToEnemyXZ = enemy_pos.xz - core_pos.xz
  let coreToEnemyXZDistanceSq = length_sq(coreToEnemyXZ)
  if coreToEnemyXZDistanceSq < 1e-3
    return enemy_pos

  let coreToEnemyXZDir = coreToEnemyXZ / sqrt(coreToEnemyXZDistanceSq)
  let baseDir = float3(coreToEnemyXZDir.x, 0.0, coreToEnemyXZDir.y)

  let yaw = gfrnd() * PI - PI * 0.5
  let pitch = sign(coreToEnemyXZ.x) * (gfrnd() * PI * 0.5 - PI * 0.25)
  var rot : quat
  euler_to_quat(yaw, pitch, 0.0, rot)

  return core_pos + rot * baseDir * rnd_float(radius_min, radius_max)


[es(tag=server, before=encounter_jump_quest_core_ai_update)]
def encounter_jump_quest_core_projectile_update(act : UpdateStageInfoAct;
                                                eid aka projectile_eid : EntityId;
                                                encounter_jump_quest_core_projectile__owner : EntityId;
                                                encounter_jump_quest_core_projectile__idleOrbitRadiusRng : float2;
                                                encounter_jump_quest_core_projectile__idleSpeedRng : float2;
                                                encounter_jump_quest_core_projectile__selectTrackingEnemyPositionInterval : float;
                                                encounter_jump_quest_core_projectile__trackingEnemySpeed : float;
                                                encounter_jump_quest_core_projectile__trackingEnemyAttackTimeRng : float2;
                                                encounter_jump_quest_core_projectile__trackingEnemyAttackDistanceMinMax : float2;
                                                encounter_jump_quest_core_projectile__chargingToRamAimTimePercent : float;
                                                encounter_jump_quest_core_projectile__chargingToRamTime : float;
                                                encounter_jump_quest_core_projectile__ramSpeed : float2;
                                                encounter_jump_quest_core_projectile__damageRng : float2;
                                                encounter_jump_quest_core_projectile__pushPowerRng : float2;
                                                encounter_jump_quest_core_projectile__moveToIdleOrbitSpeed : float = 3.0;
                                                encounter_jump_quest_core_projectile__chargingToRamSpeed : float = 0.5;
                                                encounter_jump_quest_core_projectile__ramBounceSpeed : float = 6.0;
                                                var transform aka projectile_transform : float3x4;
                                                var encounter_jump_quest_core_projectile__enemyEid : EntityId&;
                                                var encounter_jump_quest_core_projectile__dir : float3&;
                                                var encounter_jump_quest_core_projectile__currentIdleSpeed : float2&;
                                                var encounter_jump_quest_core_projectile__targetIdleSpeed : float2&;
                                                var encounter_jump_quest_core_projectile__state : int&;
                                                var encounter_jump_quest_core_projectile__idleTheta : float&;
                                                var encounter_jump_quest_core_projectile__idlePhi : float&;
                                                var encounter_jump_quest_core_projectile__selectTrackingEnemyPositionAt : float&;
                                                var encounter_jump_quest_core_projectile__trackingEnemyPosition : float3&;
                                                var encounter_jump_quest_core_projectile__trackingEnemyAttackAt : float&;
                                                var encounter_jump_quest_core_projectile__stateProgressTimer : float&;
                                                var encounter_jump_quest_core_projectile__ramSrcPosition : float3&;
                                                var encounter_jump_quest_core_projectile__ramDestPosition : float3&)

  assume state = encounter_jump_quest_core_projectile__state
  assume coreEid = encounter_jump_quest_core_projectile__owner
  if state == int(EncounterJumpQuestCoreProjectileState.MOVE_TO_IDLE_ORBIT)
    query(coreEid) <| $ [es] (transform aka core_transform : float3x4)
      let idleOrbitRadiusMinSq = square(encounter_jump_quest_core_projectile__idleOrbitRadiusRng.x)
      let idleOrbitRadiusMaxSq = square(encounter_jump_quest_core_projectile__idleOrbitRadiusRng.y)

      let distanceToCoreSq = distance_sq(core_transform[3], projectile_transform[3])

      if distanceToCoreSq < idleOrbitRadiusMinSq || distanceToCoreSq > idleOrbitRadiusMaxSq
        let idleOrbitRadiusMid = (encounter_jump_quest_core_projectile__idleOrbitRadiusRng.x +
                                 encounter_jump_quest_core_projectile__idleOrbitRadiusRng.y) * 0.5
        let toProjectile = projectile_transform[3] - core_transform[3]
        let toProjectileLenSq = length_sq(toProjectile)

        var destPoint = core_transform[3]
        if toProjectileLenSq < 1e-3
          destPoint = core_transform[3] + rnd_dir3() * idleOrbitRadiusMid
        else
          let toPojectileDir = toProjectile / sqrt(toProjectileLenSq)
          destPoint = core_transform[3] + toPojectileDir * idleOrbitRadiusMid
        projectile_transform[3] = move_to(projectile_transform[3], destPoint, act.dt, encounter_jump_quest_core_projectile__moveToIdleOrbitSpeed)
      else
        encounter_jump_quest_core_projectile__state = int(EncounterJumpQuestCoreProjectileState.IDLE)
        let pos = projectile_transform[3] - core_transform[3]
        encounter_jump_quest_core_projectile__idleTheta = asin(safediv(pos.y, length(pos)))
        encounter_jump_quest_core_projectile__idlePhi = atan(safediv(pos.z, pos.x))
        if pos.x < 0.0
          encounter_jump_quest_core_projectile__idlePhi += PI
        assume idleSpeedRng = encounter_jump_quest_core_projectile__idleSpeedRng
        encounter_jump_quest_core_projectile__targetIdleSpeed = generate_encounter_jump_quest_core_projectile_idle_speed(idleSpeedRng)
  elif state == int(EncounterJumpQuestCoreProjectileState.IDLE)
    query(coreEid) <| $ [es] (transform aka core_transform : float3x4)
      let idleOrbitRadiusMid = (encounter_jump_quest_core_projectile__idleOrbitRadiusRng.x +
                                encounter_jump_quest_core_projectile__idleOrbitRadiusRng.y) * 0.5

      encounter_jump_quest_core_projectile__idleTheta += encounter_jump_quest_core_projectile__currentIdleSpeed.x * act.dt
      encounter_jump_quest_core_projectile__idlePhi += encounter_jump_quest_core_projectile__currentIdleSpeed.y * act.dt
      encounter_jump_quest_core_projectile__currentIdleSpeed = lerp(encounter_jump_quest_core_projectile__currentIdleSpeed,
                                                                    encounter_jump_quest_core_projectile__targetIdleSpeed,
                                                                    float2(act.dt))

      let destPoint = get_encounter_jump_quest_core_projectile_idle_point(core_transform[3], idleOrbitRadiusMid,
                                                                          encounter_jump_quest_core_projectile__idleTheta,
                                                                          encounter_jump_quest_core_projectile__idlePhi)
      projectile_transform[3] = lerp(projectile_transform[3], destPoint, float3(act.dt * 4.0))
  elif state == int(EncounterJumpQuestCoreProjectileState.MOVE_INSIDE_CORE)
    query(coreEid) <| $ [es] (transform aka core_transform : float3x4)
      projectile_transform[3] = lerp(projectile_transform[3], core_transform[3], float3(act.dt * 4.0))
      if distance_sq(projectile_transform[3], core_transform[3]) < 1e-3
        projectile_transform[3] = core_transform[3]
        encounter_jump_quest_core_projectile__state = int(EncounterJumpQuestCoreProjectileState.NONE)
  elif state == int(EncounterJumpQuestCoreProjectileState.TRACKING_ENEMY)
    query(coreEid) <| $ [es] (transform aka core_transform : float3x4;
                              encounter_jump_quest_core_ai__protectiveRadiusSq : float;
                              encounter_jump_quest_core_ai__blindZoneRadiusSq : float)
      var isTracking = false
      query(encounter_jump_quest_core_projectile__enemyEid) <| $ [es] (transform aka enemy_transform : float3x4;
                                                                       isAlive : bool;
                                                                       animchar aka enemy_animchar : AnimcharBaseComponent;
                                                                       ai_target_node__nodeId : int)
        if !isAlive
          return

        if distance_sq(core_transform[3], enemy_transform[3]) < encounter_jump_quest_core_ai__blindZoneRadiusSq
          return

        let enemyPos = *enemy_animchar.nodeTree |> geomtree_getNodeWpos(ai_target_node__nodeId)

        let projectileToEnemy = enemyPos - projectile_transform[3]
        let projectileToEnemyDistanceSq = length_sq(projectileToEnemy)
        if projectileToEnemyDistanceSq <= 1e-3
          return
        let projectileToEnemyDistance = sqrt(projectileToEnemyDistanceSq)
        let projectileToEnemyDir = projectileToEnemy / projectileToEnemyDistance

        let newRotation = slerp(dir_to_quat(encounter_jump_quest_core_projectile__dir),
                                dir_to_quat(projectileToEnemyDir),
                                act.dt)
        encounter_jump_quest_core_projectile__dir = newRotation |> quat_get_forward()


        assume attackDistanceMin = encounter_jump_quest_core_projectile__trackingEnemyAttackDistanceMinMax.x
        assume attackDistanceMax = encounter_jump_quest_core_projectile__trackingEnemyAttackDistanceMinMax.y
        if (act.curTime > encounter_jump_quest_core_projectile__trackingEnemyAttackAt &&
            projectileToEnemyDistance > attackDistanceMin &&
            projectileToEnemyDistance < attackDistanceMax)
          encounter_jump_quest_core_projectile__trackingEnemyAttackAt = act.curTime + rnd_float(encounter_jump_quest_core_projectile__trackingEnemyAttackTimeRng)
          var t = projectileToEnemyDistance
          var norm : float3

          var intersectedWithSphere = false
          using() <| $(var intersections : IntersectedEntities)
            trace_traceable_spheres_by_query(projectile_transform[3], projectileToEnemyDir, t, intersections)
            intersectedWithSphere = length(intersections) > 0

          if !intersectedWithSphere && !traceray_normalized(projectile_transform[3], projectileToEnemyDir, t, norm, ETF_RI | ETF_LMESH)
            encounter_jump_quest_core_projectile__ramSrcPosition = projectile_transform[3]
            encounter_jump_quest_core_projectile__ramDestPosition = enemyPos + projectileToEnemyDir * 0.25
            encounter_jump_quest_core_projectile__state = int(EncounterJumpQuestCoreProjectileState.CHARGING_TO_RAM)
            isTracking = true
            return

        if act.curTime > encounter_jump_quest_core_projectile__selectTrackingEnemyPositionAt
          let protectiveRadius = sqrt(encounter_jump_quest_core_ai__protectiveRadiusSq)
          let newTrackingEnemyPosition = randomize_tracking_enemy_position(core_transform[3],
                                                                           enemyPos,
                                                                           protectiveRadius * 0.33,
                                                                           protectiveRadius)
          let distanceToNewTrackingEnemyPositionSq = distance_sq(projectile_transform[3], newTrackingEnemyPosition)
          if distanceToNewTrackingEnemyPositionSq > 1e-6
            encounter_jump_quest_core_projectile__trackingEnemyPosition = newTrackingEnemyPosition

          encounter_jump_quest_core_projectile__selectTrackingEnemyPositionAt = act.curTime + encounter_jump_quest_core_projectile__selectTrackingEnemyPositionInterval

        projectile_transform[3] = move_to(projectile_transform[3],
                                          encounter_jump_quest_core_projectile__trackingEnemyPosition,
                                          act.dt,
                                          encounter_jump_quest_core_projectile__trackingEnemySpeed)

        make_tm(newRotation, projectile_transform[3], projectile_transform)
        isTracking = true
      if !isTracking
        encounter_jump_quest_core_projectile__enemyEid = INVALID_ENTITY_ID
        encounter_jump_quest_core_projectile__state = int(EncounterJumpQuestCoreProjectileState.MOVE_TO_IDLE_ORBIT)
  elif state == int(EncounterJumpQuestCoreProjectileState.CHARGING_TO_RAM)
    var isTracking = false
    query(encounter_jump_quest_core_projectile__enemyEid) <| $ [es] (isAlive : bool;
                                                                     animchar aka enemy_animchar : AnimcharBaseComponent;
                                                                     ai_target_node__nodeId : int)
      if !isAlive
        return

      let enemyPos = *enemy_animchar.nodeTree |> geomtree_getNodeWpos(ai_target_node__nodeId)

      let projectileToEnemy = enemyPos - projectile_transform[3]
      let projectileToEnemyDistanceSq = length_sq(projectileToEnemy)
      if projectileToEnemyDistanceSq <= 1e-3
        return
      let projectileToEnemyDistance = sqrt(projectileToEnemyDistanceSq)
      let projectileToEnemyDir = projectileToEnemy / projectileToEnemyDistance

      encounter_jump_quest_core_projectile__stateProgressTimer += act.dt
      if encounter_jump_quest_core_projectile__stateProgressTimer >= encounter_jump_quest_core_projectile__chargingToRamTime
        isTracking = true
        if distance_sq(encounter_jump_quest_core_projectile__ramSrcPosition,
                       encounter_jump_quest_core_projectile__ramDestPosition) >= 1e-3
          encounter_jump_quest_core_projectile__state = int(EncounterJumpQuestCoreProjectileState.RAM_ENEMY)
        else
          encounter_jump_quest_core_projectile__state = int(EncounterJumpQuestCoreProjectileState.TRACKING_ENEMY)
        return

      let chargingProgress = encounter_jump_quest_core_projectile__stateProgressTimer / encounter_jump_quest_core_projectile__chargingToRamTime

      if chargingProgress <= encounter_jump_quest_core_projectile__chargingToRamAimTimePercent
        encounter_jump_quest_core_projectile__ramSrcPosition = projectile_transform[3]
        encounter_jump_quest_core_projectile__ramDestPosition = enemyPos + projectileToEnemyDir * 0.25

      let newRotation = slerp(dir_to_quat(encounter_jump_quest_core_projectile__dir),
                              dir_to_quat(projectileToEnemyDir),
                              act.dt)
      encounter_jump_quest_core_projectile__dir = newRotation |> quat_get_forward()

      projectile_transform[3] = move_to(projectile_transform[3],
                                        projectile_transform[3] - projectileToEnemyDir,
                                        act.dt,
                                        encounter_jump_quest_core_projectile__chargingToRamSpeed)

      make_tm(newRotation, projectile_transform[3], projectile_transform)
      isTracking = true
    if !isTracking
      encounter_jump_quest_core_projectile__enemyEid = INVALID_ENTITY_ID
      encounter_jump_quest_core_projectile__state = int(EncounterJumpQuestCoreProjectileState.MOVE_TO_IDLE_ORBIT)
  elif state == int(EncounterJumpQuestCoreProjectileState.RAM_ENEMY)

    let progress = (distance(projectile_transform[3], encounter_jump_quest_core_projectile__ramSrcPosition) /
                    distance(encounter_jump_quest_core_projectile__ramDestPosition, encounter_jump_quest_core_projectile__ramSrcPosition))

    let newPos = move_to(projectile_transform[3],
                         encounter_jump_quest_core_projectile__ramDestPosition,
                         act.dt,
                         lerp(encounter_jump_quest_core_projectile__ramSpeed.x, encounter_jump_quest_core_projectile__ramSpeed.y, progress))

    let deltaDistance = newPos - projectile_transform[3]
    let deltaDistanceLen = length(newPos - projectile_transform[3])
    if deltaDistanceLen > 1e-6
      let moveDir = deltaDistance / deltaDistanceLen

      using() <| $(var intersections : IntersectedEntities)
        var t = deltaDistanceLen

        var norm : float3

        var collided = false
        if traceray_normalized(projectile_transform[3], moveDir, t, norm, ETF_RI | ETF_LMESH)
          collided = true

        trace_entities_in_grid(ecs_hash("humans"),
                              projectile_transform[3],
                              moveDir, t, projectile_eid, intersections, SortIntersections.NO)

        for isect in intersections
          query(isect.eid) <| $ [es(REQUIRE=ai_target)] ()
            let damageDesc = DamageDesc(DamageType.DM_MELEE, rnd_float(encounter_jump_quest_core_projectile__damageRng), isect.pos)
            damage_entity(isect.eid, projectile_eid, damageDesc)
            sendEvent(isect.eid, CmdPushPhys(vel = moveDir * rnd_float(encounter_jump_quest_core_projectile__pushPowerRng), push_immunity = 0.0))
            collided = true
            encounter_jump_quest_core_projectile__ramDestPosition = isect.pos
        if collided
          encounter_jump_quest_core_projectile__state = int(EncounterJumpQuestCoreProjectileState.RAM_BOUNCE)
          return


    projectile_transform[3] = newPos
    if distance_sq(projectile_transform[3], encounter_jump_quest_core_projectile__ramDestPosition) < 1e-3
      encounter_jump_quest_core_projectile__state = int(EncounterJumpQuestCoreProjectileState.RAM_BOUNCE)
  elif state == int(EncounterJumpQuestCoreProjectileState.RAM_BOUNCE)
    let ramBouncePosition = lerp(encounter_jump_quest_core_projectile__ramSrcPosition,
                                 encounter_jump_quest_core_projectile__ramDestPosition,
                                 float3(0.66))
    projectile_transform[3] = move_to(projectile_transform[3],
                                      ramBouncePosition,
                                      act.dt,
                                      encounter_jump_quest_core_projectile__ramBounceSpeed)
    if distance_sq(projectile_transform[3], ramBouncePosition) < 1e-3
      encounter_jump_quest_core_projectile__state = int(EncounterJumpQuestCoreProjectileState.TRACKING_ENEMY)


[es(tag=server, track=encounter_jump_quest_core_projectile__state)]
def encounter_jump_quest_core_projectile_state_track(evt : Event;
                                                     transform : float3x4;
                                                     encounter_jump_quest_core_projectile__state : int;
                                                     encounter_jump_quest_core_projectile__trackingEnemyAttackTimeRng : float2;
                                                     var encounter_jump_quest_core_projectile__trackingEnemyPosition : float3&;
                                                     var encounter_jump_quest_core_projectile__trackingEnemyAttackAt : float&;
                                                     var encounter_jump_quest_core_projectile__selectTrackingEnemyPositionAt : float&;
                                                     var encounter_jump_quest_core_projectile__stateProgressTimer : float&;
                                                     var encounter_jump_quest_core_projectile__enemyEid : EntityId&)
  encounter_jump_quest_core_projectile__stateProgressTimer = 0.0
  if encounter_jump_quest_core_projectile__state == int(EncounterJumpQuestCoreProjectileState.IDLE)
    encounter_jump_quest_core_projectile__enemyEid = INVALID_ENTITY_ID
  elif encounter_jump_quest_core_projectile__state == int(EncounterJumpQuestCoreProjectileState.TRACKING_ENEMY)
    encounter_jump_quest_core_projectile__trackingEnemyPosition = transform[3]
    encounter_jump_quest_core_projectile__selectTrackingEnemyPositionAt = get_sync_time()
    encounter_jump_quest_core_projectile__trackingEnemyAttackAt = get_sync_time() + rnd_float(encounter_jump_quest_core_projectile__trackingEnemyAttackTimeRng)


[es(tag=server)]
def encounter_jump_quest_core_projectile_hit(evt : EventOnProjectileHit;
                                             var transform aka projectile_transform : float3x4;
                                             var encounter_jump_quest_core_projectile__state : int&;
                                             var encounter_jump_quest_core_projectile__dir : float3&)
  if encounter_jump_quest_core_projectile__state == int(EncounterJumpQuestCoreProjectileState.CHARGING_TO_RAM)
    encounter_jump_quest_core_projectile__state = int(EncounterJumpQuestCoreProjectileState.TRACKING_ENEMY)

  var shakeNoiseQuat : quat
  let angle = float2(0.03, 0.07)
  euler_to_quat(rnd_float(angle) * rnd_sign(),
                rnd_float(angle) * rnd_sign(),
                rnd_float(angle) * rnd_sign(),
                shakeNoiseQuat)
  let newRotation = shakeNoiseQuat * dir_to_quat(encounter_jump_quest_core_projectile__dir)
  encounter_jump_quest_core_projectile__dir = newRotation |> quat_get_forward()

  make_tm(newRotation, projectile_transform[3], projectile_transform)


[es(tag=server)]
def encounter_jump_quest_core_melee_action(evt : EventMeleeAction; gun__owner : EntityId)
  volume_get_props(evt.propsId) <| $(volProps)
    melee_get_props(evt.propsId) <| $(meleeProps)
      using() <| $(var intersections : IntersectedEntities)
        query_volume_intersections(ecs_hash("am_cores"), evt.actorEid, melee_props_get_node_name(meleeProps),
                                   volProps, intersections, SortIntersections.NO)

        let damage = meleeProps.hitPower
        for it in intersections
          query(it.eid) <| $ [es(REQUIRE=encounter_jump_quest_core)] (encounter_jump_quest_core__meleeDamageMult : float = 2.0)
            let dmDesc = DamageDesc(DamageType.DM_MELEE, damage * encounter_jump_quest_core__meleeDamageMult, it.pos)
            apply_damage(it.eid, gun__owner, dmDesc)