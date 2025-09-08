module interrupt_item_use_common shared
require ecs
require app
require HumanPhys
require DngHuman
require game.events.events
require game.utils.team
require math.base
require inventory
require DngNet
require game.es.level_common
require game.es.inventory_common
require game.events.inventory_events
require game.events.events_active_matter
require game.es.use_query_params_common
require game.events.events_active_matter
require game.es.inventory_weapon_mod_common
require game.es.boxed_ammo_reload_common
require game.es.vehicle.vehicle_seats_common


def is_interrupted_by_moving(human_net_phys : HumanActor; item_eid : EntityId)
  var interrupted = false
  query(item_eid) <| $ [es] (item__interruptOnSprint : Tag const?;
                             item__canUseWhileMoving : bool const?)
    interrupted = is_interrupted_by_moving(human_net_phys, item__interruptOnSprint, item__canUseWhileMoving)
  return interrupted


def is_interrupted_by_moving(human_net_phys : HumanActor;
                             item__interruptOnSprint : Tag const?;
                             item__canUseWhileMoving : bool const?)
  assume currentState = human_net_phys.phys.currentState
  assume appliedCT = human_net_phys.phys.appliedCT

  let interruptOnSprint = item__interruptOnSprint != null
  if interruptOnSprint && currentState.moveState == HUMoveState.EMS_SPRINT && !currentState |> human_phys_state_stoppedSprint()
    return true

  let moving = appliedCT.walkSpeed > 0.
  if moving && currentState.isCrawl
    return true

  let canUseWhileMoving = item__canUseWhileMoving != null ? *item__canUseWhileMoving : true
  if (moving || appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_JUMP)) && !canUseWhileMoving
    return true

  return false


def human_inventory_should_interrupt_item_use(cur_time : float;
                                              human_eid : EntityId;
                                              item_eid : EntityId;
                                              vehicle_eid : EntityId;
                                              human_weap__currentGunEid : EntityId;
                                              human_net_phys : HumanActor;
                                              ct : HumanControlState;
                                              human_weap_anim__reloadAtTime : float;
                                              human_in_air : bool;
                                              human_in_vehicle : bool;
                                              human_is_downed : bool)
  var result = CanUseItemResponse.Declined
  query(item_eid) <| $ [es] (item__interruptsReloading : Tag const?;
                             item__interruptOnReloading : Tag const?;
                             item__canUseWhileSwimmingStill : Tag const?;
                             item__canUseWhileSwimming : Tag const?;
                             item__canUseUnderWater : Tag const?;
                             item__ignoreShootInputInterrupt : Tag const?;
                             item__ignoreMeleeInputInterrupt : Tag const?;
                             item__ignoreZoomViewInputInterrupt : Tag const?;
                             item__interruptInAir : Tag const?;
                             item__interruptOnDodge : Tag const?;
                             item__interruptOnCrawl : Tag const?;
                             item__interruptOnCrouch : Tag const?;
                             item__interruptOnSprint : Tag const?;
                             item__dontInterruptOnDowned : Tag const?;
                             item__interruptOnStanceChange : Tag const?;
                             item__interruptInDriverSeat : Tag const?;
                             item__interruptNotInVehicle : Tag const?;
                             interruptUseOnWeaponSwitch : Tag const?;
                             item__interruptOnLandingSpeed : float = -1.0)

    result = human_inventory_should_interrupt_item_use(cur_time, human_eid, vehicle_eid, human_weap__currentGunEid, human_net_phys, ct,
                                                       human_weap_anim__reloadAtTime, human_in_air, human_in_vehicle, human_is_downed,
                                                       item__interruptsReloading, item__interruptOnReloading, item__canUseWhileSwimmingStill,
                                                       item__canUseWhileSwimming, item__canUseUnderWater, item__ignoreShootInputInterrupt,
                                                       item__ignoreMeleeInputInterrupt, item__ignoreZoomViewInputInterrupt, item__interruptInAir,
                                                       item__interruptOnDodge, item__interruptOnCrawl, item__interruptOnCrouch, item__interruptOnSprint,
                                                       item__dontInterruptOnDowned, item__interruptOnStanceChange, item__interruptInDriverSeat,
                                                       item__interruptNotInVehicle, interruptUseOnWeaponSwitch, item__interruptOnLandingSpeed)
  return result


def human_inventory_should_interrupt_item_use(cur_time : float;
                                              human_eid : EntityId;
                                              vehicle_eid : EntityId;
                                              human_weap__currentGunEid : EntityId;
                                              human_net_phys : HumanActor;
                                              ct : HumanControlState;
                                              human_weap_anim__reloadAtTime : float;
                                              human_in_air : bool;
                                              human_in_vehicle : bool;
                                              human_is_downed : bool;
                                              item__interruptsReloading : Tag const?;
                                              item__interruptOnReloading : Tag const?;
                                              item__canUseWhileSwimmingStill : Tag const?;
                                              item__canUseWhileSwimming : Tag const?;
                                              item__canUseUnderWater : Tag const?;
                                              item__ignoreShootInputInterrupt : Tag const?;
                                              item__ignoreMeleeInputInterrupt : Tag const?;
                                              item__ignoreZoomViewInputInterrupt : Tag const?;
                                              item__interruptInAir : Tag const?;
                                              item__interruptOnDodge : Tag const?;
                                              item__interruptOnCrawl : Tag const?;
                                              item__interruptOnCrouch : Tag const?;
                                              item__interruptOnSprint : Tag const?;
                                              item__dontInterruptOnDowned : Tag const?;
                                              item__interruptOnStanceChange : Tag const?;
                                              item__interruptInDriverSeat : Tag const?;
                                              item__interruptNotInVehicle : Tag const?;
                                              interruptUseOnWeaponSwitch : Tag const?;
                                              item__interruptOnLandingSpeed : float = -1.0)
  assume currentState = human_net_phys.phys.currentState
  let standing = currentState.moveState == HUMoveState.EMS_STAND
  let interruptsReloading = item__interruptsReloading != null
  let interruptOnReloading = item__interruptOnReloading != null
  let canUseWhileSwimming = (standing ? item__canUseWhileSwimmingStill : item__canUseWhileSwimming) != null
  let canUseUnderWater = item__canUseUnderWater != null
  let ignoreShootInputInterrupt = item__ignoreShootInputInterrupt != null
  let ignoreMeleeInputInterrupt = item__ignoreMeleeInputInterrupt != null
  let ignoreZoomViewInputInterrupt = item__ignoreZoomViewInputInterrupt != null
  let interruptOnCrawl = item__interruptOnCrawl != null
  let interruptOnCrouch = item__interruptOnCrouch != null
  let interruptInAir = item__interruptInAir != null
  let interruptOnDodge = item__interruptOnDodge != null
  let interruptOnSprint = item__interruptOnSprint != null
  let interruptOnDowned = (item__dontInterruptOnDowned == null)
  let interruptOnStanceChange = item__interruptOnStanceChange != null
  let interruptOnLandingSpeed = item__interruptOnLandingSpeed
  let interruptOnWeaponSwitch = interruptUseOnWeaponSwitch != null
  let interruptInDriverSeat = item__interruptInDriverSeat != null
  let interruptNotInVehicle = item__interruptNotInVehicle != null

  let interruptBecauseOfStanceChange = interruptOnStanceChange ? (
    (ct |> is_control_bit_set(HumanPhysControlType.HCT_CRAWL) != (currentState.standState == HUStandState.ESS_CRAWL)) ||
    (ct |> is_control_bit_set(HumanPhysControlType.HCT_CROUCH) != (currentState.standState == HUStandState.ESS_CROUCH))
  ) : false
  let interruptBecauseLanding = interruptOnLandingSpeed >= .0 ? ((uint(currentState.isInAirHistory) & 1u) == 0u &&
                                                                  (uint(currentState.isInAirHistory) & 2u) != 0u &&
                                                                  length(currentState.spdSummaryDiff) > interruptOnLandingSpeed
                                                                ) : false
  assume weapEquipState = currentState.weapEquipState
  assume isUnarmedEquipping = weapEquipState.nextSlot == HUWeaponSlots.EWS_UNARMED && weapEquipState.curState == HUWeaponEquipState.EES_EQUIPING
  assume isUnarmed = weapEquipState.curSlot == HUWeaponSlots.EWS_UNARMED

  if ((human_weap_anim__reloadAtTime > cur_time && !interruptsReloading)
      || (human_weap_anim__reloadAtTime > cur_time && interruptOnReloading))
    return CanUseItemResponse.Reload
  if currentState |> human_phys_state_get_isClimbing()
    return CanUseItemResponse.Climb
  if ((currentState |> human_phys_state_get_is_swimming() && !canUseWhileSwimming)
      || (currentState |> human_phys_state_get_is_underwater() && !canUseUnderWater))
    return CanUseItemResponse.Swim
  if ct |> is_control_bit_set(HumanPhysControlType.HCT_ZOOM_VIEW) && !ignoreZoomViewInputInterrupt
    return CanUseItemResponse.Zoom
  if ct |> is_control_bit_set(HumanPhysControlType.HCT_SHOOT) && !ignoreShootInputInterrupt
    return CanUseItemResponse.Shoot
  if ct |> is_control_bit_set(HumanPhysControlType.HCT_MELEE) && !ignoreMeleeInputInterrupt
    return CanUseItemResponse.Melee
  if ct |> is_control_bit_set(HumanPhysControlType.HCT_THROW)
    return CanUseItemResponse.Throw
  if ct |> is_control_bit_set(HumanPhysControlType.HCT_CRAWL) && interruptOnCrawl
    return CanUseItemResponse.Crawl
  if ct |> is_control_bit_set(HumanPhysControlType.HCT_CROUCH) && interruptOnCrouch
    return CanUseItemResponse.Crouch
  if ct |> is_control_bit_set(HumanPhysControlType.HCT_SPRINT) && interruptOnSprint
    return CanUseItemResponse.Sprint
  if (ct.dodgeState != DodgeState.No) && interruptOnDodge
    return CanUseItemResponse.Dodge
  if human_in_air && interruptInAir
    return CanUseItemResponse.InAir
  if human_in_vehicle && currentState.isAiming
    return CanUseItemResponse.AimInVehicle
  if human_in_vehicle && interruptInDriverSeat && get_vehicle_driver(vehicle_eid) == human_eid
    return CanUseItemResponse.Driver
  if !human_in_vehicle && interruptNotInVehicle
    return CanUseItemResponse.NotInVehicle
  if human_is_downed && interruptOnDowned
    return CanUseItemResponse.Downed
  if interruptBecauseLanding
    return CanUseItemResponse.Landing
  if interruptBecauseOfStanceChange
    return CanUseItemResponse.StanceChange
  if interruptOnWeaponSwitch && weapEquipState.curSlot != weapEquipState.nextSlot && weapEquipState.nextSlot != HUWeaponSlots.EWS_UNARMED
    return CanUseItemResponse.WeaponSwitch


  if interruptOnReloading
    var shouldInterruptOnReloading = false
    query(human_weap__currentGunEid) <| $ [es] (gun_boxed_ammo_reload__reloadState = int(BoxedAmmoReloadState.NONE);
                                                weapon_mods__delayedMoveSlotName = "";
                                                weapon_mods__delayedMoveState = int(ModDelayedMoveState.NONE))
      if (gun_boxed_ammo_reload__reloadState > int(BoxedAmmoReloadState.WAIT) ||
          (weapon_mods__delayedMoveState > int(ModDelayedMoveState.WAIT) && weapon_mods__delayedMoveSlotName == "magazine"))
        shouldInterruptOnReloading = true
    if shouldInterruptOnReloading
      return CanUseItemResponse.Reload
  return CanUseItemResponse.Approved


def check_human_can_use_item(isAlive : bool;
                             human_inventory__canUseItems : bool;
                             human_inventory__entityToUse : EntityId)
  if !human_inventory__canUseItems
    return CanUseItemResponse.BlockedByHuman
  if !isAlive
    return CanUseItemResponse.NotAlive
  if human_inventory__entityToUse != INVALID_ENTITY_ID
    return CanUseItemResponse.OtherItemInUse
  return CanUseItemResponse.Approved


def check_item_can_be_used(human_eid : EntityId;
                           item_eid : EntityId;
                           human_weap__currentGunEid : EntityId;
                           human_anim__vehicleSelected : EntityId;
                           human_net_phys : HumanActor;
                           cur_time : float;
                           start_time : float;
                           human_weap_anim__reloadAtTime : float;
                           isDowned : bool;
                           human_net_phys__isInAir : bool;
                           isInVehicle : bool;
                           human_inventory__canHeal : bool;
                           human_inventory__canLoadCharges : bool)
  if !item_eid || !doesEntityExist(item_eid)
    return CanUseItemResponse.ItemNotExists
  var canUseItem = CanUseItemResponse.Declined
  query(item_eid) <| $ [es] (boxed_item__actionsBlock : bool = false;
                             item__canUseWhileMoving : bool const?;
                             item__blockUse : Tag const?;
                             item__blockUseOnPlayerBase : Tag const?;
                             item__interruptsReloading : Tag const?;
                             item__interruptOnReloading : Tag const?;
                             item__canUseWhileSwimmingStill : Tag const?;
                             item__canUseWhileSwimming : Tag const?;
                             item__canUseUnderWater : Tag const?;
                             item__ignoreShootInputInterrupt : Tag const?;
                             item__ignoreMeleeInputInterrupt : Tag const?;
                             item__ignoreZoomViewInputInterrupt : Tag const?;
                             item__interruptInAir : Tag const?;
                             item__interruptOnDodge : Tag const?;
                             item__interruptOnCrawl : Tag const?;
                             item__interruptOnCrouch : Tag const?;
                             item__interruptOnSprint : Tag const?;
                             item__dontInterruptOnDowned : Tag const?;
                             item__interruptOnStanceChange : Tag const?;
                             item__interruptInDriverSeat : Tag const?;
                             item__interruptNotInVehicle : Tag const?;
                             interruptUseOnWeaponSwitch : Tag const?;
                             item_heal : Tag const?;
                             item__interruptOnLandingSpeed : float = -1.0;
                             item_holder__maxItemCount : int = 0)
    if item__blockUse != null || boxed_item__actionsBlock
      canUseItem = CanUseItemResponse.BlockedByItem
      return
    if item_heal != null && !human_inventory__canHeal
      canUseItem = CanUseItemResponse.BlockedByItem
      return
    if item_holder__maxItemCount > 0 && !human_inventory__canLoadCharges
      canUseItem = CanUseItemResponse.BlockedByItem
      return
    if is_player_base() && item__blockUseOnPlayerBase != null
      canUseItem = CanUseItemResponse.ForbiddenOnPlayerBase
      return
    if is_interrupted_by_moving(human_net_phys, item__interruptOnSprint, item__canUseWhileMoving)
      canUseItem = CanUseItemResponse.Move
      return
    if cur_time >= start_time + 0.4f
      canUseItem = CanUseItemResponse.TooMuchDelay
      return
    canUseItem = human_inventory_should_interrupt_item_use(start_time, human_eid, human_anim__vehicleSelected, human_weap__currentGunEid, human_net_phys, human_net_phys.phys.producedCT,
                                                           human_weap_anim__reloadAtTime, human_net_phys__isInAir, isInVehicle, isDowned,
                                                           item__interruptsReloading, item__interruptOnReloading, item__canUseWhileSwimmingStill,
                                                           item__canUseWhileSwimming, item__canUseUnderWater, item__ignoreShootInputInterrupt,
                                                           item__ignoreMeleeInputInterrupt, item__ignoreZoomViewInputInterrupt, item__interruptInAir,
                                                           item__interruptOnDodge, item__interruptOnCrawl, item__interruptOnCrouch, item__interruptOnSprint,
                                                           item__dontInterruptOnDowned, item__interruptOnStanceChange, item__interruptInDriverSeat,
                                                           item__interruptNotInVehicle, interruptUseOnWeaponSwitch, item__interruptOnLandingSpeed)
  return canUseItem


def check_item_can_be_used(human_eid, item_eid : EntityId)
  var ret = CanUseItemResponse.Declined
  query(human_eid) <| $ [es] (human_weap__currentGunEid : EntityId;
                              human_anim__vehicleSelected : EntityId;
                              human_net_phys : HumanActor;
                              human_weap_anim__reloadAtTime : float;
                              isDowned : bool;
                              human_net_phys__isInAir : bool;
                              human_inventory__canHeal : bool;
                              human_inventory__canLoadCharges : bool;
                              isInVehicle : bool)
    let cur_time = get_sync_time()
    ret = check_item_can_be_used(human_eid, item_eid, human_weap__currentGunEid, human_anim__vehicleSelected, human_net_phys,
      cur_time, cur_time, human_weap_anim__reloadAtTime, isDowned, human_net_phys__isInAir, isInVehicle, human_inventory__canHeal,
      human_inventory__canLoadCharges)

  return ret