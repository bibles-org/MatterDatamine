require ecs
require app
require DngNet
require math
require math.base
require math.linear
require game.events.events
require game.events.events_game
require Dacoll
require DagorMath
require DagorRandom
require DagorSystem
require AnimV20
require GeomNodeTree
require DagorMathUtils
require Ballistics
require DngHuman
require DngDm
require GamePhys
require game.events.events_active_matter
require game.utils.hero
require math.maybe_pos
require active_matter.game.es.liana_trap_common


let MIN_DST_SQ_WORTH_TRACING = 0.1

[es(tag=gameClient, track=liana_tentacle__attachNodeEid)]
def sync_tentacle_params(evt : Event;
                         eid, liana_tentacle__lianaEid, liana_tentacle__attachNodeEid : EntityId;
                         liana_tentacle__maxPoints : int;
                         var spline_gen_geometry__points : Point3List;
                         var spline_gen_geometry__request_active : bool&)
  spline_gen_geometry__request_active = true
  if liana_tentacle__attachNodeEid == INVALID_ENTITY_ID
    return
  var i = length(spline_gen_geometry__points)
  while i < liana_tentacle__maxPoints
    push(spline_gen_geometry__points, spline_gen_geometry__points[length(spline_gen_geometry__points) - 1])
    i++
  query(liana_tentacle__lianaEid) <| $ [es] (liana_trap__target : EntityId)
    if liana_trap__target == INVALID_ENTITY_ID
      logerr("Failed to attach tentacle on client - liana trap target is 0")
    query(liana_trap__target) <| $ [es] (animchar : AnimcharBaseComponent)
      assign_params_from_attach_node(eid, liana_tentacle__attachNodeEid, animchar)

[es(tag=server, on_appear)]
def liana_trap_created(evt : Event; eid : EntityId; var liana_trap__tentacles : EidList)
  push(liana_trap__tentacles, add_liana_tentacle(eid)) //To ensure there is at least one tentacle already created when someone walks into the trap

[es(tag=gameClient, on_appear)]
def liana_tentacle_created(evt : Event;
                           liana_tentacle__fromPos : float3;
                           liana_tentacle__maxPoints : int;
                           var spline_gen_geometry__points : Point3List)
  for _ in range(liana_tentacle__maxPoints)
    push(spline_gen_geometry__points, liana_tentacle__fromPos)


[es(tag=server)]
def liana_trap_enter(evt : EventZoneEnter; eid : EntityId; var liana_trap__target : EntityId&; liana_trap__catchChance : float = 1.0)
  if liana_trap__target != INVALID_ENTITY_ID || gfrnd() > liana_trap__catchChance
    return // ignore this one, we didn't trigger on it.
  query(evt.visitorEid) <| $ [es] (var liana_trap__eid : EntityId&;
                                   var liana__locoAcc : float3&;
                                   var liana__locoQuat : float4&)
    if liana_trap__eid == INVALID_ENTITY_ID
      liana_trap__target = evt.visitorEid
      liana_trap__eid = eid
      liana__locoAcc = float3()
      liana__locoQuat = float4(0.0, 0.0, 0.0, 1.0)

 /*
  General idea of getting out of liana's grip:
  As the player applies force and stretches tentacles their 'strain' rises and they become easier to break and don't pull as much.
  ...which allows to stretch them even more. This creates a positive feedback loop.
  New tentacles replace broken ones and decrease 'strain' once - when they appear. This creates a negative feedback loop.
  The player is stuck in the balance created by the two loops.
  But each broken tentacle also increases 'injury'. Even more if the tentacle has been shot.
  'Injury' increases cooldown between new tentacle spawns. Which ultimately allows the player to escape.
*/


[es(tag=server, REQUIRE=human_net_phys, after=net_phys_update_es)]
def liana_trap_update_server(info : CmdPostPhysUpdate;
                             animchar : AnimcharBaseComponent;
                             liana_trap__eid : EntityId)
  query(liana_trap__eid) <| $ [es] (transform : float3x4;
                                    liana_trap__maxActiveTentacles : int;
                                    liana_trap__maxCreatedTentacles : int;
                                    liana_trap__cooldown : float;
                                    liana_trap__maxDist : float;
                                    liana_trap__travelSpeed : float;
                                    liana_trap__tentaclesToLift : int;
                                    liana_trap__maxLiftHeight : float;
                                    liana_trap__breakChanceMultiplier : float;
                                    liana_trap__liftPointRadius : float;
                                    liana_trap__cooldownPerInjury : float;
                                    liana_trap__injuryPerBreak : float;
                                    liana_trap__velDot : float;

                                    liana_trap__damage : float;
                                    liana_trap__damageInterval : float;
                                    var liana_trap__nextDamageAt : float&;

                                    var liana_trap__moveToPos : float3&;
                                    var liana_trap__strain : float&;
                                    var liana_trap__injury : float&;
                                    var liana_trap__healedAt : float&;
                                    var liana_trap__lastDisplacement : float&;
                                    var liana_trap__addTentacleAt : float&;
                                    var liana_trap__breakCount : float&;
                                    var liana_trap__tentacles : EidList;
                                    var liana_trap__target : EntityId&)
    assume strain = liana_trap__strain
    assume injury = liana_trap__injury
    assume displacement = liana_trap__lastDisplacement
    let curTime = get_sync_time()

    //Add new tentacle?
    var numActiveTentacles = 0
    for tentacle_eid in liana_trap__tentacles
      query(tentacle_eid) <| $ [es] (liana_tentacle__attachNodeEid : EntityId)
        if liana_tentacle__attachNodeEid != INVALID_ENTITY_ID
          numActiveTentacles++
    if liana_trap__addTentacleAt < curTime
      let cd = liana_trap__cooldown + injury * liana_trap__cooldownPerInjury
      liana_trap__addTentacleAt = curTime + cd

      if numActiveTentacles < liana_trap__maxActiveTentacles
        //Pick existing unused tentacle
        var newTentacle = INVALID_ENTITY_ID
        for tentacle_eid in liana_trap__tentacles
          query(tentacle_eid) <| $ [es] (liana_tentacle__attachNodeEid : EntityId; liana_tentacle__aliveAt : float)
            if liana_tentacle__attachNodeEid == INVALID_ENTITY_ID && liana_tentacle__aliveAt <= curTime
              newTentacle = tentacle_eid
          if newTentacle != INVALID_ENTITY_ID
            break

        if newTentacle == INVALID_ENTITY_ID
          //Create new tentacle
          if length(liana_trap__tentacles) < liana_trap__maxCreatedTentacles
            push(liana_trap__tentacles, add_liana_tentacle(liana_trap__eid))
        elif set_tentacle_target(newTentacle, animchar, numActiveTentacles)
          numActiveTentacles++
          if numActiveTentacles == liana_trap__tentaclesToLift
            var axPos : float3
            sincos(gfrnd() * TWOPI, axPos.z, axPos.x)
            var relativePos = axPos * liana_trap__liftPointRadius
            relativePos.y = liana_trap__maxLiftHeight * (0.8 + gfrnd() * 0.2)
            liana_trap__moveToPos = transform[3] + relativePos
        else
          logerr("Failed to attach {numActiveTentacles}'th liana tentacle to <{getEntityTemplateName(liana_trap__target)}>")

      if numActiveTentacles < liana_trap__tentaclesToLift
        liana_trap__moveToPos = transform[3]

    //Update tentacle position and damage long tentacles
    liana_trap__breakCount = 0.0
    var hasDamageTentacle = false
    let canBreak = liana_trap__velDot < 0.0
    for tentacle_eid in liana_trap__tentacles
      query(tentacle_eid) <| $ [es] (liana_tentacle__nodeId : int;
                                     liana_tentacle__spawnedAt : float;
                                     liana_tentacle__dealsDamage : bool;
                                     liana_tentacle__verticalGrowTime : float;
                                     liana_tentacle__fromPos : float3;
                                     liana_tentacle__aliveAt : float;
                                     var liana_tentacle__isAttached : bool&;
                                     var liana_tentacle__toPos : float3&)
        if liana_tentacle__aliveAt > curTime || liana_tentacle__nodeId == -1
          return

        //Positioning
        let targetNodePos = geomtree_getNodeWpos(*animchar.nodeTree, liana_tentacle__nodeId)
        if liana_tentacle__isAttached
          hasDamageTentacle ||= liana_tentacle__dealsDamage
          liana_tentacle__toPos = targetNodePos
        else
          let verticalGrow = (curTime - liana_tentacle__spawnedAt) < liana_tentacle__verticalGrowTime
          let target = verticalGrow ? liana_tentacle__fromPos + float3(.0, 1000.0, .1) : targetNodePos
          let toTargetDir = normalize(target - liana_tentacle__toPos)
          liana_tentacle__toPos += toTargetDir * liana_trap__travelSpeed * info.dt
          if distance(liana_tentacle__toPos, targetNodePos) < liana_trap__travelSpeed * info.dt
            liana_tentacle__isAttached = true
            strain *= 0.75

        //Break because extreme tension or length
        let dst = distance(liana_tentacle__fromPos, targetNodePos)
        let breakChance = square(displacement * strain / liana_trap__maxDist) * info.dt * liana_trap__breakChanceMultiplier
        let breaks = liana_tentacle__isAttached && canBreak && gfrnd() < breakChance
        if dst > liana_trap__maxDist || breaks
          liana_trap__breakCount++
          injury += liana_trap__injuryPerBreak
          kill_liana_tentacle(tentacle_eid)
          return

    //Heal injury
    injury = max(0.0, injury - curTime + liana_trap__healedAt)
    liana_trap__healedAt = curTime

    //Lose target
    if numActiveTentacles == 0
      query(liana_trap__target) <| $ [es] (var liana_trap__eid : EntityId&)
        liana_trap__eid = INVALID_ENTITY_ID
        liana_trap__target = INVALID_ENTITY_ID
      displacement = 0.0
      strain = 0.0
      return

    if curTime > liana_trap__nextDamageAt
      liana_trap__nextDamageAt = curTime + liana_trap__damageInterval
      if hasDamageTentacle
        let damageValue = liana_trap__damage * square(1.0 - strain)
        let dd = DamageDesc(DamageType.DM_HOLD_BREATH, damageValue, transform[3], float3(0.0, -1.0, 0.0))
        damage_entity(liana_trap__target, liana_trap__eid, dd)

[es]
def liana_trap_update(info : CmdPostPhysUpdate;
                      transform : float3x4;
                      var human_net_phys : HumanActor;
                      liana_trap__eid : EntityId)
  query(liana_trap__eid) <| $ [es] (liana_trap__maxActiveTentacles : int;
                                    liana_trap__lianaStrength : float;
                                    liana_trap__humanStrength : float;
                                    liana_trap__strainHalfLife : float;
                                    liana_trap__strainFromVelocity : float;
                                    liana_trap__strainFromHuman : float;
                                    liana_trap__breakCount : float;
                                    liana_trap__moveToPos : float3;
                                    liana_trap__tentacles : EidList;
                                    liana_trap__stabilityMul : float = 0.5;
                                    var liana_trap__strain : float&;
                                    var liana_trap__velDot : float&;
                                    var liana_trap__lastDisplacement : float&)
    assume strain = liana_trap__strain
    assume displacement = liana_trap__lastDisplacement

    var numAttachedTentacles = 0
    for tentacleEid in liana_trap__tentacles
      query(tentacleEid) <| $ [es] (liana_tentacle__isAttached : bool)
        if liana_tentacle__isAttached
          numAttachedTentacles++

    //pull human
    strain = min(strain * exp(calc_nu(liana_trap__strainHalfLife) * info.dt), 0.99)
    assume curState = human_net_phys.phys.currentState
    if numAttachedTentacles != 0
      let lianaAccel = liana_trap__lianaStrength * (3.0 - strain) * float(numAttachedTentacles)
      let gravVec = float3(0.0, gravity(), 0.0)
      assume ct = human_net_phys.phys.appliedCT
      let humanVec = apply_ct_to_look_dir(ct.walkDir, ct.wishLookDir)
      let delta3D = liana_trap__moveToPos - transform[3]
      displacement = length(delta3D)
      let dirTo = delta3D * safeinv(displacement)
      curState.velocity += gravVec * info.dt * float(numAttachedTentacles) / float(liana_trap__maxActiveTentacles)
      if displacement > VERY_SMALL_NUMBER
        let timeEstimate = sqrt(2.0 * displacement / (3.0 * lianaAccel))
        let desiredSpeed = lianaAccel * timeEstimate * liana_trap__stabilityMul
        let velocityDiff = dirTo * desiredSpeed - curState.velocity

        let stabilizingForce = lianaAccel * info.dt > length(velocityDiff) ? velocityDiff : normalize(velocityDiff) * lianaAccel * info.dt
        let reactiveForce = dirTo * displacement * lianaAccel * info.dt
        let resultingForce = stabilizingForce * (1.0 - strain) + reactiveForce * strain
        curState.velocity += resultingForce

      curState.velocity += humanVec * liana_trap__humanStrength * info.dt * ct.walkSpeed

      liana_trap__velDot = dot(curState.velocity, dirTo)

      strain += max(0.0, -dot(curState.velocity.xz, dirTo.xz)) * info.dt * liana_trap__strainFromVelocity
      strain += ct.walkSpeed * info.dt * liana_trap__strainFromHuman
    curState.velocity -= min(liana_trap__breakCount * 3.0, length(curState.velocity) * 0.95) * normalize(curState.velocity)


[es(tag=gameClient, after=net_phys_update_es)]
def liana_trap_update_client(info : UpdateStageInfoAct;
                             transform : float3x4;
                             liana_trap__maxDist : float;
                             liana_trap__travelSpeed : float;
                             liana_trap__lastDisplacement : float;
                             liana_trap__strain : float;
                             liana_trap__tentacles : EidList;
                             liana_trap__target : EntityId)
  query(liana_trap__target) <| $ [es] (animchar : AnimcharBaseComponent)
    for tentacleEid in liana_trap__tentacles
      query(tentacleEid) <| $ [es] (liana_tentacle__nodeId : int;
                                    liana_tentacle__spawnedAt : float;
                                    liana_tentacle__verticalGrowTime : float;
                                    liana_tentacle__deviationDirVel : float;
                                    liana_tentacle__coilThickness : float;
                                    liana_tentacle__numCoils : float;
                                    liana_tentacle__coilRadius : float;
                                    liana_tentacle__numCoilPoints : int;
                                    liana_tentacle__coilSpeed : float;
                                    liana_tentacle__fromPos : float3;
                                    liana_tentacle__toPos : float3;
                                    liana_tentacle__isAttached : bool;
                                    liana_tentacle__aliveAt : float;
                                    liana_tentacle__attachNodeEid : EntityId;

                                    var liana_tentacle__waveIndex : float&;
                                    var liana_tentacle__waveWidth : float&;
                                    var liana_tentacle__waveQuat : float4&;

                                    var liana_tentacle__coilingProgress : float&;
                                    var liana_tentacle__deviationDir : float&;
                                    var spline_gen_geometry__points : Point3List)
        if liana_tentacle__aliveAt > info.curTime || liana_tentacle__attachNodeEid == INVALID_ENTITY_ID
          return
        let reachPoints = length(spline_gen_geometry__points) - liana_tentacle__numCoilPoints
        let segmentLength = liana_trap__maxDist / float(reachPoints)
        if reachPoints < 2
          return

        //Positioning
        let firstGeomPoint = spline_gen_geometry__points[0]
        assume lastGeomPoint = spline_gen_geometry__points[reachPoints - 1]
        let targetNodePos = geomtree_getNodeWpos(*animchar.nodeTree, liana_tentacle__nodeId)
        if liana_tentacle__isAttached
          lastGeomPoint = targetNodePos
        else
          let verticalGrow = (info.curTime - liana_tentacle__spawnedAt) < liana_tentacle__verticalGrowTime
          let target = verticalGrow ? firstGeomPoint + float3(.0, 1000.0, .1) : targetNodePos
          let toTargetDir = normalize(target - lastGeomPoint)
          let dstToTarget = distance(lastGeomPoint, targetNodePos)
          let deviation = lerp(0.0, 15.0, safediv(dstToTarget, liana_trap__maxDist))
          let normalVec1 = normalize(cross(toTargetDir, toTargetDir + float3(liana_trap__maxDist, 0.0, 0.0)))
          let normalVec2 = cross(toTargetDir, normalVec1)
          var s, c : float
          sincos(liana_tentacle__deviationDir, s, c)
          var deviatedTarget = target + (normalVec1 * s + normalVec2 * c) * deviation
          let minY = min(targetNodePos.y, transform[3].y)
          deviatedTarget.y = max(minY, deviatedTarget.y)
          lastGeomPoint += normalize(deviatedTarget - lastGeomPoint) * liana_trap__travelSpeed * info.dt * (verticalGrow ? 1.0 : 3.0)
          liana_tentacle__deviationDir += liana_tentacle__deviationDirVel * info.dt

        query(liana_trap__target) <| $ [es] (human_net_phys : HumanActor)
          if liana_tentacle__waveIndex > liana_tentacle__waveWidth
            liana_tentacle__waveIndex -= info.dt * float(reachPoints) * 0.8
            let from = max(liana_tentacle__waveWidth, liana_tentacle__waveIndex - liana_tentacle__waveWidth)
            let to = min(float(reachPoints), liana_tentacle__waveIndex + liana_tentacle__waveWidth)
            for i in range(from, to)
              if distance(spline_gen_geometry__points[i], spline_gen_geometry__points[i - 1]) < VERY_SMALL_NUMBER
                continue
              let waveRatio = abs(liana_tentacle__waveIndex - float(i))
              let strength = lerp(1.0, 0.0, waveRatio / liana_tentacle__waveWidth) * 60.0
              let segment = spline_gen_geometry__points[i] - spline_gen_geometry__points[i - 1]
              let rotatedSegment = quat(liana_tentacle__waveQuat.xyz, liana_tentacle__waveQuat.w * strength * info.dt) * segment
              spline_gen_geometry__points[i] = spline_gen_geometry__points[i - 1] + rotatedSegment
          else
            assume ct = human_net_phys.phys.appliedCT
            let walkSpeedFactor = ct.walkSpeed * 0.5
            let displacementFactor = liana_trap__lastDisplacement / liana_trap__maxDist * 0.5
            let strainFactor = liana_trap__strain * 0.5
            let factorSum = walkSpeedFactor + displacementFactor + strainFactor
            if gfrnd() < factorSum * info.dt * 0.5
              liana_tentacle__waveIndex = float(reachPoints)
              liana_tentacle__waveWidth = factorSum + rnd_float(4.0, 7.0)
              var quatAxis = normalize(cross(float3(.0, 1.0, .0), liana_tentacle__toPos - liana_tentacle__fromPos))
              let randQ = normalize(quat(float3(.0, 1.0, .0), rnd_float(-PI, PI) * 0.5))
              quatAxis = randQ * quatAxis
              liana_tentacle__waveQuat = float4(quatAxis.x, quatAxis.y, quatAxis.z, -(2.0 + factorSum) / 10.0)


        //Update inner tentacle points
        apply_tentacle_phys(spline_gen_geometry__points, 0, reachPoints, segmentLength)

        //Coiling
        if liana_tentacle__isAttached
          var tm : float3x4
          geomtree_getNodeWtmScalar(*animchar.nodeTree, liana_tentacle__nodeId, tm)
          assume progress = liana_tentacle__coilingProgress
          progress = min(1.0, progress + info.dt * liana_tentacle__coilSpeed)
          let numCoilPoints = float(liana_tentacle__numCoilPoints)
          let iterTo = min(reachPoints + int(numCoilPoints * progress) + 1, length(spline_gen_geometry__points))
          for k in range(reachPoints, iterTo)
            let kProgress = min(progress, float(k - reachPoints + 1) / numCoilPoints)
            let angle = lerp(0.0, liana_tentacle__numCoils * PI * 2.0, kProgress)
            var s, c : float
            sincos(angle, s, c)
            assume p = spline_gen_geometry__points[k]
            p = (lastGeomPoint +
                tm[0] * liana_tentacle__coilThickness * kProgress +
                tm[1] * s * liana_tentacle__coilRadius +
                tm[2] * c * liana_tentacle__coilRadius)
          for k in range(iterTo, length(spline_gen_geometry__points))
            spline_gen_geometry__points[k] = spline_gen_geometry__points[iterTo - 1]

        else
          for k in range(reachPoints, length(spline_gen_geometry__points))
            spline_gen_geometry__points[k] = lastGeomPoint


[es(tag=gameClient, after=net_phys_update_es)]
def liana_tentacle_retract_client(info : UpdateStageInfoAct;
                                  liana_tentacle__aliveAt : float;
                                  liana_tentacle__hitRadius : float;
                                  liana_tentacle__maxPoints : int;
                                  liana_tentacle__maxLength : float;
                                  var liana_tentacle__numCoilPoints : int&;
                                  var liana_tentacle__fallVelocity : float&;
                                  var spline_gen_geometry__request_active : bool&;
                                  var spline_gen_geometry__points : Point3List;
                                  var liana_tentacle__fallTargets : Point3List)
  if !spline_gen_geometry__request_active
    return
  if liana_tentacle__aliveAt < info.curTime
    if length(liana_tentacle__fallTargets) > 0
      clear(liana_tentacle__fallTargets)
    return

  let numDetachedSegments = liana_tentacle__maxPoints - max(0, liana_tentacle__numCoilPoints)
  var i = length(spline_gen_geometry__points)
  while i-- > numDetachedSegments
    erase(spline_gen_geometry__points, i)
  liana_tentacle__numCoilPoints = 0
  let numPoints = length(spline_gen_geometry__points)

  //Init fall params
  if length(liana_tentacle__fallTargets) == 0
    liana_tentacle__fallVelocity = 0.0
    for _ in spline_gen_geometry__points
      push(liana_tentacle__fallTargets, float3())
    let MAX_TRACES = 8
    let traces = min(MAX_TRACES, numPoints - 1)
    var floorSegments : array<float3>
    push(floorSegments, spline_gen_geometry__points[0])
    for n in range(1, traces + 1)
      let idx = numPoints * n / traces - 1
      if distance_sq(spline_gen_geometry__points[idx], spline_gen_geometry__points[0]) > MIN_DST_SQ_WORTH_TRACING
        var t = liana_tentacle__maxLength
        tracedown_normalized(spline_gen_geometry__points[idx] + float3(.0, liana_tentacle__hitRadius, .0), t, ETF_DEFAULT)
        push(floorSegments, spline_gen_geometry__points[idx] + float3(.0, -t + 2.0 * liana_tentacle__hitRadius, .0))
      else
        push(floorSegments, spline_gen_geometry__points[idx])
    for n in range(traces)
      let segFrom = floorSegments[n]
      let segTo = floorSegments[n + 1]
      let idx1 = numPoints * n / traces
      let idx2 = numPoints * (n + 1) / traces - 1
      for m in range(idx1, idx2 + 1)
        if segTo.y < segFrom.y
          liana_tentacle__fallTargets[m] = segTo + spline_gen_geometry__points[m] - spline_gen_geometry__points[idx2]
        else
          liana_tentacle__fallTargets[m] = segFrom + spline_gen_geometry__points[m] - spline_gen_geometry__points[idx1]
    let segLen = liana_tentacle__maxLength / float(length(liana_tentacle__fallTargets))
    apply_tentacle_phys(liana_tentacle__fallTargets, 0, length(liana_tentacle__fallTargets), segLen)

  //The fall
  liana_tentacle__fallVelocity += abs(gravity()) * info.dt
  var numActivePoints = 0
  for j in iter_range(spline_gen_geometry__points)
    let diff = liana_tentacle__fallTargets[j] - spline_gen_geometry__points[j]
    if length(diff) > liana_tentacle__fallVelocity * info.dt
      spline_gen_geometry__points[j] += normalize(diff) * liana_tentacle__fallVelocity * info.dt
    else
      spline_gen_geometry__points[j] = liana_tentacle__fallTargets[j]
      numActivePoints++
  if numActivePoints == numPoints
    spline_gen_geometry__request_active = false


[es(after=human_locomotion_es)]
def liana_locomotion(act : UpdateStageInfoAct;
                     human_net_phys : HumanActor;
                     liana_trap__eid : EntityId;
                     var prevLocoQuat : float4&;
                     var transform : float3x4&;
                     liana__locomotionFactor : float = 0.04;
                     liana__locomotionTau : float = 0.11;
                     liana__locomotionQuatTau : float = 0.31;
                     var liana__locoAcc : float3&;
                     var liana__locoQuat : float4&)
  var acc = float3()
  query(liana_trap__eid) <| $ [es] (liana_trap__humanStrength : float)
    assume ct = human_net_phys.phys.appliedCT
    let humanVec = apply_ct_to_look_dir(ct.walkDir, ct.wishLookDir)
    acc = humanVec * liana_trap__humanStrength * ct.walkSpeed
  acc = approach(liana__locoAcc, float3(acc.x, 0.0, acc.z), act.dt, liana__locomotionTau)
  let axis = float3(dot(transform[2], acc), 0.0, dot(-transform[0], acc)) // it's cross-product with 0, 1, 0
  let lenAxis = length(axis)
  var qDefl = quat(axis * safediv(1.0, lenAxis), lenAxis * liana__locomotionFactor)
  let f4Deft = float4(qDefl)
  qDefl = quat(normalize(approach(liana__locoQuat, f4Deft, act.dt, liana__locomotionQuatTau)))
  if abs(f4Deft.w) < 1.0
    var quatTm : float3x4
    make_tm(qDefl, quatTm)
    transform = transform * quatTm
  liana__locoAcc = acc
  liana__locoQuat = f4Deft
  prevLocoQuat += liana__locoQuat


// TODO:
//  This variation of the es order gives the projectile
//  behavior inside kill_liana so that it can pass through objects.
//  It is important to fix this in the future!
[es(tag=gameClient, before=after_update_projectile_es, after=update_projectile_es)]
def liana_hit_detection(info : ParallelUpdateFrameDelayed;
                        projectile_ballistics : ProjectileBallistics;
                        ownerEid : EntityId;
                        projectile__prevPos : float3;
                        projectile__stopped : bool)
  if projectile__stopped || !has(ownerEid, "hero")
    return
  let projectileCurPos = projectile_ballistics.state.pos
  let projectilePrevPos = projectile__prevPos
  let travelDst = distance(projectilePrevPos, projectileCurPos)
  let midPoint = (projectileCurPos + projectilePrevPos) * 0.5
  find_query() <| $ [es] (eid : EntityId;
                          liana_tentacle__fromPos : float3;
                          liana_tentacle__toPos : float3;
                          liana_tentacle__maxLength : float;
                          liana_tentacle__aliveAt : float;
                          liana_tentacle__hitRadius : float;
                          liana_tentacle__numCoilPoints : int;
                          liana_tentacle__lianaEid : EntityId;
                          spline_gen_geometry__points : Point3List)
    if liana_tentacle__aliveAt > info.curTime
      return false
    let tentacleMid = (liana_tentacle__toPos + liana_tentacle__fromPos) / 2.0
    if distance_sq(midPoint, tentacleMid) > square(travelDst + liana_tentacle__maxLength * 0.5)
      return false

    assume lianaPoints = spline_gen_geometry__points
    let reachPoints = length(lianaPoints) - max(0, liana_tentacle__numCoilPoints) - 1
    var i = 0
    var accumLength = 0.0
    var startIdx = 0
    while i < reachPoints
      i++
      accumLength += distance(lianaPoints[i], lianaPoints[i - 1])
      if accumLength > 0.5 || (accumLength > VERY_SMALL_NUMBER && i == reachPoints)
        var mua, mub : float
        line_line_intersect(projectilePrevPos,
                            projectileCurPos,
                            lianaPoints[startIdx],
                            lianaPoints[i],
                            mua, mub)
        if mua >= 0.0 && mua <= 1.0 && mub >= 0.0 && mub <= 1.0
          let projectilePos = projectilePrevPos + (projectileCurPos - projectilePrevPos) * mua
          let lianaPos = lianaPoints[startIdx] + (lianaPoints[i] - lianaPoints[startIdx]) * mub
          if distance_sq(projectilePos, lianaPos) < square(liana_tentacle__hitRadius)
            send_net_event(liana_tentacle__lianaEid, CmdKillLianaTentacle(pos = lianaPos, tentacleEid = eid))
            return true
        accumLength = 0.0
        startIdx = i
    return false


[es(tag=server)]
def on_liana_tentacle_killed(cmd : CmdKillLianaTentacle;
                             liana_trap__injuryPerShot : float;
                             var liana_trap__injury : float&)
  liana_trap__injury += liana_trap__injuryPerShot
  kill_liana_tentacle(cmd.tentacleEid)


def damage_liana_tentacles_in_radius(pos : float3; radius : float)
  query() <| $ [es] (eid, liana_tentacle__lianaEid : EntityId;
                     liana_tentacle__fromPos : float3;
                     liana_tentacle__toPos : float3;
                     liana_tentacle__aliveAt : float)
    if liana_tentacle__aliveAt > get_sync_time()
      return
    let damagePoint = closest_pt_on_seg(pos, liana_tentacle__fromPos, liana_tentacle__toPos)
    if distance_sq(damagePoint, pos) < square(radius)
      send_net_event(liana_tentacle__lianaEid, CmdKillLianaTentacle(pos = damagePoint, tentacleEid = eid))


[es(tag=server, REQUIRE=fire_source__startTime, before=fire_damage, after=dmgzone_es)]
def dmgzone_kills_tentacles(info : UpdateStageInfoAct;
                            transform : float3x4;
                            dmgzone__lastUpdate : float;
                            sphere_zone__radius : float)
  if dmgzone__lastUpdate == info.curTime
    damage_liana_tentacles_in_radius(transform[3], sphere_zone__radius)


[es(tag=server, REQUIRE=(shell, phys_vars))]
def grenade_kills_tentacles(evt : CmdShellExplode; shell__owner : EntityId; transform : float3x4;
                            shell__shell_id__shell_id, shell__shell_id__damage_id, shell__shell_id__ballistics_id : int)
  if !shell__owner
    return
  let radius = get_shell_max_radius(shell__shell_id__shell_id, shell__shell_id__damage_id, shell__shell_id__ballistics_id)
  if radius <= 0f
    return
  damage_liana_tentacles_in_radius(transform[3], radius)