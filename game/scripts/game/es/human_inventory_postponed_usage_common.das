module human_inventory_postponed_usage_common shared
require ecs
require DngHuman
require game.events.events_game


enum PostponedUsageState
  None
  WaitForSwapToUnarmed
  WaitForEndOfUsage
  Ended


def try_postponed_usage_on_unurmed_usage_item(human_eid : EntityId;
                                              human_net_phys : HumanActor;
                                              var human_inventory__entityUseStart : float&;
                                              var human_inventory__entityUseEnd : float&;
                                              var human_inventory_postponed_usage__state : int&;
                                              var human_inventory_postponed_usage__useDuration : float&)
  assume weapEquipState = human_net_phys.phys.currentState.weapEquipState
  let curGunSlot = weapEquipState.curSlot
  let nextGunSlot = weapEquipState.nextSlot
  let curState = weapEquipState.curState

  let isUnarmed = (curGunSlot == HUWeaponSlots.EWS_UNARMED)
  let isUnarmedEquipping = (nextGunSlot == HUWeaponSlots.EWS_UNARMED && curState == HUWeaponEquipState.EES_EQUIPING)
  let isEquippingNotUnarmed = isUnarmed && nextGunSlot != HUWeaponSlots.EWS_UNARMED && curState == HUWeaponEquipState.EES_EQUIPING

  if !isUnarmed && !isUnarmedEquipping
    human_inventory_postponed_usage__useDuration = human_inventory__entityUseEnd - human_inventory__entityUseStart
    human_inventory__entityUseStart = -1.0
    human_inventory__entityUseEnd = -1.0
    human_inventory_postponed_usage__state = int(PostponedUsageState.WaitForSwapToUnarmed)
    sendEventImmediate(human_eid, HumanWeapSetCurrentGun(slot = uint8(HUWeaponSlots.EWS_UNARMED)))
    return true
  elif isEquippingNotUnarmed
    human_inventory_postponed_usage__state = int(PostponedUsageState.WaitForSwapToUnarmed)
    sendEventImmediate(human_eid, HumanWeapSetCurrentGun(slot = uint8(HUWeaponSlots.EWS_UNARMED)))
    return true
  return false


def try_postponed_usage_on_unurmed_usage_item(human_eid : EntityId;
                                              human_net_phys : HumanActor;
                                              var human_inventory_postponed_usage__state : int&)
  assume weapEquipState = human_net_phys.phys.currentState.weapEquipState
  let curGunSlot = weapEquipState.curSlot
  let nextGunSlot = weapEquipState.nextSlot
  let curState = weapEquipState.curState

  let isUnarmed = (curGunSlot == HUWeaponSlots.EWS_UNARMED)
  let isUnarmedEquipping = (nextGunSlot == HUWeaponSlots.EWS_UNARMED && curState == HUWeaponEquipState.EES_EQUIPING)
  let isEquippingNotUnarmed = isUnarmed && nextGunSlot != HUWeaponSlots.EWS_UNARMED && curState == HUWeaponEquipState.EES_EQUIPING

  if !isUnarmed && !isUnarmedEquipping
    human_inventory_postponed_usage__state = int(PostponedUsageState.WaitForSwapToUnarmed)
    sendEventImmediate(human_eid, HumanWeapSetCurrentGun(slot = uint8(HUWeaponSlots.EWS_UNARMED)))
    return true
  elif isEquippingNotUnarmed
    human_inventory_postponed_usage__state = int(PostponedUsageState.WaitForSwapToUnarmed)
    sendEventImmediate(human_eid, HumanWeapSetCurrentGun(slot = uint8(HUWeaponSlots.EWS_UNARMED)))
    return true
  return isUnarmedEquipping
