options always_export_initializer = true
require ecs
require ecs.safe
require ecs.common
require app
require net
require math
require math.base
require math.random
require game.es.level_common
require game.events.events
require game.es.damage_systems.damage_model_common
require game.es.bees_swarm_common
require DagorRandom
require DagorMath
require Dacoll
require BehNodes
require DagorSystem
require DagorDataBlock
require DngDm
require GridCollision
require Grid
require danetlibs.swarm.main.swarm_events
require game.events.events_active_matter
require game.utils.net_utils
require game.es.pain_common
require DagorMathUtils


[beh_node(name="flyingSwarmSetWaypointTarget")]
class FlyingSwarmSetWaypointTarget : BehNodeAdapter

  def override loadFromBlk(var data : DataBlock)
    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(patroller__currentWaypoint, swarm_cluster__target, swarm_cluster__targetPos))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> FlyingSwarmSetWaypointTarget requires patroller.currentWaypoint, swarm_cluster.target, swarm_cluster.targetPos fields")

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (patroller__currentWaypoint : float3;
                                          am_habitat_swarm__minHeight : float;
                                          var swarm_cluster__target : EntityId&;
                                          var swarm_cluster__targetPos : float3&)
      swarm_cluster__target = INVALID_ENTITY_ID
      swarm_cluster__targetPos = patroller__currentWaypoint + float3(0.0, am_habitat_swarm__minHeight, 0.0)
      result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="flyingSwarmMoveToTarget")]
class FlyingSwarmMoveToTarget : BehNodeAdapter

  def override loadFromBlk(var data : DataBlock)
    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(swarm_cluster__radius, swarm_cluster__target, transform, swarm_cluster__targetPos,
                                      swarm_cluster__velocity, swarm_cluster__contactPoints, swarm_cluster__maxSpeed, swarm_cluster__acceleration))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> FlyingSwarmMoveToTarget requires swarm_cluster.radius, swarm_cluster.target, transform, swarm_cluster.targetPos, swarm_cluster.targetDistCheckTime, swarm_cluster.lastTargetDist, swarm_cluster.velocity, swarm_cluster.contactPoints, swarm_cluster.maxSpeed, swarm_cluster.acceleration fields")

  def override init()
    query(beh_tree_eid(owner)) <| $ [es] (swarm__moveSpeedAttack : float;
                                          swarm_attack__zoomHeightOffset : float;
                                          swarm_attack__zoomXYOffsetLen : float;
                                          swarm_attack__boomStage : bool;
                                          var swarm_attack__zoomOffset : float3&;
                                          var swarm__moveSpeed : float&)
      swarm__moveSpeed = swarm__moveSpeedAttack
      if !swarm_attack__boomStage
        let ang = rnd_float(0.0, TWOPI)
        swarm_attack__zoomOffset = (float3(cos(ang), 0.0, sin(ang)) * swarm_attack__zoomXYOffsetLen
                                  + float3(0.0, swarm_attack__zoomHeightOffset, 0.0))
      else
        send_net_event(beh_tree_eid(owner), CmdSetBoidsStamina())

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (swarm_cluster__radius : float;
                                          var swarm_cluster__target : EntityId&;
                                          var transform : float3x4&;
                                          var swarm_cluster__targetPos : float3&;
                                          var swarm_cluster__velocity : float3&;
                                          var swarm_cluster__contactPoints : Point4List&;
                                          var swarm_attack__boomStage : bool&;
                                          var swarm_attack__zoomPos : float3&;
                                          var swarm_attack__zoomOffset : float3&;
                                          swarm_attack__boomOffset : float3;
                                          swarm_attack__zoomHeightOffset : float;
                                          swarm_attack__zoomXYOffsetLen : float;
                                          swarm_cluster__visibilityRange : float;
                                          swarm_cluster__hivePos = float3();
                                          swarm_cluster__maxSpeed : float = 10.0;
                                          swarm_cluster__acceleration : float = 1.0)
      query(swarm_cluster__target) <| $ [es] (transform : float3x4; use_object__offset = float3())
        swarm_cluster__targetPos = transform * use_object__offset

      var finalTargetPos = float3()
      if swarm_attack__boomStage
        let fromZoomDir = swarm_cluster__targetPos + swarm_attack__boomOffset - swarm_attack__zoomPos
        var dir = normalize(fromZoomDir)
        var t = length(fromZoomDir)
        var norm : float3
        if traceray_normalized(swarm_attack__zoomPos, dir, t, norm)
          finalTargetPos = swarm_attack__zoomPos + dir * t + swarm_attack__boomOffset // block on path from zoom pos
        else
          let toTargetDir = swarm_cluster__targetPos + swarm_attack__boomOffset - transform[3]
          dir = normalize(toTargetDir)
          t = length(toTargetDir)
          if traceray_normalized(transform[3], dir, t, norm)
            finalTargetPos = transform[3] + dir * t + swarm_attack__boomOffset // block on path from current pos
          else
            finalTargetPos = swarm_cluster__targetPos + swarm_attack__boomOffset // no blocks
      else
        finalTargetPos = swarm_cluster__targetPos + swarm_attack__zoomOffset // offset for swarming target's overhead
      if (
        (length_sq(swarm_cluster__hivePos) > 0.f && distance_sq(swarm_cluster__targetPos, swarm_cluster__hivePos) > square(swarm_cluster__visibilityRange))
        || level_common::is_pos_indoor(swarm_cluster__targetPos, 5.0)
      )
        query(swarm_cluster__target) <| $ [es] (var targetUnreachable : bool&)
          targetUnreachable = true
        swarm_cluster__target = INVALID_ENTITY_ID
        return

      let targetDir = finalTargetPos - transform[3]
      let wishVel = targetDir * swarm_cluster__acceleration
      var accel = wishVel - swarm_cluster__velocity
      let accelLength = length(accel)
      if accelLength > swarm_cluster__acceleration
        accel *= swarm_cluster__acceleration / accelLength
      let curSpd = length(swarm_cluster__velocity)
      let flyingDir = curSpd > 0f ? normalize(swarm_cluster__velocity) : float3(0f, -1f, 0f)

      var norm : float3
      var dirT = curSpd * 5.0
      if traceray_normalized(transform[3], flyingDir, dirT, norm)
        accel.y += 5.0 * safediv(curSpd, dirT)

      let numContactPoints = float(length(swarm_cluster__contactPoints))
      for pt in swarm_cluster__contactPoints
        let point = float3(pt.x, pt.y, pt.z)
        let dir = transform[3] - point
        let len = length(dir)
        let force = (len == 0.0 || numContactPoints == 0.0
          ? float3()
          : (dir / len) * (swarm_cluster__radius / (len * numContactPoints)))
        accel += force // mass is 1 for this calc

      let clampedDt = min(1.f, dt)
      transform[3] += swarm_cluster__velocity * clampedDt + accel * clampedDt * clampedDt * 0.5
      swarm_cluster__velocity += accel * clampedDt
      let speed = length(swarm_cluster__velocity)
      if speed > swarm_cluster__maxSpeed
        swarm_cluster__velocity *= swarm_cluster__maxSpeed / speed

      let curTime = get_sync_time()
      for i, pt in iter_range(swarm_cluster__contactPoints), swarm_cluster__contactPoints
        if pt.w + 1.0 < curTime
          erase(swarm_cluster__contactPoints, i)
          break
      let traceDir = normalize(float3(gsrnd(), gsrnd(), gsrnd()))
      var t = swarm_cluster__radius * 2.0
      if traceray_normalized(transform[3], traceDir, t, norm)
        let pos = transform[3] + traceDir * t
        push(swarm_cluster__contactPoints, float4(pos.x, pos.y, pos.z, curTime))
        if length(swarm_cluster__contactPoints) > 10
          erase(swarm_cluster__contactPoints, 0)

      let distanceToTarget = length_sq(transform[3] - finalTargetPos)
      if distanceToTarget < square(1.0)
        result = EBehResult.ER_SUCCESS
        if !swarm_attack__boomStage
          // end zoom stage
          swarm_attack__zoomPos = finalTargetPos
          swarm_cluster__velocity = normalize(swarm_cluster__targetPos - transform[3])
          send_net_event(beh_tree_eid(owner), CmdSetBoidsStamina())
        else
          // end boom stage
          let ang = rnd_float(0.0, TWOPI)
          swarm_attack__zoomOffset = (float3(cos(ang), 0.0, sin(ang)) * swarm_attack__zoomXYOffsetLen
                                    + float3(0.0, swarm_attack__zoomHeightOffset, 0.0))
        swarm_attack__boomStage = !swarm_attack__boomStage
      else
        result = EBehResult.ER_RUNNING
    return result

  def override exit()
    query(beh_tree_eid(owner)) <| $ [es] (swarm__moveSpeedNormal : float;
                                          var swarm__moveSpeed : float&)
      swarm__moveSpeed = swarm__moveSpeedNormal


[beh_node(name="flyingSwarmFindLeadingSwarm")]
class FlyingSwarmFindLeadingSwarm : BehNodeAdapter

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4;
                                          swarm_cluster__target aka current_swarm_cluster__target : EntityId;
                                          am_bees_leader__searchRadius : float;
                                          am_bees_leader__isFollowed : bool;
                                          var swarm_cluster__targetPos : float3&;
                                          var am_bees_leader__leaderSwarmEid : EntityId&)
      if am_bees_leader__isFollowed
        return
      // check old leader
      query(am_bees_leader__leaderSwarmEid) <| $ [es] (swarm_cluster__target aka leader_swarm_cluster__target : EntityId;
                                                       am_bees_leader__positionHistory : float3;
                                                       var am_bees_leader__isFollowed : bool&)
        if current_swarm_cluster__target == leader_swarm_cluster__target
          swarm_cluster__targetPos = am_bees_leader__positionHistory
          result = EBehResult.ER_SUCCESS
        else
          am_bees_leader__isFollowed = false
      if result == EBehResult.ER_SUCCESS
        return
      let leaderFound = find_query() <| $ [es] (eid : EntityId;
                                                am_bees_leader__positionHistory : float3;
                                                swarm_cluster__target aka leader_swarm_cluster__target : EntityId;
                                                var am_bees_leader__isFollowed : bool&)
        if (!am_bees_leader__isFollowed
          && current_swarm_cluster__target == leader_swarm_cluster__target
          && beh_tree_eid(owner) != eid
          && distance_sq(am_bees_leader__positionHistory, transform[3]) < square(am_bees_leader__searchRadius))
          am_bees_leader__isFollowed = true
          am_bees_leader__leaderSwarmEid = eid
          swarm_cluster__targetPos = am_bees_leader__positionHistory
          return true
        return false
      result = leaderFound ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED
    return result


[beh_node(name="flyingSwarmLeaderIsNear")]
class FlyingSwarmLeaderIsNear : BehNodeAdapter
  nearDistance : float

  def override loadFromBlk(var data : DataBlock)
    nearDistance = square(data |> datablock_getReal("nearDistance", 1.0))

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (am_bees_leader__leaderSwarmEid : EntityId;
                                          transform : float3x4)
      if am_bees_leader__leaderSwarmEid == INVALID_ENTITY_ID
        return

      let swarmPos = transform[3]
      query(am_bees_leader__leaderSwarmEid) <| $ [es] (transform aka leader_transform : float3x4)
        if distance_sq(swarmPos, leader_transform[3]) < square(nearDistance)
          result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="flyingSwarmFindDanger")]
class FlyingSwarmFindDanger : BehNodeAdapter
  searchRange : float

  def override loadFromBlk(var data : DataBlock)
    searchRange = data |> datablock_getReal("searchRange", 10.0)
    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(transform, swarm_cluster__visibilityRange, swarm_cluster__target))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> FlyingSwarmFindDanger requires transform, swarm_cluster.visibilityRange, swarm_cluster.target fields")

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (transform : float3x4;
                                          swarm_cluster__visibilityRange : float;
                                          swarm_cluster__hivePos : float3;
                                          var swarm_cluster__target : EntityId&;
                                          var swarm_cluster__targetPos : float3&;
                                          var swarm__hitTargets : Array&)
      let swarmClusterPos = transform[3]
      var alreadyHaveTarget = false
      query(swarm_cluster__target) <| $ [es] (isAlive : bool; transform : float3x4)
        let isHide = level_common::is_pos_indoor(transform[3], 5.0)
        if (!isHide && isAlive && length_sq(transform[3] - swarmClusterPos) < square(searchRange)
          && length_sq(x0z(transform[3] - swarm_cluster__hivePos)) < square(swarm_cluster__visibilityRange))
          alreadyHaveTarget = true
      if alreadyHaveTarget
        result = EBehResult.ER_SUCCESS
        return

      if length(swarm__hitTargets) == 0
        swarm_cluster__target = INVALID_ENTITY_ID
        swarm_cluster__targetPos = float3()
        return

      var visibleTargets : array<EntityId>
      for it in swarm__hitTargets
        let data = it as Object
        if data?.visible ?? false
          let victimEid = data?.eid ?? INVALID_ENTITY_ID
          visibleTargets |> push(victimEid)

      if visibleTargets |> empty()
        swarm_cluster__target = INVALID_ENTITY_ID
        swarm_cluster__targetPos = float3()
        return

      swarm_cluster__target = visibleTargets[grnd() % length(visibleTargets)]
      query(swarm_cluster__target) <| $ [es] (transform : float3x4)
        swarm_cluster__targetPos = transform[3]
      result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="flyingSwarmSetTargetPosFromTarget")]
class FlyingSwarmSetTargetPosFromTarget : BehNodeAdapter
  minHeightFromTarget : float

  def override loadFromBlk(var data : DataBlock)
    minHeightFromTarget = data |> datablock_getReal("minHeightFromTarget", 0.0)

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (swarm_cluster__target : EntityId;
                                          var swarm_cluster__targetPos : float3&)
      query(swarm_cluster__target) <| $ [es] (transform : float3x4)
        swarm_cluster__targetPos = transform[3] + float3(0.0, minHeightFromTarget, 0.0)
        result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="flyingSwarmMoveToTargetSimple")]
class FlyingSwarmMoveToTargetSimple : BehNodeAdapter
  overrideMinHeight : float
  setAttackState : bool
  stopDistanceSq : float
  updateTargetPos : bool

  def override loadFromBlk(var data : DataBlock)
    overrideMinHeight = data |> datablock_getReal("minHeight", VERY_BIG_NUMBER)
    setAttackState = data |> datablock_getBool("setAttackState", true)
    updateTargetPos = data |> datablock_getBool("updateTargetPos", false)
    stopDistanceSq = square(data |> datablock_getReal("stopDistance", 1.0))
    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(transform, swarm_cluster__targetPos, swarm_cluster__maxSpeed))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> FlyingSwarmMoveToTargetSimple requires transform, swarm_cluster.targetPos, swarm_cluster.maxSpeed fields")

  def override init()
    query(beh_tree_eid(owner)) <| $ [es] (swarm__moveSpeedAttack : float;
                                          var swarm__moveSpeed : float&)
      if setAttackState
        swarm__moveSpeed = swarm__moveSpeedAttack
        send_net_event(beh_tree_eid(owner), CmdSetBoidsStamina())

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (var transform : float3x4&;
                                          var swarm_cluster__targetPos : float3&;
                                          swarm_cluster__maxSpeed : float = 10.0;
                                          am_habitat_swarm__minHeight : float = 0.0)
      let minHeight = overrideMinHeight != VERY_BIG_NUMBER ? overrideMinHeight : am_habitat_swarm__minHeight
      let flyPos = float3(swarm_cluster__targetPos.x, max(minHeight, swarm_cluster__targetPos.y), swarm_cluster__targetPos.z)
      if updateTargetPos
        swarm_cluster__targetPos = flyPos
      let targetDir = flyPos - transform[3]
      let curSpd = swarm_cluster__maxSpeed
      var flyingDir = normalize(targetDir)

      var norm : float3
      var dirT = curSpd * 5.0
      if traceray_normalized(transform[3], flyingDir, dirT, norm)
        var a = transform[3] + flyingDir * dirT
        dirT = 30.0
        a.y += dirT
        traceray_normalized(a, float3(0.0, -1.0, 0.0), dirT, norm)
        a.y -= dirT
        a.y = max(a.y, minHeight)
        let newDir = a - transform[3]
        flyingDir = normalize(newDir)

      transform[3] += flyingDir * curSpd * dt

      let distanceToTargetSq = length_sq(transform[3] - flyPos)
      if distanceToTargetSq < stopDistanceSq
        result = EBehResult.ER_SUCCESS
      else
        result = EBehResult.ER_RUNNING
    return result

  def override exit()
    query(beh_tree_eid(owner)) <| $ [es] (swarm__moveSpeedNormal : float;
                                          var swarm__moveSpeed : float&)
      if setAttackState
        swarm__moveSpeed = swarm__moveSpeedNormal


[beh_node(name="flyingSwarmDamageInArea")]
class FlyingSwarmDamageInArea : BehNodeAdapter

  def override loadFromBlk(var data : DataBlock)
    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(transform, swarm_cluster__damage, radius, swarm_cluster__timeToDamage))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> FlyingSwarmDamageInArea requires transform, swarm_cluster.damage, radius, swarm_cluster.timeToDamage fields")

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    let swarmEid = beh_tree_eid(owner)
    query(swarmEid) <| $ [es] (transform : float3x4;
                               swarm_cluster__damage : float;
                               swarm_cluster__attackRadius : float;
                               var swarm_cluster__timeToDamage : float&;
                               swarm_cluster__poisonAttack = false;
                               swarm_cluster__attackProbability = 1.0;
                               swarm_cluster__attackAddTrauma = .0;
                               swarm_cluster__attakMaxTrauma = .0;
                               swarm_cluster__damagePeriod = float2(1, 1);
                               swarm_cluster__poisonDuration : float = 10.0;
                               swarm__hitTargets : Array const?;
                               swarm__damageZoneType = int(DamageZoneType.SPHERE))
      result = EBehResult.ER_RUNNING
      swarm_cluster__timeToDamage -= dt
      if swarm_cluster__timeToDamage > 0.0
        return
      swarm_cluster__timeToDamage = rnd_float(swarm_cluster__damagePeriod)

      let swarmClusterPos = transform[3]
      var targets : array<EntityId>
      let searchBoxSize = float3(swarm_cluster__attackRadius, swarm_cluster__attackRadius * 2.0, swarm_cluster__attackRadius)
      let searchBox = BBox3(swarmClusterPos - searchBoxSize, swarmClusterPos + searchBoxSize)
      for_each_entity_in_grid(ecs_hash("humans"), searchBox, GridEntCheck.POS) <| $(itEid : EntityId)
        query(itEid) <| $ [es(REQUIRE=human, REQUIRE_NOT=deadEntity)] (eid : EntityId;
                                                                       transform : float3x4;
                                                                       human_net_phys__isUnderwater : bool = false)
          if human_net_phys__isUnderwater
            return
          var dir = transform[3] - swarmClusterPos
          if swarm__damageZoneType == int(DamageZoneType.CYLINDER)
            dir.y = 0.0
          if length_sq(dir) > square(swarm_cluster__attackRadius)
            return
          if !level_common::is_pos_indoor(transform[3], 5.0)
            if swarm__hitTargets != null
              var isTargetVisible = false
              for target in *swarm__hitTargets
                let targetObj = target as Object
                let targetEid = targetObj?.eid ?? INVALID_ENTITY_ID
                if targetEid == itEid
                  isTargetVisible = targetObj?.visible ?? false
                  break
              if !isTargetVisible
                return
            targets |> push(eid)

      if length(targets) > 0
        for target in targets
          if swarm_cluster__attackProbability == 1.0 || swarm_cluster__attackProbability > gfrnd()
            if swarm_cluster__poisonAttack
              let isAffected = find_query() <| $ [es(REQUIRE=game_effect__poisonAffect)] (game_effect__attachedTo : EntityId;
                                                                                          game_effect__timeToDestroy : float;
                                                                                          var game_effect__destroyAt : float&)
                if game_effect__attachedTo == target
                  game_effect__destroyAt = get_sync_time() + game_effect__timeToDestroy
                  return true
                return false
              if !isAffected
                var affect_template = "poison_affect"
                if !has_pain_immunity(target)
                  affect_template = add_sub_template_name(affect_template, "poison_visual_affect")
                createEntity(affect_template) <| $(var initList)
                  initList |> set("game_effect__ownerEid", swarmEid)
                  initList |> set("game_effect__attachedTo", target)
                  initList |> set("game_effect__damageTargetDeltaHp", swarm_cluster__damage)
                  initList |> set("game_effect__damageType", int(DamageType.DM_GAS))
                  initList |> set("game_effect__timeToDestroy", swarm_cluster__poisonDuration)
              send_net_event(target, EventBeesLeftStain(value = 0.1), possessed_and_spectated(target))
            else
              query(target) <| $ [es] (human_damage_model__parts : Object)
                let randomIdx = rnd_int(0, length(human_damage_model__parts) - 1)
                var i = 0
                for_each_part_in_damage_model(human_damage_model__parts) <| $(bodypart : BodyPartV2)
                  if i++ != randomIdx
                    return true
                  if length(bodypart.nodeIds) > 0
                    human_damage_model_damage_entity(target, swarmEid, swarm_cluster__damage, bodypart.nodeIds[0], DamageType.DM_MELEE)
                  return false

              if swarm_cluster__attackAddTrauma > 0.0 && !has_pain_immunity(target)
                send_net_event(target, CmdCauseTrauma(addTrauma = swarm_cluster__attackAddTrauma, maxTrauma = swarm_cluster__attakMaxTrauma),
                    possessed_and_spectated(target))
      else
        result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="returnToHive")]
class ReturnToHive : BehNodeAdapter

  def override loadFromBlk(var data : DataBlock)
    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(swarm_cluster__hivePos))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> ReturnToHive requires swarm_cluster__hivePos field")

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (swarm_cluster__hivePos : float3;
                                          swarm__orbitRadRng : float2;
                                          swarm__orbitOffset : float3;
                                          swarm_cluster__maxSpeed : float;
                                          var transform : float3x4&)
      let centerPos = swarm_cluster__hivePos + swarm__orbitOffset
      let toSwarmDir = x0z(centerPos - transform[3])
      let targetPos = centerPos + normalize(toSwarmDir) * swarm__orbitRadRng.y
      let flyingVel = normalize(targetPos - transform[3]) * swarm_cluster__maxSpeed
      transform[3] += flyingVel * dt
      if length(transform[3] - swarm_cluster__hivePos) < swarm__orbitRadRng.y
        result = EBehResult.ER_SUCCESS
      else
        result = EBehResult.ER_RUNNING
    return result


[beh_node(name="swarmInvesigateSurroundings")]
class SwarmInvesigateSurroundings : BehNodeAdapter

  def override init()
    query(beh_tree_eid(owner)) <| $ [es] (swarm__orbitRotSpdRng : float2;
                                          swarm__orbitRadRng : float2;
                                          var swarm__orbitCurRad : float&;
                                          var swarm__orbitCurRotSpd : float&)
      swarm__orbitCurRad = rnd_float(swarm__orbitRadRng.x, swarm__orbitRadRng.y)
      swarm__orbitCurRotSpd = rnd_float(swarm__orbitRotSpdRng.x, swarm__orbitRotSpdRng.y)

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (swarm_cluster__hivePos : float3;
                                          swarm__orbitCurRad : float;
                                          swarm__orbitCurRotSpd : float;
                                          swarm__orbitOffset : float3;
                                          var swarm__orbitAngle : float&;
                                          var transform : float3x4&)
      let centerPos = swarm_cluster__hivePos
      swarm__orbitAngle += dt * swarm__orbitCurRotSpd
      if swarm__orbitAngle > TWOPI
        swarm__orbitAngle -= TWOPI
      var sine, cosine : float
      sincos(swarm__orbitAngle, sine, cosine)
      let orbitOffset = swarm__orbitCurRad * float3(sine, 0.0, cosine)
      transform[3] = centerPos + orbitOffset + swarm__orbitOffset
      result = EBehResult.ER_RUNNING
    return result


[beh_node(name="flyingSwarmRecoveryPopulation")]
class FlyingSwarmRecoveryPopulation : BehNodeAdapter

  def override loadFromBlk(var data : DataBlock)
    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(swarm_cluster__maxCount, swarm_cluster__spawnCountRng, swarm_cluster__spawnTimeRng,
                                      swarm_cluster__serverCount, swarm_cluster__nextBoidsSpawnTime))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> FlyingSwarmRecoveryPopulation requires swarm_cluster.maxCount, swarm_cluster.spawnCountRng, swarm_cluster.spawnTimeRng, count, swarm_cluster.nextBoidsSpawnTime fields")

  def override update(dt : float) : EBehResult
    var result = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (eid : EntityId;
                                          swarm_cluster__maxCount : int;
                                          swarm_cluster__spawnCountRng : int2;
                                          swarm_cluster__spawnTimeRng : float2;
                                          swarm_cluster__spawnMult : float;
                                          transform : float3x4;
                                          var position : float3?;
                                          var swarm_cluster__serverCount : int&;
                                          var swarm_cluster__nextBoidsSpawnTime : float&)
      if swarm_cluster__serverCount == swarm_cluster__maxCount
        return

      if swarm_cluster__spawnMult <= 0.0
        return

      let curTime = get_sync_time()
      if swarm_cluster__nextBoidsSpawnTime == 0.0
        let spawnTimeRng = swarm_cluster__spawnTimeRng
        swarm_cluster__nextBoidsSpawnTime = curTime + rnd_float(spawnTimeRng.x, spawnTimeRng.y)

      if curTime < swarm_cluster__nextBoidsSpawnTime
        result = EBehResult.ER_RUNNING
        return

      swarm_cluster__nextBoidsSpawnTime = 0.0
      var boidsToBorn = int(float(rnd_int(swarm_cluster__spawnCountRng.x, swarm_cluster__spawnCountRng.y)) * swarm_cluster__spawnMult)
      boidsToBorn = min(boidsToBorn, swarm_cluster__maxCount - swarm_cluster__serverCount)
      if position != null
        *position = transform[3]
      swarm_cluster__serverCount += boidsToBorn
      print("flying swarm: cluster {eid} create new boids count {boidsToBorn}, now count {swarm_cluster__serverCount}")
      result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="flyingSwarmGetAttractionPosition")]
class FlyingSwarmGetAttractionPosition : BehNodeAdapter

  def override loadFromBlk(var data : DataBlock)
    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(attract_point__eid, attract_point__targetPos, swarm_cluster__targetPos))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> FlyingSwarmGetAttractionPosition requires attract_point.eid, attract_point.targetPos and swarm_cluster.targetPos fields")

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (attract_point__eid : EntityId;
                                          attract_point__targetPos : float3;
                                          var swarm_cluster__targetPos : float3&)
      if attract_point__eid != INVALID_ENTITY_ID
        swarm_cluster__targetPos = attract_point__targetPos
        res = EBehResult.ER_SUCCESS
    return res


[beh_node(name="flyingSwarmGetHivePosition")]
class FlyingSwarmGetHivePosition : BehNodeAdapter

  def override loadFromBlk(var data : DataBlock)
    let eid = beh_tree_eid(owner)
    if !(query(eid) <| $ [es(REQUIRE=(transform, swarm_cluster__hivePos))] {})
      logerr("{eid}: <{getEntityTemplateName(eid)}> FlyingSwarmPatrollingHive requires transform, swarm_cluster.hivePos and swarm_cluster.targetPos fields")

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (swarm_cluster__hivePos : float3;
                                          var swarm_cluster__targetPos : float3&;
                                          swarm_cluster__aggressionLevel = 0f)
      let curTime = get_sync_time()
      let heightRange = float2(0f, 10f)
      let radRange = float2(0f, 10f)
      let height = lerp(heightRange.x, heightRange.y, swarm_cluster__aggressionLevel) * (sin(curTime / 5f) + 1f) / 2f
      let rad = cvt(height, heightRange.x, heightRange.y, radRange.x, radRange.y)
      var x, z : float
      sincos(curTime / 5f, z, x)
      swarm_cluster__targetPos = swarm_cluster__hivePos + float3(rad * x, height, rad * z)
      res = EBehResult.ER_SUCCESS
    return res

// CORPSE ATTACHED SWARM

[beh_node(name="corpseAttachedSwarmApproachCorpse")]
class CorpseAttachedSwarmApproachCorpse : BehNodeAdapter
  startPosition : float3
  endPosition : float3
  startTime : float
  flyTime : float
  swirlRadius : float = 20.0
  swirlPeriod : float = 8.0
  speedMultiplier : float = 0.3

  def override init()
    startTime = get_sync_time()
    query(beh_tree_eid(owner)) <| $ [es] (corpse_attached_swarm__corpseEid : EntityId; transform aka swarm_transform : float3x4; swarm__moveSpeed : float)
      query(corpse_attached_swarm__corpseEid) <| $ [es] (transform aka corpse_transform : float3x4)
        startPosition = swarm_transform[3]
        endPosition = corpse_transform[3]
        flyTime = distance(endPosition, startPosition) / swarm__moveSpeed / speedMultiplier

  def override update(dt : float) : EBehResult
    let curTime = get_sync_time()
    var result = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (var transform : float3x4&; var swarm_cluster__targetPos : float3&)
      if curTime >= startTime + flyTime
        transform[3] = endPosition
        swarm_cluster__targetPos = endPosition
        result = EBehResult.ER_SUCCESS
        return

      result = EBehResult.ER_RUNNING
      let moveDirection = endPosition - startPosition
      let param = (curTime - startTime) / flyTime
      let basePosition = startPosition + moveDirection * param
      var s, c : float
      let normalizedDir = normalize(moveDirection)
      let up = get_some_normal(normalizedDir)
      let right = cross(up, normalizedDir)
      let curRadius = swirlRadius * (1.0 - param)
      sincos((curTime - startTime) / swirlPeriod * 2.0 * PI, s, c)
      transform[3] = basePosition + right * curRadius * c + up * curRadius * s
      swarm_cluster__targetPos = transform[3]
    return result


[beh_node(name="corpseAttachedSwarmDoesCorpseExist")]
class CorpseAttachedSwarmUpdateCorpsePosition : BehNodeAdapter
  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (corpse_attached_swarm__corpseEid : EntityId)
      res = doesEntityExist(corpse_attached_swarm__corpseEid) ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED
    return res


def try_extract_am_from_monster(phys_obj : EntityId; var am_storage__value : int&; var res : EBehResult&)
  find_query() <| $ [es] (eid : EntityId;
                          am_pile_attached_to_corpse__corpseEid : EntityId;
                          var item__count : int&)
    if am_pile_attached_to_corpse__corpseEid != phys_obj
      return false

    // check before decrement as someone else could have extracted last AM from corpse
    if item__count <= 0
      res = EBehResult.ER_SUCCESS
    else
      item__count -= 1
      am_storage__value += 1
      res = EBehResult.ER_RUNNING
      if item__count == 0
        res = EBehResult.ER_SUCCESS
        destroyEntity(eid)
      print("[CorpseAttachedSwarmGatherAm] gathered 1 am from monster corpse <{phys_obj}>")
    return true


def try_extract_am_from_container_items(itemContainer : EidList; var swarm_am_storage__value : int&; var res : EBehResult&)
  find_index_if(each(itemContainer)) <| $(item_eid : EntityId)
    var foundAm = false
    query(item_eid) <| $ [es] (var am_storage__value : int&)
      if am_storage__value > 0
        am_storage__value -= 1
        swarm_am_storage__value += 1
        res = EBehResult.ER_RUNNING
        print("[CorpseAttachedSwarmGatherAm] gathered 1 am from container item {item_eid} ({getEntityTemplateName(item_eid)})")
        foundAm = true
    return foundAm


[beh_node(name="corpseAttachedSwarmGatherAm")]
class corpseAttachedSwarmGatherAm : BehNodeAdapter
  def override exit()
    query(beh_tree_eid(owner)) <| $ [es] (var corpse_attached_swarm__isGatheringAm : bool&)
      corpse_attached_swarm__isGatheringAm = false

  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (corpse_attached_swarm__corpseEid : EntityId;
                                          corpse_attached_swarm__amExtractionPeriod : float;
                                          am_storage__maxValue : int;
                                          var corpse_attached_swarm__isGatheringAm : bool&;
                                          var am_storage__value aka swarm_am_storage__value : int&;
                                          var corpse_attached_swarm__nextAmTickAt : float&)
      if am_storage__maxValue <= am_storage__value
        return
      let curTime = get_sync_time()
      if corpse_attached_swarm__nextAmTickAt > curTime
        res = EBehResult.ER_RUNNING
        return

      corpse_attached_swarm__nextAmTickAt = curTime + corpse_attached_swarm__amExtractionPeriod
      query(corpse_attached_swarm__corpseEid) <| $ [es] (ragdoll_phys_obj__physObjEid : EntityId)
        try_extract_am_from_monster(ragdoll_phys_obj__physObjEid, am_storage__value, res)
        if res != EBehResult.ER_FAILED
          return

        query(ragdoll_phys_obj__physObjEid) <| $ [es] (var am_storage__value aka corpse_am_storage__value : int&)
          if corpse_am_storage__value > 0
            corpse_am_storage__value -= 1
            swarm_am_storage__value += 1
            res = EBehResult.ER_RUNNING
            print("[CorpseAttachedSwarmGatherAm] gathered 1 am from {ragdoll_phys_obj__physObjEid} ({getEntityTemplateName(ragdoll_phys_obj__physObjEid)})")

      if res == EBehResult.ER_RUNNING
        corpse_attached_swarm__isGatheringAm = true

    return res


[beh_node(name="corpseAttachedSwarmEatCorpse")]
class CorpseAttachedSwarmEatCorpse : BehNodeAdapter
  oldStayTime : float
  oldRotSpeed : float

  def override init()
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (corpse_attached_swarm__corpseEid : EntityId;
                               var swarm__rotSpeed : float&;
                               var swarm__minStayTime : float&)
      oldStayTime = swarm__minStayTime
      oldRotSpeed = swarm__rotSpeed

      swarm__rotSpeed = max(7.0, swarm__rotSpeed)
      swarm__minStayTime = max(2.0, swarm__minStayTime)
      var querySuccess = false
      query(corpse_attached_swarm__corpseEid) <| $ [es] (var corpse_eaten_by_swarm__swarm : EntityId&)
        querySuccess = true
        corpse_eaten_by_swarm__swarm = ownerEid

      if !querySuccess
        addSubTemplate(corpse_attached_swarm__corpseEid, "corpse_eaten_by_swarm") <| $(i)
          set(i, "corpse_eaten_by_swarm__swarm", ownerEid)


  def override exit()
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (corpse_attached_swarm__corpseEid : EntityId;
                               var swarm__rotSpeed : float&;
                               var swarm__minStayTime : float&)
      swarm__rotSpeed = oldRotSpeed
      swarm__minStayTime = oldStayTime
      query(corpse_attached_swarm__corpseEid) <| $ [es] (var corpse_eaten_by_swarm__swarm : EntityId&)
        if corpse_eaten_by_swarm__swarm == ownerEid
          corpse_eaten_by_swarm__swarm = INVALID_ENTITY_ID


  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_RUNNING
    let ownerEid = beh_tree_eid(owner)
    query(ownerEid) <| $ [es] (corpse_attached_swarm__searchCooldownAfterEaten : float;
                               corpse_attached_swarm__gainAmPerCorpseEaten : int;
                               var transform aka swarm_transform : float3x4&;
                               var swarm_cluster__targetPos : float3&;
                               var am_storage__value : int&;
                               var corpse_attached_swarm__searchCooldownUntil : float&;
                               var corpse_attached_swarm__corpseEid : EntityId&)
      if !doesEntityExist(corpse_attached_swarm__corpseEid)
        print("[CorpseAttachedSwarmEatCorpse] <{ownerEid}> fail: <{corpse_attached_swarm__corpseEid}> doesn't exist")
        res = EBehResult.ER_FAILED
        return
      query(corpse_attached_swarm__corpseEid) <| $ [es] (var corpse_eaten_by_swarm__eatTimeLeft : float&;
                                                         corpse_eaten_by_swarm__swarm : EntityId;
                                                         transform aka corpse_transform : float3x4;
                                                         human_net_phys__isUnderwater : bool = false)
        if corpse_eaten_by_swarm__swarm != ownerEid
          print("[CorpseAttachedSwarmEatCorpse] <{ownerEid}> fail: <{corpse_attached_swarm__corpseEid}> eaten by another swarm {corpse_eaten_by_swarm__swarm}")
          res = EBehResult.ER_FAILED
          return
        swarm_transform[3] = corpse_transform[3]
        swarm_cluster__targetPos = corpse_transform[3]
        if human_net_phys__isUnderwater
          print("[CorpseAttachedSwarmEatCorpse] <{ownerEid}> fail: <{corpse_attached_swarm__corpseEid}> under water")
          res = EBehResult.ER_FAILED
          sendEvent(ownerEid, EventCorpseSwarmRepelled(repelPos = swarm_transform[3], repelDuration = 5.0))
          return

        corpse_eaten_by_swarm__eatTimeLeft -= dt
        if corpse_eaten_by_swarm__eatTimeLeft <= 0.0
          print("[CorpseAttachedSwarmEatCorpse] <{ownerEid}> success: <{corpse_attached_swarm__corpseEid}> eaten")
          res = EBehResult.ER_SUCCESS
          corpse_attached_swarm__searchCooldownUntil = corpse_attached_swarm__searchCooldownAfterEaten + get_sync_time()
          sendEvent(corpse_attached_swarm__corpseEid, EventCorpseEaten())
          corpse_attached_swarm__corpseEid = INVALID_ENTITY_ID
          am_storage__value += corpse_attached_swarm__gainAmPerCorpseEaten

    return res


[beh_node(name="corpseAttachedSwarmChooseRepelPosition")]
class CorpseAttachedSwarmChooseRepelPosition : BehNodeAdapter
  def override update(dt : float) : EBehResult
    var res = EBehResult.ER_FAILED
    query(beh_tree_eid(owner)) <| $ [es] (corpse_attached_swarm__detractPos : float3;
                                          transform : float3x4;
                                          var swarm_cluster__targetPos : float3&)
      let direction = transform[3] - corpse_attached_swarm__detractPos
      res = EBehResult.ER_SUCCESS
      if length_sq(direction) < 1.0
        // if swarm is very close to the detract pos, fly away randomly
        let offset = float3(rnd_float(-30.0, 30.0), 20.0, rnd_float(-30.0, 30.0))
        swarm_cluster__targetPos = transform[3] + offset
      else
        swarm_cluster__targetPos += normalize(direction) * 50.0
    return res
