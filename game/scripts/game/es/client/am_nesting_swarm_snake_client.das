require app
require ecs
require ecs.common
require net
require math.base
require math.random
require fx
require DagorSystem
require DagorMath
require RendInst
require CollRes
require Dacoll
require danetlibs.renderer.includes.render_events
require game.events.events_active_matter
require game.events.events_game
require game.es.system_common
require game.es.swarm_common
require game.es.am_nesting_swarm_snake_common
require game.es.surface_crawler_common


[es(tag=gameClient, on_appear)]
def nesting_swarm_snake_init_client(evt : Event;
                                    eid : EntityId;
                                    nesting_swarm_snake__segmentVisualShowHideCheckInterval : float;
                                    var nesting_swarm_snake__segmentVisualShowHideCheckAt : float&)
  nesting_swarm_snake__segmentVisualShowHideCheckAt = eid_frnd(eid) * nesting_swarm_snake__segmentVisualShowHideCheckInterval


def update_nesting_swarm_snake_segments_visibility(nesting_swarm_snake__segmentEids : EidList;
                                                   value : bool)
  for segmentEid in nesting_swarm_snake__segmentEids
    query(segmentEid) <| $ [es] (nesting_swarm_snake_segment__visualEid : EntityId)
      if nesting_swarm_snake_segment__visualEid == INVALID_ENTITY_ID
        return
      if !value
        addSubTemplate(nesting_swarm_snake_segment__visualEid, "swarm_disabled")
      else
        removeSubTemplate(nesting_swarm_snake_segment__visualEid, "swarm_disabled")


[es(tag=gameClient, no_order)]
def nesting_swarm_snake_update_client(act : ParallelUpdateFrameDelayed;
                                      nesting_swarm_snake__segmentVisualShowHideDistanceSq : float2;
                                      nesting_swarm_snake__segmentVisualShowHideCheckInterval : float;
                                      nesting_swarm_snake__state : int;
                                      transform aka nesting_swarm_snake_transform : float3x4;
                                      nesting_swarm_snake__segmentEids : EidList;
                                      var nesting_swarm_snake__segmentVisualVisible : bool&;
                                      var nesting_swarm_snake__segmentVisualShowHideCheckAt : float&)
  if act.curTime >= nesting_swarm_snake__segmentVisualShowHideCheckAt
    nesting_swarm_snake__segmentVisualShowHideCheckAt = act.curTime + nesting_swarm_snake__segmentVisualShowHideCheckInterval
    query() <| $ [es(REQUIRE=watchedByPlr)] (transform aka watched_transform : float3x4)
      let distanceToWatchedHero = distance_sq(nesting_swarm_snake_transform[3], watched_transform[3])
      if distanceToWatchedHero <= nesting_swarm_snake__segmentVisualShowHideDistanceSq.x && !nesting_swarm_snake__segmentVisualVisible
        nesting_swarm_snake__segmentVisualVisible = true
        update_nesting_swarm_snake_segments_visibility(nesting_swarm_snake__segmentEids, true)
      elif distanceToWatchedHero >= nesting_swarm_snake__segmentVisualShowHideDistanceSq.y && nesting_swarm_snake__segmentVisualVisible
        if nesting_swarm_snake__state == int(NestingSwarmSnakeState.Nest)
          nesting_swarm_snake__segmentVisualVisible = false
          update_nesting_swarm_snake_segments_visibility(nesting_swarm_snake__segmentEids, false)


[es(tag=gameClient, REQUIRE=nesting_swarm_snake_segment, on_appear, on_event=EventSnakeSegmentPositionSync, after=client_do_sync_snake_segment_position)]
def nesting_swarm_snake_segment_init_client(evt : Event;
                                            eid : EntityId;
                                            transform : float3x4;
                                            nesting_swarm_snake_segment__visualTemplate : string;
                                            var nesting_swarm_snake_segment__visualEid : EntityId&)
  if nesting_swarm_snake_segment__visualTemplate != ""
    destroyEntity(nesting_swarm_snake_segment__visualEid)
    nesting_swarm_snake_segment__visualEid = createEntity(nesting_swarm_snake_segment__visualTemplate) <| $(var init : ComponentsInitializer)
      init |> set("attached__entity", eid)
      init |> set("transform", transform)


[es(tag=gameClient, on_event=EventWentToNetStash)]
def nesting_swarm_snake_disable_segments_visual_in_net_stash(evt : Event; nesting_swarm_snake__segmentEids : EidList)
  for segment in nesting_swarm_snake__segmentEids
    query(segment) <| $ [es] (var nesting_swarm_snake_segment__visualEid : EntityId&)
      destroyEntity(nesting_swarm_snake_segment__visualEid)
      nesting_swarm_snake_segment__visualEid = INVALID_ENTITY_ID


[es(tag=gameClient, on_event=EventNoLongerInNetStash)]
def nesting_swarm_snake_enable_segments_visual_when_out_of_net_stash(evt : Event;
                                                                     nesting_swarm_snake__segmentEids : EidList)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    for segment in nesting_swarm_snake__segmentEids
      send_net_event(segment, CmdRequestSnakeSegmentPositionSync(hero = eid))


[es(tag=gameClient)]
def client_do_sync_snake_segment_position(evt : EventSnakeSegmentPositionSync; var transform : float3x4)
  transform[3] = evt.position


[es(tag=gameClient, REQUIRE=nesting_swarm_snake_segment, on_disappear)]
def nesting_swarm_snake_segment_disappear_client(evt : Event;
                                                 nesting_swarm_snake_segment__visualEid : EntityId)
  query(nesting_swarm_snake_segment__visualEid) <| $ [es] (eid aka swarm_eid : EntityId;
                                                           swarm__deadBoidTemplateName : string;
                                                           swarm__deathExplosionBoidsImpulse : float)
    query() <| $ [es(REQUIRE_NOT=boidDead)] (eid aka boid_eid : EntityId;
                                             parentSwarm : EntityId;
                                             trajectoryPos : Point4List const?;
                                             boid__dyingTime : float = 5.5;
                                             var velocity : float3&;
                                             var staying_time : float&;
                                             var boid_state : int&;
                                             var boid__isHitted : bool&)
      if parentSwarm == swarm_eid
        boid_state = int(BoidState.BOID_DEAD)
        staying_time = boid__dyingTime
        boid__isHitted = true
        var deadBoidTemplateName : string
        if swarm__deadBoidTemplateName != ""
          deadBoidTemplateName := swarm__deadBoidTemplateName
        elif trajectoryPos == null
          deadBoidTemplateName := "deadBoid"
        else
          deadBoidTemplateName := "trajectoryDeadBoid"
        reCreateEntityFrom(boid_eid, deadBoidTemplateName)

        // Non-uniform impulse distribution
        let r = grnd() % 5
        if r == 0
          velocity = rnd_dir3() * rnd_float(0.78, 1.0) * swarm__deathExplosionBoidsImpulse
          velocity.y = abs(velocity.y)
        elif r >= 1 && r <= 2
          velocity = rnd_dir3() * rnd_float(0.07, 1.0) * swarm__deathExplosionBoidsImpulse
          velocity.y = abs(velocity.y)
        else
          velocity = rnd_dir3() * rnd_float(0.21, 0.35) * swarm__deathExplosionBoidsImpulse
    addSubTemplate(nesting_swarm_snake_segment__visualEid, "swarm_destroy_if_empty")


[es(tag=gameClient, REQUIRE=swarm__disabled, on_appear, on_disappear)]
def nesting_swarm_snake_segment_visual_disable_changed(evt : Event;
                                                       transform aka segment_transform : float3x4;
                                                       nesting_swarm_snake_segment_visual__boidEids : EidList)
  for boidEid in nesting_swarm_snake_segment_visual__boidEids
    query(boidEid) <| $ [es] (var position : float3&;
                              var prevPosition : float3&)
      position = segment_transform[3]
      prevPosition = position


[es(tag=gameClient, REQUIRE=nesting_swarm_snake_segment_visual_boid_element, on_appear)]
def nesting_swarm_snake_segment_visual_boid_element_appear(evt : Event;
                                                           eid aka boid_eid : EntityId;
                                                           parentSwarm : EntityId;
                                                           var position : float3&;
                                                           var prevPosition : float3&)
  query(parentSwarm) <| $ [es] (transform aka segment_transform : float3x4;
                                var nesting_swarm_snake_segment_visual__boidEids : EidList)
    nesting_swarm_snake_segment_visual__boidEids |> push(boid_eid)
    position = segment_transform[3]
    prevPosition = position


[es(tag=gameClient, REQUIRE=nesting_swarm_snake_segment_visual_boid_element, on_disappear)]
def nesting_swarm_snake_segment_visual_boid_element_disappear(evt : Event;
                                                              eid aka boid_eid : EntityId;
                                                              parentSwarm : EntityId)
  query(parentSwarm) <| $ [es] (var nesting_swarm_snake_segment_visual__boidEids : EidList)
    let boidIdx = nesting_swarm_snake_segment_visual__boidEids |> find_index(boid_eid)
    if boidIdx >= 0
      nesting_swarm_snake_segment_visual__boidEids |> erase(boidIdx)


def set_targets(timer, time_interval : float;
                swarm_pos, swarm_dir : float3;
                swarm_length : float;
                var targets : Point3List)
  var progress = timer / time_interval
  progress = square((progress < 0.5 ? progress : 1.0 - progress) * 2.0)
  targets |> resize(3)
  targets[0] = swarm_pos + progress * swarm_dir * swarm_length
  targets[1] = swarm_pos + 0.5 * swarm_dir * swarm_length
  targets[2] = swarm_pos + (1.0 - progress) * swarm_dir * swarm_length


[es(tag=gameClient, on_appear, before=boids_spawner)]
def nesting_swarm_snake_segment_visual_init_client(evt : Event;
                                                   eid : EntityId;
                                                   attached__entity : EntityId;
                                                   nesting_swarm_snake_segment_visual__timeInterval : float;
                                                   nesting_swarm_snake_segment_visual__swarmMoveSpeedDeviationFactor : float;
                                                   nesting_swarm_snake_segment_visual__swarmRotSpeedDeviationFactor : float;
                                                   transform : float3x4;
                                                   nesting_swarm_snake_segment_visual__dir : float3;
                                                   nesting_swarm_snake_segment_visual__length : float;
                                                   var count : int&;
                                                   var nesting_swarm_snake_segment_visual__timer : float&;
                                                   var nesting_swarm_snake_segment_visual__swarmMoveSpeedDeviation : float&;
                                                   var nesting_swarm_snake_segment_visual__swarmRotSpeedDeviation : float&;
                                                   var swarm__extraTargets : Point3List)
  nesting_swarm_snake_segment_visual__timer = eid_frnd(eid) * nesting_swarm_snake_segment_visual__timeInterval

  set_targets(nesting_swarm_snake_segment_visual__timer, nesting_swarm_snake_segment_visual__timeInterval,
              transform[3], nesting_swarm_snake_segment_visual__dir,
              nesting_swarm_snake_segment_visual__length, swarm__extraTargets)

  query(attached__entity) <| $ [es] (nesting_swarm_snake_segment__snakeEid : EntityId;
                                     nesting_swarm_snake_segment__index : int)
    query(nesting_swarm_snake_segment__snakeEid) <| $ [es] (nesting_swarm_snake__boidsPerSegment : int2;
                                                            nesting_swarm_snake__boidsPerSegmentDeviation : int2;
                                                            nesting_swarm_snake__segmentsCount : int)
      let t = float(nesting_swarm_snake_segment__index) / float(nesting_swarm_snake__segmentsCount - 1)
      let interpolatedCount = int(lerp(float(nesting_swarm_snake__boidsPerSegment.x), float(nesting_swarm_snake__boidsPerSegment.y), sqrt(t)))
      let deviation = int(rnd_sign()) * rnd_int(nesting_swarm_snake__boidsPerSegmentDeviation.x, nesting_swarm_snake__boidsPerSegmentDeviation.y + 1)
      count = max(1, interpolatedCount + deviation)

  assume swarmMoveSpeedDeviationFactor = nesting_swarm_snake_segment_visual__swarmMoveSpeedDeviationFactor
  assume swarmRotSpeedDeviationFactor = nesting_swarm_snake_segment_visual__swarmRotSpeedDeviationFactor

  nesting_swarm_snake_segment_visual__swarmMoveSpeedDeviation = eid_frnd(eid) * swarmMoveSpeedDeviationFactor * rnd_sign()
  nesting_swarm_snake_segment_visual__swarmRotSpeedDeviation = eid_frnd(eid) * swarmRotSpeedDeviationFactor * rnd_sign()


[es(tag=gameClient, REQUIRE=nesting_swarm_snake_segment_visual, no_order)]
def nesting_swarm_snake_segment_visual_client(act : ParallelUpdateFrameDelayed;
                                              transform : float3x4;
                                              nesting_swarm_snake_segment_visual__dir : float3;
                                              nesting_swarm_snake_segment_visual__length : float;
                                              nesting_swarm_snake_segment_visual__timeInterval : float;
                                              var swarm__extraTargets : Point3List;
                                              var nesting_swarm_snake_segment_visual__timer : float&)
  nesting_swarm_snake_segment_visual__timer += act.dt
  while nesting_swarm_snake_segment_visual__timer >= nesting_swarm_snake_segment_visual__timeInterval
    nesting_swarm_snake_segment_visual__timer -= nesting_swarm_snake_segment_visual__timeInterval

  set_targets(nesting_swarm_snake_segment_visual__timer, nesting_swarm_snake_segment_visual__timeInterval,
              transform[3], nesting_swarm_snake_segment_visual__dir,
              nesting_swarm_snake_segment_visual__length, swarm__extraTargets)


[es(after=nesting_swarm_snake_segments_update, before=nesting_swarm_snake_segment_visual_client)]
def nesting_swarm_snake_segment_update_client(act : ParallelUpdateFrameDelayed;
                                              nesting_swarm_snake_segment__snakeEid : EntityId;
                                              nesting_swarm_snake_segment__dir : float3;
                                              nesting_swarm_snake_segment__visualEid : EntityId)
  query(nesting_swarm_snake_segment__snakeEid) <| $ [es] (nesting_swarm_snake__state : int)
    let isFly = (nesting_swarm_snake__state == int(NestingSwarmSnakeState.Fly)
              || nesting_swarm_snake__state == int(NestingSwarmSnakeState.Attack))
    query(nesting_swarm_snake_segment__visualEid) <| $ [es] (var nesting_swarm_snake_segment_visual__dir : float3&;
                                                             var swarm__moveSpeed : float&;
                                                             var swarm__rotSpeed : float&;
                                                             nesting_swarm_snake_segment_visual__nestSwarmMoveSpeed : float;
                                                             nesting_swarm_snake_segment_visual__nestSwarmRotSpeed : float;
                                                             nesting_swarm_snake_segment_visual__flySwarmMoveSpeed : float;
                                                             nesting_swarm_snake_segment_visual__flySwarmRotSpeed : float;
                                                             nesting_swarm_snake_segment_visual__swarmMoveSpeedDeviation : float;
                                                             nesting_swarm_snake_segment_visual__swarmRotSpeedDeviation : float)
      nesting_swarm_snake_segment_visual__dir = nesting_swarm_snake_segment__dir

      assume nestSwarmMoveSpeed = nesting_swarm_snake_segment_visual__nestSwarmMoveSpeed
      assume nestSwarmRotSpeed = nesting_swarm_snake_segment_visual__nestSwarmRotSpeed
      assume flySwarmMoveSpeed = nesting_swarm_snake_segment_visual__flySwarmMoveSpeed
      assume flySwarmRotSpeed = nesting_swarm_snake_segment_visual__flySwarmRotSpeed

      var requiredMoveSpeed = isFly ? flySwarmMoveSpeed : nestSwarmMoveSpeed
      var requiredRotSpeed = isFly ? flySwarmRotSpeed : nestSwarmRotSpeed

      requiredMoveSpeed += nesting_swarm_snake_segment_visual__swarmMoveSpeedDeviation * requiredMoveSpeed
      requiredRotSpeed += nesting_swarm_snake_segment_visual__swarmRotSpeedDeviation * requiredRotSpeed

      let dt = min_30_fps_dt(act.dt)
      swarm__moveSpeed = lerp(swarm__moveSpeed, requiredMoveSpeed, dt)
      swarm__rotSpeed = lerp(swarm__rotSpeed, requiredRotSpeed, dt)


[es(tag=gameClient, track=nesting_swarm_snake__state, on_appear)]
def nesting_swarm_snake_track_state_client(evt : Event;
                                           eid : EntityId;
                                           nesting_swarm_snake__state : int;
                                           nesting_swarm_snake__nestSegmentLengthMin : float;
                                           nesting_swarm_snake__nestSegmentLengthDesired : float;
                                           nesting_swarm_snake__nestSegmentLengthMax : float;
                                           nesting_swarm_snake__flySegmentLengthMin : float;
                                           nesting_swarm_snake__flySegmentLengthDesired : float;
                                           nesting_swarm_snake__flySegmentLengthMax : float;
                                           nesting_swarm_snake__holeFxsTemplate : string;
                                           nesting_swarm_snake_hole_fxs : Tag const?;
                                           var nesting_swarm_snake__targetSegmentLengthMin : float&;
                                           var nesting_swarm_snake__targetSegmentLengthDesired : float&;
                                           var nesting_swarm_snake__targetSegmentLengthMax : float&)
  if nesting_swarm_snake__state == int(NestingSwarmSnakeState.Nest)
    nesting_swarm_snake__targetSegmentLengthMin = nesting_swarm_snake__nestSegmentLengthMin
    nesting_swarm_snake__targetSegmentLengthDesired = nesting_swarm_snake__nestSegmentLengthDesired
    nesting_swarm_snake__targetSegmentLengthMax = nesting_swarm_snake__nestSegmentLengthMax
  elif (nesting_swarm_snake__state == int(NestingSwarmSnakeState.Fly) ||
      nesting_swarm_snake__state == int(NestingSwarmSnakeState.Attack))
    nesting_swarm_snake__targetSegmentLengthMin = nesting_swarm_snake__flySegmentLengthMin
    nesting_swarm_snake__targetSegmentLengthDesired = nesting_swarm_snake__flySegmentLengthDesired
    nesting_swarm_snake__targetSegmentLengthMax = nesting_swarm_snake__flySegmentLengthMax

  if nesting_swarm_snake__state == int(NestingSwarmSnakeState.Nest) && nesting_swarm_snake_hole_fxs != null
    removeSubTemplate(eid, nesting_swarm_snake__holeFxsTemplate)
  elif nesting_swarm_snake__state != int(NestingSwarmSnakeState.Nest) && nesting_swarm_snake_hole_fxs == null
    addSubTemplate(eid, nesting_swarm_snake__holeFxsTemplate)


[es(tag=gameClient, on_appear)]
def nesting_swarm_snake_hole_fxs_init(evt : Event;
                                      transform : float3x4;
                                      nesting_swarm_snake_hole_fxs__interval : float;
                                      nesting_swarm_snake_hole_fxs__holesInFxName : string;
                                      nesting_swarm_snake_hole_fxs__holesOutFxName : string;
                                      var nesting_swarm_snake_hole_fxs__timer : float&;
                                      var nesting_swarm_snake_hole_fxs__prevPos : float3&;
                                      var nesting_swarm_snake_hole_fxs__holesInFxType : int&;
                                      var nesting_swarm_snake_hole_fxs__holesOutFxType : int&)
  nesting_swarm_snake_hole_fxs__timer = nesting_swarm_snake_hole_fxs__interval
  nesting_swarm_snake_hole_fxs__prevPos = transform[3]

  nesting_swarm_snake_hole_fxs__holesInFxType = get_type_by_name(nesting_swarm_snake_hole_fxs__holesInFxName)
  nesting_swarm_snake_hole_fxs__holesOutFxType = get_type_by_name(nesting_swarm_snake_hole_fxs__holesOutFxName)


[es(tag=gameClient, no_order)]
def nesting_swarm_snake_hole_fxs_update(act : UpdateStageInfoAct;
                                        transform : float3x4;
                                        nesting_swarm_snake_hole_fxs__createSwarmTemplate : string;
                                        nesting_swarm_snake_hole_fxs__interval : float;
                                        nesting_swarm_snake_hole_fxs__holesInFxType : int&;
                                        nesting_swarm_snake_hole_fxs__holesOutFxType : int;
                                        var nesting_swarm_snake_hole_fxs__prevPos : float3&;
                                        var nesting_swarm_snake_hole_fxs__timer : float&)
  nesting_swarm_snake_hole_fxs__timer -= act.dt
  if nesting_swarm_snake_hole_fxs__timer <= 0.0
    nesting_swarm_snake_hole_fxs__timer += nesting_swarm_snake_hole_fxs__interval

    let curPos = transform[3]

    let deltaPos = curPos - nesting_swarm_snake_hole_fxs__prevPos
    let deltaPosLenSq = length_sq(deltaPos)
    if deltaPosLenSq > 1e-6
      let deltaPosLen = sqrt(deltaPosLenSq)
      let dir = deltaPos / deltaPosLen

      var t = deltaPosLen
      var norm : float3

      // Holes in
      if traceray_normalized(nesting_swarm_snake_hole_fxs__prevPos, dir, t,
                             norm, ETF_RI)
        let holePos = nesting_swarm_snake_hole_fxs__prevPos + dir * t

        var tm = IDENT_TM
        let fxPos = holePos + norm * 0.0001
        make_tm(dir_to_quat(norm), fxPos, tm)
        start_effect(nesting_swarm_snake_hole_fxs__holesInFxType,
                     tm, IDENT_TM, false)
        broadcastEvent(EventNesingSnakeCollided(holeIn = true, pos = holePos, dir = dir, norm = norm, templ = nesting_swarm_snake_hole_fxs__createSwarmTemplate))

      // Holes out
      t = deltaPosLen
      if traceray_normalized(curPos, -dir, t,
                             norm, ETF_RI)
        let holePos = curPos - dir * t

        var tm = IDENT_TM
        let fxPos = holePos + norm * 0.0001
        make_tm(dir_to_quat(norm), fxPos, tm)
        start_effect(nesting_swarm_snake_hole_fxs__holesOutFxType,
                     tm, IDENT_TM, false)
        broadcastEvent(EventNesingSnakeCollided(holeIn = false, pos = holePos, dir = dir, norm = norm, templ = nesting_swarm_snake_hole_fxs__createSwarmTemplate))

      nesting_swarm_snake_hole_fxs__prevPos = curPos


[es(tag=render, REQUIRE=eid)]
def disturb_nesting_snake_swarm_on_shot(evt : EventShot)
  nesting_swarm_snake_avoid_projectile(evt.launchDesc.tm[3], normalize(evt.launchDesc.vel))


[es(tag=render, REQUIRE=eid)]
def disturb_nesting_snake_swarm_on_net_shot(evt : CmdNetShot)
  nesting_swarm_snake_avoid_projectile(evt.tm[3], normalize(evt.vel))


def nesting_swarm_snake_avoid_projectile(pos, dir : float3)
  query() <| $ [es(REQUIRE=watchedByPlr)] (transform : float3x4; nesting_swarm_fx__maxDisturbedDstSq : float)
    if distance_sq(transform[3], pos) > nesting_swarm_fx__maxDisturbedDstSq
      return
    var t = -1.0
    query() <| $ [es] (transform : float3x4; nesting_swarm_snake__segmentEids : EidList)
      if distance_sq(transform[3], pos) < nesting_swarm_fx__maxDisturbedDstSq
        if t < .0
          t = sqrt(nesting_swarm_fx__maxDisturbedDstSq * 0.5)
          var norm : float3
          traceray_normalized(pos, dir, t, norm, ETF_ALL)
        for seid in nesting_swarm_snake__segmentEids
          var disturbPoint : float2
          var disturbStrength = .0
          query(seid) <| $ [es] (nesting_swarm_snake_segment__visualEid : EntityId)
            query(nesting_swarm_snake_segment__visualEid) <| $ [es] (transform : float3x4;
                                                                     swarm_cluster__radius : float;
                                                                     oscillating_swarm__side : float3;
                                                                     oscillating_swarm__forward : float3;
                                                                     oscillating_swarm__avoidMaxSpeed : float;
                                                                     var oscillating_swarm__avoidSpeed : float&;
                                                                     var oscillating_swarm__avoidPoint : float2&;
                                                                     var oscillating_swarm__avoidRadius : float&)
              let denominator = dot(dir, oscillating_swarm__forward)
              if abs(denominator) > 1e-6
                let numerator = dot(transform[3] - pos, oscillating_swarm__forward)
                let u = numerator / denominator
                if u > 0.0
                  let intersectionPoint = pos + dir * u
                  let distanceToCenterSq = distance_sq(intersectionPoint, transform[3])
                  if distanceToCenterSq < square(swarm_cluster__radius * 2.0) && distanceToCenterSq < square(u)
                    let side2 = cross(oscillating_swarm__forward, oscillating_swarm__side)
                    let reIntersection = intersectionPoint - transform[3]
                    let oldAvoidPoint = oscillating_swarm__avoidPoint
                    oscillating_swarm__avoidPoint = float2(dot(reIntersection, oscillating_swarm__side), dot(reIntersection, side2))
                    if oscillating_swarm__avoidRadius > .0
                      oscillating_swarm__avoidPoint = (oscillating_swarm__avoidPoint + oldAvoidPoint) * 0.5
                    oscillating_swarm__avoidRadius = max(.0, oscillating_swarm__avoidRadius)
                    oscillating_swarm__avoidSpeed = oscillating_swarm__avoidMaxSpeed
                    disturbPoint = oscillating_swarm__avoidPoint
                    disturbStrength = 1.0
                    return
              if disturbStrength > .0
                disturbStrength *= 0.9
                let oldAvoidPoint = oscillating_swarm__avoidPoint
                oscillating_swarm__avoidPoint = disturbPoint
                if oscillating_swarm__avoidRadius > .0
                  oscillating_swarm__avoidPoint = (oscillating_swarm__avoidPoint + oldAvoidPoint) * 0.5
                oscillating_swarm__avoidRadius = max(.0, oscillating_swarm__avoidRadius)
                oscillating_swarm__avoidSpeed = oscillating_swarm__avoidMaxSpeed * disturbStrength


[es(tag=gameClient, on_appear)]
def init_oscillating_swarm_avoid_radius(evt : Event;
                                        var oscillating_swarm__avoidMaxRadius : float&;
                                        oscillating_swarm__avoidMaxSpeed : float;
                                        oscillating_swarm__avoidAccel : float)
  let multipleBulletsCorrection = 2.0 //In case the swarm is disturbed while already disturbed
  //Calculate how large the radius can get given starting speed and accel
  oscillating_swarm__avoidMaxRadius = square(oscillating_swarm__avoidMaxSpeed) / 2.0 / abs(oscillating_swarm__avoidAccel) * multipleBulletsCorrection


[es(tag=gameClient, REQUIRE=watchedByPlr)]
def spawn_surface_runners_when_colliding(evt : EventNesingSnakeCollided; transform : float3x4; nesting_swarm_fx__maxRunnerDstSq : float)
  if distance_sq(transform[3], evt.pos) > nesting_swarm_fx__maxRunnerDstSq
    return
  var tm = IDENT_TM
  createEntity(evt.templ) <| $(var init)
    tm[1] = -evt.dir
    tm[0] = get_normal(tm[1])
    tm[2] = cross(tm[0], tm[1])
    tm[3] = evt.pos + evt.norm * 0.1
    init |> set("transform", tm)


[es(tag=gameClient, on_appear)]
def init_surface_runner_swarm_on_appear(evt : Event;
                                        eid : EntityId;
                                        surface_runner_swarm__spawnCount : int2;
                                        swarm__boidTemplateName : string;
                                        transform : float3x4;
                                        var surface_runner_swarm__activeRunnersCount : int&;
                                        var swarmIdx : int&)
  if swarmIdx < 0
    swarmIdx = new_swarm_index()
  surface_runner_swarm__activeRunnersCount = rnd_int(surface_runner_swarm__spawnCount)
  for _ in range(surface_runner_swarm__activeRunnersCount)
    let angle = PI * 2.0 * gfrnd()
    var s, c : float
    sincos(angle, s, c)

    createEntity(swarm__boidTemplateName) <| $(var init)
      init |> set("position", transform[3])
      init |> set("boid_state", 0)
      init |> set("parentSwarm", eid)
      init |> set("parentSwarmIdx", swarmIdx)
      init |> set("surface_crawler__seed", grnd())
      init |> set("surface_crawler__dir", float3(s, .0, c))
      init |> set("surface_crawler__norm", transform[1])
      init |> set("surface_crawler__head", transform[3])
      init |> set("surface_crawler__active", true)
  if surface_runner_swarm__activeRunnersCount <= 0
    destroyEntity(eid)


def new_swarm_index()
  var currentSwarmIdxs : array<int>
  query() <| $ [es] (swarmIdx : int)
    if swarmIdx >= 0
      currentSwarmIdxs |> push(swarmIdx)
  currentSwarmIdxs |> sort()

  for i in iter_range(currentSwarmIdxs)
    if currentSwarmIdxs[i] != i
      return i
  return length(currentSwarmIdxs)


[es(tag=gameClient, on_disappear, REQUIRE=nesting_snake_runner__lifeDuration)]
def on_nesting_surface_runner_died(evt : Event; parentSwarm : EntityId)
  query(parentSwarm) <| $ [es] (var surface_runner_swarm__activeRunnersCount : int&)
    surface_runner_swarm__activeRunnersCount--
    if surface_runner_swarm__activeRunnersCount <= 0
      destroyEntity(parentSwarm)


[es(tag=gameClient, on_appear)]
def init_nesting_snake_runner(evt : Event;
                              nesting_snake_runner__lifeDuration : float;
                              nesting_snake_runner__buryDuration : float;
                              var nesting_snake_runner__buryAt : float&;
                              var nesting_snake_runner__killAt : float&)
  nesting_snake_runner__killAt = get_sync_time() + nesting_snake_runner__lifeDuration
  nesting_snake_runner__buryAt = nesting_snake_runner__killAt - nesting_snake_runner__buryDuration


[es(tag=gameClient, no_order)]
def surface_runner_update(act : UpdateStageInfoAct;
                          eid : EntityId;
                          var position : float3&;
                          surface_crawler__lookDown : float3;
                          surface_crawler__lookAhead : float2 = float2(0.15, 0.4);
                          surface_crawler__curvePerSecond : float = 4.0;
                          surface_crawler__curvePerSecondRnd : float = 1.0;
                          surface_crawler__rndInfluence : float = 10.0;
                          surface_crawler__maxFrustration : int = 10;
                          nesting_snake_runner__buryAt : float;
                          nesting_snake_runner__killAt : float;
                          nesting_snake_runner__lifeDuration : float;
                          nesting_snake_runner__buryDuration : float;
                          nesting_snake_runner__buryOffset : float3;
                          nesting_snake_runner__speed : float2;
                          var orientation_quat : vec4f&;
                          var surface_crawler__offset : float3&;
                          var surface_crawler__speed : float&;
                          var surface_crawler__matId : int&;
                          var surface_crawler__frustration : int&;
                          var surface_crawler__seed : int&;
                          var surface_crawler__head : float3&;
                          var surface_crawler__dir : float3&;
                          var surface_crawler__norm : float3&;
                          var surface_crawler__active : bool&)
  if act.curTime > nesting_snake_runner__killAt || !surface_crawler__active
    destroyEntity(eid)

  let speedRatio = clamp((nesting_snake_runner__killAt - act.curTime) / nesting_snake_runner__lifeDuration, 0.0, 1.0)
  surface_crawler__speed = lerp(nesting_snake_runner__speed.y, nesting_snake_runner__speed.x, speedRatio)
  let buryRatio = clamp((act.curTime - nesting_snake_runner__buryAt) / nesting_snake_runner__buryDuration, 0.0, 1.0)
  surface_crawler__offset = nesting_snake_runner__buryOffset * buryRatio

  surface_crawler_update(act.dt,
                          surface_crawler__lookAhead,
                          surface_crawler__lookDown,
                          surface_crawler__curvePerSecond,
                          surface_crawler__curvePerSecondRnd,
                          surface_crawler__rndInfluence,
                          surface_crawler__speed,
                          surface_crawler__maxFrustration,
                          surface_crawler__frustration,
                          surface_crawler__seed,
                          surface_crawler__head,
                          surface_crawler__dir,
                          surface_crawler__norm,
                          surface_crawler__matId,
                          surface_crawler__active) <| $ [unused_argument(riDesc)] (riDesc : RendInstDesc){}
  position = (surface_crawler__head +
              surface_crawler__dir * surface_crawler__offset.x +
              surface_crawler__norm * surface_crawler__offset.y +
              cross(surface_crawler__dir, surface_crawler__norm) * surface_crawler__offset.z)
  let north = float3(1, 0, 0)
  orientation_quat = float4(quat_rotation_arc(north, surface_crawler__dir))