require ecs
require ecs.safe
require ecs.soa_template
require app
require CollRes
require AnimV20
require math.base
require game.events.events
require game.events.events_game
require game.events.events_active_matter
require DngHumanAnim
require DngHuman
require DngActor
require PhysVars
require PhysDecl
require HumanPhys
require DagorMath
require DagorSystem
require DngWeapon
require strings
require HumanAnim
require DagorMathUtils


def calc_head_pitch_yaw(state : HumanPhysState)
  let localGunDir = inverse(state.location.O.quat) * state.gunDir
  let localHeadDir = inverse(state.location.O.quat) * state.headDir
  let yawPitch = float2(-atan2(localGunDir.z, localGunDir.x), atan2(localGunDir.y, length(localGunDir.xz)))
  return float2(-atan2(localHeadDir.z, localHeadDir.x) - yawPitch.x,
                 atan2(localHeadDir.y, length(localHeadDir.xz)) - yawPitch.y)

def calc_shoot_anims(actor : HumanActor;
                     eid : EntityId;
                     at_time : float;
                     tm : float3x4;
                     var pitch : float&;
                     var head_pitch : float&;
                     var head_yaw : float&)
  assume phys = actor.phys
  let interpK = get_phys_interpk_clamped(phys, at_time)

  let prevHead = calc_head_pitch_yaw(phys.previousState)
  let curHead = calc_head_pitch_yaw(phys.currentState)
  let prevGun = dir_to_quat(phys.previousState.gunDir)
  let curGun = dir_to_quat(phys.currentState.gunDir)
  var interpGun = slerp(prevGun, curGun, interpK)
  let gun = get_human_gun(eid)
  var shootTm : float3x4
  make_tm(interpGun, shootTm)
  let requiredNetRole = uint(NetRole.URF_LOCAL_CONTROL)
  let isRealWeaponInHand = phys.currentState.weapEquipState.curSlot != HUWeaponSlots.EWS_GRENADE // Workaround, need better check
  if isRealWeaponInHand && gun != null && (uint(actor.role) & requiredNetRole) != 0u
    human_gun_get_shoot_tm(*gun, phys, at_time, shootTm)
    interpGun = DagorMath::quat(shootTm)

  pitch = atan2(dot(tm[1], shootTm[0]), dot(tm[0], shootTm[0]))
  head_yaw = clamp(lerp(prevHead.x, curHead.x, interpK), deg_to_rad(-45.0), deg_to_rad(45.0))
  head_pitch = clamp(lerp(prevHead.y, curHead.y, interpK), deg_to_rad(-70.0), deg_to_rad(60.0))


[es(REQUIRE_NOT=animchar__actOnDemand, no_order)]
def human_anim_es(info : ParallelUpdateFrameDelayed;
                  ragdoll : PhysRagdoll const?;
                  human_anim__climbHeights : Array;
                  human_anim__fastClimbHeights : Array;
                  human_anim__climbOverHorzPoints : Array;
                  human_anim__crawlMoveTransitionTime : float;
                  human_anim__crawlMoveTransitionLimit : float;
                  human_anim__crawlMoveTransitionSpeed : float;
                  dm_parts__hitPartsAnimationId : Array const?;
                  human_net_phys__climbToPos : float3 = float3();
                  human_net_phys__climbPosBehindObstacle : float3 = float3();
                  transform : float3x4;
                  prevLocoQuat : float4 = float4(0.0, 0.0, 0.0, 1.0);
                  human_net_phys : HumanActor;
                  eid : EntityId;
                  isAlive : bool;
                  stunTimer : float;
                  human_phys__jumpEndTime : float;
                  human_phys__afterJumpDelay : float;
                  hitpoints__lastHitNodeId : int = -1;
                  human_inventory__entityToUse : EntityId = INVALID_ENTITY_ID;
                  human_inventory__targetToUse : EntityId = INVALID_ENTITY_ID;
                  human_inventory__entityUseEnd : float = -1.0;
                  human_anim__vehicleSelected : EntityId = INVALID_ENTITY_ID;
                  human_anim__headYawRotVisc : float = 0.2;
                  human_net_phys__isClimbing : bool = false;
                  human_net_phys__isFastClimbing : bool = false;
                  human_net_phys__isClimbingOverObstacle : bool = false;
                  human_weap_anim__reloadAtTime : float = -1.0;
                  human_weap_anim__reloadStartTime : float = -1.0;
                  human_weap__blockAiming : bool = false;
                  isGunner : bool = false;
                  isInVehicle : bool = false;
                  human_weap__throwMode : bool = false;
                  animchar__scale : float = 1.0;
                  human_anim__airSpeedMult : float = 0.05;
                  human_anim__jumpTransitionTime : float = 2.0;
                  human_anim__jumpVertSpeedTransitionOffset : float = -10.0;
                  human_anim__vertVelVisc : float = 0.2;
                  human_anim__considerFwdStopped : float = 0.1;
                  human_anim__considerFallingCoef : float = 2.0;
                  human_anim__localWalkDirVarId : int;
                  human_anim__rootRotateVarId : int;
                  human_anim__rootRotateViscosity : float = 0.05;
                  human_anim__headRollVarId : int;
                  human_anim__headRollViscosity : float = 0.1;
                  human_anim__headRollSpeed : float = 7.0;
                  human_anim__headRollInAim : float = 22.0;
                  human_death_anim__selectedDeathAnimStateId : int;
                  burning__isPuttingOut : bool = false;
                  burning__animPutOutEnum : int = -1;
                  human_anim__crawlThreshold : float = -0.1f;
                  human_anim__toCrawlTransitionAnimId : int = -1;
                  human_anim__toCrawlTransitionVarId : int = -1;
                  human_anim__fromCrawlTransitionAnimId : int = -1;
                  human_anim__fromCrawlTransitionVarId : int = -1;
                  human_vehicle_anim__upperId : int = -1;
                  human_vehicle_anim__lowerId : int = -1;
                  human_vehicle_anim__fireReadyUpperId : int = -1;
                  human_vehicle_anim__fireReadyLowerId : int = -1;
                  animchar__updatable : bool;
                  animchar__visible : bool = true;
                  animchar__accumDt = -1.f;
                  animchar__dtThreshold = 0.f;
                  animchar__actWhenInvisible : bool = false;
                  var human_anim : HumanAnimCtx;
                  var phys_vars : PhysVars;
                  var animchar__animSpeed : float&;
                  var human_anim__crawlMoveTransitionEndAt : float&;
                  var human_anim__jumpTimer : float&;
                  var human_anim__lastClimbTime : float&;
                  human_anim__headAimOffsets = float2(0.0))
  if !animchar__updatable || (!animchar__visible && (animchar__accumDt + info.dt) < animchar__dtThreshold && !animchar__actWhenInvisible)
    return

  var pitch : float
  var headPitch : float
  var headYaw : float

  calc_shoot_anims(human_net_phys, eid, info.curTime, transform, pitch, headPitch, headYaw)
  headPitch += human_anim__headAimOffsets.x
  headYaw += human_anim__headAimOffsets.y

  let dt = info.dt
  let curTime = get_sync_time()

  var animHitPartId = 0
  if dm_parts__hitPartsAnimationId != null && hitpoints__lastHitNodeId > -1
    animHitPartId = (hitpoints__lastHitNodeId < length(*dm_parts__hitPartsAnimationId) ?
      (*dm_parts__hitPartsAnimationId)[hitpoints__lastHitNodeId] ?? 0 : 0)

  let unitTm = transform
  assume phys = human_net_phys.phys

  let interpK = get_phys_interpk_clamped(phys, curTime)

  let rootDir = get_some_normal(phys.currentState.vertDirection)
  let sideDir = normalize(cross(rootDir, phys.currentState.vertDirection))

  let prevRootDir = get_some_normal(phys.previousState.vertDirection)
  let prevSideDir = normalize(cross(prevRootDir, phys.previousState.vertDirection))

  //Can't lerp phys.currentState.bodyOrientDir because it may change in a non-smooth way. Lerp bodyDir3d instead.
  let curBodyDir3d = relative_2d_dir_to_absolute_3d_dir(phys.currentState.bodyOrientDir, rootDir, sideDir)
  let prevBodyDir3d = relative_2d_dir_to_absolute_3d_dir(phys.previousState.bodyOrientDir, prevRootDir, prevSideDir)
  let bodyDir3d = lerp(prevBodyDir3d, curBodyDir3d, float3(interpK))

  let curWalkDir3d = relative_2d_dir_to_absolute_3d_dir(phys.currentState.walkDir, rootDir, sideDir)
  let prevWalkDir3d = relative_2d_dir_to_absolute_3d_dir(phys.previousState.walkDir, prevRootDir, prevSideDir)
  let walkDir3d = lerp(prevWalkDir3d, curWalkDir3d, float3(interpK))


  let velDelta = lerp(phys.previousState.velocity - phys.previousState.standingVelocity,
                      phys.currentState.velocity - phys.currentState.standingVelocity, float3(interpK))
  var isClimbing = human_net_phys__isClimbing
  let isFastClimbing = human_net_phys__isFastClimbing
  let isClimbingOverObstacle = human_net_phys__isClimbingOverObstacle

  var headRoll = 0.0

  phys_vars |> setVar(human_anim.gunPitchVarId, rad_to_deg(pitch))

  // human_net_phys.phys.appliedCT HCT_AIM has human_phys_state_can_aim && when recieving snapshots
  // but this does not happen for local client hence the additional human_phys_state_can_aim check
  if is_control_bit_set(human_net_phys.phys.appliedCT, HumanPhysControlType.HCT_AIM) && human_phys_state_can_aim(phys.currentState)
    let breathOffset = lerp(phys.previousState.breathOffset, phys.currentState.breathOffset, float2(interpK))
    headYaw += breathOffset.x * 0.9
    headPitch += breathOffset.y * 0.9
    headRoll = human_anim__headRollInAim
    var hd : float
    var att : float
    var bank : float
    let q = quat(prevLocoQuat)
    quat_to_euler(q, hd, att, bank)
    headPitch += att
    headPitch = max(0.0, headPitch)
  phys_vars |> setVar(human_anim.headPitchVarId, rad_to_deg(headPitch))
  let prevHeadYawVar = phys_vars |> getVar(human_anim.headYawVarId)
  let newHeadYawVar = approach(prevHeadYawVar, rad_to_deg(headYaw),
                               dt, human_anim__headYawRotVisc)
  phys_vars |> setVar(human_anim.headYawVarId, newHeadYawVar)
  let prevHeadRollVar = phys_vars |> getVar(human_anim__headRollVarId)
  let newHeadRollVar = approach(move_to(prevHeadRollVar, headRoll, dt, human_anim__headRollSpeed), headRoll,
                                dt, human_anim__headRollViscosity)
  let standHeight = lerp(phys.previousState.height, phys.currentState.height, interpK)
  phys_vars |> setVar(human_anim__headRollVarId, newHeadRollVar)
  phys_vars |> setVar(human_anim.leanVarId, lerp(phys.previousState.leanPosition, phys.currentState.leanPosition, interpK))
  phys_vars |> setVar(human_anim.standHeightVarId, standHeight)
  phys_vars |> setVar(human_anim.hitPartsSelectedVarId, float(animHitPartId))

  let up = unitTm[1]
  var dir = unitTm[0]
  dir = normalize(dir - up * dot(dir, up))
  //let persCourse = rad_to_deg(atan2(dot(dir, sideDir), dot(dir, rootDir)))
  let bodyAngles = basis_aware_dir_to_angles(bodyDir3d, up, dir)
  let walkAngles = basis_aware_dir_to_angles(walkDir3d, up, dir)
  phys_vars |> setVar(human_anim.persCourseVarId, .0)

  let isSwimming = human_phys_state_get_is_swimming(human_net_phys.phys.currentState)
  let spd = invoke() <|
    if (int(human_net_phys.phys.currentState.isInAirHistory) & 1) != 0 && !isSwimming && !isClimbing
      human_anim__jumpTimer += info.dt
      let jk = cvt(human_anim__jumpTimer, 0.0, human_anim__jumpTransitionTime * 0.5, 1.0, human_anim__airSpeedMult)
      return length(velDelta) * jk
    else
      human_anim__jumpTimer = 0.0
      return length(velDelta)

  let standState = phys.currentState.standState
  let isFromCrawlTransition = standHeight > phys.previousState.height && phys.currentState.height < human_anim__crawlThreshold

  let statePos = (
                 standState == HUStandState.ESS_STAND ? HumanStatePos.E_STAND :
                 standState == HUStandState.ESS_DOWNED ? HumanStatePos.E_DOWNED :
                 standState == HUStandState.ESS_CROUCH ? HumanStatePos.E_CROUCH :
                 standState == HUStandState.ESS_CRAWL ? HumanStatePos.E_CRAWL :
                 standState == HUStandState.ESS_SWIM ? HumanStatePos.E_SWIM :
                 standState == HUStandState.ESS_SWIM_UNDERWATER ? HumanStatePos.E_SWIM_UNDERWATER :  HumanStatePos.E_STAND)

  var stateMove = (phys.currentState.moveState == HUMoveState.EMS_SPRINT ? HumanStateMove.E_SPRINT :
                   phys.currentState.moveState == HUMoveState.EMS_WALK || phys.currentState.moveState == HUMoveState.EMS_RUN ? HumanStateMove.E_MOVE :
                   phys.currentState.moveState == HUMoveState.EMS_ROTATE_LEFT ? HumanStateMove.E_ROTATE_LEFT :
                   phys.currentState.moveState == HUMoveState.EMS_ROTATE_RIGHT ? HumanStateMove.E_ROTATE_RIGHT :
                   HumanStateMove.E_STILL)

  let standingInPlace = (stateMove == HumanStateMove.E_ROTATE_LEFT ||
                         stateMove == HumanStateMove.E_ROTATE_RIGHT ||
                         stateMove == HumanStateMove.E_STILL)
  let localWalkDirFrom = standingInPlace ? -rad_to_deg(bodyAngles.x) : -rad_to_deg(walkAngles.x)
  let localWalkDir = norm_s_ang_deg(localWalkDirFrom + rad_to_deg(bodyAngles.x))
  phys_vars |> setVar(human_anim__localWalkDirVarId, localWalkDir)

  let prevRootRotate = phys_vars |> getVar(human_anim__rootRotateVarId)
  var rootRotate = (standingInPlace ? localWalkDirFrom : approach(prevRootRotate, 0.0, dt, human_anim__rootRotateViscosity))

  var stateUpperBody = HumanStateUpperBody.E_READY
  if human_weap__throwMode
    let effectiveCurSlot = phys.currentState.weapEquipState.effectiveCurSlot
    stateUpperBody = (effectiveCurSlot == HUWeaponSlots.EWS_GRENADE ? HumanStateUpperBody.E_THROW
                                                                    : HumanStateUpperBody.E_FAST_THROW)
  elif (phys.currentState.weapEquipState.curState == HUWeaponEquipState.EES_HOLSTERING ||
        phys.currentState.weapEquipState.curState == HUWeaponEquipState.EES_EQUIPING ||
        phys.previousState.weapEquipState.curState == HUWeaponEquipState.EES_HOLSTERING ||
        phys.previousState.weapEquipState.curState == HUWeaponEquipState.EES_EQUIPING)
    stateUpperBody = HumanStateUpperBody.E_CHANGE

    assume prevState = phys.previousState.weapEquipState
    assume curState = phys.currentState.weapEquipState
    let prevProgress = (prevState.curState == HUWeaponEquipState.EES_EQUIPING ? 0.5 : 0.0) + prevState.progress * 0.5
    let curProgress = (curState.curState != HUWeaponEquipState.EES_HOLSTERING ? 0.5 : 0.0) + curState.progress * 0.5
    let progress = lerp(prevProgress, curProgress, interpK)
    phys_vars |> setVar(human_anim.changeWeaponVarId, 1.0 - abs(1.0 - progress * 2.0))
    phys_vars |> setVar(human_anim.changeDirVarId, (progress <= 0.5 ? -1.0 : 1.0))
  elif phys.currentState.weapEquipState.curState == HUWeaponEquipState.EES_EQUIPED
    let reload = (curTime >= human_weap_anim__reloadStartTime &&
                  curTime <= human_weap_anim__reloadAtTime)
    stateUpperBody = (reload ? HumanStateUpperBody.E_RELOAD :
                      human_phys_isAiming(phys) ? HumanStateUpperBody.E_AIM : HumanStateUpperBody.E_READY)
    phys_vars |> setVar(human_anim.changeWeaponVarId, 0.0)

  elif phys.currentState.weapEquipState.curState == HUWeaponEquipState.EES_DOWN
    let reload = phys_vars |> getVar(human_anim.reloadVarId)
    // When climbing EES_DOWN is set to disable weapon firing
    // To avoid some frames of weapon down animation after climbing we don't allow it to happen instantly after a climb
    let afterClimbWeaponDownAnimCooldwon = 0.5
    stateUpperBody = reload > 0.0 || abs(human_anim__lastClimbTime - curTime) < afterClimbWeaponDownAnimCooldwon ? HumanStateUpperBody.E_READY : HumanStateUpperBody.E_DOWN

  if standState == HUStandState.ESS_CRAWL && (stateMove != HumanStateMove.E_STILL || isFromCrawlTransition || stateUpperBody == HumanStateUpperBody.E_CHANGE) && abs(rootRotate) > human_anim__crawlMoveTransitionLimit && human_anim__crawlMoveTransitionEndAt < curTime
    human_anim__crawlMoveTransitionEndAt = curTime + human_anim__crawlMoveTransitionTime
  if human_anim__crawlMoveTransitionEndAt > curTime
    stateMove = HumanStateMove.E_STILL
    rootRotate = move_to(prevRootRotate, 0.0, dt, human_anim__crawlMoveTransitionSpeed)
    if abs(rootRotate) < human_anim__crawlMoveTransitionLimit
      human_anim__crawlMoveTransitionEndAt = -1.0

  phys_vars |> setVar(human_anim__rootRotateVarId, rootRotate)

  if human_inventory__entityToUse != INVALID_ENTITY_ID && info.curTime < human_inventory__entityUseEnd
    if has(human_inventory__entityToUse, "item__healAnimEnumValue")
      stateUpperBody = HumanStateUpperBody.E_HEAL
      query(human_inventory__entityToUse) <| $ [es] (item__healAnimEnumValue : int;
                                                     item__healTargetAnimEnumValue : int)
        let isTarget = human_inventory__targetToUse != INVALID_ENTITY_ID && human_inventory__targetToUse != eid
        let healEnum = (isTarget && item__healTargetAnimEnumValue > -1 ?
                       item__healTargetAnimEnumValue : item__healAnimEnumValue)
        phys_vars |> setVar(human_anim.healItemSelectedVarId, float(healEnum))

  if burning__isPuttingOut
    stateUpperBody = HumanStateUpperBody.E_PUT_OUT_FIRE
    phys_vars |> setVar(human_anim.healItemSelectedVarId, float(burning__animPutOutEnum))

  let isToCrawlTransition = standHeight < phys.previousState.height && phys.currentState.height < human_anim__crawlThreshold && phys.currentState.height > -1.
  var toFromCrawlingAnim = -1
  if human_anim__crawlMoveTransitionEndAt < curTime
    if human_anim__toCrawlTransitionAnimId >= 0 && isToCrawlTransition
      toFromCrawlingAnim = human_anim__toCrawlTransitionAnimId
      if human_anim__toCrawlTransitionVarId >= 0
        phys_vars |> setVar(human_anim__toCrawlTransitionVarId, cvt(standHeight, 0., -1., 0., 1.))
    elif human_anim__fromCrawlTransitionAnimId >= 0 && isFromCrawlTransition
      toFromCrawlingAnim = human_anim__fromCrawlTransitionAnimId
      if human_anim__fromCrawlTransitionVarId >= 0
        phys_vars |> setVar(human_anim__fromCrawlTransitionVarId, cvt(standHeight, 0., -1., 1., 0.))

  if isClimbing
    human_anim__lastClimbTime = curTime
    var distance = 0f
    let visualCollPos = float3(phys.visualLocation.P)
    let curCimbPos = isFastClimbing || isClimbingOverObstacle ? visualCollPos : unitTm[3]
    if isClimbingOverObstacle
      let climbToPosAwareBasis = basis_aware_xVz(human_net_phys__climbToPos, human_net_phys__climbPosBehindObstacle, phys.currentState.vertDirection)
      let climbDir = normalize(human_net_phys__climbPosBehindObstacle - climbToPosAwareBasis)
      if dot(normalize(human_net_phys__climbPosBehindObstacle - curCimbPos), climbDir) > 0f
        distance = distance(human_net_phys__climbPosBehindObstacle, curCimbPos)
    else
      let wishPos = basis_aware_xVz(curCimbPos, human_net_phys__climbToPos, phys.currentState.vertDirection)
      if dot(wishPos, phys.currentState.vertDirection) > dot(curCimbPos, phys.currentState.vertDirection)
        distance = distance(wishPos, curCimbPos)
    var startPt = float2(0.0, 1.0)
    var endPt = float2(0.0, 1.0)
    for attr in (isFastClimbing ?
                 human_anim__fastClimbHeights : isClimbingOverObstacle ?
                 human_anim__climbOverHorzPoints : human_anim__climbHeights)
      let ht = attr ?? float2()
      if distance > ht.x
        startPt = ht
        endPt = ht
      else
        endPt = ht
        break
    let climbProgress = cvt(distance, startPt.x, endPt.x, startPt.y, endPt.y)
    if climbProgress >= 1.0 || climbProgress < 0.0
      isClimbing = false
      stateMove = HumanStateMove.E_MOVE
    phys_vars |> setVar(human_anim.climbProgressVarId, climbProgress)

  query(human_anim__vehicleSelected) <| $ [es] (vehicle_seats__seatEids : EidList;
                                                vehicle_seats__enumVarId : int = -1)
    if vehicle_seats__enumVarId >= 0
      phys_vars |> setVar(human_anim.vehicleSelectedVarId, float(vehicle_seats__enumVarId))
    for seatEid in vehicle_seats__seatEids
      query(seatEid) <| $ [es] (seat__ownerEid : EntityId;
                                seat__enumVarId : int)
        if eid == seat__ownerEid && seat__enumVarId >= 0
          phys_vars |> setVar(human_anim.seatTypeVarId, float(seat__enumVarId))

  var state_flags = uint(HumanAnimStateFlags.None)
  if ragdoll == null && !isAlive
    state_flags |= uint(HumanAnimStateFlags.Dead)
  if stunTimer >= 0.0
    state_flags |= uint(HumanAnimStateFlags.Attacked)
  if isGunner
    state_flags |= uint(HumanAnimStateFlags.Gunner)
  if isClimbing
    if isClimbingOverObstacle
      state_flags |= uint(HumanAnimStateFlags.ClimbingOverObstacle)
    else
      state_flags |= isFastClimbing ? uint(HumanAnimStateFlags.FastClimbing) : uint(HumanAnimStateFlags.Climbing)

  // Jumping and falling animation
  let moveVThres = 0.01
  let moveV = float3(phys.currentState.location.P - phys.previousState.location.P)
  let moveVlen = length(moveV)
  let moveDir = moveVlen > moveVThres ? moveV / moveVlen : float3()
  let fwdV = phys.currentState.location.fwd
  let fwdStopped = dot(moveDir, fwdV) < human_anim__considerFwdStopped
  let isOnGround = (uint(phys.currentState.states) & uint(StateFlag.ST_ON_GROUND)) != 0u
  let isClimbingCurrentState = human_phys_state_get_isClimbing(phys.currentState)
  let inJumping = (!isOnGround && !isClimbingCurrentState &&
                  (statePos != HumanStatePos.E_SWIM && statePos != HumanStatePos.E_SWIM_UNDERWATER))
  let inLongJump = human_anim__jumpTimer > human_anim__jumpTransitionTime
  let walkSpeed = phys |> human_phys_getWalkSpeed(HUStandState.ESS_STAND, HUMoveState.EMS_WALK)
  let isFalling = phys.currentState.velocity.y < -walkSpeed * human_anim__considerFallingCoef
  let jumpFromStand = inJumping && fwdStopped && !isFalling
  let vertSpeed = phys.currentState.velocity.y + (jumpFromStand ? 0.0 :
                                                  cvt(human_anim__jumpTimer,
                                                      human_anim__jumpTransitionTime,
                                                      human_anim__jumpTransitionTime * 2.0,
                                                      human_anim__jumpVertSpeedTransitionOffset,
                                                      0.0))
  let prevVertSpeedVar = phys_vars |> getVar(human_anim.vertSpeedVarId)
  let newVertSpeedVar = approach(prevVertSpeedVar, vertSpeed, dt, human_anim__vertVelVisc)
  phys_vars |> setVar(human_anim.vertSpeedVarId, newVertSpeedVar)
  let stateJump = (jumpFromStand || inLongJump) ? StateJump.E_FROM_STAND : inJumping ? StateJump.E_NOT_JUMP : StateJump.E_NOT_JUMP

  var state = HumanAnimStateResult(-1, -1)
  if isInVehicle
    state = (!human_weap__blockAiming && phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_AIM) ?
      HumanAnimStateResult(human_vehicle_anim__fireReadyUpperId, human_vehicle_anim__fireReadyLowerId) :
      HumanAnimStateResult(human_vehicle_anim__upperId, human_vehicle_anim__lowerId))
  else
    if curTime < human_phys__jumpEndTime + human_phys__afterJumpDelay && stateMove == HumanStateMove.E_SPRINT
      stateMove = HumanStateMove.E_MOVE
    state = human_anim.animState |> updateState(statePos, stateMove, stateJump, stateUpperBody, state_flags)
    if toFromCrawlingAnim != -1
      state = HumanAnimStateResult(toFromCrawlingAnim, toFromCrawlingAnim)

  if human_death_anim__selectedDeathAnimStateId != -1
    state = HumanAnimStateResult(human_death_anim__selectedDeathAnimStateId, human_death_anim__selectedDeathAnimStateId)

  send_change_anim_state_event(eid, "lower", ecs_hash("lower"), state.lower)
  send_change_anim_state_event(eid, "upper", ecs_hash("upper"), state.upper)
  animchar__animSpeed = spd * safeinv(animchar__scale)

// Not all weapons support 360 crawl anims yet. For such cases we want to fallback to old behavior
[es(REQUIRE_NOT=deadEntity)]
def human_phys_enable_360_crawl(evt : CmdPostPhysUpdate;
                                human_weap__currentGunEid : EntityId;
                                human_phys__crawlAlignSpeed : float = 90.0f;
                                var human_net_phys : HumanActor&)
  assume phys = human_net_phys.phys

  var enabled = false
  query(human_weap__currentGunEid) <| $ [es] (gun__enable360CrawlAnim : bool)
    enabled = gun__enable360CrawlAnim

  // Changing weapons dont look good right now too, so just force rotation to default pose when changing weapons
  // This is not great, but better than nothing.
  let changingWeapon = (phys.currentState.weapEquipState.curState == HUWeaponEquipState.EES_HOLSTERING ||
                        phys.currentState.weapEquipState.curState == HUWeaponEquipState.EES_EQUIPING)
  enabled &&= !changingWeapon

  human_net_phys.phys.alignSpeeds[int(HUStandState.ESS_CRAWL)] = enabled ? 0.0f : human_phys__crawlAlignSpeed


[es(on_appear)]
def init_human_anim_params(evt : Event;
                           animchar : AnimcharBaseComponent;
                           human_anim__localWalkDirVar : string;
                           human_anim__rootRotateVar : string;
                           var phys_vars : PhysVars;
                           var human_anim__localWalkDirVarId : int&;
                           var human_anim__rootRotateVarId : int&;
                           var human_anim__headRollVarId : int&)
  if animchar.animGraph != null
    human_anim__localWalkDirVarId = phys_vars |> registerVar(human_anim__localWalkDirVar, 0.)
    human_anim__rootRotateVarId = phys_vars |> registerVar(human_anim__rootRotateVar, 0.)
    human_anim__headRollVarId = phys_vars |> registerVar("head_roll", 0.)

[es(tag=(server, net), REQUIRE=human_net_phys, REQUIRE_NOT=ragdoll, track=isAlive)]
def human_anim_disable_anim_updates_for_deadmen_server_es(evt : Event;
                                                          isAlive : bool;
                                                          var animchar__updatable : bool&)
  animchar__updatable = isAlive

[es(on_appear, before=anim_phys_init_es)]
def human_anim_set_animchar_params_es(event : Event;
                                      animcharParams : Object;
                                      var phys_vars : PhysVars)
  var params : array<int>
  var values : array<float>
  for item in animcharParams
    let k = phys_vars |> registerVar(item.key, 0.0)
    params |> push(k)
    let v = item.value ?? 0.0
    values |> push(v)
  for i in iter_range(animcharParams)
    phys_vars |> setVar(params[i], values[i])

[soa_template]
struct HumanDeathAnim
  human_death_anim__animStateIds : int
  human_death_anim__collNodeIds : int
  human_death_anim__allowRagdoll : bool
  human_death_anim__ragdollPowerTime : float

[soa_es, es(on_appear, tag=gameClient)]
def human_death_anim_init(evt : Event;
                          eid : EntityId;
                          animchar : AnimcharBaseComponent;
                          collres : CollisionResource;
                          @shared_comp human_death_anim__anims : Array;
                          human_death_anim__defaultDeathState : string;
                          human_death_anim__ragdollPowerDefaultTime : float;
                          var humanDeathAnim : HumanDeathAnim_SOA&;
                          var human_death_anim__defaultDeathStateId : int&)
  let defaultStateId = *animchar.animGraph |> anim_graph_getStateIdx(human_death_anim__defaultDeathState)
  if defaultStateId < 0 && !empty(human_death_anim__defaultDeathState) // human_death_anim__defaultDeathState = "" means we fallback to default ragdoll
    logerr("Death animation default state '{human_death_anim__defaultDeathState}' not found in ({eid})<{getEntityTemplateName(eid)}>")
    return
  human_death_anim__defaultDeathStateId = defaultStateId

  let deathAnimsCount = length(human_death_anim__anims)
  humanDeathAnim |> clear()
  humanDeathAnim |> reserve(deathAnimsCount)
  for anim in human_death_anim__anims
    var animObject = anim |> get_ecs_object()
    if animObject == null
      continue

    let stateName = animObject?["state"] ?as string
    let collNodeName = animObject?["coll_node"] ?as string
    let allowRagdoll = animObject?["allow_ragdoll"] ?? true
    let ragdollPowerTime = animObject?["ragdoll_power_time"] ?? human_death_anim__ragdollPowerDefaultTime
    if stateName == null || collNodeName == null
      logerr("Death animation object is missing 'state' or 'coll_node' field")
      continue

    let stateId = *animchar.animGraph |> anim_graph_getStateIdx("{*stateName}")
    if stateId < 0
      logerr("Death animation anim state '{*stateName}' not found")
      continue
    let collNodeId = collres_get_node_index_by_name(collres, "{*collNodeName}")
    if collNodeId < 0
      logerr("Death animation coll node '{*collNodeName}' not found")
      continue

    humanDeathAnim |> push() <| HumanDeathAnim(
      human_death_anim__animStateIds = stateId,
      human_death_anim__collNodeIds = collNodeId,
      human_death_anim__allowRagdoll = allowRagdoll,
      human_death_anim__ragdollPowerTime = ragdollPowerTime)

[soa_es, es(on_event, tag=gameClient)]
def human_death_anim_select_on_death(evt : EventEntityDied;
                                     human_death_anim__defaultDeathStateId : int;
                                     human_death_anim__ragdollPowerDefaultTime : float;
                                     humanDeathAnim : HumanDeathAnim_SOA;
                                     var human_death_anim__selectedDeathAnimStateId : int&;
                                     var human_death_anim__ragdollPowerStartedAtTime : float&;
                                     var human_death_anim__ragdollPowerEndAtTime : float&;
                                     var ragdoll__isAllowed : bool&;
                                     var ragdoll : PhysRagdoll&)
  human_death_anim__selectedDeathAnimStateId = human_death_anim__defaultDeathStateId

  var ragdollPowerTime = human_death_anim__ragdollPowerDefaultTime

  for i in humanDeathAnim
    if i.human_death_anim__collNodeIds == evt.collNodeId
      human_death_anim__selectedDeathAnimStateId = i.human_death_anim__animStateIds
      ragdoll__isAllowed = i.human_death_anim__allowRagdoll

      ragdollPowerTime = i.human_death_anim__ragdollPowerTime
      break

  if ragdollPowerTime > 0.0
    human_death_anim__ragdollPowerStartedAtTime = get_sync_time()
    human_death_anim__ragdollPowerEndAtTime = get_sync_time() + ragdollPowerTime
    ragdoll |> ragdoll_setDriveBodiesToAnimchar(true)


[es(REQUIRE=deadEntity, no_order)]
def human_death_anim_update_ragdoll_power(info : ParallelUpdateFrameDelayed;
                                          human_death_anim__ragdollPowerStartedAtTime : float;
                                          human_death_anim__ragdollPowerEndAtTime : float;
                                          human_death_anim__ragdollPowerKeys : FloatList;
                                          human_death_anim__ragdollPowerNotes : Point4List;
                                          var ragdoll : PhysRagdoll&)
  if human_death_anim__ragdollPowerKeys |> length() == 0 || human_death_anim__ragdollPowerStartedAtTime < 0.0 || human_death_anim__ragdollPowerEndAtTime < 0.0
    return

  var physSys = ragdoll |> ragdoll_getPhysSys()
  if physSys == null
    return

  if human_death_anim__ragdollPowerKeys |> length() != human_death_anim__ragdollPowerNotes |> length()
    // TODO: can't logerr_once here cause threaded system, but we probably should in this case
    // logerr_once("human_death_anim_update_ragdoll_power: human_death_anim__ragdollPowerKeys and human_death_anim__ragdollPowerNotes must have the same length")
    return

  let currentProgress = cvt(get_sync_time(), human_death_anim__ragdollPowerStartedAtTime, human_death_anim__ragdollPowerEndAtTime, 0.0, 1.0)

  var idx0 = 0
  var idx1 = 0
  for i in range(human_death_anim__ragdollPowerKeys |> length())
    if i == 0 // skip first value, we select it by default
      continue

    idx0 = i - 1
    idx1 = i

    if currentProgress >= human_death_anim__ragdollPowerKeys[idx0] && currentProgress <= human_death_anim__ragdollPowerKeys[idx1]
      break

  let currentKeysPower = cvt(currentProgress, human_death_anim__ragdollPowerKeys[idx0], human_death_anim__ragdollPowerKeys[idx1], 0.0, 1.0)
  let currentPower = lerp(human_death_anim__ragdollPowerNotes[idx0], human_death_anim__ragdollPowerNotes[idx1], currentKeysPower)

  *physSys |> phys_system_instance_setJointsMotorSettings(currentPower.x, currentPower.y, currentPower.z, currentPower.w)


[es(on_appear)]
def init_to_from_crawl_transition_anim_id(evt : Event;
                                          animchar : AnimcharBaseComponent;
                                          human_anim__toCrawlTransitionAnim : string;
                                          human_anim__toCrawlTransitionVar : string;
                                          human_anim__fromCrawlTransitionAnim : string;
                                          human_anim__fromCrawlTransitionVar : string;
                                          var phys_vars : PhysVars;
                                          var human_anim__toCrawlTransitionAnimId : int&;
                                          var human_anim__toCrawlTransitionVarId : int&;
                                          var human_anim__fromCrawlTransitionAnimId : int&;
                                          var human_anim__fromCrawlTransitionVarId : int&)
  if animchar.animGraph != null
    human_anim__toCrawlTransitionAnimId = *animchar.animGraph |> anim_graph_getStateIdx(human_anim__toCrawlTransitionAnim)
    human_anim__toCrawlTransitionVarId = phys_vars |> registerVar(human_anim__toCrawlTransitionVar, 0.)
    human_anim__fromCrawlTransitionAnimId = *animchar.animGraph |> anim_graph_getStateIdx(human_anim__fromCrawlTransitionAnim)
    human_anim__fromCrawlTransitionVarId = phys_vars |> registerVar(human_anim__fromCrawlTransitionVar, 0.)