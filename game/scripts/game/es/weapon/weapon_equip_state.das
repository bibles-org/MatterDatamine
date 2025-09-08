require ecs
require GamePhys
require HumanPhys
require DngHuman
require game.events.events
require DagorMath
require math.base
require game.events.events_game
require game.es.human_weap_common
require game.es.ecs_common
require debug.logerr_once

[es(REQUIRE_NOT=disableUpdate)]
def update_weapon_equip_state(evt : CmdPostPhysUpdate;
                              eid : EntityId;
                              isAlive : bool = true;
                              human_weap__gunMatId : int;
                              human_weap__gunBackoffVisc : float = 0.1;
                              human_weap__gunDownDisableDelay : float = 0.2;
                              human_weap__gunDownTimeToStart : float = 0.35;
                              human_weap__gunMaxBackoff : float = 0.0;
                              human_weap__gunMinBackupDist : float = 0.2;
                              human_weap__gunBackupDistFactor : float = 0.5;
                              var human_weap__gunBackupLastTime : float&;
                              human_weap__gunBackupOptTime : float = 0.5;
                              human_weap__defaultHolsterTime : float;
                              human_weap__defaultEquipTime : float;
                              human_weap__unarmedHolsterTime : float;
                              human_weap__unarmedEquipTime : float;
                              human_weap__gunEids : EidList&;
                              human_net_phys__isSimplifiedPhys : bool = false;
                              action__running : bool = false;
                              transform : float3x4;
                              var human_net_phys : HumanActor&)
  assume phys = human_net_phys.phys
  assume previousState = phys.previousState
  assume currentState = phys.currentState
  assume appliedCT = phys.appliedCT
  assume weapEquipState = currentState.weapEquipState
  assume weaponParams = phys.weaponParams

  if !phys.hasGuns
    return

  var humanTm : float3x4
  currentState.location |> location_toTM(humanTm)
  if is_nan(humanTm[3])
    logerr_once("NaN in humanTm: {humanTm}
eid={get_entity_info(eid)}
transform=<{transform}>
isAlive={isAlive}
previousState.location.P=<{previousState.location.P}>
previousState.location.O=<{previousState.location.O.quat}>
currentState.location.P=<{currentState.location.P}>
currentState.location.O=<{currentState.location.O.quat}>
currentState.velocity={currentState.velocity}
currentState.walkNormal={currentState.walkNormal}
currentState.gravDirection={currentState.gravDirection}
currentState.posOffset={currentState.posOffset}
currentState.standingVelocity={currentState.standingVelocity}
currentState.spdSummaryDiff={currentState.spdSummaryDiff}")
    humanTm[3] = float3()

  // We use gunTM here to throw traces from that position and calculate backoff amount.
  // This amount is than applied to gunOffset through some systems and changes gunTm calculated in
  // human_phys_calcGunTm.
  // If we get this tm as is calculated backoff offset can start jittering back and forth so we need
  // remove it before throwing these traces.
  var noOffsetGunTm : float3x4
  var dynOffset = float3(0.0)
  query(human_weap__gunEids[int(weapEquipState.curSlot)]) <| $ [es] (gun_dynamic_position__offset : float3 = float3(0.0))
    dynOffset = gun_dynamic_position__offset
  phys.gunOffset -= dynOffset
  human_phys_calcGunTm(phys, PrecomputedPresetMode.TPV, humanTm, currentState.gunAngles.y, currentState.leanPosition, currentState.height, noOffsetGunTm)
  phys.gunOffset += dynOffset
  if is_nan(noOffsetGunTm[3])
    logerr_once("NaN in noOffsetGunTm:{noOffsetGunTm}\ngunAngles:{currentState.gunAngles}\nlean:{currentState.leanPosition}\nh:{currentState.height}")
    noOffsetGunTm[3] = float3()

  if weapEquipState.curState == HUWeaponEquipState.EES_EQUIPED || weapEquipState.curState == HUWeaponEquipState.EES_DOWN
    let isChosenWeaponValid = weaponParams[int(appliedCT.chosenWeapon)].exists || appliedCT.chosenWeapon == HUWeaponSlots.EWS_UNARMED
    if appliedCT.chosenWeapon != weapEquipState.curSlot && isChosenWeaponValid && phys.canSwitchWeapon && !action__running
      phys |> reset_weapon_state()
      sendEvent(eid, HumanSwitchWeaponStarted())

  // We want to reset progress to zero when weapon change ends but on only on the next tick so that animation can interpolate between correct values
  // when actual weapon change is done between phys ticks. Otherwise last frames of weapon change animation are skipped.
  if weapEquipState.curState != HUWeaponEquipState.EES_HOLSTERING && weapEquipState.curState != HUWeaponEquipState.EES_EQUIPING
    weapEquipState.progress = 0.0

  if weapEquipState.curState == HUWeaponEquipState.EES_EQUIPED
    if human_phys_state_forceWeaponUp(currentState) || human_phys_state_attachedToExternalGun(currentState)
      return
    var backoff = 0.
    if !human_net_phys__isSimplifiedPhys
      let curTime = float(evt.tick) * evt.dt
      let doOpt = curTime - human_weap__gunBackupLastTime > human_weap__gunBackupOptTime
      let fastCheckIdx = doOpt ? evt.tick % 4 : -1
      let intersects = check_gun_trace(phys, noOffsetGunTm, -1., human_weap__gunMatId, human_weap__gunMaxBackoff, backoff, human_weap__gunMinBackupDist, human_weap__gunBackupDistFactor, fastCheckIdx)
      if intersects
        currentState.gunTraceTimer += evt.dt
      else
        currentState.gunTraceTimer = 0.
      if intersects || backoff > 0.f
        human_weap__gunBackupLastTime = curTime
      if (intersects && currentState.gunTraceTimer > human_weap__gunDownTimeToStart) || human_phys_state_get_forceWeaponDown(currentState) || human_phys_state_get_isClimbing(currentState)
        weapEquipState.curState = HUWeaponEquipState.EES_DOWN
    currentState.gunBackoffAmount = approach(currentState.gunBackoffAmount, backoff, evt.dt, human_weap__gunBackoffVisc)

  elif weapEquipState.curState == HUWeaponEquipState.EES_HOLSTERING
    let curSlot = int(weapEquipState.curSlot)
    assume curWeapEid = human_weap__gunEids[curSlot]
    var holsterTime = (curSlot == int(HUWeaponSlots.EWS_UNARMED)) ? human_weap__unarmedHolsterTime : human_weap__defaultHolsterTime
    var minHolsterTime = holsterTime
    query(curWeapEid) <| $ [es] (gun__holsterTime : float;
                                 gun__minHolsterTime : float = 0.2f)
      holsterTime = gun__holsterTime
      minHolsterTime = gun__minHolsterTime
    assume nextWeapEid = human_weap__gunEids[int(weapEquipState.nextSlot)]
    // this multiplier (stated in the next weapon) makes holstering current weapon faster => overall switch is faster
    var holsterSwapSpeedMult = 1.f
    query(nextWeapEid) <| $ [es] (gun__holsterSwapSpeedMult : float)
      holsterSwapSpeedMult = gun__holsterSwapSpeedMult
    let multipliedHolsterTime = max(minHolsterTime, safediv(holsterTime, currentState.fasterChangeWeaponMult * holsterSwapSpeedMult))
    weapEquipState.progress += safediv(evt.dt, multipliedHolsterTime)

    if appliedCT.chosenWeapon != weapEquipState.nextSlot
      weapEquipState.nextSlot = appliedCT.chosenWeapon
      if weapEquipState.curSlot == weapEquipState.nextSlot
        sendEventImmediate(eid, HumanEquipStateWeaponEquipped(slot = int(weapEquipState.nextSlot)))
    if weapEquipState.progress >= 1.
      weapEquipState.progress = 0.
      weapEquipState.curState = HUWeaponEquipState.EES_EQUIPING
    if currentState.moveState == HUMoveState.EMS_SPRINT && !phys.allowWeaponSwitchOnSprint
      weapEquipState.progress = 0.
      weapEquipState.curState = HUWeaponEquipState.EES_EQUIPED
  elif weapEquipState.curState == HUWeaponEquipState.EES_EQUIPING
    let nextSlot = int(weapEquipState.nextSlot)
    assume nextWeapEid = human_weap__gunEids[nextSlot]
    var equipTime = (nextSlot == int(HUWeaponSlots.EWS_UNARMED)) ? human_weap__unarmedEquipTime : human_weap__defaultEquipTime
    query(nextWeapEid) <| $ [es] (gun__equipTime : float)
      equipTime = gun__equipTime
    weapEquipState.progress += safediv(evt.dt, equipTime) * currentState.fasterChangeWeaponMult
    if weapEquipState.progress >= 1.
      weapEquipState.progress = 1.
      weapEquipState.curState = HUWeaponEquipState.EES_EQUIPED
    if phys.canSwitchWeapon && weapEquipState.curSlot != weapEquipState.nextSlot
      weapEquipState.curSlot = weapEquipState.nextSlot
      sendEventImmediate(eid, HumanEquipStateWeaponEquipped(slot = int(weapEquipState.nextSlot)))
  elif weapEquipState.curState == HUWeaponEquipState.EES_DOWN
    var backoff = 0.
    let isGunDownByState = human_phys_state_get_forceWeaponDown(currentState) || human_phys_state_get_isClimbing(currentState)
    if (human_phys_state_forceWeaponUp(currentState)
        || human_phys_state_attachedToExternalGun(currentState)
        || (!isGunDownByState &&
           (human_net_phys__isSimplifiedPhys || !check_gun_trace(phys, noOffsetGunTm, -1., human_weap__gunMatId, human_weap__gunMaxBackoff, backoff, human_weap__gunMinBackupDist, human_weap__gunBackupDistFactor))))
      currentState.gunTraceTimer += evt.dt
      if (currentState.gunTraceTimer > human_weap__gunDownDisableDelay)
        weapEquipState.curState = HUWeaponEquipState.EES_EQUIPED
        currentState.gunTraceTimer = 0.0
