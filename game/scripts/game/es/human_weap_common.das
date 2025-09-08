module human_weap_common shared
require app
require ecs
require ecs.safe
require ecs.common
require game.es.ecs_common
require game.es.grenade_thrower_common
require game.events.events
require game.es.action_common
require game.events.events_game
require game.utils.net_utils
require game.utils.animchar
require inventory
require HumanPhys
require DaWeaponProps
require DaWeapons
require DagorSystem
require DngWeapon
require DngHuman
require DngNet
require Gun
require AnimV20
require DagorMath
require DagorMathUtils
require WeapHelpers
require game.es.human.human_gun_common
require game.es.boxed_item_common
require RendInst
require Dacoll
require GamePhys
require daslib.strings_boost
require game.es.inventory_drop_common
require AnimatedPhys
require math.base
require game.es.states_common
require Grid
require GridCollision
require CollisionTraces
require game.es.inventory_weapon_common
require game.events.inventory_events
require game.es.status_tip_common
require game.es.gun_jamming_common
require debug.logerr_once


def get_weapon_slot_from_name(name : string) : tuple<slot : HUWeaponSlots; found : bool>
  let slotIdx = int(HUWeaponSlots(name))
  for slot in each_enum(HUWeaponSlots.EWS_PRIMARY)
    if int(slot) == slotIdx
      return (slot, true)

  return (HUWeaponSlots.EWS_PRIMARY, false)


def request_unload_ammo_from_gun(hero_eid : EntityId;
                                 weapon_slot_name : string;
                                 to_inventory_eid : EntityId = INVALID_ENTITY_ID)
  let slotId = int(HUWeaponSlots(weapon_slot_name))
  if slotId < 0
    return false
  request_unload_ammo_from_gun(hero_eid, slotId, to_inventory_eid)
  return true


def request_unload_ammo_from_gun(hero_eid : EntityId;
                                 weapon_slot_id : int;
                                 to_inventory_eid : EntityId = INVALID_ENTITY_ID)
  send_net_event(hero_eid, CmdUnloadAmmoFromGunToInventory(
    slotId = weapon_slot_id, toInventoryEid = to_inventory_eid))


def request_load_weapon_from_inventory(hero_eid : EntityId;
                                       weapon_slot_id : int;
                                       from_inventory_eid : EntityId)
  query(hero_eid) <| $ [es] (human_weap__gunEids : EidList)
    let gunEid = human_weap__gunEids[weapon_slot_id]
    query(gunEid) <| $ [es] (gun__boxedAmmoHolderTemplate : string)
      let ammoEid = find_boxed_item_to_draw_from(gun__boxedAmmoHolderTemplate, from_inventory_eid)
      if ammoEid != INVALID_ENTITY_ID
        send_net_event(hero_eid, CmdLoadAmmoFromInventoryToGun(ammoEid = ammoEid, gunEid = gunEid))
      else
        create_status_tip("status_tip_no_boxed_ammo_to_load")


def request_load_weapon_from_inventory(hero_eid : EntityId;
                                       weapon_slot_name : string;
                                       from_inventory_eid : EntityId)
  let slotId = int(HUWeaponSlots(weapon_slot_name))
  if slotId < 0
    return false
  request_load_weapon_from_inventory(hero_eid, slotId, from_inventory_eid)
  return true


def load_weapon_ammo_from_inventory(eid : EntityId; ammo_eid : EntityId; slot_name : string)
  let slotId = int(HUWeaponSlots(slot_name))
  if slotId < 0
    return
  query(eid) <| $ [es] (human_weap__gunEids : EidList)
    let gunEid = human_weap__gunEids[slotId]
    if gunEid == INVALID_ENTITY_ID
      return
    send_net_event(eid, CmdLoadAmmoFromInventoryToGun(ammoEid = ammo_eid, gunEid = gunEid))


def choose_weapon(eid : EntityId; slot_name : string)
  let slot = get_weapon_slot_from_name(slot_name)
  if !slot.found
    return false
  query(eid) <| $ [es] (human_weap__gunEids : EidList; var human_net_phys : HumanActor&)
    if human_weap__gunEids[int(slot.slot)] == INVALID_ENTITY_ID
      return
    elif slot.slot == HUWeaponSlots.EWS_GRENADE
      if HUWeaponSlots.EWS_GRENADE != human_net_phys.phys.producedCT.chosenWeapon
        send_net_event(eid, HumanRequestTakeGrenade())
    else
      human_net_phys.phys.producedCT |> set_chosen_weapon(slot.slot)
  return true


def reset_weapon_state(var phys : HumanPhys&)
  assume weapEquipState = phys.currentState.weapEquipState
  weapEquipState.progress = 0.
  weapEquipState.curState = HUWeaponEquipState.EES_HOLSTERING
  weapEquipState.nextSlot = phys.appliedCT.chosenWeapon


def check_gun_trace(var phys : HumanPhys;
                    gun_tm : float3x4;
                    len_override : float;
                    gun_mat_id : int;
                    max_backoff : float;
                    var backoff : float&;
                    min_backup_dist : float = 0.2;
                    backup_dist_factor : float = 0.5;
                    fast_check_idx : int = -1)
  assume currentState = phys.currentState
  assume weaponParams = phys.weaponParams[int(currentState.weapEquipState.curSlot)]

  let traceHandle = phys |> human_phys_getTraceHandle()
  let gunDir = currentState.gunDir

  backoff = 0.

  if (phys.precompWeaponPos == null ||
      !phys.precompWeaponPos.isLoaded ||
      !weaponParams.exists ||
      currentState.isCrawl ||
      weaponParams.gunLen < 0.05)
    return false

  let gunLen = len_override >= 0. ? len_override : weaponParams.gunLen
  let backupDist = min(min_backup_dist, gunLen * backup_dist_factor)
  let gunStartPos = gun_tm[3] - gunDir * backupDist

  let gunAimPos = gun_tm * weaponParams.offsAimNode - gunDir * backupDist
  let leftPos = gun_tm * weaponParams.offsCheckLeftNode - gunDir * backupDist
  let rightPos = gun_tm * weaponParams.offsCheckRightNode - gunDir * backupDist
  var t = gunLen + backupDist
  var pmid = -1
  var norm : float3
  var riDesc = RendInstDesc()
  if check_nan(gunStartPos, gunAimPos, leftPos, rightPos, gunDir, gun_tm, weaponParams)
    return false
  var res = false
  if fast_check_idx <= 0
    res = traceray_normalized(gunStartPos, gunDir, t, pmid, norm, ETF_DEFAULT, riDesc, gun_mat_id, traceHandle)
  if !res && (fast_check_idx < 0 || fast_check_idx == 1)
    res = traceray_normalized(gunAimPos, gunDir, t, pmid, norm, ETF_DEFAULT, riDesc, gun_mat_id, traceHandle)
  if !res && (fast_check_idx < 0 || fast_check_idx == 2)
    res = traceray_normalized(leftPos, gunDir, t, pmid, norm, ETF_DEFAULT, riDesc, gun_mat_id, traceHandle)
  if !res && (fast_check_idx < 0 || fast_check_idx == 3)
    res = traceray_normalized(rightPos, gunDir, t, pmid, norm, ETF_DEFAULT, riDesc, gun_mat_id, traceHandle)

  if !res
    return false
  let backoffAmount = gunLen + backupDist - t
  if backoffAmount <= max_backoff
    backoff = backoffAmount
    return false
  return true

def check_nan(gunStartPos, gunAimPos, leftPos, rightPos, gunDir : float3; gun_tm : float3x4; weaponParams : HumanWeaponParams)
  if is_nan(gunStartPos) || is_nan(gunAimPos) || is_nan(leftPos) || is_nan(rightPos)
    logerr_once("NaN trace\n gunStartPos: {gunStartPos}\n gunAimPos: {gunAimPos}\n leftPos: {leftPos}\n rightPos: {rightPos}\n gunDir: {gunDir}\n gun_tm: {gun_tm}\n gunLen: {weaponParams.gunLen}\n offsAimNode: {weaponParams.offsAimNode}\n offsCheckLeftNode: {weaponParams.offsCheckLeftNode}\n offsCheckRightNode: {weaponParams.offsCheckRightNode} ")
    return true
  return false


def is_human_allowed_aiming(eid : EntityId; attached_gun_eid : EntityId; human_net_phys : HumanActor) : bool
  assume currentState = human_net_phys.phys.currentState
  let isSprinting = currentState.moveState == HUMoveState.EMS_SPRINT
  let isMeleeOrUnarmed = currentState.weapEquipState.curSlot == HUWeaponSlots.EWS_MELEE || currentState.weapEquipState.curSlot == HUWeaponSlots.EWS_UNARMED
  let isGunEquipped = currentState.weapEquipState.curState == HUWeaponEquipState.EES_EQUIPED || attached_gun_eid != INVALID_ENTITY_ID
  let isMoving = currentState.moveState != HUMoveState.EMS_STAND
  var res = (!(isSprinting && !isMeleeOrUnarmed) &&
            !currentState |> human_phys_state_get_is_swimming() && isGunEquipped &&
            currentState |> human_phys_state_get_canShoot() &&
            !(currentState.isCrawl && isMoving))
  if !res
    return false
  query(eid) <| $ [es] (isInVehicle : bool = false;
                        human_weap__blockAiming : bool = false; human_vehicle__canHoldWeapon : bool = false)
    res = (!human_weap__blockAiming &&
          (!isInVehicle || (human_vehicle__canHoldWeapon && !isMeleeOrUnarmed && human_net_phys.phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_AIM))))
  return res


def is_human_aiming(eid : EntityId; gun_eid : EntityId; human_net_phys : HumanActor)
  return (is_human_allowed_aiming(eid, gun_eid, human_net_phys)
          && is_control_bit_set(human_net_phys.phys.appliedCT, HumanPhysControlType.HCT_AIM))


def is_human_allowed_shooting(eid : EntityId; attached_gun_eid : EntityId; human_net_phys : HumanActor) : bool
  var res = is_human_allowed_aiming(eid, attached_gun_eid, human_net_phys)
  query(eid) <| $ [es] (isShootingAllowed : bool = true)
    res &&= isShootingAllowed
  return res


def is_human_allowed_shooting(eid : EntityId)
  var res = false
  query(eid) <| $ [es] (human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                        human_net_phys : HumanActor)
    res = is_human_allowed_shooting(eid, human_attached_gun__attachedGunEid, human_net_phys)
  return res

def human_weap_clamp_vert_aim_angle(angle : float; interp_quat : quat; limits : float2; up : float3)
  let fwd = quat_get_forward(interp_quat)
  let vertComponent = dot(fwd, up)
  let pitchBasis = asin(vertComponent)
  return clamp(angle, pitchBasis + limits.x, pitchBasis + limits.y)

def apply_gun_angle_offsets(phys : HumanPhys; at_time : float; limits : float2; up : float3; var angles : float2&)
  assume prevState = phys.previousState
  assume curState  = phys.currentState
  let prevOffset = prevState.breathOffset + prevState.handsShakeOffset + prevState.gunAimOffset
  let curOffset = curState.breathOffset + curState.handsShakeOffset + curState.gunAimOffset
  let interpK = get_phys_interpk_clamped(phys, at_time)

  angles += lerp(prevOffset, curOffset, float2(interpK))
  let interpQuat = slerp(prevState.location.O.quat, curState.location.O.quat, interpK)
  angles.y = human_weap_clamp_vert_aim_angle(angles.y, interpQuat, limits, up)


def human_weap_get_shoot_tm(eid : EntityId; at_time : float; var out_tm : float3x4&) : bool
  let gun = get_human_gun(eid)
  if gun == null || !is_human_allowed_shooting(eid)
    return false
  var isOk = false
  query(eid) <| $ [es] (human_net_phys : HumanActor)
    isOk = true
    human_gun_get_shoot_tm(*gun, human_net_phys.phys, at_time, out_tm)
  return isOk


def human_weap_get_aim_tm_impl(human_net_phys : HumanActor; at_time : float; apply_offsets : bool; vert_limits : float2; up : float3) : float3x4
  var gunDir = human_net_phys.phys.producedCT.wishShootDir
  var gunAngles = dir_to_angles(gunDir)
  if apply_offsets
    apply_gun_angle_offsets(human_net_phys.phys, at_time, vert_limits, up, gunAngles)
  gunDir = angles_to_dir(gunAngles)
  var camPos : float3

  find_query() <| $ [es] (camera__active : bool; transform : float3x4)
    if camera__active
      camPos = transform[3]
    return camera__active

  var outTm : float3x4
  outTm[3] = camPos
  outTm[0] = gunDir
  outTm[2] = normalize(cross(gunDir, float3(0.0, 1.0, 0.0)))
  outTm[1] = normalize(cross(outTm[2], gunDir))
  return outTm


def human_weap_get_aim_tm(eid : EntityId; at_time : float; var out_tm : float3x4&) : bool
  if !has(eid, "human_input")
    return human_weap_get_shoot_tm(eid, at_time, out_tm)

  if !is_human_allowed_shooting(eid)
    return false

  var isOk = false
  query(eid) <| $ [es] (human_net_phys : HumanActor;
                        human_weap__crawlClampVertAngleRad : float2;
                        human_weap__clampVertAngleRad : float2;
                        human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID)
    isOk = true
    let applyOffsets = !human_attached_gun__attachedGunEid
    let vertLimits = human_net_phys.phys.currentState.isCrawl ? human_weap__crawlClampVertAngleRad : human_weap__clampVertAngleRad
    out_tm = human_weap_get_aim_tm_impl(human_net_phys, at_time, applyOffsets, vertLimits, human_net_phys.phys.currentState.vertDirection)
  return isOk


def set_cur_ammo_num(gun_eid : EntityId; num : int; templ : string)
  query(gun_eid) <| $ [es] (gun__ammo : int;
                            gun__owner : EntityId;
                            gun__shell_prop_ids : GunShellPropIds;
                            var gun__boxedAmmoHolderTemplate : das_string&;
                            var gun__curShellId : ShellPropIds)
    if num >= gun__ammo
      if int(gun__curShellId.shellId) < 0
        gun__curShellId = gun__shell_prop_ids[0]
      gun__boxedAmmoHolderTemplate := templ
      sendEventImmediate(gun_eid, CmdLoadAmmo(loadAmmoCount = (num - gun__ammo)))
      reload_projectile(gun__owner, gun_eid)
    else
      sendEventImmediate(gun_eid, CmdUnloadAmmo(unloadAmmoCount = (gun__ammo - num)))


struct GunUpdateCtx
  dt : float
  atTime : float
  isForReal : bool
  eid : EntityId
  isDowned : bool
  isThrowingAllowed : bool
  shotDeviationMult : float
  rotationShotSpreadDecrMult : float
  aimingAfterFireMult : float
  boltActionMult : float
  shotDeviationAdd : float
  fastThrowExclusive : bool
  deviationBufferSizeMult : float


def private calc_gun_deviation(gun_eid : EntityId;
                               phys : HumanPhys;
                               ctx : GunUpdateCtx)
  query(gun_eid) <| $ [es] (var gun_deviation_ct__bufferSizeMult : float&;
                            var gun_deviation_ct__tauMult : float&;
                            var gun_deviation_ct__rotationShotSpreadDecrMult : float&;
                            var gun_deviation_ct__aimingAfterFireMult : float&;
                            var gun_deviation_ct__movement : float2&;
                            var gun_deviation_ct__minExtraDev : float&;
                            gun__deviationInFireReady = 0.0)
    if ctx.isForReal
      gun_deviation_ct__bufferSizeMult = ctx.deviationBufferSizeMult
      gun_deviation_ct__tauMult = ctx.shotDeviationMult
      gun_deviation_ct__rotationShotSpreadDecrMult = ctx.rotationShotSpreadDecrMult
      gun_deviation_ct__aimingAfterFireMult = ctx.aimingAfterFireMult
      gun_deviation_ct__movement = phys.currentState.velocity.xz
      gun_deviation_ct__minExtraDev = lerp(gun__deviationInFireReady, 0.0, phys.currentState.aimPosition)
      gun_deviation_ct__minExtraDev += ctx.shotDeviationAdd


def private is_shoot_blocked_by_item_use(eid : EntityId)
  var res = false
  query(eid) <| $ [es] (human_inventory__entityToUse : EntityId)
    if human_inventory__entityToUse != INVALID_ENTITY_ID
      if has(human_inventory__entityToUse, "item__ignoreShootInputInterrupt")
        res = true
  return res


def private notify_if_shoot_blocked(gun_eid : EntityId)
  var blocked = false
  query(gun_eid) <| $ [es] (gun : Gun const?;
                            blockShoot : bool;
                            blockShootReason : string = "")
    if blockShoot && gun != null && !gun.appliedControls.wishShoot
      broadcastEvent(EventOnGunBlocksShoot(reason = blockShootReason))
    blocked = blockShoot
  return blocked


def private is_need_interrupt_actions(eid : EntityId;
                                      cur_weap_slot : HUWeaponSlots;
                                      human_weap__gunEids : EidList)
  var needInterrupt = false
  query(eid) <| $ [es] (human_unarmed__active : bool = false;
                        building_action__target : EntityId = INVALID_ENTITY_ID)
    let isMeleeWeapon = (cur_weap_slot == HUWeaponSlots.EWS_MELEE) || (cur_weap_slot == HUWeaponSlots.EWS_UNARMED) || human_unarmed__active
    let buildingAction = building_action__target != INVALID_ENTITY_ID
    let gunEid = human_weap__gunEids[int(cur_weap_slot)]
    let isBuildingToolGun = has(gunEid, "previewEid") && buildingAction
    let itemGuninstallationInProgress = get_bool(gunEid, "placeable_item__inProgress") ?? false
    needInterrupt = !isMeleeWeapon && !isBuildingToolGun && !itemGuninstallationInProgress
  return needInterrupt


def private is_weap_usable(weap_eid : EntityId)
  var res = false
  query(weap_eid) <| $ [es] (gun : Gun const?;
                             gun__ammo : int = 0;
                             gun__totalAmmo : int = 0)
    if gun == null || gun__ammo != 0 || gun__totalAmmo != 0
      res = true
  return res

def private switch_to_usable_weap(cur_weap : HUWeaponSlots;
                                  wish_weap : HUWeaponSlots;
                                  human_weap__gunEids : EidList;
                                  var phys : HumanPhys)
  var bestSlot = cur_weap

  if phys.currentState.weapEquipState.curState == HUWeaponEquipState.EES_EQUIPED && !is_weap_usable(human_weap__gunEids[int(cur_weap)])
    var i = 0
    bestSlot = wish_weap
    while i < int(HUWeaponSlots.EWS_UNARMED) && bestSlot == wish_weap
      if i == int(wish_weap)
        ++i
        continue
      if i == int(HUWeaponSlots.EWS_MELEE) && human_weap__gunEids[i] != INVALID_ENTITY_ID
        bestSlot = HUWeaponSlots(i)
      query(human_weap__gunEids[i]) <| $ [es] (gun__totalAmmo : int = 0; gun__ammo : int = 0)
        if gun__totalAmmo > 0 || gun__ammo > 0
          bestSlot = HUWeaponSlots(i)
      ++i
    phys.producedCT |> set_chosen_weapon(bestSlot)

  return bestSlot


def private update_weap_phys(ct : HumanControlState;
                             cur_gun_slot : HUWeaponSlots;
                             human_weap__gunEids : EidList;
                             shoot : bool;
                             transform : float3x4;
                             gun_dir : float3;
                             gun_shoot_dir : float3;
                             phys_transform : float3x4;
                             ctx : GunUpdateCtx;
                             phys : HumanPhys)
  if isLoadingEntity(human_weap__gunEids[int(cur_gun_slot)])
    return // cannot send Immediate event
  using() <| $(var gctrl : GunControls#)
    gctrl.shoot = shoot
    gctrl.wishShoot = ct |> is_control_bit_set(HumanPhysControlType.HCT_SHOOT)
    gctrl.boltActionMult = ctx.boltActionMult
    gctrl.timeStep = phys.timeStep

    if ct |> human_control_state_get_shootPos_packed() > 0u
      let worldShootPos = phys_transform * ct |> human_control_state_unpack_shootPos()
      using(gun_dir, gun_shoot_dir, phys.currentState.velocity, worldShootPos) <| $(var gloc : GunLocation#)
        sendEventImmediate(human_weap__gunEids[int(cur_gun_slot)], CmdWeapPhysUpdate(
                                                                     owner = ctx.eid,
                                                                     atTime = ctx.atTime,
                                                                     dt = ctx.dt,
                                                                     isForReal = ctx.isForReal,
                                                                     slotId = int(cur_gun_slot),
                                                                     gctrl := gctrl,
                                                                     gloc := gloc))
    else
      using(gun_dir, gun_shoot_dir, phys.currentState.velocity, transform, phys_transform) <| $(var gloc : GunLocation#)
        sendEventImmediate(human_weap__gunEids[int(cur_gun_slot)], CmdWeapPhysUpdate(
                                                                     owner = ctx.eid,
                                                                     atTime = ctx.atTime,
                                                                     dt = ctx.dt,
                                                                     isForReal = ctx.isForReal,
                                                                     slotId = int(cur_gun_slot),
                                                                     gctrl := gctrl,
                                                                     gloc := gloc))


def update_throw_state(var human_net_phys : HumanActor;
                       human_weap__gunEids : EidList;
                       var human_weap__throwMode : bool&;
                       ctx : GunUpdateCtx;
                       transform : float3x4;
                       gun_dir : float3;
                       gun_shoot_dir : float3;
                       phys_transform : float3x4;
                       ct : HumanControlState;
                       human_unarmed__active : bool;
                       human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID)
  assume phys = human_net_phys.phys
  let selectedGun = determine_current_weapon_slot(ctx.atTime, human_net_phys)
  var curGun = selectedGun
  let allowShootingNoAttach = is_human_allowed_shooting(ctx.eid) && !human_attached_gun__attachedGunEid

  // TODO: Rethrowing grenade by foot
  // if (ct |> is_control_bit_set(HumanPhysControlType HCT_THROW_BACK) && ctx.isForReal &&
  //     !human_weap__throwMode && allowShootingNoAttach && curGun != HUWeaponSlots EWS_GRENADE)
  //   human_weap__throwMode = try_rethrow_grenade(ctx.eid, human_weap__gunEids, phys, human_use_object__selectedObject)

  let grenadeSlotEid = human_weap__gunEids[int(HUWeaponSlots.EWS_GRENADE)]
  if ctx.isForReal && ctx.isThrowingAllowed && allowShootingNoAttach && !human_weap__throwMode
    human_weap__throwMode = try_reload_grenade(ctx.eid, curGun, grenadeSlotEid, human_weap__gunEids, ctx.isDowned, ct)

  if !human_weap__throwMode
    return false

  curGun = HUWeaponSlots.EWS_GRENADE
  let gunEid = human_weap__gunEids[int(curGun)]

  var grenadeThrower : GrenadeThrower const? = null
  query(gunEid) <| $ [es] (grenade_thrower : GrenadeThrower const?)
    grenadeThrower = grenade_thrower
  if grenadeThrower == null
    return false

  calc_gun_deviation(gunEid, phys, ctx)

  var shoot = ((is_control_bit_set(ct, HumanPhysControlType.HCT_THROW_BACK) || is_control_bit_set(ct, HumanPhysControlType.HCT_SHOOT) || is_control_bit_set(ct, HumanPhysControlType.HCT_THROW)) &&
               !ctx.isDowned)

  if shoot
    shoot = !is_shoot_blocked_by_item_use(ctx.eid) && shoot
    let shootBlocked = notify_if_shoot_blocked(gunEid)
    shoot = !shootBlocked && !human_unarmed__active && shoot
    if ctx.isForReal
      query(gunEid) <| $ [es] (grenade_thrower__projectileEntity : EntityId;
                               shell__autoThrowCountdown : float = 0.0)
        let explTime = get_float(grenade_thrower__projectileEntity, "shell__explTime") ?? 0.0
        if shell__autoThrowCountdown > 0.0 && explTime > 0.0 && ctx.atTime > explTime - shell__autoThrowCountdown
          shoot = false

  var needsInterruptActions = shoot && is_need_interrupt_actions(ctx.eid, curGun, human_weap__gunEids)

  query(gunEid) <| $ [es] (gun : Gun)
    if ctx.isForReal && !gun.appliedControls.shoot && shoot
      let newSlot = switch_to_usable_weap(curGun, selectedGun, human_weap__gunEids, phys)
      let isMeleeOrUnarmed = (newSlot == HUWeaponSlots.EWS_MELEE) || (newSlot == HUWeaponSlots.EWS_UNARMED)
      needsInterruptActions = (newSlot != selectedGun && isMeleeOrUnarmed) || needsInterruptActions

  if ct |> is_control_bit_set(HumanPhysControlType.HCT_RELOAD) && ctx.isForReal
    sendEvent(ctx.eid, CmdRequestReload(atTime = ctx.atTime, gunEid = gunEid))

  update_weap_phys(ct, curGun, human_weap__gunEids, shoot, transform, gun_dir, gun_shoot_dir, phys_transform, ctx, phys)

  if needsInterruptActions
    // Call 'interrupt_actions' after CmdWeapPhysUpdate, cause it in turn may trigger actions
    // and that can cause jittery behavior, like action is always starting and interrupting in a loop.
    interrupt_actions(ctx.eid)

  if human_weap__throwMode && ctx.isForReal && grenadeThrower != null && grenadeThrower.state == GrenadeThrowState.GTS_READY && !ctx.isDowned
    clear_throw_mode(ctx.eid, gunEid, human_weap__gunEids, human_weap__throwMode, phys)
  return true


def update_shoot_state(var human_net_phys : HumanActor;
                       human_weap__gunEids : EidList;
                       ctx : GunUpdateCtx;
                       transform : float3x4;
                       gun_dir : float3;
                       gun_shoot_dir : float3;
                       phys_transform : float3x4;
                       ct : HumanControlState;
                       human_unarmed__active : bool;
                       human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID)
  assume phys = human_net_phys.phys
  let curGun = determine_current_weapon_slot(ctx.atTime, human_net_phys)
  let allowShootingNoAttach = is_human_allowed_shooting(ctx.eid) && !human_attached_gun__attachedGunEid
  let gunEid = human_weap__gunEids[int(curGun)]

  var defaultInit = false
  if curGun == HUWeaponSlots.EWS_MELEE
    if !has(gunEid, "melee_weapon__propsId")
      return
  else
    defaultInit = true

  if defaultInit
    calc_gun_deviation(gunEid, phys, ctx)

  var shoot = is_control_bit_set(ct, HumanPhysControlType.HCT_SHOOT) && allowShootingNoAttach && !ctx.isDowned

  if shoot
    shoot = !is_shoot_blocked_by_item_use(ctx.eid) && shoot
    let shootBlocked = notify_if_shoot_blocked(gunEid)
    shoot = !shootBlocked && shoot
    query(gunEid) <| $ [es] (gun__reloadFinishTime : float = -1.0)
      shoot = ctx.atTime > gun__reloadFinishTime && shoot
    query(gunEid) <| $ [es] (gun_boxed_ammo_reload__reloadState : int)
      shoot = gun_boxed_ammo_reload__reloadState == -1 && shoot
    query(gunEid) <| $ [es] (weapon_mods__delayedMoveState : int)
      shoot = weapon_mods__delayedMoveState == -1 && shoot
    shoot = !human_unarmed__active && shoot

  let needsInterruptActions = shoot && is_need_interrupt_actions(ctx.eid, curGun, human_weap__gunEids)

  var isJammed = false
  var readyToFixJamm = false
  query(gunEid) <| $ [es] (gun__owner : EntityId;
                           gun_jamming__isJammed : bool;
                           gun_jamming__fixJammingEndAt : float;
                           gun_anim__reloadProgress : float;
                           gun_jamming__isJammedClient : bool const?)
    isJammed = gun_jamming__isJammed
    if isJammed && gun_jamming__fixJammingEndAt == -1.0
      if gun_jamming__isJammedClient != null && !*gun_jamming__isJammedClient
        // we client and already fixed jamming localy
        return
      let isReloading = gun_anim__reloadProgress > 0.0 && gun_anim__reloadProgress < 1.0
      let inspectionProgress = gun__owner |> get_float("check_ammo_controller__ammoInspectionProgress") ?? -1.0
      let isInspecting = inspectionProgress > 0.0 && inspectionProgress < 3.0
      if isReloading || isInspecting
        //reload/inspect in progress
        return
      readyToFixJamm = true

  if ct |> is_control_bit_set(HumanPhysControlType.HCT_RELOAD) && ctx.isForReal
    if isJammed && readyToFixJamm
      sendEvent(ctx.eid, CmdRequestFixJamming(gunEid = gunEid))
    elif !isJammed
      sendEvent(ctx.eid, CmdRequestReload(atTime = ctx.atTime, gunEid = gunEid, minReloadAmmoCount = 1))

  update_weap_phys(ct, curGun, human_weap__gunEids, shoot, transform, gun_dir, gun_shoot_dir, phys_transform, ctx, phys)

  if needsInterruptActions
    // Call 'interrupt_actions' after CmdWeapPhysUpdate, cause it in turn may trigger actions
    // and that can cause jittery behavior, like action is always starting and interrupting in a loop.
    interrupt_actions(ctx.eid)


def human_weap_update(var human_net_phys : HumanActor;
                      human_weap__gunEids : EidList;
                      var human_weap__throwMode : bool&;
                      ctx : GunUpdateCtx;
                      transform : float3x4;
                      gun_dir : float3;
                      gun_shoot_dir : float3;
                      phys_transform : float3x4;
                      ct : HumanControlState;
                      human_unarmed__active : bool;
                      human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID)
  if !update_throw_state(human_net_phys, human_weap__gunEids, human_weap__throwMode, ctx,
                         transform, gun_dir, gun_shoot_dir, phys_transform, ct,
                         human_unarmed__active, human_attached_gun__attachedGunEid)
    update_shoot_state(human_net_phys, human_weap__gunEids, ctx,
                       transform, gun_dir, gun_shoot_dir, phys_transform, ct,
                       human_unarmed__active, human_attached_gun__attachedGunEid)


def human_weap_can_reload(human_eid : EntityId; gun_eid : EntityId) : bool
  var canReload = true
  query(human_eid) <| $ [es] (human_net_phys : HumanActor;
                              human_weap__throwMode : bool;
                              boltActionProgress : float;
                              human_weap__lockWeaponReload : bool = false;
                              burning__isBurning : bool = false;
                              human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                              human_inventory__entityToUse : EntityId = INVALID_ENTITY_ID;
                              human_use_object__currentInteractable : EntityId = INVALID_ENTITY_ID)
    assume currentState = human_net_phys.phys.currentState
    assume eqState = currentState.weapEquipState.curState
    assume mvState = currentState.moveState
    let isCrawlMoving = currentState.isCrawl && mvState != HUMoveState.EMS_STAND
    let isAttachedToGun = !!human_attached_gun__attachedGunEid
    let isBlockedByBoltAction = ((get_bool(gun_eid, "reload__waitBoltActionFinished") ?? false) &&
                                  boltActionProgress > 0. && boltActionProgress < 1.)
    let usingItem = !!human_inventory__entityToUse && has(human_inventory__entityToUse, "item__interruptsReloading")
    let usingInteractable = human_use_object__currentInteractable != INVALID_ENTITY_ID

    canReload = (!human_weap__throwMode &&
                 !isCrawlMoving &&
                 !burning__isBurning &&
                 (eqState == HUWeaponEquipState.EES_EQUIPED || eqState == HUWeaponEquipState.EES_DOWN || isAttachedToGun) &&
                 !isBlockedByBoltAction && !human_weap__lockWeaponReload && !usingItem && !usingInteractable)
  return canReload


def do_gun_traceray(from : float3; dir : float3; var t : float&; ray_mat_id : int; ignore_human_eid : EntityId)
  var retEid = INVALID_ENTITY_ID
  var pmid : int
  var norm : float3
  using() <| $(var desc : RendInstDesc#)
    traceray_normalized(from, dir, t, pmid, norm, 127, desc, ray_mat_id)
  using() <| $(var intersections : IntersectedEntities)
    trace_entities_in_grid(ecs_hash("humans"), from, dir, t, ignore_human_eid, intersections, SortIntersections.NO)
    trace_entities_in_grid(ecs_hash("vehicles"), from, dir, t, ignore_human_eid, intersections, SortIntersections.YES)
    for isect in intersections
      if get_bool(isect.eid, "animchar__visible") ?? true
        retEid = isect.eid
        break
  return retEid


def set_current_hero_weapon(weapon_eid, hero_eid : EntityId)
  var curWeaponChanged = false
  query(hero_eid) <| $ [es] (human_weap__gunEids : EidList;
                             human_weap__currentGunSlot : int)
    if human_weap__gunEids[human_weap__currentGunSlot] != weapon_eid
      curWeaponChanged = true
      let weapIdx = human_weap__gunEids |> find_index(weapon_eid)
      if weapIdx == -1
        logerr("[INVENTORY] Weapon {get_entity_info(weapon_eid)} is not equipped on hero <{hero_eid}>.")
        return
      sendEventImmediate(hero_eid, HumanWeapSetCurrentGun(slot = uint8(weapIdx)))
  return curWeaponChanged


def update_weapon_attachment(actor_eid : EntityId;
                             slot : int;
                             human_weap__gunEids : EidList;
                             human_weap__currentGunSlot : int)
  if slot < length(human_weap__gunEids)
    let isAttached = (slot == human_weap__currentGunSlot)
    send_event_if_possible(human_weap__gunEids[slot], CmdWeapAttach(toEid = actor_eid, isAttached = isAttached, slotId = slot))


def update_weapons_attachment(actor_eid : EntityId;
                              human_weap__gunEids : EidList;
                              human_weap__currentGunSlot : int)
  for i in iter_range(human_weap__gunEids)
    let isAttached = (i == human_weap__currentGunSlot)
    send_event_if_possible(human_weap__gunEids[i], CmdWeapAttach(toEid = actor_eid, isAttached = isAttached, slotId = i))


def get_total_ammo_count(item_container : EidList; gun_eid : EntityId)
  var res = 0
  query(gun_eid) <| $ [es] (gun__ammoHolderIds : IntList;
                            gun__shell_prop_ids : GunShellPropIds)
    for itemEid in item_container
      query(itemEid) <| $ [es] (shell_props : ShellPropIds const?;
                                ammo_holder__id : int const?;
                                item__currentBoxedItemCount : int const?)
        if ammo_holder__id != null && item__currentBoxedItemCount != null && is_ammo_for_gun(*ammo_holder__id, gun__ammoHolderIds)
          res += *item__currentBoxedItemCount
          return
        if shell_props != null && is_shell_for_gun(*shell_props, gun__shell_prop_ids)
          res++ // add 1 shell to total ammo count of gun
          return
  return res


def determine_current_slot(cur_time : float;
                           human_net_phys : HumanActor;
                           human_inventory__entityToUse : EntityId;
                           state_counter__disableWeaponSwitch : int;
                           isDowned : bool;
                           human_sec_anim__hideWeapon : bool;
                           human_sec_anim__hideMelee : bool;
                           human_sec_anim__play : bool;
                           human_unarmed__hiddenWeapon : bool;
                           action__running : bool;
                           burning__isPuttingOut : bool;
                           human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID)
  var curSlot = int(determine_current_weapon_slot(cur_time, human_net_phys))
  if has_state_by_counter(state_counter__disableWeaponSwitch)
    return curSlot

  let attachedToGun = (human_attached_gun__attachedGunEid != INVALID_ENTITY_ID)
  let isHealing = (human_inventory__entityToUse != INVALID_ENTITY_ID &&
                  has(human_inventory__entityToUse, "item__healAnimEnumValue"))
  if ((!action__running && (human_net_phys.phys.currentState |> human_phys_state_get_is_swimming))
      || attachedToGun || isHealing || burning__isPuttingOut || isDowned || human_unarmed__hiddenWeapon
      || human_net_phys.phys.currentState |> human_phys_state_attachedToLadder)
    curSlot = int(HUWeaponSlots.EWS_UNARMED)
  if human_sec_anim__play && (human_sec_anim__hideWeapon || (human_sec_anim__hideMelee && curSlot == int(HUWeaponSlots.EWS_MELEE)))
    curSlot = int(HUWeaponSlots.EWS_UNARMED)
  return curSlot


def has_any_attached_gun(human_weap__gunEids : EidList)
  for gunEid in human_weap__gunEids
    if get_bool(gunEid, "human_gun_attached") ?? false
      return true
  return false


def set_current_gun(eid : EntityId;
                    human_weap__gunEids : EidList;
                    cur_gun : int;
                    var human_weap__currentGunSlot : int&;
                    var human_weap__previousGunSlot : int&)
  if human_weap__currentGunSlot == cur_gun
    return

  human_weap__previousGunSlot = human_weap__currentGunSlot
  human_weap__currentGunSlot = cur_gun
  update_weapons_attachment(eid, human_weap__gunEids, cur_gun)


def send_attach_event_to_current_gun(eid : EntityId;
                                     human_weap__gunEids : EidList;
                                     human_weap__currentGunSlot : int)
  if human_weap__currentGunSlot < 0 || human_weap__currentGunSlot >= length(human_weap__gunEids)
    return
  let gunEid = human_weap__gunEids[human_weap__currentGunSlot]
  if !(get_bool(gunEid, "human_gun_attached") ?? true)
    send_event_if_possible(gunEid, CmdWeapAttach(toEid = eid, isAttached = true, slotId = human_weap__currentGunSlot))


def human_weap_es_impl(var human_weap__currentGunSlot : int&;
                       var human_weap__previousGunSlot : int&;
                       cur_time : float;
                       eid : EntityId;
                       human_weap__gunEids : EidList;
                       human_net_phys : HumanActor;
                       human_inventory__entityToUse : EntityId;
                       action__running : bool;
                       isInVehicle : bool;
                       isPassenger : bool;
                       isInVehicleHidden : bool;
                       isDowned : bool;
                       human_sec_anim__hideWeapon : bool;
                       human_sec_anim__hideMelee : bool;
                       human_sec_anim__play : bool;
                       human_unarmed__hiddenWeapon : bool;
                       state_counter__disableWeaponSwitch : int;
                       burning__isPuttingOut : bool;
                       human_weap__blockAiming : bool;
                       human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID)
  let curSlot = determine_current_slot(cur_time, human_net_phys, human_inventory__entityToUse,
    state_counter__disableWeaponSwitch, isDowned, human_sec_anim__hideWeapon, human_sec_anim__hideMelee,
    human_sec_anim__play, human_unarmed__hiddenWeapon, action__running, burning__isPuttingOut,
    human_attached_gun__attachedGunEid)

  let shootingPassenger = (isPassenger && human_net_phys.phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_AIM)
                          && !human_weap__blockAiming && curSlot < int(HUWeaponSlots.EWS_MELEE))

  let animSlot = isInVehicle && !isInVehicleHidden && !shootingPassenger && !action__running ? -1 : curSlot

  if human_weap__currentGunSlot != curSlot || (animSlot < 0 && has_any_attached_gun(human_weap__gunEids))
    set_current_gun(eid, human_weap__gunEids, animSlot, human_weap__currentGunSlot, human_weap__previousGunSlot)
  human_weap__currentGunSlot = curSlot

  if !isDowned
    send_attach_event_to_current_gun(eid, human_weap__gunEids, animSlot)


def update_total_ammo(gun_eid : EntityId;
                      itemContainer : EidList)
  query(gun_eid) <| $ [es(REQUIRE=gun)] (var gun__totalAmmo : int&)
    gun__totalAmmo = get_total_ammo_count(itemContainer, gun_eid)


def no_other_slots_have_weapon(slot_id : int; human_weap__gunEids : EidList)
  for e, idx in human_weap__gunEids, iter_range(human_weap__gunEids)
    if e != INVALID_ENTITY_ID && idx != slot_id && idx != int(HUWeaponSlots.EWS_GRENADE)
      return false
  return true

def deselect_slot_and_try_switch_to_previous_slot(human_eid : EntityId;
                                                  deselect_slot : int;
                                                  previous_slot : int;
                                                  human_net_phys : HumanActor)
  assume weapEquipState = human_net_phys.phys.currentState.weapEquipState
  let currentSlot = int(weapEquipState.curSlot)
  let nextSlot = int(weapEquipState.nextSlot)
  if currentSlot != deselect_slot && nextSlot != deselect_slot
    return

  var switchToSlot = previous_slot
  if currentSlot != nextSlot // already switching
    if nextSlot != deselect_slot
      return // Already switching to other slot
    else
      switchToSlot = currentSlot // Cancel switch

  sendEvent(human_eid, HumanWeapSetCurrentGun(slot = uint8(switchToSlot)))
