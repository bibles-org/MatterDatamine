require ecs
require math.base
require DngCamera
require DagorMathUtils
require Gun
require DngActor
require game.es.human.human_weap_mods_common
require DngHuman
require DngWeapon
require DagorMath
require AnimV20
require GeomNodeTree
require game.es.human_weap_common
require game.events.events_active_matter


[es(tag=netClient, after=(human_phys_es, before_human_inventory_use_update), before=human_weap_update_es)]
def human_weap_client_es(info : UpdateStageInfoAct;
                         eid : EntityId;
                         human_weap__gunEids : EidList;
                         human_net_phys : HumanActor;
                         human_inventory__entityToUse : EntityId;
                         action__running : bool = false;
                         isInVehicle : bool = false;
                         isPassenger : bool = false;
                         isInVehicleHidden : bool = false;
                         isDowned : bool = false;
                         human_sec_anim__hideWeapon : bool = false;
                         human_sec_anim__hideMelee : bool = false;
                         human_sec_anim__play : bool = false;
                         human_unarmed__hiddenWeapon : bool = false;
                         state_counter__disableWeaponSwitch : int = 0;
                         burning__isPuttingOut : bool = false;
                         human_weap__blockAiming : bool = false;
                         isAlive : bool;
                         human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                         var human_weap__currentGunSlot : int&;
                         var human_weap__previousGunSlot : int&)
  if isAlive
    human_weap_es_impl(
      human_weap__currentGunSlot, human_weap__previousGunSlot, info.curTime, eid, human_weap__gunEids,
      human_net_phys, human_inventory__entityToUse, action__running,
      isInVehicle, isPassenger, isInVehicleHidden, isDowned, human_sec_anim__hideWeapon, human_sec_anim__hideMelee,
      human_sec_anim__play, human_unarmed__hiddenWeapon, state_counter__disableWeaponSwitch, burning__isPuttingOut,
      human_weap__blockAiming, human_attached_gun__attachedGunEid)


[es(tag=gameClient, after=human_phys_es, before=after_guns_update_sync, REQUIRE=(watchedByPlr, human_weap), REQUIRE_NOT=deadEntity)]
def human_weap_update_es(info : ParallelUpdateFrameDelayed;
                         eid : EntityId;
                         human_weap__gunAngleTau : float;
                         isInVehicle : bool;
                         human_weap__crawlClampVertAngleRad : float2;
                         human_weap__clampVertAngleRad : float2;
                         human_weap__aimInertia : float2;
                         humap_weap__useGrenadeInVehicle : bool = false;
                         human_weap__lockedGrenadeThrowingCounter : int = 0;
                         isDowned : bool = false;
                         entity_mods__shotDeviationMult : float = 1.0;
                         entity_mods__rotationShotSpreadDecrMult : float = 1.0;
                         entity_mods__aimingAfterFireMult : float = 1.0;
                         entity_mods__boltActionMult : float = 1.0;
                         entity_mods__deviationBufferSizeMult : float = 1.0;
                         entity_mods__shotDeviationAdd : float = 0.0;
                         human_weap__fastThrowExclusive : bool = true;
                         human_weap__maxParallaxDeviation : float = 10.0;
                         human_weap__extraGunSpeedOnJump : float = 0.0;
                         human_unarmed__active : bool = false;
                         human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                         var human_net_phys : HumanActor;
                         var transform : float3x4;
                         human_weap__gunEids : EidList;
                         var human_weap__throwMode : bool&;
                         var human_weap__prevGunAngles : float2&;
                         var human_weap__gunAngleSpeed : float2&;
                         var human_weap__traceIntersectedEid : EntityId&;
                         var human_weap__tracerayLen : float&)
  if isDowned || human_net_phys.phys.currentState |> human_phys_state_attachedToLadder
    return

  let dt = info.dt
  var atTime = info.curTime

  // Align updates on phys ticks to phys.timeStep for shooting end time synchronization
  let isLocallyControlled = (int(human_net_phys.role) & int(NetRole.URF_LOCAL_CONTROL)) != 0
  assume ct = isLocallyControlled ? human_net_phys.phys.producedCT : human_net_phys.phys.appliedCT
  if ct |> is_control_bit_set(HumanPhysControlType.HCT_SHOOT) && !ct.haveUnenqueuedHctShoot
    atTime = floor(atTime / human_net_phys.phys.timeStep) * human_net_phys.phys.timeStep // same time as on server

  let isForReal = true
  let wishGunDir = ct.wishShootDir
  var gunDir = wishGunDir
  var gunAngles = dir_to_angles(gunDir)
  var gunSpeedAng = gunAngles - human_weap__prevGunAngles
  gunSpeedAng.x = norm_s_ang(gunSpeedAng.x)
  let isInAir = (int(human_net_phys.phys.currentState.isInAirHistory) & 1) != 0
  if human_weap__extraGunSpeedOnJump > 0.0 && isInAir
    let humanVel = human_net_phys.phys.currentState.velocity
    let dir = human_net_phys.phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_AIM) ? 1.0 : -1.0
    gunSpeedAng.y += dir * cvt(humanVel.y, -1.0, 1.0, -human_weap__extraGunSpeedOnJump * dt * 60., human_weap__extraGunSpeedOnJump * dt * 60.)
  let gunSpeed = gunSpeedAng * safeinv(dt)
  human_weap__gunAngleSpeed = approach(human_weap__gunAngleSpeed, gunSpeed, dt, human_weap__gunAngleTau)

  assume phys = human_net_phys.phys
  let vertLimits = phys.currentState.isCrawl ? human_weap__crawlClampVertAngleRad : human_weap__clampVertAngleRad
  let vertDir = human_net_phys.phys.currentState.vertDirection
  let rootDir = get_some_normal(vertDir)
  var properAngles = basis_aware_dir_to_angles(gunDir, vertDir, rootDir)
  apply_gun_angle_offsets(phys, atTime, vertLimits, phys.currentState.vertDirection, properAngles)
  let postDir = basis_aware_angles_to_dir(properAngles, vertDir, rootDir)
  gunAngles = dir_to_angles(postDir)
  let gunAnglesOffset = human_weap__aimInertia // TODO: move to apply_gun_angle_offsets
  gunAngles += gunAnglesOffset
  human_weap__prevGunAngles = gunAngles
  gunDir = angles_to_dir(gunAngles)

  let up = transform[1]
  var horzDir = normalize(gunDir - dot(gunDir, up) * up)

  assume prevState = phys.previousState
  assume curState  = phys.currentState
  if prevState.moveState == HUMoveState.EMS_SPRINT || curState.moveState == HUMoveState.EMS_SPRINT
    let from = prevState.moveState == HUMoveState.EMS_SPRINT ? 1.0 : 0.0
    let to = curState.moveState == HUMoveState.EMS_SPRINT ? 1.0 : 0.0
    let interpK = get_phys_interpk_clamped(phys, atTime)
    horzDir = slerp(dir_to_quat(horzDir), dir_to_quat(transform[0]), lerp(from, to, interpK)) |> quat_get_forward()
  transform[0] = horzDir
  transform |> orthonormalize()

  var gunShootDir = gunDir
  let gunEid = get_human_gun_eid(eid)
  if gunEid != INVALID_ENTITY_ID && ct |> is_control_bit_set(HumanPhysControlType.HCT_SHOOT) && !ct.haveUnenqueuedHctShoot
    query(gunEid) <| $ [es] (gun__aimRayMatId : int = -1; gun : Gun)
      let cameraTm = get_cur_cam_entity() |> get_TMatrix("transform") ?? IDENT_TM
      let camPos = cameraTm[3]
      human_weap__tracerayLen = 100.0
      human_weap__traceIntersectedEid = do_gun_traceray(camPos, gunDir, human_weap__tracerayLen, gun__aimRayMatId, eid)
      let shootTm = gun.shootNodeData |> gun_shoot_node_data_calcShootTm(gunDir, transform, transform)
      let shootPos = shootTm[3]
      gunShootDir = normalize(camPos + gunDir * human_weap__tracerayLen - shootPos)
      let initialGunAngles = dir_to_angles(gunDir)
      var wishGunAngles = dir_to_angles(gunShootDir)
      let angDevRad = deg_to_rad(human_weap__maxParallaxDeviation)
      wishGunAngles.x = clamp(renorm_ang(wishGunAngles.x, initialGunAngles.x), initialGunAngles.x - angDevRad,
                                                                               initialGunAngles.x + angDevRad)
      wishGunAngles.y = clamp(wishGunAngles.y, initialGunAngles.y - angDevRad, initialGunAngles.y + angDevRad)
      gunShootDir = angles_to_dir(wishGunAngles)

  let updCtx = GunUpdateCtx(
    dt = dt,
    atTime = atTime,
    isForReal = isForReal,
    eid = eid,
    isDowned = isDowned,
    isThrowingAllowed = human_weap__lockedGrenadeThrowingCounter == 0 && (humap_weap__useGrenadeInVehicle || !isInVehicle),
    shotDeviationMult = entity_mods__shotDeviationMult,
    rotationShotSpreadDecrMult = entity_mods__rotationShotSpreadDecrMult,
    aimingAfterFireMult = entity_mods__aimingAfterFireMult,
    boltActionMult = entity_mods__boltActionMult,
    shotDeviationAdd = entity_mods__shotDeviationAdd,
    fastThrowExclusive = human_weap__fastThrowExclusive,
    deviationBufferSizeMult = entity_mods__deviationBufferSizeMult)

  let physTransform = human_net_phys.phys.currentState.location |> location_makeTM()
  human_weap_update(human_net_phys, human_weap__gunEids, human_weap__throwMode,
                    updCtx, transform, gunDir, gunShootDir, physTransform,
                    ct, human_unarmed__active, human_attached_gun__attachedGunEid)


[es(tag=gameClient, before=human_weap_update_es, REQUIRE_NOT=deadEntity)]
def human_weapon_inertia(info : ParallelUpdateFrameDelayed;
                         isDowned : bool;
                         isInVehicle : bool;
                         human_net_phys : HumanActor;
                         human_input__aimAngle : float2;
                         human_input__oldAimAngle : float2;
                         human_weap__currentGunEid : EntityId;
                         human_weap__aimInertiaCrouchMult : float;
                         human_weap__aimInertiaCrawlMult : float;
                         human_weap__aimInertiaAimingMult : float;
                         human_weap__aimInertiaStrengthMult : float;
                         human_weap__aimInertiaDampingMult : float;
                         human_weap__aimInertiaStiffnessMultStart : float;
                         human_weap__aimInertiaStiffnessMultEnd : float;
                         human_weap__aimInertiaDampingMultStart : float;
                         human_weap__aimInertiaDampingMultEnd : float;
                         human_weap__aimInertiaBoostInterval : float2;
                         human_weap__aimInertiaDeltaTime : float;
                         human_weap__aimInertiaMaxMult : float;
                         human_weap__aimInertiaVelocityMax : float;
                         human_weap__aimInertiaMinWeight : float;
                         human_weap__aimInertiaViscosity : float;
                         human_weap__crawlClampVertAngleRad : float2;
                         human_weap__clampVertAngleRad : float2;
                         var human_weap__aimInertia : float2&;
                         var human_weap__aimInertiaVelocity : float2&;
                         var human_weap__aimInertiaLastTick : int&;
                         var human_weap__aimInertiaLocal : float2&;
                         human_input__gunToAimAngleLimit = float2(180f, 180f))
  if human_weap__aimInertiaLastTick < 0
    human_weap__aimInertiaLastTick = int(safediv(info.curTime, human_weap__aimInertiaDeltaTime))
    return

  assume inertia = human_weap__aimInertia
  assume localInertia = human_weap__aimInertiaLocal
  assume inertiaVel = human_weap__aimInertiaVelocity

  let curTick = int(safediv(info.curTime, human_weap__aimInertiaDeltaTime))
  let weight = get_float(human_weap__currentGunEid, "item__weight") ?? 0.0

  if (isDowned || isInVehicle || has(human_weap__currentGunEid, "disableWeaponInertia") ||
    weight < human_weap__aimInertiaMinWeight)
    inertia = float2()
    localInertia = float2()
    inertiaVel = float2()
    human_weap__aimInertiaLastTick = curTick
    return

  var strength = weight * human_weap__aimInertiaStrengthMult
  if human_net_phys.phys.currentState.isCrouch
    strength *= human_weap__aimInertiaCrouchMult
  elif human_net_phys.phys.currentState.isCrawl
    strength *= human_weap__aimInertiaCrawlMult
  if human_phys_isAiming(human_net_phys.phys)
    strength *= human_weap__aimInertiaAimingMult
  strength = safeinv(strength)

  var k = square(strength)
  var c = 2.0 * human_weap__aimInertiaDampingMult * strength

  let deltaAimAngleRaw = human_input__aimAngle - human_input__oldAimAngle
  let deltaAimAngle = float2(norm_s_ang(deltaAimAngleRaw.x), norm_s_ang(deltaAimAngleRaw.y))
  localInertia -= deltaAimAngle

  let inertiaLenSq = length_sq(inertia)
  if inertiaLenSq < square(human_weap__aimInertiaBoostInterval.x)
    k *= human_weap__aimInertiaStiffnessMultEnd
    c *= human_weap__aimInertiaDampingMultEnd
  elif inertiaLenSq > square(human_weap__aimInertiaBoostInterval.y)
    k *= human_weap__aimInertiaStiffnessMultStart
    c *= human_weap__aimInertiaDampingMultStart

  let inertiaMax = human_weap__aimInertiaMaxMult * deg_to_rad(human_input__gunToAimAngleLimit)
  for _ in range(human_weap__aimInertiaLastTick, curTick)
    let inertiaAccel = -localInertia * k - inertiaVel * c
    localInertia += inertiaVel * human_weap__aimInertiaDeltaTime
    localInertia.x = clamp(localInertia.x, -inertiaMax.x, inertiaMax.x)
    localInertia.y = clamp(localInertia.y, -inertiaMax.y, inertiaMax.y)
    inertiaVel += inertiaAccel * human_weap__aimInertiaDeltaTime
    inertiaVel.x = clamp(inertiaVel.x, -human_weap__aimInertiaVelocityMax, human_weap__aimInertiaVelocityMax)
    inertiaVel.y = clamp(inertiaVel.y, -human_weap__aimInertiaVelocityMax, human_weap__aimInertiaVelocityMax)

  human_weap__aimInertiaLastTick = curTick

  let vertDir = human_net_phys.phys.currentState.vertDirection
  let rootDir = get_some_normal(vertDir)
  let aimDir = basis_aware_angles_to_dir(human_input__aimAngle, vertDir, rootDir)
  let vertLimits = human_net_phys.phys.currentState.isCrawl ? human_weap__crawlClampVertAngleRad : human_weap__clampVertAngleRad
  var localInertiaInLocAngles = human_input__aimAngle + localInertia
  localInertiaInLocAngles.y = clamp(localInertiaInLocAngles.y, vertLimits.x, vertLimits.y)
  let localInertiaInGlobDir = basis_aware_angles_to_dir(localInertiaInLocAngles, vertDir, rootDir)
  var wishInertia = dir_to_angles(localInertiaInGlobDir) - dir_to_angles(aimDir)
  wishInertia = float2(norm_s_ang(wishInertia.x), norm_s_ang(wishInertia.y))
  inertia = approach(inertia, wishInertia, info.dt, human_weap__aimInertiaViscosity)


[es(tag=render, REQUIRE=watchedByPlr, after=camera_set_sync, before=before_camera_sync,
     after=animchar_cam_target_es, after=(animchar_cam_target_with_offset_es, after_net_phys_sync, human_fpv_cam_pos))]
def human_gun_lookat_camera_es(info : UpdateStageInfoAct;
                               human_net_phys : HumanActor;
                               human_weap__currentGunEid : EntityId;
                               human__aimTm : float3x4;
                               human_weap__gunOffset : float3;
                               action__running : bool = false;
                               var camera__aimPosition : float&;
                               var camera__gunAimOffset : float2&;
                               var camera__lastValidGunAimPos : float3&;
                               var camera__look_at : DPoint3&;
                               isReplayObserved : Tag const?;
                               spectator__observed : Tag const?)

  query(human_weap__currentGunEid) <| $ [es] (entity_cam_nodes__aimNodeIdx : int;
                                              animchar : AnimcharBaseComponent;
                                              gun__maxSightOffset : float = 0.03;
                                              gun__sightOffsetToAimPositionPower : float = 3.0;
                                              weapon__aimPointRelativePos : float = 0.0;
                                              weapon__aimNodeOffset : float = 0.0;
                                              weapon_frontsight_node__nodeIdx : int const?;
                                              weapon_rearsight_node__nodeIdx : int const?;
                                              weapon_sight__minDistFrom : float = 0.05)

    if entity_cam_nodes__aimNodeIdx < 0
      return

    let interpK = get_phys_interpk_clamped(human_net_phys.phys, info.curTime)
    let physPreviousStateAimPosition = human_net_phys.phys.previousState.aimPosition
    let physCurrentStateAimPosition = human_net_phys.phys.currentState.aimPosition
    var wishAimPosition = lerp(physPreviousStateAimPosition, physCurrentStateAimPosition, interpK)

    let wofsF = *animchar.nodeTree |> geomtree_getWtmOfs()
    let wofs = DPoint3(wofsF)
    var aimTm : float3x4
    *animchar.nodeTree |> geomtree_getNodeWtmRelScalar(entity_cam_nodes__aimNodeIdx, aimTm)
    var aimPos = aimTm[3] + aimTm[0] * weapon__aimNodeOffset
    var aimOffset = float2(0.0, 0.0)

    if weapon_frontsight_node__nodeIdx != null && weapon_rearsight_node__nodeIdx != null
      let weaponFrontsightNodeIdx = *weapon_frontsight_node__nodeIdx
      let weaponRearsightNodeIdx = *weapon_rearsight_node__nodeIdx

      if weaponFrontsightNodeIdx < 0 || weaponRearsightNodeIdx < 0
        return

      let fsPos = *animchar.nodeTree |> geomtree_getNodeWposRel(weaponFrontsightNodeIdx)
      let rsPos = *animchar.nodeTree |> geomtree_getNodeWposRel(weaponRearsightNodeIdx)

      var frontSightTm : float3x4
      *animchar.nodeTree |> geomtree_getNodeWtmRelScalar(0, frontSightTm)
      frontSightTm[3] = fsPos
      let sightDir = normalize(inverse(frontSightTm) * rsPos)
      frontSightTm[3] = fsPos + (rsPos - fsPos) * weapon__aimPointRelativePos

      // Now construct augmented tm so we can use it
      var augmentedFrontSightTm = frontSightTm
      // fix fps camera in replay
      // human__aimTm is local and server variable, so we can't get this varible in replay
      // for 'restore' it we need to sync HCT_SHOOT, but if we will use frontSightTm
      // we get the same result, so let's use frontSightTm without any extra replication
      if isReplayObserved == null && spectator__observed == null
        augmentedFrontSightTm[0] = human__aimTm[2]
        augmentedFrontSightTm[1] = human__aimTm[1]
        augmentedFrontSightTm[2] = -human__aimTm[0]

      var len = length(frontSightTm[3] - aimPos)
      let dir = rsPos - frontSightTm[3]
      let dist = length(dir)
      len = max(dist + weapon_sight__minDistFrom, len + human_weap__gunOffset.x)
      let currentRearSightPos = sightDir * len
      let trueAimPos = frontSightTm * currentRearSightPos
      let wishAimPos = augmentedFrontSightTm * currentRearSightPos

      let aimPosOffsetDir = wishAimPos - trueAimPos
      let aimPosOffsetLenSq = length_sq(aimPosOffsetDir)
      if aimPosOffsetLenSq < square(gun__maxSightOffset)
        aimPos = wishAimPos
      else
        let offsetRatio = safediv(gun__maxSightOffset, sqrt(aimPosOffsetLenSq))
        aimPos = trueAimPos + aimPosOffsetDir * offsetRatio
        wishAimPosition = min(wishAimPosition, pow(offsetRatio, gun__sightOffsetToAimPositionPower))
      aimOffset = float2(0.0, atan2(-sightDir.y, sightDir.z))

    if !human_net_phys.phys.currentState |> human_phys_state_can_aim()
      wishAimPosition = 0.0
      aimOffset = float2(0.0, 0.0)
      aimPos = camera__lastValidGunAimPos
    else
      camera__lastValidGunAimPos = aimPos

    let aimSpeed = human_net_phys.phys.aimSpeed * human_net_phys.phys.currentState.aimSpeedMult
    camera__aimPosition = move_to(camera__aimPosition, wishAimPosition, info.dt, aimSpeed)

    if !action__running
      camera__look_at = lerp(camera__look_at, wofs + DPoint3(aimPos), camera__aimPosition)
      aimOffset = lerp(float2(0.0, 0.0), aimOffset, float2(camera__aimPosition))
    else
      aimOffset = float2(0.0, 0.0)

    camera__gunAimOffset = approach(camera__gunAimOffset, aimOffset, info.dt, 0.1)


[es(tag=render,
     before=before_camera_sync,
     after=(animchar_cam_target_es, animchar_cam_target_with_offset_es, human_gun_lookat_camera_es),
     REQUIRE=watchedByPlr)]
def human_optics_lookat_camera_es(info : UpdateStageInfoAct;
                                  human__aimTm : float3x4;
                                  human_net_phys : HumanActor;
                                  human_weap__currentGunEid : EntityId;
                                  human_weap__currentGunModEids : ecs::EidList;
                                  human_weap__recoilPunchPos : float;
                                  bindedCamera : EntityId;
                                  var camera__look_at : DPoint3&;
                                  var camera__gunAimOffset : float2&;
                                  var camera__lastValidGunAimPos : float3&;
                                  action__running : bool = false)
  var gunScopeEid = find_scope_eid(human_weap__currentGunModEids)
  let isIntegratedScope = get_bool(human_weap__currentGunEid, "gun__integratedScope") ?? false
  if isIntegratedScope && !gunScopeEid
    gunScopeEid = human_weap__currentGunEid

  var gunTm = human__aimTm
  query(human_weap__currentGunEid) <| $ [es] (animchar : AnimcharBaseComponent)
    animchar |> animchar_get_tm(gunTm)

  query(gunScopeEid) <| $ [es] (gunmod__camNode : string;
                                animchar : AnimcharBaseComponent;
                                gunmod__camShiftMin : float;
                                gunmod__camShiftMax : float;
                                gunmod__camFovMin : float;
                                gunmod__camFovMax : float)
    set_lookat_from_sight_node(info.curTime, human_net_phys,
                               gunmod__camNode, animchar,
                               human__aimTm, human_weap__recoilPunchPos,
                               gunTm, bindedCamera,
                               gunmod__camShiftMin, gunmod__camShiftMax,
                               gunmod__camFovMin, gunmod__camFovMax,
                               gunScopeEid,
                               action__running,
                               camera__look_at,
                               camera__gunAimOffset,
                               camera__lastValidGunAimPos)


[es(tag=render, REQUIRE=watchedByPlr, after=camera_set_sync, before=before_camera_sync,
     after=human_gun_lookat_camera_es, after=human_optics_lookat_camera_es)]
def human_gun_lookat_camera_on_action_es(info : UpdateStageInfoAct;
                                         animchar : AnimcharBaseComponent;
                                         animchar_camera_target__nodeIndex : int;
                                         human_weap__cameraTransitionOnActionProgress : float;
                                         var camera__look_at : DPoint3&)
  let progress = saturate(human_weap__cameraTransitionOnActionProgress)
  if (progress > 0.0)
    let animcharCameraTargetPos = *animchar.nodeTree |> geomtree_getNodeWpos(animchar_camera_target__nodeIndex)
    camera__look_at = lerp(camera__look_at, DPoint3(animcharCameraTargetPos), progress)


[es(tag=gameClient, before=human_gun_lookat_camera_on_action_es)]
def human_weap_camera_in_action_es(act : UpdateStageInfoAct;
                                   action__running : bool;
                                   human_weap__cameraTransitionOnActionTime : float = 0.2;
                                   var human_weap__cameraTransitionOnActionProgress : float&)
  if action__running || human_weap__cameraTransitionOnActionProgress > 0.0
    let change = safediv(act.dt, human_weap__cameraTransitionOnActionTime)
    human_weap__cameraTransitionOnActionProgress += action__running ? change : -change
    human_weap__cameraTransitionOnActionProgress = saturate(human_weap__cameraTransitionOnActionProgress)