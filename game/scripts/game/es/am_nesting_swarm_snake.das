require app
require ecs
require ecs.safe
require ecs.common
require math.base
require math.random
require walkerai
require DagorSystem
require DagorMath
require Grid
require GridCollision
require CollisionTraces
require RendInst
require CollRes
require Dacoll
require DngDm
require game.events.events_active_matter
require game.es.am_nesting_swarm_snake_common
require game.events.events
require game.es.system_common
require game.events.events_game
require game.utils.net_utils
require net


[es(tag=server, on_appear)]
def nesting_swarm_snake_placer_init(evt : Event;
                                    nesting_swarm_snake_nest_placer__nestTemplate : string;
                                    nesting_swarm_snake_nest_placer__offset : float3;
                                    transform : float3x4;
                                    var nesting_swarm_snake_nest_placer__nest : EntityId&)
  nesting_swarm_snake_nest_placer__nest = createEntity(nesting_swarm_snake_nest_placer__nestTemplate) <| $(var init)
    var tm := transform
    tm[3] += nesting_swarm_snake_nest_placer__offset
    init |> set("transform", tm)
    init |> set("transform__dropOnGroundOffset", nesting_swarm_snake_nest_placer__offset.y)


[es(tag=server, on_disappear)]
def nesting_swarm_snake_placer_remove(evt : Event;
                                      nesting_swarm_snake_nest_placer__nest : EntityId)
  destroyEntity(nesting_swarm_snake_nest_placer__nest)


[es(tag=server, track=transform)]
def nesting_swarm_snake_placer_translate(evt : Event;
                                         transform aka placer_transform : float3x4;
                                         nesting_swarm_snake_nest_placer__nest : EntityId)
  query(nesting_swarm_snake_nest_placer__nest) <| $ [es] (transform__dropOnGroundOffset : float;
                                                          var transform : float3x4&;
                                                          var static_sinusoidal_oscillation__origin : float3&)
    transform = placer_transform
    static_sinusoidal_oscillation__origin = placer_transform[3] + float3(0.0, transform__dropOnGroundOffset, 0.0)


[es(tag=server, on_appear)]
def nesting_swarm_snake_init(evt : Event;
                             eid : EntityId;
                             transform aka snake_transform : float3x4;
                             nesting_swarm_snake__segmentsCount : int;
                             nesting_swarm_snake__segmentTemplate : string;
                             nesting_swarm_snake__segmentLengthMin : float;
                             var nesting_swarm_snake__state : int&;
                             var nesting_swarm_snake__segmentEids : EidList;
                             var nesting_swarm_snake__targetPos : float3&;
                             var nesting_swarm_snake__collisionTracePrevPos : float3&)
  nesting_swarm_snake__state = int(NestingSwarmSnakeState.Nest)

  nesting_swarm_snake__targetPos = transform[3]
  nesting_swarm_snake__collisionTracePrevPos = transform[3]
  nesting_swarm_snake__segmentEids |> resize(nesting_swarm_snake__segmentsCount)

  var pos = snake_transform[3]
  for segmentIdx, segmentEid in range(nesting_swarm_snake__segmentsCount), nesting_swarm_snake__segmentEids
    segmentEid = createEntity(nesting_swarm_snake__segmentTemplate) <| $(var init : ComponentsInitializer)
      var tm = IDENT_TM
      tm[3] = pos
      let attackEnabled = segmentIdx % 3 == 0 && segmentIdx > 6 // Workaround fix for high ping
      init |> set("transform", tm)
      init |> set("nesting_swarm_snake_segment__index", segmentIdx)
      init |> set("nesting_swarm_snake_segment__snakeEid", eid)
      init |> set("nesting_swarm_snake_segment__attackingEnabled", attackEnabled)

      pos += rnd_dir3() * nesting_swarm_snake__segmentLengthMin


[es(tag=server)]
def sync_snake_segment_position(evt : CmdRequestSnakeSegmentPositionSync; eid : EntityId; transform : float3x4)
  send_net_event(eid, EventSnakeSegmentPositionSync(position = transform[3]), target_entity_conn(evt.hero))


[es(tag=server, on_disappear)]
def nesting_swarm_snake_disappear(evt : Event;
                                  nesting_swarm_snake__segmentEids : EidList)
  for segementEid in nesting_swarm_snake__segmentEids
    destroyEntity(segementEid)


[es(tag=server, no_order)]
def nesting_swarm_snake(act : UpdateStageInfoAct;
                        flyer__directionViscosity : float;
                        stride__worstDot : float;
                        stride__focus : float;
                        stride__absoluteFocusDistance : float2;
                        walker_agent__targetEid : EntityId;
                        nesting_swarm_snake__state : int;
                        swarm_warrior__primaryNest : EntityId;
                        nesting_swarm_snake__requiredSpeed : float;
                        nesting_swarm_snake__targetSavedPos : float3;
                        nesting_swarm_snake__attackSmoothKoef : float;
                        nesting_swarm_snake__attackPerforatingSpanSq : float;
                        nesting_swarm_snake__nestOffsetFrom : float = 1.0;
                        nesting_swarm_snake__nestOffsetLength : float = 0.5;
                        nesting_swarm_snake__collisionTraceDistSq : float;
                        nesting_swarm_snake__collisionSpeedSlowdownDamping : float;
                        nesting_swarm_snake__collisionSpeedSlowdown : float;
                        var nesting_swarm_snake__targetPos : float3&;
                        var flyer__speed : float&;
                        var flyer__velocityDir : float3&;
                        var flyer__wishLookDir : float3&;
                        var transform aka snake_transform : float3x4;
                        var nesting_swarm_snake__collisionTracePrevPos : float3&;
                        var nesting_swarm_snake__collisionSpeedCurrentSlowdown : float&)
  let clampedDt = min_30_fps_dt(act.dt)

  flyer__speed = lerp(flyer__speed, nesting_swarm_snake__requiredSpeed, 2.0 * clampedDt)

  if (nesting_swarm_snake__state == int(NestingSwarmSnakeState.Fly) ||
    nesting_swarm_snake__state == int(NestingSwarmSnakeState.Nest))

    // Determine target pos
    var hasTarget = false
    query(walker_agent__targetEid) <| $ [es] (isAlive : bool = true;
                                              transform aka target_transform : float3x4;
                                              ai_target : Target const?)
      if isAlive
        nesting_swarm_snake__targetPos = ai_target != null ? ai_target.targetPos : target_transform[3]
        hasTarget = true

    if nesting_swarm_snake__state == int(NestingSwarmSnakeState.Nest)
      query(swarm_warrior__primaryNest) <| $ [es] (transform aka nest_transform : float3x4)
        nesting_swarm_snake__targetPos = nest_transform[3]
        assume nestOffsetFrom = nesting_swarm_snake__nestOffsetFrom
        assume nestOffsetLength = nesting_swarm_snake__nestOffsetLength
        let nestOffset = ((sin(act.curTime) + 1.0) * 0.5) * nestOffsetLength + nestOffsetFrom
        nesting_swarm_snake__targetPos += nest_transform[1] * nestOffset

    let meToTarget = nesting_swarm_snake__targetPos - snake_transform[3]
    let dstSq = length_sq(meToTarget)

    if dstSq > 1e-3
      let dst = sqrt(dstSq)
      var rndDir = normalize(float3(gfrnd() - 0.5, gfrnd() - 0.5, gfrnd() - 0.5))
      let targetDir = meToTarget / dst
      if dot(targetDir, rndDir) < stride__worstDot
        rndDir *= -1.0
      var focus = stride__focus
      if dst < stride__absoluteFocusDistance.x
        let absoluteFocusDist = stride__absoluteFocusDistance.x - stride__absoluteFocusDistance.y
        let focusProgress = 1.0 - ((dst - stride__absoluteFocusDistance.y) / absoluteFocusDist)
        focus *= focusProgress
      let strideDir = normalize(targetDir * focus + rndDir * (1.0 - focus))

      flyer__velocityDir = normalize(approach(flyer__velocityDir, strideDir, act.dt, flyer__directionViscosity))
      flyer__wishLookDir = meToTarget / dst
  elif nesting_swarm_snake__state == int(NestingSwarmSnakeState.Attack)
    if distance_sq(snake_transform[3], nesting_swarm_snake__targetSavedPos) >= nesting_swarm_snake__attackPerforatingSpanSq
      let meToTarget = nesting_swarm_snake__targetPos - snake_transform[3]
      let dstSq = length_sq(meToTarget)
      if dstSq > 1e-3
        let dst = sqrt(dstSq)
        let targetDir = meToTarget / dst
        flyer__velocityDir = slerp(dir_to_quat(flyer__velocityDir), dir_to_quat(targetDir), nesting_swarm_snake__attackSmoothKoef * clampedDt) |> quat_get_forward()
        if flyer__velocityDir.y < 0.0
          flyer__velocityDir.y = -flyer__velocityDir.y

  let slowdownMult = 1.0 - nesting_swarm_snake__collisionSpeedCurrentSlowdown
  let speed = flyer__speed * slowdownMult
  let newPos = transform[3] + flyer__velocityDir * speed * act.dt
  transform[3] = newPos

  nesting_swarm_snake__collisionSpeedCurrentSlowdown = lerp(nesting_swarm_snake__collisionSpeedCurrentSlowdown, 0.0,
                                                            nesting_swarm_snake__collisionSpeedSlowdownDamping * clampedDt)

  if nesting_swarm_snake__state == int(NestingSwarmSnakeState.Fly)
    let colTraceDelta = newPos - nesting_swarm_snake__collisionTracePrevPos
    let colTraceLenSq = length_sq(colTraceDelta)
    if colTraceLenSq >= nesting_swarm_snake__collisionTraceDistSq
      let colTraceLen = sqrt(colTraceLenSq)
      let colTraceDir = colTraceDelta / colTraceLen

      var t = colTraceLen
      var norm : float3
      if traceray_normalized(nesting_swarm_snake__collisionTracePrevPos, colTraceDir, t,
                             norm, ETF_RI)
        nesting_swarm_snake__collisionSpeedCurrentSlowdown = nesting_swarm_snake__collisionSpeedSlowdown


      nesting_swarm_snake__collisionTracePrevPos = newPos
  else
    nesting_swarm_snake__collisionTracePrevPos = newPos


[es(track=nesting_swarm_snake__state, on_appear)]
def nesting_swarm_snake_track_state(evt : Event;
                                    nesting_swarm_snake__state : int;
                                    nesting_swarm_snake__nestSpeed : float;
                                    nesting_swarm_snake__flySpeed : float;
                                    nesting_swarm_snake__attackSpeed : float;
                                    nesting_swarm_snake__segmentEids : EidList;
                                    var nesting_swarm_snake__requiredSpeed : float&;
                                    var nesting_swarm_snake__stateTimestamp : float&)
  nesting_swarm_snake__stateTimestamp = get_sync_time()

  if nesting_swarm_snake__state == int(NestingSwarmSnakeState.Nest)
    nesting_swarm_snake__requiredSpeed = nesting_swarm_snake__nestSpeed
  elif nesting_swarm_snake__state == int(NestingSwarmSnakeState.Fly)
    nesting_swarm_snake__requiredSpeed = nesting_swarm_snake__flySpeed
  elif nesting_swarm_snake__state == int(NestingSwarmSnakeState.Attack)
    nesting_swarm_snake__requiredSpeed = nesting_swarm_snake__attackSpeed

  if nesting_swarm_snake__state == int(NestingSwarmSnakeState.Attack)
    for segmentEid in nesting_swarm_snake__segmentEids
      query(segmentEid) <| $ [es(REQUIRE_NOT=nesting_swarm_snake_segment_attacking)] (nesting_swarm_snake_segment__attackingTemplate : string;
                                                                                      nesting_swarm_snake_segment__attackingEnabled : bool)
        if nesting_swarm_snake_segment__attackingEnabled
          addSubTemplate(segmentEid, nesting_swarm_snake_segment__attackingTemplate)
  else
    for segmentEid in nesting_swarm_snake__segmentEids
      query(segmentEid) <| $ [es(REQUIRE=nesting_swarm_snake_segment_attacking)] (nesting_swarm_snake_segment__attackingTemplate : string)
        removeSubTemplate(segmentEid, nesting_swarm_snake_segment__attackingTemplate)


[es(tag=server, on_appear)]
def nesting_swarm_snake_segment_attacking_init(evt : Event;
                                               eid : EntityId;
                                               transform : float3x4;
                                               nesting_swarm_snake_segment_attacking__interval : float;
                                               var nesting_swarm_snake_segment_attacking__timer : float&;
                                               var nesting_swarm_snake_segment_attacking__prevPos : float3&)
  nesting_swarm_snake_segment_attacking__timer = eid_frnd(eid) * nesting_swarm_snake_segment_attacking__interval
  nesting_swarm_snake_segment_attacking__prevPos = transform[3]


[es(tag=server, after=nesting_swarm_snake_segments_update)]
def nesting_swarm_snake_segment_attacking_update(act : UpdateStageInfoAct;
                                                 transform : float3x4;
                                                 eid : EntityId;
                                                 nesting_swarm_snake_segment_attacking__interval : float;
                                                 nesting_swarm_snake_segment__attackInterval : float;
                                                 nesting_swarm_snake_segment__attackRng : float2;
                                                 nesting_swarm_snake_segment__attackRadius : float;
                                                 nesting_swarm_snake_segment__pushRng : float2;
                                                 var nesting_swarm_snake_segment_attacking__timer : float&;
                                                 var nesting_swarm_snake_segment__lastAttackTime : Object;
                                                 var nesting_swarm_snake_segment_attacking__prevPos : float3&)


  nesting_swarm_snake_segment_attacking__timer -= act.dt
  if nesting_swarm_snake_segment_attacking__timer <= 0.0
    nesting_swarm_snake_segment_attacking__timer += nesting_swarm_snake_segment_attacking__interval

    let curPos = transform[3]
    let deltaPos = curPos - nesting_swarm_snake_segment_attacking__prevPos
    let deltaPosLenSq = length_sq(deltaPos)
    if deltaPosLenSq > 1e-6
      let deltaPosLen = sqrt(deltaPosLenSq)
      let dir = deltaPos / deltaPosLen
      using() <| $(var intersections : IntersectedEntities)
        var t = deltaPosLen
        trace_entities_in_grid_by_capsule(ecs_hash("humans"),
                                          nesting_swarm_snake_segment_attacking__prevPos,
                                          dir, t, nesting_swarm_snake_segment__attackRadius,
                                          INVALID_ENTITY_ID, intersections, SortIntersections.NO)
        for isect in intersections
          query(isect.eid) <| $ [es(REQUIRE=ai_target)] ()
            let lastAttackTime = nesting_swarm_snake_segment__lastAttackTime["{isect.eid}"] ?? 0.0
            if lastAttackTime + nesting_swarm_snake_segment__attackInterval < act.curTime
              let damageDesc = DamageDesc(DamageType.DM_MELEE, rnd_float(nesting_swarm_snake_segment__attackRng), isect.pos)
              damage_entity(isect.eid, eid, damageDesc)
              sendEvent(isect.eid, CmdPushPhys(vel = dir * rnd_float(nesting_swarm_snake_segment__pushRng), push_immunity = 0.0))
              nesting_swarm_snake_segment__lastAttackTime |> set("{isect.eid}", act.curTime)

      nesting_swarm_snake_segment_attacking__prevPos = curPos


[es(REQUIRE_NOT=net_stash_entity, no_order)]
def nesting_swarm_snake_segments_update(act : UpdateStageInfoAct;
                                        nesting_swarm_snake__segmentEids : EidList;
                                        transform aka snake_transform : float3x4;
                                        nesting_swarm_snake__segmentLengthMin : float;
                                        nesting_swarm_snake__segmentLengthDesired : float;
                                        nesting_swarm_snake__segmentLengthMax : float)
  let segmentsCount = length(nesting_swarm_snake__segmentEids)
  if segmentsCount == 0
    return

  assume segmentLengthMin = nesting_swarm_snake__segmentLengthMin
  assume segmentLengthDesired = nesting_swarm_snake__segmentLengthDesired
  assume segmentLengthMax = nesting_swarm_snake__segmentLengthMax

  for segmentIdx, segmentEid in iter_range(nesting_swarm_snake__segmentEids), nesting_swarm_snake__segmentEids
    query(segmentEid) <| $ [es] (var transform aka segment_transform : float3x4;
                                 var nesting_swarm_snake_segment__dir : float3&)
      if segmentIdx == 0
        let smoothHeadPosition = lerp(segment_transform[3], snake_transform[3], float3(30.0 * min_30_fps_dt(act.dt)))
        segment_transform[3] = smoothHeadPosition
        if segmentsCount > 1
          query(nesting_swarm_snake__segmentEids[segmentIdx + 1]) <| $ [es] (transform aka next_segment_transform : float3x4)
            let nextPos = next_segment_transform[3]
            let toNextDelta = nextPos - segment_transform[3]
            let toNextDistanceSq = length_sq(toNextDelta)
            if toNextDistanceSq > 1e-3
              let toNext = toNextDelta / sqrt(toNextDistanceSq)
              nesting_swarm_snake_segment__dir = toNext
      else
        query(nesting_swarm_snake__segmentEids[segmentIdx - 1]) <| $ [es] (transform aka parent_segment_transform : float3x4)
          let parentPos = parent_segment_transform[3]

          let toParentDelta = parentPos - segment_transform[3]
          let toParentDistanceSq = length_sq(toParentDelta)

          let toParentDistance = sqrt(toParentDistanceSq)
          var toParent : float3
          if toParentDistance < 1e-3
            toParent = rnd_dir3()
          else
            toParent = toParentDelta / toParentDistance

          nesting_swarm_snake_segment__dir = toParent

          if toParentDistance < segmentLengthMin
            segment_transform[3] = parentPos - toParent * segmentLengthMin
          elif toParentDistance > segmentLengthMax
            segment_transform[3] = parentPos - toParent * segmentLengthMax
          else
            let desiredPos = parentPos - toParent * segmentLengthDesired
            segment_transform[3] = lerp(segment_transform[3], desiredPos, float3(4.0 * min_30_fps_dt(act.dt)))


[es(no_order)]
def nesting_swarm_snake_update(act : UpdateStageInfoAct;
                               nesting_swarm_snake__targetSegmentLengthMin : float;
                               nesting_swarm_snake__targetSegmentLengthDesired : float;
                               nesting_swarm_snake__targetSegmentLengthMax : float;
                               var nesting_swarm_snake__segmentLengthMin : float&;
                               var nesting_swarm_snake__segmentLengthDesired : float&;
                               var nesting_swarm_snake__segmentLengthMax : float&)
  assume segmentLengthMin = nesting_swarm_snake__segmentLengthMin
  assume segmentLengthDesired = nesting_swarm_snake__segmentLengthDesired
  assume segmentLengthMax = nesting_swarm_snake__segmentLengthMax

  let t = 1.0 * min_30_fps_dt(act.dt)
  segmentLengthMin = lerp(segmentLengthMin, nesting_swarm_snake__targetSegmentLengthMin, t)
  segmentLengthDesired = lerp(segmentLengthDesired, nesting_swarm_snake__targetSegmentLengthDesired, t)
  segmentLengthMax = lerp(segmentLengthMax, nesting_swarm_snake__targetSegmentLengthMax, t)


[es(tag=gameClient, on_appear)]
def init_min_compensation_speed_for_nesting_swarm_snake(evt : Event;
                                                        nesting_swarm_snake__flySpeed : float;
                                                        loc_snapshots__compensationSpeedMult = float2(0.4, 1.4);//min, max
                                                        var loc_snapshots__compensationSpeed : float2&)
  loc_snapshots__compensationSpeed = loc_snapshots__compensationSpeedMult * nesting_swarm_snake__flySpeed


[es(on_appear)]
def oscillating_cluster_init_speed(evt : Event;
                                   oscillating_swarm__lateralAngleSpeedRnd : float2;
                                   var oscillating_swarm__lateralAngleSpeed : float&)
  oscillating_swarm__lateralAngleSpeed *= rnd_float(oscillating_swarm__lateralAngleSpeedRnd)


[es(on_appear)]
def oscillating_boid_init_offset_radius(evt : Event;
                                        parentSwarm : EntityId;
                                        var oscillating_boid__offsetRadiusMult : float&)
  query(parentSwarm) <| $ [es] (oscillating_swarm__offsetRadiusRange : float2)
    oscillating_boid__offsetRadiusMult = rnd_float(oscillating_swarm__offsetRadiusRange)


[es(tag=gameClient, no_order)]
def nesting_swarm_snake_attack_radius(act : UpdateStageInfoAct;
                                      nesting_swarm_snake__state : int;
                                      nesting_swarm_snake__targetSavedPos : float3;
                                      nesting_swarm_snake__segmentEids : EidList)
  if nesting_swarm_snake__state == int(NestingSwarmSnakeState.Attack) || nesting_swarm_snake__state == int(NestingSwarmSnakeState.Fly)
    for segmentEid in nesting_swarm_snake__segmentEids
      query(segmentEid) <| $ [es] (nesting_swarm_snake_segment__visualEid : EntityId)
        query(nesting_swarm_snake_segment__visualEid) <| $ [es] (transform : float3x4;
                                                                 oscillating_swarm__lateralAngleSpeedRange : float2;
                                                                 oscillating_swarm__oscilationAngleSpeedRange : float2;
                                                                 oscillating_swarm__radiusRange : float2;
                                                                 oscillating_swarm__approachThreshold : float2;
                                                                 var swarm_cluster__radius : float&;
                                                                 var oscillating_swarm__lateralAngleSpeed : float&;
                                                                 var oscillating_swarm__oscilationAngleSpeed : float&)
          let dst = distance(transform[3], nesting_swarm_snake__targetSavedPos)
          oscillating_swarm__lateralAngleSpeed = cvt(dst,
                                                    oscillating_swarm__approachThreshold.x,
                                                    oscillating_swarm__approachThreshold.y,
                                                    oscillating_swarm__lateralAngleSpeedRange.x,
                                                    oscillating_swarm__lateralAngleSpeedRange.y)
          oscillating_swarm__oscilationAngleSpeed = cvt(dst,
                                                    oscillating_swarm__approachThreshold.x,
                                                    oscillating_swarm__approachThreshold.y,
                                                    oscillating_swarm__oscilationAngleSpeedRange.x,
                                                    oscillating_swarm__oscilationAngleSpeedRange.y)
          swarm_cluster__radius = cvt(dst,
                                                    oscillating_swarm__approachThreshold.x,
                                                    oscillating_swarm__approachThreshold.y,
                                                    oscillating_swarm__radiusRange.x,
                                                    oscillating_swarm__radiusRange.y)