require ecs
require app
require DagorMath
require math
require math.base
require level
require Dacoll
require replay
require HumanPhys
require DngHuman
require game.es.underground_zone_common


def calc_camera_tilt_vector(transform : float3x4;
                            var camera_tilt__rotateInertion : float&;
                            camera_move_vector : float3;
                            human_net_phys : HumanActor;
                            camera_tilt__rotateInertionForce : float;
                            camera_tilt__moveInertionForce : float;
                            camera_tilt__rotateInertionMoveInfluence : float)
  camera_tilt__rotateInertion += dot(camera_move_vector, transform[2])
  let curVelocity = human_net_phys.phys.currentState.velocity
  let prevVelocity = human_net_phys.phys.previousState.velocity
  let interpK = get_phys_interpk_clamped(human_net_phys.phys, get_sync_time())
  var velocity = lerp(prevVelocity, curVelocity, float3(interpK))
  var speed = length(velocity)
  var rotSpeedInfluence = 1.0
  if speed != 0.0
    velocity /= speed
    speed = clamp(speed, 0.0, 10.0) // to limit camera move tilt
    rotSpeedInfluence *= speed * camera_tilt__rotateInertionMoveInfluence
  let tiltVelocityVector = velocity * speed * camera_tilt__moveInertionForce
  let rotVecLen = camera_tilt__rotateInertion * camera_tilt__rotateInertionForce * rotSpeedInfluence
  let tiltRotationVector = transform[2] * rotVecLen
  return tiltVelocityVector + tiltRotationVector


[es(tag=render, after=shooter_cam_act_es, before=after_camera_sync)]
def shooter_cam_clamp_tau_es(info : UpdateStageInfoAct;
                             camera__tauPos : float;
                             camera__active : bool;
                             shooter_cam__tauOnChange : float;
                             var shooter_cam__wasAlternative : bool&;
                             var shooter_cam__tauInc : float&;
                             shooter_cam__alternative_settings = false;
                             camera__updateWhileInactive = false)
  if !(camera__active || camera__updateWhileInactive) || is_level_loading()
    return

  if shooter_cam__wasAlternative != shooter_cam__alternative_settings
    shooter_cam__tauInc = max(camera__tauPos, max(shooter_cam__tauInc, shooter_cam__tauOnChange))
  shooter_cam__wasAlternative = shooter_cam__alternative_settings

[es(tag=render, after=shooter_cam_clamp_tau_es, before=after_camera_sync)]
def shooter_cam_tau_move_scalar_es(info : UpdateStageInfoAct;
                                   camera__active : bool;
                                   var shooter_cam__tauInc : float&;
                                   camera__updateWhileInactive = false)
  if !(camera__active || camera__updateWhileInactive) || is_level_loading()
    return
  shooter_cam__tauInc = move_to_scalar(shooter_cam__tauInc, 0.f, info.dt, 0.4f)

[es(tag=render, after=shooter_cam_clamp_tau_es, before=shooter_cam_tau_move_scalar_es)]
def shooter_cam_rotate_es(info : UpdateStageInfoAct;
                          camera__active : bool;
                          camera__target : EntityId;
                          camera__vertOffset : float;
                          shooter_cam__tauInc : float;
                          var shooter_cam__lastDir : float3&;
                          var transform aka camera_transform : float3x4;
                          var camera_tilt__rotateInertion : float?;
                          camera_tilt__rotateInertionDumpViscosity = 0.1;
                          camera_tilt__rotateInertionForce = 1.0;
                          camera_tilt__moveInertionForce = 0.07;
                          camera_tilt__rotateInertionMoveInfluence = 0.5;
                          shooter_camera__forceStabilized = false;
                          camera__updateWhileInactive = false)
  if !(camera__active || camera__updateWhileInactive) || is_level_loading()
    return
  query(camera__target) <| $ [es] (transform : float3x4;
                                   human_net_phys : HumanActor const?;
                                   camera__isStabilized = true;
                                   camera__isRotateInGlobal = false;
                                   camera__relative_roll_angle = 0.f; // if not stabilized
                                   camera__relative_angle = float2(0.f, 0.f);
                                   camera__lookDir = float3(1.f, 0.f, 0.f))
    var wishQ = dir_to_quat(camera__lookDir)
    if length_sq(camera__relative_angle) > 0.f
      var relativeQuat : quat
      euler_to_quat(camera__relative_angle.x, camera__relative_angle.y, camera__relative_roll_angle, relativeQuat)
      let worldDir = relativeQuat * camera__lookDir
      wishQ = camera__isRotateInGlobal ? dir_to_quat(worldDir) : (wishQ * relativeQuat)
    var additionalReplayTau = 0.f
    if human_net_phys != null && is_replay_playing()
      additionalReplayTau = cvt(human_net_phys.phys.currentState.zoomPosition, 0.f, 1.f, 0.f, 0.2f)
    let lastQ = normalize(approach(dir_to_quat(shooter_cam__lastDir), wishQ, info.dt, additionalReplayTau + shooter_cam__tauInc))
    let lastDir = quat_get_forward(lastQ)
    if camera_tilt__rotateInertion != null
      *camera_tilt__rotateInertion = approach(*camera_tilt__rotateInertion, 0.0, info.dt, camera_tilt__rotateInertionDumpViscosity)

    var stabVec = float3(0.f, 1.f, 0.f)
    if !camera__isStabilized && !shooter_camera__forceStabilized && camera_tilt__rotateInertion != null
      let cameraTiltVector = calc_camera_tilt_vector(
        transform,
        *camera_tilt__rotateInertion,
        lastDir - shooter_cam__lastDir,
        *human_net_phys,
        camera_tilt__rotateInertionForce,
        camera_tilt__moveInertionForce,
        camera_tilt__rotateInertionMoveInfluence
      )
      stabVec = normalize(transform[1] + cameraTiltVector)
    shooter_cam__lastDir = lastDir

    let dir0 = normalize(cross(stabVec, lastDir))
    let dir2 = quat(dir0, camera__vertOffset) * lastDir
    camera_transform[0] = dir0
    camera_transform[2] = dir2
    camera_transform[1] = normalize(cross(dir2, dir0)) // up


def apply_zoom_on_fov(fov : float; magnification : float)
  return rad_to_deg(atan(tan(deg_to_rad(fov * 0.5f)) * safeinv(magnification))) * 2.f

[es(tag=render, after=shooter_cam_clamp_tau_es, before=shooter_cam_tau_move_scalar_es)]
def shooter_cam_update_tm_es(info : UpdateStageInfoAct;
                             var fov : float&;
                             var transform aka camera_transform : float3x4;
                             var shooter_cam__lastPos : float3&;
                             var shooter_cam__lastAnimTmOffset : float3&;
                             var camera__accuratePos : DPoint3&;
                             var isHeroCockpitCam : bool&;
                             var camera__totalMagnification : float&;
                             var shooter_cam__isLastPosValid : bool&;
                             var shooter_cam__velMain : float3&;
                             var shooter_cam__velAnim : float3&;
                             var shooter_cam__lastOffsDistMult : float&;
                             var camera__prevOffset : float3&;
                             var camera__posOnlyBaseOffset : DPoint3&;
                             fovSettings : float;
                             camera__target : EntityId;
                             camera__active : bool;
                             camera__offset : float3;
                             camera__pivotPos : float3;
                             camera__velTau : float;
                             camera__velFactor : float;
                             camera__tau : float;
                             camera__tmToAnimRatio : float;
                             camera__animTau : float;
                             shooter_cam__tauInc : float;
                             shooter_cam__rayMatId : int;
                             ignoreMagnification : Tag const?;
                             shooter_cam__moveInSpd = 2.f;
                             shooter_cam__moveOutSpd = 2.f;
                             shooter_cam__offset = float3(0.f, 0.f, 0.f);
                             shooter_cam__additionalOffset = float3(0.f, 0.f, 0.f);
                             shooter_cam__tauMult = 1.f;
                             shooter_cam__velTauMult = 1.f;
                             shooter_cam__magnificationMult = 1.f;
                             shooter_cam__offset_multiplier = 1.f;
                             camera__updateWhileInactive = false)
  if !(camera__active || camera__updateWhileInactive) || is_level_loading()
    return

  query(camera__target) <| $ [es] (transform : float3x4;
                                   camera__look_at : DPoint3;
                                   camera__magnification = 1.f;
                                   camera__tauMult = 1.f;
                                   isInVehicle = false;
                                   human_cam__isIndoor = false;
                                   human_cam__indoorOffs = float3(0f);
                                   isTpsView = false;
                                   human_cam__viscosity = 1f;
                                   human_cam__horizontalOffsetMult = 1f;
                                   isAlive = true;
                                   isDowned = false;
                                   camera__fallenGroundDistance = 0.3f)
    assert(camera__magnification > 0.0f)
    let baseOffset = camera__offset + shooter_cam__offset + shooter_cam__additionalOffset
    isHeroCockpitCam = length_sq(baseOffset) == 0f // exactly zero, we switch to a cockpit cam in that case
    let offset = invoke() <|
      if isTpsView && !isInVehicle && !isHeroCockpitCam
        let offs = (human_cam__isIndoor ? baseOffset + human_cam__indoorOffs : baseOffset) * float3(human_cam__horizontalOffsetMult, 1.f, 1.f)
        return approach(camera__prevOffset, offs, info.dt, human_cam__viscosity)
      else
        return baseOffset
    camera__prevOffset = offset

    let magnification = (ignoreMagnification == null ? camera__magnification : 1.f) * shooter_cam__magnificationMult
    fov = apply_zoom_on_fov(fovSettings, magnification)
    camera__totalMagnification = magnification

    let lookAtPos = length_sq(camera__look_at) != 0. ? camera__look_at : DPoint3(transform[3])
    var velMain = DPoint3(shooter_cam__velMain)
    var wishPos = lookAtPos

    let animTmOffset = lookAtPos - DPoint3(transform[3])
    var velAnim = DPoint3(shooter_cam__velAnim)
    var wishPosAnim = animTmOffset

    if shooter_cam__isLastPosValid
      let velTau = camera__velTau * shooter_cam__velTauMult

      let tau = (camera__tau * shooter_cam__tauMult + shooter_cam__tauInc) * camera__tauMult
      wishPos = approach_vel(DPoint3(shooter_cam__lastPos), lookAtPos, info.dt, tau, velMain, velTau, camera__velFactor)

      let taua = (camera__animTau + shooter_cam__tauInc) * camera__tauMult
      wishPosAnim = approach_vel(DPoint3(shooter_cam__lastAnimTmOffset), animTmOffset, info.dt, taua, velAnim, velTau, camera__velFactor)

    shooter_cam__lastPos = float3(wishPos)
    shooter_cam__velMain = float3(velMain)

    shooter_cam__lastAnimTmOffset = float3(wishPosAnim)
    shooter_cam__velAnim = float3(velAnim)

    shooter_cam__isLastPosValid = true

    let finalWishPos = wishPos * (1.f - camera__tmToAnimRatio) + (wishPosAnim + DPoint3(transform[3])) * camera__tmToAnimRatio

    let cameraOffs = rotate(camera_transform, offset * shooter_cam__offset_multiplier)
    let cameraBaseOffs = rotate(camera_transform, baseOffset * shooter_cam__offset_multiplier)
    let cameraOffsLenSq = length_sq(cameraOffs)

    let basePivotOffs = rotate(camera_transform, camera__pivotPos)
    let sphereRad = 0.1f
    let pivotOffs = invoke() <|
      if length_sq(basePivotOffs) > 1e-4f && cameraOffsLenSq > 1e-4f
        // do additional check to original pivot from this one
        var queryOut = ShapeQueryOutput()
        if sphere_cast(float3(finalWishPos), float3(finalWishPos + DPoint3(basePivotOffs)), sphereRad, queryOut, shooter_cam__rayMatId)
          return rotate(camera_transform, (camera__pivotPos * queryOut.t))
      return basePivotOffs

    let wishDistMult = invoke() <|
      if cameraOffsLenSq > 1e-4f
        var queryOut = ShapeQueryOutput()
        if sphere_cast(float3(finalWishPos + DPoint3(pivotOffs)), float3(finalWishPos + DPoint3(cameraOffs)), sphereRad, queryOut, shooter_cam__rayMatId)
          //This will result in camera position approaching the same location (save for sphereRad) as the collision point returned by sphere_cast
          let wishOffs = DPoint3(queryOut.res) - finalWishPos - DPoint3(pivotOffs)
          return safediv(max(length(wishOffs) - sphereRad, 0.f), length(cameraOffs - pivotOffs))
      return 1.f

    let multSpd = wishDistMult > shooter_cam__lastOffsDistMult ? shooter_cam__moveOutSpd : shooter_cam__moveInSpd
    shooter_cam__lastOffsDistMult = move_to_scalar(shooter_cam__lastOffsDistMult, wishDistMult, info.dt, multSpd)
    let pivotCameraOffs = lerp(pivotOffs, cameraOffs, float3(shooter_cam__lastOffsDistMult))
    camera__posOnlyBaseOffset = approach(camera__posOnlyBaseOffset, finalWishPos + DPoint3(cameraBaseOffs), info.dt, shooter_cam__tauInc)
    camera__accuratePos = approach(camera__accuratePos, finalWishPos + DPoint3(pivotCameraOffs), info.dt, shooter_cam__tauInc)

    if (!isAlive || isDowned) && camera__fallenGroundDistance > 0.f
      let tracePoint = float2(float(camera__accuratePos.x), float(camera__accuratePos.z))
      let lMeshHeight = traceht_lmesh(tracePoint)
      let minHeight = camera__fallenGroundDistance + lMeshHeight
      if camera__accuratePos.y < double(minHeight)
        if !is_in_underground_zone(transform[3])
          camera__accuratePos.y = double(minHeight)

    assert(length_sq(camera__accuratePos) < 1e10)
    camera_transform[3] = float3(camera__accuratePos)
