require ecs
require math.base
require DagorMath
require Dacoll
require game.es.grav_zones_common


[es(tag=gameClient, on_appear, track=camera__active)]
def free_camera_init(evt : Event;
                     free_camera__moveSpeedDefault : float;
                     transform aka camera_transform : float3x4;
                     camera__active : bool;
                     var free_camera__moveSpeed : float&;
                     var free_camera__upVector : float3&)
  if camera__active
    free_camera__moveSpeed = free_camera__moveSpeedDefault
    free_camera__upVector = camera_transform[1]
    find_query() <| $[es(REQUIRE=hero)] (transform : float3x4)
      free_camera__upVector = transform[1]
      return true


[es(tag=gameClient, no_order)]
def free_camera_update(act : UpdateStageInfoAct;
                       free_camera__move : float3;
                       free_camera__rotate : float3;
                       free_camera__moveSpeed : float;
                       free_camera__rotationSpeed : float2;
                       free_camera__turboMode : bool;
                       free_camera__useFixedDirection : bool;
                       free_camera__fixedDirection : float3;
                       free_camera__dashDir : float3;
                       var free_camera__upVector : float3&;
                       var free_camera__curVelocity : float3&;
                       var transform : float3x4&;
                       var free_cam__lastGravity : float3?;
                       var free_camera__dashFramesLeft : int&;
                       var free_camera__dstLeft : float&;
                       free_cam__checkGravity = false;
                       free_camera__turboSpeedScale = 20.0;
                       free_camera__moveInertia = 0.0;
                       free_camera__stopInertia = 0.0)
  let dt = max(1.0 / 60.0, act.dt)
  var moveSpeed = free_camera__moveSpeed
  if free_camera__turboMode
    moveSpeed *= free_camera__turboSpeedScale

  let currentPitch = asin(dot(transform[2], free_camera__upVector))
  let cosFactor = cos(currentPitch) //Slow down camera rotation when looking up or down

  if free_cam__checkGravity && free_cam__lastGravity != null
    let grav = get_grav_dir(transform[3])
    if grav != *free_cam__lastGravity
      let changeArc = quat_rotation_arc(*free_cam__lastGravity, grav)
      free_camera__upVector = changeArc * free_camera__upVector
      *free_cam__lastGravity = grav


  let inertia = length_sq(free_camera__move) <= 1e-8 ? free_camera__stopInertia : free_camera__moveInertia
  assume move = free_camera__move
  if free_camera__useFixedDirection
    let fixedDir = free_camera__fixedDirection
    let q = dir_to_quat(fixedDir)
    var tmpTm = IDENT_TM
    make_tm(q, transform[3], tmpTm)
    let moveVelocity = tmpTm[0] * move.x + tmpTm[1] * move.y + tmpTm[2] * move.z
    free_camera__curVelocity = free_camera__curVelocity * inertia + moveVelocity * moveSpeed * (1.0 - inertia)
    if (length_sq(moveVelocity) >= 1e-8)
      transform[3] += moveVelocity * moveSpeed * dt
  else
    var rotQ : quat
    var rotateTm = IDENT_TM
    let rotDelta = free_camera__rotationSpeed * dt
    if free_camera__rotate.x != 0.0
      let bankQuat = quat(transform[2], free_camera__rotate.x * rotDelta.x)
      free_camera__upVector = normalize(bankQuat * free_camera__upVector)

    let lockAng = dot(transform[2], free_camera__upVector)
    let lockPitch = (lockAng > 0.98 && free_camera__rotate.z > 0.0) ||  (lockAng < -0.98 && free_camera__rotate.z < 0.0)
    euler_to_quat(free_camera__rotate.y * rotDelta.y * cosFactor, 0.0, (lockPitch ? 0.0 : 1.0) * -free_camera__rotate.z * rotDelta.y, rotQ)
    make_tm(rotQ, rotateTm)
    transform = transform * rotateTm
    transform[0] = cross(free_camera__upVector, transform[2])
    transform[1] = cross(transform[2], transform[0])
    transform |> orthonormalize()

    let moveVelocity = transform[0] * move.x + transform[1] * move.y + transform[2] * move.z
    free_camera__curVelocity = free_camera__curVelocity * inertia + moveVelocity * moveSpeed * (1.0 - inertia)
    if (length_sq(moveVelocity) >= 1e-8)
      transform[3] += moveVelocity * moveSpeed * dt

  if free_camera__dashFramesLeft > 0
    free_camera__dashFramesLeft--
    let dashDst = free_camera__dashFramesLeft > 0 ? free_camera__dstLeft * 0.5 : free_camera__dstLeft
    free_camera__dstLeft -= dashDst
    transform[3] += free_camera__dashDir * dashDst


[es(tag=gameClient, on_event=CmdCameraDash)]
def free_camera_dash_es(evt : Event;
                        var free_camera__dashDir : float3&;
                        var free_camera__dashFramesLeft : int&;
                        var free_camera__dstLeft : float&;
                        transform : float3x4;
                        free_camera__move : float3;
                        free_camera__turboMode : bool;
                        free_camera__dashOverFrames = 5;
                        free_camera__dashDst = 100.0;
                        free_camera__dashStopAt = 5.0)
  let moveDir = normalize(transform * free_camera__move - transform[3])
  let traceDir = moveDir != float3() ? moveDir : transform[2]
  let multi = free_camera__turboMode ? 2.0 : 1.0
  var t = free_camera__dashDst * multi
  var norm : float3
  traceray_normalized(transform[3], traceDir, t, norm)
  if t <= free_camera__dashStopAt * multi * 1.05 //tolerance
    t *= 0.5
  else
    t -= free_camera__dashStopAt * multi
  free_camera__dashDir = traceDir
  free_camera__dashFramesLeft = free_camera__dashOverFrames
  free_camera__dstLeft = t