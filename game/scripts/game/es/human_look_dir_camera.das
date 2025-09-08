require ecs
require DngActor
require DngHuman
require HumanPhys
require math
require math.base
require DagorMathUtils
require math.ang
require app
require replay
require DagorMath
require AnimV20
require GeomNodeTree


[es(after=after_net_phys_sync, REQUIRE=watchedByPlr, REQUIRE_NOT=deadEntity)]
def human_look_dir_camera_es(info : UpdateStageInfoAct;
                             bindedCamera : EntityId;
                             isCameraTarget : bool;
                             human_net_phys : HumanActor;
                             camera__gunAimOffset : float2;
                             camera__followWeaponSpeed : float;
                             var camera__fastFollowViscosity : float&;
                             var camera__shootOffset : float2&;
                             var camera__prevLookDir : float3&;
                             var camera__lookDir : float3&;
                             camera__allowSlowFollow : bool = true;
                             camera__shootOffsetTau : float = 0.05f;
                             isAlive : bool = true;
                             noKillCam : Tag const?;
                             killer : EntityId = INVALID_ENTITY_ID;
                             human_inventory__entityToUse = INVALID_ENTITY_ID;
                             isInVehicle = false;
                             isDowned = false)

  if !isCameraTarget
    return

  camera__prevLookDir = camera__lookDir

  if isAlive || killer == INVALID_ENTITY_ID || noKillCam != null
    assume ct = human_net_phys.phys.producedCT
    let interpK = get_phys_interpk_clamped(human_net_phys.phys, info.curTime)

    var ang : float2
    if (int(human_net_phys.role) & int(NetRole.URF_LOCAL_CONTROL)) != 0
      ang = dir_to_angles(ct.wishLookDir)
    else
      // when in replay or observer, there's no need to lerp between currentState and previousState
      // headDir is more correct, but causes noticable jittering when in replay.
      ang = dir_to_angles(human_net_phys.phys.currentState.gunDir)

    var aimOffs = lerp(human_net_phys.phys.previousState.gunAimOffset, human_net_phys.phys.currentState.gunAimOffset, float2(interpK))
    if has(bindedCamera, "spectator") // human_weapon_aim on CmdPostPhysUpdate doesn't processed
      aimOffs = approach(aimOffs, float2(), info.dt, 0.f)
    aimOffs += camera__gunAimOffset

    camera__shootOffset = approach(camera__shootOffset, aimOffs, info.dt, camera__shootOffsetTau)
    ang += camera__shootOffset

    ang.y = clamp(ang.y, -SAFE_HALF_PI, SAFE_HALF_PI)

    let wishLookDir = angles_to_dir(ang)

    let isSprinting = human_net_phys.phys.currentState.moveState == HUMoveState.EMS_SPRINT
    let isAiming = human_net_phys.phys.currentState.isAiming
    let allowingSlowFollow = (!isSprinting &&
                          !isInVehicle &&
                          !isDowned &&
                          !isAiming &&
                          camera__allowSlowFollow &&
                          human_inventory__entityToUse == INVALID_ENTITY_ID)
    if allowingSlowFollow
      let lspeed = abs(1f - safeinv(dot(camera__lookDir, wishLookDir))) * camera__followWeaponSpeed
      camera__lookDir = move_to(camera__lookDir, wishLookDir, info.dt, lspeed)
      // find equal viscosity as start value
      let nspeed = abs(1f - safeinv(dot(camera__lookDir, wishLookDir))) * camera__followWeaponSpeed
      camera__fastFollowViscosity = safediv(length(wishLookDir - camera__lookDir), nspeed)
    else
      camera__lookDir = approach(camera__lookDir, wishLookDir, info.dt, camera__fastFollowViscosity)
      camera__fastFollowViscosity = move_to(camera__fastFollowViscosity, 0.0f, info.dt, 0.5f)


[es(on_appear)]
def camera_set_neck_node(evt : Event;
                         animchar : AnimcharBaseComponent;
                         killcam__neckNodeName : string;
                         var killcam__neckNodeIdx : int&)
  killcam__neckNodeIdx = geomtree_findNodeIndex(*animchar.nodeTree, killcam__neckNodeName)


[es(after=human_look_dir_camera_es, REQUIRE=(watchedByPlr, deadEntity), REQUIRE_NOT=noKillCam)]
def human_look_dir_dead_camera_es(info : UpdateStageInfoAct;
                                  eid : EntityId;
                                  killer : EntityId;
                                  transform : float3x4&;
                                  animchar : AnimcharBaseComponent;
                                  killcam__dotLimit : float = -0.6;
                                  killcam__killerOffset : float = 0.35;
                                  killcam__neckDotLimit : float = -0.5;
                                  killcam__neckNodeIdx : int;
                                  var camera__lookDir : float3&)
  let killerTm = get_TMatrix(killer, "transform")
  if killerTm != null
    let killerLookPos = (*killerTm)[3] + (*killerTm)[1] * killcam__killerOffset
    let toKillerDir = normalize(killerLookPos - transform[3])
    let d = dot(camera__lookDir, toKillerDir)
    if d >= killcam__dotLimit
      let lookDirQuat = dir_to_quat(camera__lookDir)
      let killerDirQuat = dir_to_quat(toKillerDir)
      camera__lookDir = slerp(lookDirQuat, killerDirQuat, info.dt) |> quat_get_forward()
  let neckPos = geomtree_getNodeWpos(*animchar.nodeTree, killcam__neckNodeIdx)
  var camPos = float3()
  find_query() <| $ [es] (camera__target : EntityId; transform : float3x4&)
    if camera__target == eid
      camPos = transform[3]
      return true
    return false
  let camToNeck = normalize(neckPos - camPos)
  let cos = dot(camToNeck, camera__lookDir)
  if cos > killcam__neckDotLimit
    //clamp
    let vec = normalize(camera__lookDir - camToNeck * cos) * sqrt(1.f - killcam__neckDotLimit * killcam__neckDotLimit)
    camera__lookDir = camToNeck * killcam__neckDotLimit + vec


[es(after=human_look_dir_camera_es, REQUIRE=watchedByPlr)]
def human_look_dir_camera_in_vehicle_es(info : UpdateStageInfoAct; bindedCamera : EntityId; isInVehicle, isAlive : bool; human_net_phys : HumanActor; var camera__lookDir : float3&)

  if !isInVehicle || !isAlive || is_replay_playing() || has(bindedCamera, "spectator")
    return

  assume ct = human_net_phys.phys.producedCT
  var ang = dir_to_angles(ct.wishLookDir)
  ang.y = clamp(ang.y, -SAFE_HALF_PI, SAFE_HALF_PI)
  camera__lookDir = angles_to_dir(ang)