from "das.inventory" import is_can_move_item_to_item_container, is_can_move_item_to_backpack, is_can_move_item_to_safepack, is_can_move_item_to_ground,
  is_inventory_have_volume_for_item, is_inventory_read_only, is_inventory_in_use, is_can_move_to_safepack_with_overflow

from "%ui/hud/menus/components/inventoryItemsListChecksCommon.nut" import MoveForbidReason, checkVolume, isDropForbiddenCommon

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
let { GROUND, HERO_ITEM_CONTAINER, STASH, BACKPACK0, EXTERNAL_ITEM_CONTAINER, SAFEPACK } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { stashEid } = require("%ui/state/allItems.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { mutationForbidenDueToInQueueState } = require("%ui/hud/state/inventory_state.nut")
let { externalInventoryEid, externalInventoryContainerOwnerEid } = require("%ui/hud/state/hero_external_inventory_state.nut")
let { backpackEid, safepackEid } = require("%ui/hud/state/hero_extra_inventories_state.nut")
let { get_controlled_hero } = require("%dngscripts/common_queries.nut")
let { selfMemberState } = require("%ui/squad/squadState.nut")

let immutableInventoriesDuringQueue = [ HERO_ITEM_CONTAINER, BACKPACK0, SAFEPACK ]

function refinerDropBackToInventory(item, container) {
  if (item?.refiner__fromList.name == container.name)
    return MoveForbidReason.NONE

  return MoveForbidReason.OTHER
}

function isHeroInventoryDropForbidden(item) {
  if (item?.refiner__fromList.name != null) {
    let ret = refinerDropBackToInventory(item, HERO_ITEM_CONTAINER)
    return ret
  }

  if (mutationForbidenDueToInQueueState.get()) {
    if (selfMemberState.get()?.ready)
      return MoveForbidReason.FORBIDDEN_READY_STATUS
    else
      return MoveForbidReason.FORBIDDEN_QUEUE_STATUS
  }

  let ret = isDropForbiddenCommon(item, HERO_ITEM_CONTAINER)
  if (ret != MoveForbidReason.NONE)
    return ret

  let inventoryEid = get_controlled_hero()

  if (!checkVolume(item, inventoryEid))
    return MoveForbidReason.VOLUME

  if (!is_can_move_item_to_item_container(item.eid))
    return MoveForbidReason.FORBIDDEN_FOR_CONTAINER

  return MoveForbidReason.NONE
}

function isItemCanBeDroppedInStash(item) {
  if (item?.refiner__fromList.name != null) {
    return refinerDropBackToInventory(item, STASH)
  }

  let itemInventoryEid = item?.inventoryEid
  if (mutationForbidenDueToInQueueState.get() && (
    (immutableInventoriesDuringQueue.findindex(@(v) v.name == item?.fromList.name) != null) ||
    (
      itemInventoryEid == externalInventoryEid.get() && (
        externalInventoryContainerOwnerEid.get() == backpackEid.get() ||
        externalInventoryContainerOwnerEid.get() == get_controlled_hero() ||
        externalInventoryContainerOwnerEid.get() == safepackEid.get()
      )
    )
  )) {
    if (selfMemberState.get()?.ready)
      return MoveForbidReason.FORBIDDEN_READY_STATUS
    else
      return MoveForbidReason.FORBIDDEN_QUEUE_STATUS
  }

  if (isOnboarding.get())
    return MoveForbidReason.OTHER

  let ret = isDropForbiddenCommon(item, STASH)
  if (ret != MoveForbidReason.NONE)
    return ret

  let inventoryEid = stashEid.get()

  if ((item?.itemContainerItems.len() ?? 0) > 0) {
    if (!is_inventory_have_volume_for_item(inventoryEid, item.eid))
      return MoveForbidReason.VOLUME
  }
  else if (!checkVolume(item, inventoryEid))
    return MoveForbidReason.VOLUME

  return MoveForbidReason.NONE
}

function isBackpackDropForbidder(item) {
  if (item?.refiner__fromList.name != null) {
    return refinerDropBackToInventory(item, BACKPACK0)
  }

  if (mutationForbidenDueToInQueueState.get()) {
    if (selfMemberState.get()?.ready)
      return MoveForbidReason.FORBIDDEN_READY_STATUS
    else
      return MoveForbidReason.FORBIDDEN_QUEUE_STATUS
  }

  let ret = isDropForbiddenCommon(item, BACKPACK0)
  if (ret != MoveForbidReason.NONE)
    return ret

  let inventoryEid = backpackEid.get()

  if (inventoryEid == ecs.INVALID_ENTITY_ID || inventoryEid == item.eid)
    return MoveForbidReason.OTHER

  if (!checkVolume(item, inventoryEid))
    return MoveForbidReason.VOLUME

  if (!is_can_move_item_to_backpack(item.eid))
    return MoveForbidReason.FORBIDDEN_FOR_CONTAINER

  if (is_inventory_in_use(inventoryEid))
    return MoveForbidReason.OTHER

  return MoveForbidReason.NONE
}

function isSafepackDropForbidder(item) {
  if (item?.refiner__fromList.name != null) {
    return refinerDropBackToInventory(item, SAFEPACK)
  }

  if (mutationForbidenDueToInQueueState.get()) {
    if (selfMemberState.get()?.ready)
      return MoveForbidReason.FORBIDDEN_READY_STATUS
    else
      return MoveForbidReason.FORBIDDEN_QUEUE_STATUS
  }

  let ret = isDropForbiddenCommon(item, SAFEPACK)
  if (ret != MoveForbidReason.NONE)
    return ret

  let inventoryEid = safepackEid.get()

  if (!checkVolume(item, inventoryEid) && !is_can_move_to_safepack_with_overflow(inventoryEid, item.eid))
    return MoveForbidReason.VOLUME

  if (!is_can_move_item_to_safepack(item.eid))
    return MoveForbidReason.FORBIDDEN_FOR_CONTAINER

  if (is_inventory_in_use(inventoryEid))
    return MoveForbidReason.OTHER

  return MoveForbidReason.NONE
}

function isItemCanBeDroppedOnGround(item) {
  let ret = isDropForbiddenCommon(item, GROUND)
  if (ret != MoveForbidReason.NONE)
    return ret

  if (!is_can_move_item_to_ground(item.eid))
    return MoveForbidReason.OTHER

  return MoveForbidReason.NONE
}

function isExternalInventoryDropForbidden(item) {
  if (item?.refiner__fromList.name != null) {
    return refinerDropBackToInventory(item, EXTERNAL_ITEM_CONTAINER)
  }

  if ( mutationForbidenDueToInQueueState.get() &&
      (
        (immutableInventoriesDuringQueue.findindex(@(v) v.name == item?.fromList.name) != null) || 
        externalInventoryContainerOwnerEid.get() == backpackEid.get() || 
        externalInventoryContainerOwnerEid.get() == get_controlled_hero() || 
        externalInventoryContainerOwnerEid.get() == safepackEid.get() 
      )
    ) {
      if (selfMemberState.get()?.ready)
        return MoveForbidReason.FORBIDDEN_READY_STATUS
      else
        return MoveForbidReason.FORBIDDEN_QUEUE_STATUS
    }

  let inventoryEid = externalInventoryEid.get()
  if (inventoryEid == item.eid)
    return MoveForbidReason.TRYING_PUT_INTO_ITSELF

  let ret = isDropForbiddenCommon(item, EXTERNAL_ITEM_CONTAINER)
  if (ret != MoveForbidReason.NONE)
    return ret


  if  (is_inventory_read_only(inventoryEid) || item.eid == inventoryEid)
    return MoveForbidReason.OTHER

  if (!checkVolume(item, inventoryEid))
    return MoveForbidReason.VOLUME

  return MoveForbidReason.NONE
}

let inventoryChecksByList = {
  inventory = isHeroInventoryDropForbidden
  stash = isItemCanBeDroppedInStash
  ground = isItemCanBeDroppedOnGround
  external_inventory = isExternalInventoryDropForbidden
  backpack0 = isBackpackDropForbidder
}

function isListMutableDueQueue(list) {
  if (!list)
    return false 
  let name = list?.name ?? list
  return (immutableInventoriesDuringQueue.findindex(@(v) v?.name == name) == null)
}

return {
  MoveForbidReason
  isDropForbiddenCommon
  checkVolume
  isHeroInventoryDropForbidden
  isItemCanBeDroppedInStash
  isBackpackDropForbidder
  isSafepackDropForbidder
  isItemCanBeDroppedOnGround
  isExternalInventoryDropForbidden
  inventoryChecksByList
  immutableInventoriesDuringQueue
  isListMutableDueQueue
}