require app // get_sync_time
require ecs
require ecs.common
require math.random
require math.base
require Dacoll
require DagorMath
require DagorSystem
require walkerai
require pathfinder
require DagorMathUtils
require DngWalkerai
require danetlibs.navmesh_phys.main.nphys_common
require danetlibs.pathfinder.main.pathfinder_common
require danetlibs.navmesh_phys.main.nphys_events
require math.shooter_phys_common


[es(tag=server, on_appear, before=nphys_push_update)]
def init_navmesh_phys(evt : Event; transform : float3x4;
                      nphys_pushable__elevation : float = 0.0;
                      var navmesh_phys__atTime : float&;
                      var navmesh_phys__currentPos, navmesh_phys__prevLookDir, navmesh_phys__currentLookDir : float3&)
  navmesh_phys__currentPos = transform[3] - float3(.0, nphys_pushable__elevation, .0)
  navmesh_phys__prevLookDir = transform[0]
  navmesh_phys__currentLookDir = navmesh_phys__prevLookDir
  navmesh_phys__atTime = get_sync_time()


[es(on_event=EventOnModsChanged)]
def navmesh_phys_walk_speed_mult(evt : Event;
                                 navmesh_phys__walkSpeedMods : Object;
                                 var navmesh_phys__walkSpeedMult : float&)
  navmesh_phys__walkSpeedMult = calc_change_mult_attr(navmesh_phys__walkSpeedMods)


[es(tag=server, no_order, REQUIRE_NOT=(deadEntity, nphys__disabled))]
def update_navmesh_walk_speed(act : UpdateStageInfoAct;
                              eid : EntityId;
                              navmesh_phys__wishWalkDir : float3;
                              navmesh_phys__currentLookDir : float3;
                              navmesh_phys__strafeWalkSpeedMult : float;
                              navmesh_phys__backwardWalkSpeedMult : float;
                              navmesh_phys__walkSpeedModLookDirMultName : string = "look_dir_mult";
                              var navmesh_phys__walkSpeedMods : Object)
  let moveDir = normalize(navmesh_phys__wishWalkDir.xz)
  if length_sq(moveDir) == 0.0
    return
  let dot = dot(moveDir, normalize(navmesh_phys__currentLookDir.xz))
  var walkSpeedLookDirMult = 1.0
  if dot > 0.0
    walkSpeedLookDirMult = cvt(dot, 0.0, 1.0, navmesh_phys__strafeWalkSpeedMult, 1.0)
  else
    walkSpeedLookDirMult = cvt(dot, 0.0, -1.0, navmesh_phys__strafeWalkSpeedMult, navmesh_phys__backwardWalkSpeedMult)
  set_mod_mult_value(navmesh_phys__walkSpeedMods, navmesh_phys__walkSpeedModLookDirMultName, walkSpeedLookDirMult, eid)


[es(tag=server, no_order, REQUIRE_NOT=(deadEntity, nphys__disabled))]
def update_navmesh_phys(act : UpdateStageInfoAct;
                        navmesh_phys__wishWalkSpeed : float;
                        navmesh_phys__wishWalkDir : float3;
                        navmesh_phys__acceleration : float;
                        navmesh_phys__maxWalkSpeed : float;
                        navmesh_phys__friction, navmesh_phys__frictionThresSpdMult : float;
                        navmesh_phys__timeStep : float;
                        navmesh_phys__wishLookDir : float3;
                        nphys_pushable__unlockMovementAt : float = 0.0;
                        navmesh_phys__walkSpeedMult : float = 1.0;
                        path_corridor__isClimbing : bool const?;
                        navmesh_phys__extraDt : float = .0;
                        navmesh_phys__upDir : float3 = float3(0, 1, 0);
                        var navmesh_phys__currentPoly : int64&;
                        var navmesh_phys__atTime : float&;
                        var navmesh_phys__prevTime : float&;
                        var navmesh_phys__prevPos : float3&;
                        var navmesh_phys__currentPos : float3&;
                        var navmesh_phys__prevLookDir : float3&;
                        var navmesh_phys__currentLookDir : float3&;
                        var navmesh_phys__currentWalkVelocity : float3&)
  while navmesh_phys__atTime < act.curTime && nphys_pushable__unlockMovementAt < act.curTime
    let dt = navmesh_phys__timeStep
    if !(path_corridor__isClimbing ?? false)
      navmesh_phys__currentWalkVelocity *= phys_calc_friction_mult(length(navmesh_phys__currentWalkVelocity),
        navmesh_phys__maxWalkSpeed * navmesh_phys__frictionThresSpdMult, navmesh_phys__friction, dt)

      let wishSpd = navmesh_phys__maxWalkSpeed * navmesh_phys__wishWalkSpeed * navmesh_phys__walkSpeedMult
      let wishAccel = wishSpd * navmesh_phys__acceleration

      if length_sq(navmesh_phys__wishWalkDir) == .0
        navmesh_phys__currentWalkVelocity = float3()
      else
        navmesh_phys__currentWalkVelocity = accelerate_dir(navmesh_phys__currentWalkVelocity, navmesh_phys__wishWalkDir, wishSpd, wishAccel, dt)

      navmesh_phys__prevPos = navmesh_phys__currentPos
      let posDelta = navmesh_phys__currentWalkVelocity * (dt + navmesh_phys__extraDt)
      navmesh_phys__currentPos += posDelta

      let extents = float3(0.5)
      using(navmesh_phys__prevPos, navmesh_phys__currentPos, extents) <| $(var req : FindRequest#)
        req.startPoly = dtPolyRef(navmesh_phys__currentPoly)
        if move_along_surface(req)
          navmesh_phys__currentPos = req.end
          navmesh_phys__currentPoly = int64(req.endPoly)
          let movementSq = distance_sq(navmesh_phys__prevPos, navmesh_phys__currentPos)
          if abs(navmesh_phys__prevPos.y - navmesh_phys__currentPos.y) < 1.2 && movementSq > 36. && navmesh_phys__extraDt == .0
            logwarn("navmesh: huge movement distance, teleportation? d={distance(navmesh_phys__prevPos, navmesh_phys__currentPos)} reqD={length(posDelta)} prev={navmesh_phys__prevPos} cur={navmesh_phys__currentPos} vel={navmesh_phys__currentWalkVelocity}")
        else
          // move_along_surface failed, cleanup current poly
          // TODO: activate stuck logic if possible
          navmesh_phys__currentPoly = int64(INVALID_POLY_REF)

    navmesh_phys__prevLookDir = navmesh_phys__currentLookDir
    let prevLookQuat = dir_and_up_to_quat(navmesh_phys__currentLookDir, navmesh_phys__upDir)
    let wishLook = approach(prevLookQuat, dir_and_up_to_quat(navmesh_phys__wishLookDir, navmesh_phys__upDir), dt, 0.2)
    navmesh_phys__currentLookDir = wishLook |> quat_get_forward()

    navmesh_phys__prevTime = navmesh_phys__atTime
    navmesh_phys__atTime += dt


[es(tag=server, REQUIRE_NOT=deadEntity, track=navmesh_phys__atTime)]
def update_navmesh_look_dir_angular_speed(event : Event;
                                          navmesh_phys__prevLookDir : float3;
                                          navmesh_phys__currentLookDir : float3;
                                          navmesh_phys__prevTime : float;
                                          navmesh_phys__atTime : float;
                                          var navmesh_phys__lookDirAngularSpeed : float3&)
  let prevLookQuat = dir_to_quat(navmesh_phys__prevLookDir)
  let wishLook = dir_to_quat(navmesh_phys__currentLookDir)
  let dt = navmesh_phys__atTime - navmesh_phys__prevTime
  let lookQuatDelta = wishLook * inverse(prevLookQuat)
  var lookDirDelta : float3
  quat_to_euler(lookQuatDelta, lookDirDelta.y, lookDirDelta.z, lookDirDelta.x)
  navmesh_phys__lookDirAngularSpeed = lookDirDelta * safediv(1.0, dt)


[es(tag=server, after=update_navmesh_phys, REQUIRE_NOT=(deadEntity, nphys__disabled, nphys__noLookDir))]
def move_navmesh_phys_lookdir(act : UpdateStageInfoAct; eid : EntityId;
                              navmesh_phys__prevTime : float;
                              navmesh_phys__atTime : float;
                              navmesh_phys__prevLookDir : float3;
                              navmesh_phys__currentLookDir : float3&;
                              navmesh_phys__upDir : float3 = float3(0, 1, 0);
                              var transform : float3x4)
  let step = navmesh_phys__atTime - navmesh_phys__prevTime
  if step > 0f
    let k = (act.curTime - navmesh_phys__prevTime) / step
    var lookDir : quat

    if eid |> has("npys_homoErectus")
      let prevLookDir = normalize(navmesh_phys__prevLookDir - navmesh_phys__upDir * dot(navmesh_phys__upDir, navmesh_phys__prevLookDir))
      let currentLookDir = normalize(navmesh_phys__currentLookDir - navmesh_phys__upDir * dot(navmesh_phys__upDir, navmesh_phys__currentLookDir))
      lookDir = slerp(dir_and_up_to_quat(prevLookDir, navmesh_phys__upDir), dir_and_up_to_quat(currentLookDir, navmesh_phys__upDir), k) |> normalize()
    else
      lookDir = slerp(dir_and_up_to_quat(navmesh_phys__prevLookDir, navmesh_phys__upDir), dir_and_up_to_quat(navmesh_phys__currentLookDir, navmesh_phys__upDir), k) |> normalize()
    make_tm(lookDir, transform[3], transform)


[es(tag=server, after=(move_navmesh_phys_lookdir, update_navmesh_phys), REQUIRE_NOT=(deadEntity, nphys__disabled))]
def move_navmesh_phys_pos(act : UpdateStageInfoAct;
                          navmesh_phys__prevTime : float;
                          navmesh_phys__atTime : float;
                          navmesh_phys__prevPos : float3;
                          navmesh_phys__currentPos : float3;
                          navmesh_phys__upDir : float3 = float3(0, 1, 0);
                          navmesh_phys__visualHeightOffsetShown : float = 0.0;
                          var transform : float3x4)
  let step = navmesh_phys__atTime - navmesh_phys__prevTime
  if step > 0f
    let k = (act.curTime - navmesh_phys__prevTime) / step
    let targetPos = lerp(navmesh_phys__prevPos, navmesh_phys__currentPos, float3(k))
    transform[3] = targetPos + navmesh_phys__upDir * navmesh_phys__visualHeightOffsetShown


[es(tag=server, before=move_navmesh_phys_pos, REQUIRE_NOT=(deadEntity, nphys__disabled))]
def nphys_calc_navmesh_drop_offset(upd : UpdateStageInfoAct;
                                   navmesh_phys__currentPos : float3;
                                   navmesh_phys__upDir : float3 = float3(0.0, 1.0, 0.0);
                                   navmesh_phys__heightOffsetTraceSphereRadius : float;
                                   navmesh_phys__heightOffsetTraceOffset : float;
                                   navmesh_phys__heightOffsetMaxTraceDist : float;
                                   navmesh_phys__heightOffsetTraceInterval : float2;
                                   navmesh_phys__heightOffsetApproachViscocity : float;
                                   var navmesh_phys__visualHeightOffsetShown : float&;
                                   var navmesh_phys__heightOffsetTraceAt : float&;
                                   var navmesh_phys__visualHeightOffsetDesired : float&)
  navmesh_phys__visualHeightOffsetShown = approach(navmesh_phys__visualHeightOffsetShown, navmesh_phys__visualHeightOffsetDesired, upd.dt, navmesh_phys__heightOffsetApproachViscocity)
  if upd.curTime < navmesh_phys__heightOffsetTraceAt
    return

  navmesh_phys__heightOffsetTraceAt = upd.curTime + rnd_float(navmesh_phys__heightOffsetTraceInterval)

  let traceLen = navmesh_phys__heightOffsetTraceOffset + navmesh_phys__heightOffsetMaxTraceDist
  let tracePos = navmesh_phys__currentPos + navmesh_phys__upDir * navmesh_phys__heightOffsetTraceOffset
  let traceToPos = tracePos - navmesh_phys__upDir * traceLen
  var castRes = ShapeQueryOutput()
  var desiredHeightOffset = 0.0
  if sphere_cast(tracePos, traceToPos, navmesh_phys__heightOffsetTraceSphereRadius, castRes, int(PhysLayer.EPL_STATIC))
    desiredHeightOffset = -distance(castRes.res, navmesh_phys__currentPos)
  navmesh_phys__visualHeightOffsetDesired = desiredHeightOffset


[es(tag=server, after=(move_navmesh_phys_pos, move_navmesh_phys_lookdir), REQUIRE_NOT=(deadEntity, nphys__disabled))]
def update_nphys_levitation(act : UpdateStageInfoAct;
                            nphys_levitating__elevationChangeSpeed : float;
                            nphys_levitating__prefferedElevation : float;
                            navmesh_phys__upDir : float3 = float3(0, 1, 0);
                            var nphys_levitating__elevation : float&;
                            var transform : float3x4)
  var delta = min(abs(nphys_levitating__prefferedElevation - nphys_levitating__elevation), nphys_levitating__elevationChangeSpeed * act.dt)
  if nphys_levitating__prefferedElevation < nphys_levitating__elevation
    delta *= -1.0
  nphys_levitating__elevation += delta
  transform[3] += navmesh_phys__upDir * nphys_levitating__elevation


[es(tag=server, after=(move_navmesh_phys_pos, move_navmesh_phys_lookdir), before=update_nphys_scale, REQUIRE=navmeshAlignedPhys, REQUIRE_NOT=(deadEntity, npys_homoErectus, nphys__disabled))]
def navmesh_aligned_phys(act : UpdateStageInfoAct; navmesh_phys__currentPoly : int64; navmesh_phys__currentPos : float3;
                         var navmesh_aligned_phys__prevPolyNormQuat, navmesh_aligned_phys__currentPolyNormQuat : float4&;
                         var navmesh_aligned_phys__prevPos : float3&; var transform : float3x4&;
                         navmesh_aligned_phys__rotationViscosity = 0.3)
  if navmesh_aligned_phys__prevPos != navmesh_phys__currentPos
    navmesh_aligned_phys__prevPos = navmesh_phys__currentPos
    let norm = get_surface_normal_by_pos(navmesh_phys__currentPos, dtPolyRef(navmesh_phys__currentPoly))
    navmesh_aligned_phys__currentPolyNormQuat = norm |> dir_to_quat() |> float4()

  let dirQuat = approach(quat(navmesh_aligned_phys__prevPolyNormQuat), quat(navmesh_aligned_phys__currentPolyNormQuat), act.dt, navmesh_aligned_phys__rotationViscosity)
  navmesh_aligned_phys__prevPolyNormQuat = float4(dirQuat)
  transform[1] = dirQuat |> quat_get_forward()
  transform[0] = normalize(cross(transform[1], transform[2]))
  transform[2] = normalize(cross(transform[0], transform[1]))


[es(before=send_transform_snapshots_es, after=interp_loc_snapshots_es)]
def update_nphys_scale(act : UpdateStageInfoAct; nPhys__animcharScale : float; var transform : float3x4&)
  transform[0] = normalize(transform[0]) * nPhys__animcharScale
  transform[1] = normalize(transform[1]) * nPhys__animcharScale
  transform[2] = normalize(transform[2]) * nPhys__animcharScale


[es(on_appear, before=update_nphys_scale)]
def nphys_randomize_animchar_scale(evt : Event; eid : EntityId; nPhys__animcharScaleRange : float2; var nPhys__animcharScale : float&)
  nPhys__animcharScale = eid_frnd(eid) * (nPhys__animcharScaleRange.y - nPhys__animcharScaleRange.x) + nPhys__animcharScaleRange.x


[es(tag=server, on_disappear, REQUIRE=nphys__disabled)]
def nphys_reset_time_when_no_longer_disabled(evt : Event; var navmesh_phys__prevTime, navmesh_phys__atTime : float&)
  navmesh_phys__prevTime = get_sync_time()
  navmesh_phys__atTime = navmesh_phys__prevTime


[es(on_appear)]
def init_rnd_walkspeed(evt : Event; eid : EntityId; navmesh_phys__rndWalkSpeed : float2; var navmesh_phys__maxWalkSpeed : float&)
  navmesh_phys__maxWalkSpeed = lerp(navmesh_phys__rndWalkSpeed.x, navmesh_phys__rndWalkSpeed.y, eid_frnd(eid))