require ecs
require Plane
require DngPlane
require DagorMath
require math.base
require TargetDesignation
require TargetSignature
require Dacoll
require PhysMat


[cpp_event(broadcast)]
struct UpdateStageUpdateInput
  curTime : float
  dt : float


def push_target(var plane_net_phys : PlaneActor&;
                dir : float3;
                time : float)
  assume producedCT = plane_net_phys.phys.producedCT
  var target : TargetDesignationControlState
  target.sourceType = uint8(TARGET_DESIGNATION_SOURCE_TYPE_INVALID)
  target.hasAimPos = true
  let aimPos = float3(plane_net_phys.phys.currentState.location.P)
  target.aimPos = aimPos
  let distMax = 10000.0f
  var dist = distMax
  var norm : float3
  var matId = PHYSMAT_INVALID
  var riDesc = RendInstDesc()
  let res = traceray_normalized(aimPos, dir, dist, matId, norm, ETF_ALL, riDesc, -1)
  if res
    target.laserIllumination = true
  elif dir.y < -1.0e-3f
    dist = min(aimPos.y / -dir.y, distMax)
    target.laserIllumination = true
  else
    target.laserIllumination = false
  target.hasDist = true
  target.pos = target.aimPos + dir * dist
  target.dir = float3(0f, 0f, 0f)
  target.relVel = -float3(plane_net_phys.phys.currentState.velocity)
  target.time = time
  target.hasDopplerSpeed = false
  target.laserBeamMaxAngle = -1.0f
  target.radarIllumination = false
  target.isSelected = false
  target.uid = uint8(0u)
  assert(length_sq(target.dir) > 0.99f || target.hasDist)
  push(producedCT.targets, target)


[es(tag=input, after=plane_input_es)]
def plane_phys_update_guided_weapon_target_designation_es(info : UpdateStageUpdateInput;
                                                          flight_angles_enabled : bool;
                                                          flight_angles : float2;
                                                          var plane_net_phys : PlaneActor&)
  assume producedCT = plane_net_phys.phys.producedCT
  clear(producedCT.targets)

  if !flight_angles_enabled
    return

  var mouseAimQuat : quat
  euler_to_quat(flight_angles.x, flight_angles.y, 0.0f, mouseAimQuat)
  let dir = quat_get_forward(mouseAimQuat)
  push_target(plane_net_phys, dir, info.curTime)


[es(tag=input, REQUIRE=turret_control__guidanceByAimPos, after=turret_update_turret_aim_point)]
def plane_phys_update_guided_weapon_target_designation_by_aim_pos_es(info : UpdateStageUpdateInput;
                                                                     turretAimPos : float3;
                                                                     var plane_net_phys : PlaneActor&)
  assume producedCT = plane_net_phys.phys.producedCT
  clear(producedCT.targets)
  let dir = normalize(turretAimPos - float3(plane_net_phys.phys.currentState.location.P))
  push_target(plane_net_phys, dir, info.curTime)

[es(after=vehicle_phys_update_guided_weapon_target_signature_detectors_es, on_event=ParallelUpdateFrameDelayed)]
def plane_phys_update_guided_weapon_target_signature_detectors_es(evt : Event;
                                                                  turret_control__gunEids : EidList;
                                                                  plane_net_phys : PlaneActor)
  assume appliedCT = plane_net_phys.phys.appliedCT
  if length(appliedCT.targets) == 0
    return
  assume target = appliedCT.targets[0]
  for gunEid in turret_control__gunEids
    query(gunEid) <| $ [es] (var target_signature_detector : TargetSignatureDetectorContainer&)
      if length(target_signature_detector.targetDesignations) == 0
        return
      assume targetDesignation = target_signature_detector.targetDesignations[0]
      targetDesignation.hasAimPos ||= target.hasAimPos
      if target.hasAimPos
        targetDesignation.aimPos = target.aimPos
      targetDesignation.time = max(targetDesignation.time, target.time)
      targetDesignation.hasDist ||= target.hasDist
      targetDesignation.dir = !target.hasDist ? normalize_default(target.dir, float3(1f, 0f, 0f)) : target.dir
      targetDesignation.pos = target.pos
      if target.hasDist
        targetDesignation.relVel = target.relVel
      targetDesignation.laserIllumination = target.laserIllumination
