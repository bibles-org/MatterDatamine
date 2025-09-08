require ecs
require ecs.common
require app
require net
require strings
require math.base
require math.random
require math.easing
require Dacoll
require DagorMath
require DagorSystem
require DngNet
require pathfinder
require fx
require math.maybe_pos
require game.es.grav_zones_common
require game.es.ai.agent_position_mapping_common
require game.es.am_debug_draw_common
require game.es.am_mimic_common
require game.events.events_game
require game.events.events_active_matter


let am_mimic__maxLegLength = 0.7
let minSpeed = 0.05

enum LegBehMode
  DEAD
  GROW
  STAY
  DIE
  HYNERNATE

def calc_spring_k(tau, delta : float)
  return square(PI / 2.0 / tau) + square(-log(delta) / tau)

def calc_damping(tau, delta : float)
  return -2.0 * log(delta) / tau


[es(tag=gameClient, on_appear)]
def init_am_mimic_leg(evt : Event;
                      spike_leg__agilityRange : float2;
                      spike_leg__branchCount = 3;
                      spike_leg__branchTemplate : string;
                      var spike_leg__agility : float&;
                      var spike_leg__branches : EidList)
  spike_leg__agility = rnd_float(spike_leg__agilityRange)
  let pos = float3(2000, -2000, 2000)
  for _ in range(spike_leg__branchCount)
    let e = createEntity(spike_leg__branchTemplate) <| $(var init)
      init |> set("spike_leg__noisePhase", 1000.0 * gfrnd())
      using() <| $(var points : Point3List)
        points |> push(pos + float3(1, 1, 1))
        points |> push(pos + float3(2, 2, 2))
        init |> set("spline_gen_geometry__points", points)
        var tm = IDENT_TM
        tm[3] = pos + float3(1, 1, 1)
        init |> set("transform", tm)
    spike_leg__branches |> push(e)


[es(tag=gameClient, on_appear)]
def init_am_mimic_branch(evt : Event; spline_gen_geometry__points : Point3List; var effect : TheEffect; var transform : float3x4)
  transform[3] = spline_gen_geometry__points[0]
  effect_set_emitter_tm(effect, transform)


[es(tag=gameClient, REQUIRE=am_mimic)]
def am_mimic_died_client(evt : EventEntityDied;
                         transform : float3x4;
                         am_mimic__clientDeathDelay : float;
                         var am_mimic__clientDeathAt : float&;
                         var am_mimic__visualVel : float3&)
  am_mimic__clientDeathAt = get_sync_time() + am_mimic__clientDeathDelay
  am_mimic__visualVel += transform[1] //prevent from falling under ground too quickly


[es(tag=gameClient, REQUIRE=deadEntity, no_order)]
def am_mimic_death_client_es(act : UpdateStageInfoAct;
                             transform : float3x4;
                             am_mimic__clientDeathAt : float;
                             am_mimic__deathTemplate : string;
                             var animchar_render__enabled : bool&;
                             var am_mimic__deathCreated : bool&)
  if !am_mimic__deathCreated && am_mimic__clientDeathAt < act.curTime
    am_mimic__deathCreated = true
    animchar_render__enabled = false
    createEntity(am_mimic__deathTemplate) <| $(var init)
      init |> set("transform", transform)


[es(tag=gameClient, on_appear)]
def init_am_mimic(evt : Event;
                  transform : float3x4;
                  am_mimic__radius : float;
                  am_mimic__innerRadius : float;
                  am_mimic__dampingTau = float2(0.17, 0.15);
                  am_mimic__dampingDelta = float2(0.5, 0.9);
                  am_mimic__flyingDampingTau = 0.09;
                  am_mimic__flyingDampingDelta = 0.85;
                  am_mimic__legTemplate : string;
                  var alt_transform : float3x4&;
                  var last_frame_transform : float3x4&;
                  var am_mimic__flyingSpringK : float&;
                  var am_mimic__flyingDamping : float&;
                  var am_mimic__springK : float2&;
                  var am_mimic__damping : float2&;
                  var nphys_levitating__elevation : float&;
                  var nphys_levitating__prefferedElevation : float&;
                  var am_mimic__visualPos : float3&;
                  var am_mimic__legs : EidList;
                  var am_mimic__attachPoints : Point3List)
  alt_transform := transform
  last_frame_transform := transform
  nphys_levitating__elevation = am_mimic__radius
  nphys_levitating__prefferedElevation = am_mimic__radius
  am_mimic__visualPos = transform[3] + transform[1] * am_mimic__radius
  let defLegs <- generate_directions_N_fibonacci(rnd_int(18, 24))
  for l in defLegs
    if dot(l, transform[1]) < .1
      am_mimic__attachPoints |> push(l * am_mimic__innerRadius)
      let leid = createEntity(am_mimic__legTemplate)
      am_mimic__legs |> push(leid)

  am_mimic__springK.x = calc_spring_k(am_mimic__dampingTau.x, am_mimic__dampingDelta.x)
  am_mimic__damping.x = calc_damping(am_mimic__dampingTau.x, am_mimic__dampingDelta.x)
  am_mimic__springK.y = calc_spring_k(am_mimic__dampingTau.y, am_mimic__dampingDelta.y)
  am_mimic__damping.y = calc_damping(am_mimic__dampingTau.y, am_mimic__dampingDelta.y)
  am_mimic__flyingSpringK = calc_spring_k(am_mimic__flyingDampingTau, am_mimic__flyingDampingDelta)
  am_mimic__flyingDamping = calc_damping(am_mimic__flyingDampingTau, am_mimic__flyingDampingDelta)


[es(tag=gameClient, on_disappear)]
def destroy_am_mimic(evt : Event; am_mimic__legs, am_mimic__tentacles : EidList)
  for e in am_mimic__legs
    destroyEntity(e)
  for e in am_mimic__tentacles
    destroyEntity(e)


[es(tag=gameClient, on_disappear)]
def destroy_am_mimic_leg(evt : Event; spike_leg__branches : EidList)
  for e in spike_leg__branches
    destroyEntity(e)


[es(tag=gameClient, on_appear)]
def create_visual_tentacle(evt : Event;
                           eid, am_mimic_attack__am_mimicEid : EntityId;
                           am_mimic_attack__dir : float3;
                           am_mimic_attack__stamp : float;
                           am_mimic_attack__at : float)
  query(am_mimic_attack__am_mimicEid) <| $ [es] (var am_mimic__tentacles : EidList;
                                                 transform : float3x4;
                                                 am_mimic__tentacleTemplate : string;
                                                 am_mimic__innerRadius : float)
    let idx = length(am_mimic__tentacles)
    if idx == 0 //New attack sequence queued
      sendEvent(am_mimic_attack__am_mimicEid, EventMimicAttackPrepare())
    let newEid = createEntity(am_mimic__tentacleTemplate) <| $(var init)
      init |> set("am_mimic_tentacle__attackEid", eid)
      init |> set("am_mimic_tentacle__dir", am_mimic_attack__dir)
      init |> set("am_mimic_tentacle__stamp", am_mimic_attack__stamp)
      init |> set("am_mimic_tentacle__at", am_mimic_attack__at)
      let agility = float(idx) * 0.1 + rnd_float(0.0, 0.75)
      init |> set("am_mimic_tentacle__agility", min(1.0, agility))
      let v = normalize(float3(1, 0, 0) * gfrnd() + float3(0, 0, 1) * gfrnd() + float3(0, 1, 0))
      init |> set("am_mimic_tentacle__base", v)
      using() <| $ [es] (var points : Point3List)
        points |> push(transform[3])
        points |> push(transform[3] + v * am_mimic__innerRadius)
        init |> set("spline_gen_geometry__points", points)
    am_mimic__tentacles |> push(newEid)


[es(tag=gameClient, track=am_mimic_attack__dir)]
def update_visual_tentacle_dir(evt : Event; eid : EntityId; am_mimic_attack__dir : float3)
  find_query() <| $ [es] (am_mimic_tentacle__attackEid : EntityId; var am_mimic_tentacle__dir : float3&)
    if am_mimic_tentacle__attackEid == eid
      am_mimic_tentacle__dir = am_mimic_attack__dir
      return true
    return false


[es(tag=gameClient, after=(update_nphys_levitation, apply_transform_from_snapshots, beh_tree_update_es))]
def am_mimic_anim_es(act : UpdateStageInfoAct; camera__active : bool; transform aka cam_transform : float3x4)
  if camera__active
    let isServer = is_server()
    query() <| $ [es] (eid : EntityId;
                       am_mimic__springK : float2;
                       am_mimic__damping : float2;
                       am_mimic__attachPoints : Point3List;
                       am_mimic__legMinInterval : float;
                       am_mimic__traceMinInterval : float;
                       am_mimic__expectedSupport : float;
                       //am_mimic__flyingSpringK : float;
                       //am_mimic__flyingDamping : float;
                       navmesh_phys__upDir : float3;
                       walker_agent__climbingTo : float3;
                       walker_agent__climbingFinish : float;
                       nphys_levitating__elevation : float;
                       am_mimic_attack__reach : float;
                       var am_mimic__avgSupport : float&;
                       var am_mimic__supportFrom : float&;
                       var am_mimic__lastLegStamp : float&;
                       var am_mimic__lastTraceStamp : float&;
                       var am_mimic__visualPos : float3&;
                       var am_mimic__visualVel : float3&;
                       var am_mimic__axis : float3&;
                       var am_mimic__up : float3&;
                       var am_mimic__supportOffset : float3&;
                       //var am_mimic__locoUp : float3&;
                       var am_mimic__lastMove : float3&;
                       var am_mimic__lastPos : float3&;
                       var am_mimic__currentSpeed : float&;
                       var am_mimic__lastSpeed : float&;
                       var am_mimic__legs : EidList;
                       var am_mimic__tentacles : EidList;
                       var am_mimic__activeLegCount : int&;
                       var am_mimic__hidden : bool&;
                       var transform aka s_transform : float3x4;
                       var last_frame_transform : float3x4;
                       var walker_agent__climbExpected : bool&;
                       walker_agent__climbingFrom : float3;
                       alt_transform : float3x4;
                       navmesh_phys__maxWalkSpeed : float;
                       irratic_walk__speedSave : float;
                       deadEntity : Tag const?;
                       sleeping_monster : Tag const?)
      if !isServer
        s_transform := alt_transform
      am_mimic__hidden = false
      let v = s_transform[3] - cam_transform[3]
      //draw_debug_sphere_buffered(s_transform[3], 0.5, ACWHITE, 12, 1)
      let dst2Cam = length(v)
      if dst2Cam < 40.0 || dst2Cam < 150.0 && dot(cam_transform[2], v * safeinv(dst2Cam)) > 0.5 //in field of vision
        let isDead = deadEntity != null
        //draw_debug_ball_buffered(s_transform[3], -am_mimic__innerRadius, ATTYELLOW, 1)
        let move = s_transform[3] - am_mimic__lastPos
        let moveLn = length(move)
        if moveLn > 0.0005
          am_mimic__lastMove = normalize(move)
          am_mimic__lastPos = s_transform[3]
        if act.dt > FLT_EPSILON
          am_mimic__lastSpeed = am_mimic__currentSpeed
          if am_mimic__currentSpeed < minSpeed
            am_mimic__supportFrom = act.curTime
            am_mimic__avgSupport = .0
          am_mimic__currentSpeed = clamp(moveLn / act.dt / navmesh_phys__maxWalkSpeed, .0, 1.0)
        //draw_debug_text_mark_buffered(s_transform[3], "{pty(am_mimic__currentSpeed)}", 1)
        let irraticalDashFactor = clamp(safediv(navmesh_phys__maxWalkSpeed, irratic_walk__speedSave), 1.0, 3.0)

        am_mimic__axis = normalize(cross(s_transform[1], am_mimic__lastMove))
        let newUp = sleeping_monster != null ? navmesh_phys__upDir : normalize(cross(am_mimic__lastMove, am_mimic__axis))
        let newUpGrad = approach(am_mimic__up, newUp, act.dt, 0.1)
        am_mimic__up = normalize(newUpGrad)

        let gravDir = get_grav_dir(s_transform[3])
        //print("akiska {am_mimic__springK} | {am_mimic__damping}")
        let climbindForecast = walker_agent__climbingTo + navmesh_phys__upDir * nphys_levitating__elevation
        let earlyFlightMode = walker_agent__climbingFinish > act.curTime //TDO: take snapshot time into account
        let dstToLanding = earlyFlightMode ? distance(s_transform[3], climbindForecast) : .0
        let flightDst = 7.0
        let flightMode = earlyFlightMode && dstToLanding  < flightDst
        let flightHeightVec = s_transform[3] - climbindForecast
        let flightHeight = navmesh_phys__upDir * dot(flightHeightVec, navmesh_phys__upDir)
        if walker_agent__climbExpected && !flightMode
          let maxPrepareDst = 3.0
          let distanceToTakeeOff = clamp(distance(s_transform[3], walker_agent__climbingFrom) - 0.3, .0, maxPrepareDst)
          let jumpPreparationRatio = square(max(.0, 1.0 - distanceToTakeeOff / maxPrepareDst))
          am_mimic__visualVel -= navmesh_phys__upDir * jumpPreparationRatio * 50.0 * act.dt
          //draw_debug_text_mark_buffered(s_transform[3], "{pty(jumpPreparationRatio)}", 1)
        if !earlyFlightMode
          process_damping(min(act.dt, 0.1), s_transform[3] + am_mimic__supportOffset, gravDir, am_mimic__springK, am_mimic__damping, am_mimic__visualPos, am_mimic__visualVel)
        else
          let climbing = climbindForecast - s_transform[3]
          let horClimbing = normalize(climbing - navmesh_phys__upDir * dot(climbing, navmesh_phys__upDir))
          let landingMove = -navmesh_phys__upDir + horClimbing * 3.0
          am_mimic__lastMove = normalize(landingMove)
          //draw_debug_arrow_buffered(climbindForecast - am_mimic__lastMove, climbindForecast, ACMAGENTA, 1)
          //let posDiscrepancy = s_transform[3] + am_mimic__supportOffset - am_mimic__visualPos
          //let speedMag = length(am_mimic__visualVel)
          //am_mimic__visualVel += normalize(posDiscrepancy) * speedMag
          //let speedMag2 = length(am_mimic__visualVel)
          //let discrepancyMag = length(posDiscrepancy)
          am_mimic__visualPos = s_transform[3] + am_mimic__supportOffset
          am_mimic__visualVel = float3()
          //  speedMag2 * 0.5
          //process_damping(min(act.dt, 0.1), s_transform[3] + am_mimic__supportOffset, gravDir, float2(am_mimic__flyingSpringK), float2(am_mimic__flyingDamping), //am_mimic__visualPos, am_mimic__visualVel)
          //am_mimic__lastLegStamp = .0
        if sleeping_monster != null
          am_mimic__visualPos = s_transform[3]
          am_mimic__visualVel = float3()
        s_transform[3] = am_mimic__visualPos
        //draw_debug_sphere_buffered(s_transform[3], 0.5, ACWHITE, 12, 1)
        var traceTm = s_transform
        if earlyFlightMode
          walker_agent__climbExpected = false
          traceTm[3] = climbindForecast
        assume rootTm = last_frame_transform
        var m = length(am_mimic__tentacles)
        while m-- > 0
          query(am_mimic__tentacles[m]) <| $ [es] (am_mimic_tentacle__dir : float3;
                                                   am_mimic_tentacle__stamp : float;
                                                   am_mimic_tentacle__at : float;
                                                   am_mimic_tentacle__agility : float;
                                                   am_mimic_tentacle__base : float3;
                                                   var am_mimic_tentacle__to : float3&;
                                                   var spline_gen_geometry__points : Point3List&)
            let startFreeze = am_mimic_tentacle__stamp + (am_mimic_tentacle__at - am_mimic_tentacle__stamp) * 0.6
            let startLunge = am_mimic_tentacle__stamp + (am_mimic_tentacle__at - am_mimic_tentacle__stamp) * 0.9
            let startRetract = am_mimic_tentacle__at + 0.05
            let endRetract = am_mimic_tentacle__at + 0.5
            let visualReach = am_mimic_attack__reach * 0.9
            let growReachMult = 0.5
            var p1, p2 : float3
            let windUpRatio = 0.5
            let growDir = normalize(am_mimic_tentacle__base - am_mimic_tentacle__dir * windUpRatio)
            if act.curTime < startFreeze //GROW
              let tWind = outCubic((startLunge - act.curTime) / (startLunge - am_mimic_tentacle__stamp))
              let windDir = normalize(am_mimic_tentacle__base - am_mimic_tentacle__dir * lerp(windUpRatio, .0, tWind))
              //draw_debug_text_mark_buffered(am_mimic_tentacle__to, "GR tw {pty(tWind)}", 1)
              let len = cvt(act.curTime, am_mimic_tentacle__stamp, startFreeze, .01, visualReach * growReachMult)
              let p1s = windDir * 0.33 * len
              let p2s = windDir * 0.66 * len
              let (p1n, p2n) = get_growing_bezier(windDir, am_mimic_tentacle__dir, am_mimic_tentacle__agility)
              am_mimic_tentacle__to = rootTm[3] + windDir * len
              let t = outQuad((act.curTime - am_mimic_tentacle__stamp) / (startFreeze - am_mimic_tentacle__stamp))
              p1 = lerp(p1s, p1n, t) * len
              p2 = lerp(p2s, p2n, t) * len
            elif act.curTime < startLunge //FREEZE
              let tWind = outCubic((startLunge - act.curTime) / (startLunge - am_mimic_tentacle__stamp))
              //draw_debug_text_mark_buffered(am_mimic_tentacle__to, "FR tw {pty(tWind)}", 1)
              let windDir = normalize(am_mimic_tentacle__base - am_mimic_tentacle__dir * lerp(windUpRatio, .0, tWind))
              let len = visualReach * growReachMult
              let (p1n, p2n) = get_growing_bezier(windDir, am_mimic_tentacle__dir, am_mimic_tentacle__agility)
              am_mimic_tentacle__to = rootTm[3] + windDir * len
              p1 = p1n * len
              p2 = p2n * len
            elif act.curTime < am_mimic_tentacle__at //LUNGE
              //draw_debug_text_mark_buffered(am_mimic_tentacle__to, "LG", 1)
              let t = (am_mimic_tentacle__at - act.curTime) / (am_mimic_tentacle__at - startLunge)
              let reach = lerp(visualReach, visualReach * growReachMult, t)
              let (p1ng, p2ng) = get_growing_bezier(growDir, am_mimic_tentacle__dir, am_mimic_tentacle__agility)
              let (p1nl, p2nl) = get_lunging_bezier(growDir, am_mimic_tentacle__dir, am_mimic_tentacle__agility)
              let from = rootTm[3] + growDir * reach
              let to = rootTm[3] + am_mimic_tentacle__dir * reach
              am_mimic_tentacle__to = to * (1.0 - t) + from * t
              let tsq = sqrt(t)
              p1 = (p1nl * (1.0 - tsq) + p1ng * tsq) * reach
              p2 = (p2nl * (1.0 - tsq) + p2ng * tsq) * reach
              am_mimic__visualVel -= am_mimic_tentacle__dir * act.dt * 50.0
            elif act.curTime < startRetract //STAY at lunge
              let (p1n, p2n) = get_lunging_bezier(growDir, am_mimic_tentacle__dir, am_mimic_tentacle__agility)
              am_mimic_tentacle__to = rootTm[3] + am_mimic_tentacle__dir * visualReach
              p1 = p1n * visualReach
              p2 = p2n * visualReach
            elif act.curTime < endRetract //RETRACT
              let t = sqrt(cvt(act.curTime, startRetract, endRetract, 1.0, 0.01))
              let (p1n, p2n) = get_lunging_bezier(growDir, am_mimic_tentacle__dir, am_mimic_tentacle__agility)
              let (p1n2, p2n2) = get_lunging_bezier2(growDir, am_mimic_tentacle__dir)
              let retractDir = am_mimic_tentacle__dir + growDir * (1.0 - t) * 0.3
              am_mimic_tentacle__to = rootTm[3] + retractDir * t * visualReach
              p1 = lerp(p1n2, p1n, t) * t * visualReach
              p2 = lerp(p2n2, p2n, t) * t * visualReach
            else
              let (p1n, p2n) = get_lunging_bezier(growDir, am_mimic_tentacle__dir, am_mimic_tentacle__agility)
              p1 = p1n * 0.01
              p2 = p2n * 0.01
              destroyEntity(am_mimic__tentacles[m])
              am_mimic__tentacles |> erase(m)
            //draw_debug_sphere_buffered(rootTm[3] + p1, 0.06, ACWHITE, 12, 1)
            //draw_debug_sphere_buffered(rootTm[3] + p2, 0.06, ACCYAN, 12, 1)
            draw_attack_tentacle(rootTm[3], am_mimic_tentacle__to, rootTm[3] + p1, rootTm[3] + p2, spline_gen_geometry__points)

        var h = 120.0
        let step = 17.0
        var support = .0
        var avgDir : float3
        var activeLegCount = 0
        //draw_debug_ball_buffered(rootTm[3], 0.10, ACYELLOW, 1)
        //draw_debug_ball_buffered(rootTm[3], -0.10, ACYELLOW, 1)
        //draw_debug_ball_buffered(s_transform[3], 0.09, ACINDI, 1)
        //draw_debug_ball_buffered(s_transform[3], -0.09, ACINDI, 1)
        //draw_debug_text_mark_buffered(rootTm[3], "{pty(am_mimic__currentSpeed)}", 1)
        for e, i in am_mimic__legs, iter_range(am_mimic__legs)
          query(e) <| $ [es] (var spike_leg__from : float3&;
                              var spike_leg__to : float3&;
                              var spike_leg__norm : float3&;
                              var spike_leg__len : float&;
                              var spike_leg__lastDst : float&;
                              var spike_leg__stamp : float&;
                              var spike_leg__kneeFactor : float&;
                              var spike_leg__mode : int&;
                              var spike_leg__strainTime : float&;
                              var spike_leg__toIsLanding : bool&;
                              spike_leg__branches : EidList;
                              spike_leg__noiseSpeed : float = 1.0;
                              spike_leg__noiseAmplitude : float = 0.2;
                              spike_leg__agility : float;
                              spike_leg__speed = 10.0;
                              spike_leg__sideFactor = 72.0;
                              spike_leg__maxLen = 2.1)
            //add_debug_text_mark_screen(80.0, h, "{spike_leg__mode}", -1, 0.f, E3DCOLOR(0xffffffff))
            //draw_debug_text_mark_buffered(spike_leg__from, "{to_enum(spike_leg__mode, LegBehMode.DEAD)}", 1)
            let effectiveMaxLen = flightMode ? spike_leg__maxLen * sqrt(spike_leg__agility) : spike_leg__maxLen
            h += step
            let efrnd = eid_frnd(e)
            let spd = spike_leg__speed * (0.8 + efrnd * 0.4) * (isDead ? 0.5 : 1.0)
            spike_leg__from = rootTm * am_mimic__attachPoints[i]
            let traceFrom = flightMode ? traceTm * am_mimic__attachPoints[i] : spike_leg__from
            let sleepingIntervalMult = sleeping_monster != null ? 5.0 : 1.0

            if isDead
              spike_leg__mode = int(LegBehMode.DIE)

            // DEAD
            if spike_leg__mode == int(LegBehMode.DEAD)
              if am_mimic__activeLegCount >= length(am_mimic__legs) - 4
                spike_leg__mode = int(LegBehMode.HYNERNATE)
                spike_leg__stamp = act.curTime
              let interval = (flightMode ? am_mimic__legMinInterval * 0.75 : am_mimic__legMinInterval) / irraticalDashFactor
              if act.curTime - am_mimic__lastLegStamp > interval && act.curTime - am_mimic__lastTraceStamp > am_mimic__traceMinInterval
                var front : float3
                let isSlowingDown = am_mimic__currentSpeed < 0.7 && am_mimic__currentSpeed < am_mimic__lastSpeed
                if isSlowingDown || flightMode && i % 2 == 0
                  front = find_largest_gap(am_mimic__legs, rootTm[3], navmesh_phys__upDir)
                  if flightMode
                    front = normalize(front - navmesh_phys__upDir * 0.5)
                else
                  front = am_mimic__currentSpeed > minSpeed ? am_mimic__lastMove : rnd_dir(am_mimic__attachPoints[i], act.curTime)
                am_mimic__lastTraceStamp = act.curTime
                let side = am_mimic__axis * dot(spike_leg__from - rootTm[3], am_mimic__axis)
                let flightSideMult = flightMode ? spike_leg__sideFactor * 1.5 : spike_leg__sideFactor
                let dirs = array<float3>(normalize(front * 2.5 * irraticalDashFactor - am_mimic__up * 0.6 + side * am_mimic__currentSpeed * flightSideMult),
                                        normalize(front * 1.8 * irraticalDashFactor - am_mimic__up * 0.8 + side * am_mimic__currentSpeed * flightSideMult),
                                        normalize(front * 1.2 * irraticalDashFactor - am_mimic__up * 0.8 + side * am_mimic__currentSpeed * flightSideMult))
                for dir in dirs
                  var t = spike_leg__maxLen * (0.75 + am_mimic__currentSpeed)
                  if traceray_normalized(traceFrom, dir, t, spike_leg__norm, ETF_ALL)
                    spike_leg__to = traceFrom + dir * t
                    spike_leg__toIsLanding = flightMode
                    spike_leg__mode = int(LegBehMode.GROW)
                    spike_leg__len = .0
                    spike_leg__lastDst = t
                    am_mimic__lastLegStamp = act.curTime
                    spike_leg__kneeFactor = .0
                    spike_leg__strainTime = .0
                    break
                  //else
                  //  draw_debug_line_buffered(traceFrom, traceFrom + dir * t, flightMode ? ACYELLOW : ACINDI, 100)
                if spike_leg__mode == int(LegBehMode.DEAD)
                  spike_leg__mode = int(LegBehMode.HYNERNATE)
                  spike_leg__stamp = act.curTime
              //else
              //  draw_debug_text_mark_buffered(spike_leg__from + meter * 0.2, "{pty(am_mimic__lastLegStamp + am_mimic__legMinInterval - act.curTime)}", 1)

            // GROW
            elif spike_leg__mode == int(LegBehMode.GROW)
              activeLegCount++
              let dst = distance(spike_leg__from, spike_leg__to)
              //let dststr = "{pty(dst)} vs {pty(spike_leg__lastDst)}"
              //draw_debug_text_mark_buffered((spike_leg__from + spike_leg__to)*0.5 + meter * 0.3, "{dststr} strain: {pty(spike_leg__strainTime)}", 1)
              if dst >= spike_leg__lastDst && am_mimic__currentSpeed > minSpeed
                spike_leg__strainTime += act.dt
                if spike_leg__strainTime > 0.075 && !earlyFlightMode || spike_leg__strainTime > 0.3
                  spike_leg__mode = int(LegBehMode.DIE)
              else
                spike_leg__len += min(dst - spike_leg__len, spd * act.dt * spike_leg__agility)
                if spike_leg__len > effectiveMaxLen
                  spike_leg__len = effectiveMaxLen
                  if am_mimic__currentSpeed <= minSpeed
                    spike_leg__mode = int(LegBehMode.DIE)
                elif !flightMode && dst - spike_leg__len <= spd * act.dt
                  spike_leg__mode = int(LegBehMode.STAY)
                  spike_leg__stamp = act.curTime
                  sendEvent(eid, EventamMimicStep(pos = spike_leg__to))
              spike_leg__lastDst = dst
              spike_leg__len = min(spike_leg__len, dst)

            // STAY
            elif spike_leg__mode == int(LegBehMode.STAY)
              activeLegCount++
              spike_leg__stamp += act.dt * (1.0 - am_mimic__currentSpeed) * 0.9 * sleepingIntervalMult
              let dst = distance(spike_leg__from, spike_leg__to)
              support += max(.0, dot(spike_leg__to - spike_leg__from, gravDir)) * safeinv(dst)
              avgDir += normalize(spike_leg__to - spike_leg__from)
              var mustBreak = dst > effectiveMaxLen && dst > spike_leg__lastDst
              mustBreak ||= dot(normalize(spike_leg__to - spike_leg__from), am_mimic__lastMove) < -0.95 && am_mimic__currentSpeed > minSpeed
              mustBreak ||= act.curTime - spike_leg__stamp > 1.6 + efrnd * 0.8
              if mustBreak
                spike_leg__mode = int(LegBehMode.DIE)
                //if dst > effectiveMaxLen && dst > spike_leg__lastDst
                //  draw_debug_sphere_buffered(spike_leg__to, 0.1, ACGREEN, 12, 200)
                //elif dot(normalize(spike_leg__to - spike_leg__from), am_mimic__lastMove) < -0.95 && am_mimic__currentSpeed > minSpeed
                //  draw_debug_sphere_buffered(spike_leg__to, 0.1, ACBLUE, 12, 200)
                //else // act.curTime - spike_leg__stamp > 1.6 + efrnd * 0.8
                //  draw_debug_sphere_buffered(spike_leg__to, 0.1, ACYELLOW, 12, 200)
              else
                spike_leg__len = dst
              spike_leg__lastDst = dst

            // DIE
            elif spike_leg__mode == int(LegBehMode.DIE)
              spike_leg__len -= spd * act.dt * 0.7
              if spike_leg__len <= .0
                spike_leg__len = .0
                spike_leg__mode = int(LegBehMode.DEAD)
                if isDead
                  destroyEntity(e)

            // HYNERNATE
            elif am_mimic__currentSpeed > minSpeed || act.curTime - spike_leg__stamp > 2.0
              spike_leg__mode = int(LegBehMode.DEAD)

            let finalPointRatio = pow(cvt(dstToLanding, flightDst, .0, 1.0, .0), square(spike_leg__agility))
            let growPoint = spike_leg__to + finalPointRatio * flightHeight / spike_leg__agility
            let finalPoint = spike_leg__toIsLanding && spike_leg__mode == int(LegBehMode.GROW) ? growPoint : spike_leg__to
            draw_leg(spike_leg__from, finalPoint, am_mimic__up, spike_leg__norm, spike_leg__len, effectiveMaxLen, act.dt, act.curTime, spike_leg__agility, spike_leg__mode, spike_leg__kneeFactor,
                              spike_leg__noiseSpeed,
                              spike_leg__noiseAmplitude,
                              spike_leg__branches)
        am_mimic__avgSupport += support * act.dt
        am_mimic__activeLegCount = activeLegCount
        let supDiff = support - am_mimic__expectedSupport
        am_mimic__visualVel -= gravDir * supDiff * act.dt * 9.0
        avgDir -= gravDir * dot(avgDir, gravDir)
        let ln = length(avgDir)
        avgDir = normalize(avgDir)
        let lackOffsupport = lerp(0.0, 0.4, ln / 8.0 / am_mimic__maxLegLength)
        am_mimic__supportOffset = avgDir * lackOffsupport
        //let locoAxis = cross(up, avgDir)
        //let q = quat(locoAxis, lackOffsupport * act.dt)
        //let desiredLocoUp = q * am_mimic__up
        //let locoQ = dir_to_quat(desiredLocoUp)
        //let realLocoQ = dir_to_quat(am_mimic__locoUp)
        //let resQ = approach(realLocoQ, locoQ, act.dt, 0.5)
        //am_mimic__locoUp = quat_get_forward(resQ)
      else
        if !am_mimic__hidden
          am_mimic__hidden = true
          let hiddenPos = get_hidden_pos()
          for e in am_mimic__legs
            query(e) <| $ [es] (var spike_leg__mode : int&; spike_leg__branches : EidList)
              spike_leg__mode = int(LegBehMode.DEAD)
              for b in spike_leg__branches
                query(b) <| $ [es] (var spline_gen_geometry__points : Point3List)
                  clear(spline_gen_geometry__points)
                  spline_gen_geometry__points |> push(hiddenPos)
                  spline_gen_geometry__points |> push(hiddenPos + float3(1, 1, 1))
          am_mimic__activeLegCount = 0
        am_mimic__visualPos = s_transform[3]
        am_mimic__lastPos = s_transform[3]
        am_mimic__visualVel = float3()
      last_frame_transform = s_transform


def find_largest_gap(legs : EidList; from, up : float3)
  var angles : array<float>
  let ax1 = get_normal(up)
  let ax2 = normalize(cross(ax1, up))
  var uu = 0.0
  for leg in legs
    query(leg) <| $ [es] (spike_leg__mode : int; spike_leg__to : float3)
      if spike_leg__mode == int(LegBehMode.GROW) || spike_leg__mode == int(LegBehMode.STAY)
        uu += 0.2
        let horDir = normalize((spike_leg__to - from) - up * dot(spike_leg__to - from, up))
        let xC = dot(horDir, ax1)
        let yC = dot(horDir, ax2)
        let angle = atan2(yC, xC)
        push(angles, angle)
  let numAngles = length(angles)
  if numAngles == 0
    return ax1
  elif numAngles == 1
    return -dir_from_angle(angles[0], ax1, ax2)
  sort(angles)

  var largestGapStart = angles[0]
  var largestGap = 0.0f
  for i in range(numAngles)
    let k = (i + 1) % numAngles
    let gap = angles[k] > angles[i] ? angles[k] - angles[i] : angles[k] - angles[i] + 2.0 * PI
    if gap > largestGap
      largestGap = gap
      largestGapStart = angles[i]
  return dir_from_angle(largestGapStart + largestGap / 2.0f, ax1, ax2)


def dir_from_angle(angle : float; ax1, ax2 : float3)
  var s, c : float
  sincos(angle, s, c)
  return ax1 * c + ax2 * s

def to_enum(val : int; defVal : auto(E)) : E
  for en in each_enum(defVal)
    if val == int(en)
      return en
  return defVal

def bezier_interp4(x0, x1, x2, x3 : auto(TT); t : float)
  let q0 = lerp(x0, x1, t)
  let q1 = lerp(x1, x2, t)
  let q2 = lerp(x2, x3, t)
  let r0 = lerp(q0, q1, t)
  let r1 = lerp(q1, q2, t)
  return lerp(r0, r1, t)


let KNEE_HEIGHT_FACTOR : float = 0.8
let CONTROL_POINT_ALONG_FACTOR : float = 0.33
let MIN_LEG_LENGTH_FOR_CURVE : float = 0.1
let EPSILON_FOR_LENGTH : float = 0.02


def draw_leg(from, to, up, norm : float3;
             len, max_len, dt, time, agility : float;
             mode : int;
             var knee_factor : float&;
             speed : float;
             amplitude : float;
             branches : EidList)
  let fullLegDirVec = to - from
  let distToTarget = length(fullLegDirVec)
  let legDirActual = normalize(fullLegDirVec)
  let trueLen = min(len, distToTarget)

  for branch, idx in branches, iter_range(branches)
    let thisLen = trueLen * pow(trueLen / distToTarget, 0.4 + 2.6 * float(idx) * ceil(float(length(branches)) * 0.5))
    query(branch) <| $ [es] (var spline_gen_geometry__points : Point3List;
                             spike_leg__noisePhase : float;
                             var effect : TheEffect;
                             var transform : float3x4)
      //draw_debug_sphere_buffered(from, 0.05, ACCYAN, 12, 1)
      //draw_debug_sphere_buffered(to, 0.05, ACCYAN, 12, 1)
      clear(spline_gen_geometry__points)
      spline_gen_geometry__points |> push(from)
      effect_set_spawn_rate(effect, 0.0)

      if distToTarget < EPSILON_FOR_LENGTH
        spline_gen_geometry__points |> push(to)
        return
      let endPointForStraightLine = from + legDirActual * thisLen

      if thisLen < MIN_LEG_LENGTH_FOR_CURVE
        spline_gen_geometry__points |> push(endPointForStraightLine)
        return

      var kneeBendDirection : float3
      let binormalCandidate = cross(up, legDirActual)

      if length(binormalCandidate) < EPSILON_FOR_LENGTH
        spline_gen_geometry__points |> push(endPointForStraightLine)
        //draw_debug_line_buffered(from, endPointForStraightLine, ACWHITE, 1)
        return
      let binormal = normalize(binormalCandidate)
      kneeBendDirection = cross(legDirActual, binormal)
      let verticality = abs(dot(legDirActual, up))
      let kneeFactor = mode == int(LegBehMode.GROW) ? (1.0 - agility) : (thisLen == max_len || thisLen <= distToTarget ? 1.0 : .0)
      knee_factor = approach(knee_factor, kneeFactor, dt, 0.45)
      //visual_log("kneeFactor {pty(kneeFactor)}")
      let actualKneeHeight_fullShape = distToTarget * knee_factor * KNEE_HEIGHT_FACTOR * (1.0 - verticality)
      let controlOffsetDistance_fullShape = distToTarget * CONTROL_POINT_ALONG_FACTOR
      let d0 = from + legDirActual * controlOffsetDistance_fullShape + kneeBendDirection * actualKneeHeight_fullShape
      let d1 = to - legDirActual * controlOffsetDistance_fullShape + kneeBendDirection * actualKneeHeight_fullShape
      //draw_debug_tehedron_buffered(d0, 0.03, ACCYAN, 1)
      //draw_debug_tehedron_buffered(d1, 0.03, ACCYAN, 1)
      //draw_debug_line_buffered(d0, d1, ACCYAN, 1)
      //draw_debug_line_buffered(from, to, ACBLUE, 1)
      //draw_debug_text_mark_buffered((from + to) * 0.5, "{pty(len)} vs {pty(distance(from, to))} {to_enum(mode, LegBehMode.DIE)}", 1)
      var drawT : float
      if distToTarget > EPSILON_FOR_LENGTH
        drawT = clamp(thisLen / distToTarget, .0, 1.0)
        drawT -= min(0.03, drawT)
      let ax2 = get_normal(kneeBendDirection)
      let ax3 = normalize(cross(kneeBendDirection, ax2))
      let num = 20.0
      var disp : float3
      let effectKey = num * float(idx + 1) / float(length(branches) + 1)
      effect_set_spawn_rate(effect, 1.0)
      for j in range(int(num))
        let tu = float(j + 1) / num
        let ts = tu * drawT
        let s = bezier_interp4(from, d0, d1, to, ts)
        let noise1 = perlin_noise1(speed * (time * 1.0 - float(j) * 0.2) + spike_leg__noisePhase)
        let noise2 = perlin_noise1(speed * (time * 1.0 - float(j) * 0.2) + spike_leg__noisePhase + 200.0)
        let noise3 = perlin_noise1(speed * (time * 1.0 - float(j) * 0.2) + spike_leg__noisePhase + 400.0)
        let dispMult = amplitude * knee_factor * thisLen / max_len
        disp = kneeBendDirection * noise1 + ax2 * noise2 + ax3 * noise3
        let splinePoint = s + disp * dispMult
        spline_gen_geometry__points |> push(splinePoint)
        if effectKey < float(j + 1) && effectKey >= float(j)
          transform[3] = splinePoint
          //draw_debug_sphere_buffered(transform[3], 0.1, ACWHITE, 12, 1)
      if mode == int(LegBehMode.STAY)
        let nax1 = get_normal(norm)
        let nax2 = normalize(cross(norm, nax1))
        let a = 2.0 * PI * float(idx) / float(length(branches)) + agility * 100.0 + (spike_leg__noisePhase % 1000.0) * 0.15
        var s, c : float
        sincos(a, s, c)
        let fingerShift = (nax1 * s + nax2 * c) * 0.2 * agility
        let fingerPoint = endPointForStraightLine + fingerShift
        spline_gen_geometry__points |> push(fingerPoint)
        if agility > 0.8 && idx == 0
          spline_gen_geometry__points |> push(fingerPoint + fingerShift * 0.5)


def rnd_dir(dir : float3; t : float)
  var seed = int(t * 100.0)
  let n1 = get_normal(dir)
  let n2 = normalize(cross(dir, n1))
  return normalize(dir + n1 * _rnd_float(seed, -0.5, 0.5) + n2 * _rnd_float(seed, -0.5, 0.5))


def draw_attack_tentacle(from, to, p1, p2 : float3; var points : Point3List)
  clear(points)
  points |> push(from)

  let fullLegDirVec = to - from
  let distToTarget = length(fullLegDirVec)

  if distToTarget < EPSILON_FOR_LENGTH
    points |> push(to)
    return

  let num = 20
  for j in range(num)
    let tu = float(j + 1) / float(num)
    let s = bezier_interp4(from, p1, p2, to, tu)
    points |> push(s)


let GROW_P1_ANGLE = -0.95

def get_growing_bezier(base, dir : float3; agility : float)
  let axisRaw = cross(base, dir)
  let ln = length(axisRaw)
  if ln < 0.01
    return (base * 0.33, base * 0.66)
  let axis = axisRaw / ln
  let q = quat(axis, GROW_P1_ANGLE * (0.7 + agility * 0.6))
  let p1 = q * base
  let p2 = (p1 + base) * (0.55 + agility * 0.07)
  return (p1, p2)


def get_lunging_bezier(base, dir : float3; agility : float)
  let norm = normalize(base - dir * dot(base, dir))
  return (dir * (0.16 + agility * 0.6) + norm * 0.33, dir * (0.33 + agility * 0.15))

[unused_argument(dir)]
def get_lunging_bezier2(base, dir : float3)
  return (base * 0.3, base * 1.5)


let FIXED_DT = 1.0 / 1024.0
def process_damping(dt : float;
                    pos : float3;
                    grav : float3;
                    am_mimic__springK : float2;
                    am_mimic__damping : float2;
                    var am_mimic__visualPos : float3&;
                    var am_mimic__visualVel : float3&)
  var dtLeft = dt
  while dtLeft > .0
    dtLeft -= FIXED_DT
    let displacementToTarget = pos - am_mimic__visualPos;
    let clampedDisplacement = float3(clamp(displacementToTarget.x, -0.5, 0.5),
                                     clamp(displacementToTarget.y, -0.5, 0.5),
                                     clamp(displacementToTarget.z, -0.5, 0.5))
    let vertDisplacement = grav * dot(clampedDisplacement, grav)
    let horDisplacement = clampedDisplacement - vertDisplacement
    let vertVel = -grav * dot(am_mimic__visualVel, grav)
    let horVel = am_mimic__visualVel - vertVel
    let newVel = (vertVel * (1.0 - am_mimic__damping.y * FIXED_DT) + vertDisplacement * am_mimic__springK.y * FIXED_DT +
                  horVel * (1.0 - am_mimic__damping.x * FIXED_DT) + horDisplacement * am_mimic__springK.x * FIXED_DT)
    am_mimic__visualPos += (newVel + am_mimic__visualVel) * 0.5 * FIXED_DT
    am_mimic__visualVel = newVel


[es(tag=gameClient, track=walker_agent__climbingFrom)]
def mimic_set_expected_climb(evt : Event; walker_agent__climbingFrom : float3; var walker_agent__climbExpected : bool&)
  walker_agent__climbExpected = walker_agent__climbingFrom != float3()
