from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
let { is_can_move_item_to_item_container, is_can_move_item_to_backpack,
      is_can_move_item_to_safepack, is_can_move_item_to_ground,
      is_inventory_read_only, is_inventory_in_use, is_can_move_to_safepack_with_overflow } = require("das.inventory")
let { GROUND, HERO_ITEM_CONTAINER, STASH, BACKPACK0,
      EXTERNAL_ITEM_CONTAINER, SAFEPACK } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { get_controlled_hero } = require("%dngscripts/common_queries.nut")
let { stashEid } = require("%ui/state/allItems.nut")
let { backpackEid, safepackEid } = require("%ui/hud/state/hero_extra_inventories_state.nut")
let { externalInventoryEid } = require("%ui/hud/state/hero_external_inventory_state.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { MoveForbidReason, checkVolume, isDropForbiddenCommon } = require("%ui/hud/menus/components/inventoryItemsListChecksCommon.nut")

function isHeroInventoryDropForbidden(item) {
  let ret = isDropForbiddenCommon(item, HERO_ITEM_CONTAINER)
  if (ret != MoveForbidReason.NONE)
    return ret

  let inventoryEid = get_controlled_hero()

  if (!checkVolume(item, inventoryEid))
    return MoveForbidReason.VOLUME

  if (!is_can_move_item_to_item_container(item.eid))
    return MoveForbidReason.OTHER

  return MoveForbidReason.NONE
}

function isItemCanBeDroppedInStash(item) {
  if (isOnboarding.get())
    return MoveForbidReason.OTHER

  let ret = isDropForbiddenCommon(item, STASH)
  if (ret != MoveForbidReason.NONE)
    return ret

  let inventoryEid = stashEid.get()

  if (!checkVolume(item, inventoryEid))
    return MoveForbidReason.VOLUME

  return MoveForbidReason.NONE
}

function isBackpackDropForbidder(item) {
  let ret = isDropForbiddenCommon(item, BACKPACK0)
  if (ret != MoveForbidReason.NONE)
    return ret

  let inventoryEid = backpackEid.get()

  if (!checkVolume(item, inventoryEid))
    return MoveForbidReason.VOLUME

  if (!is_can_move_item_to_backpack(item.eid))
    return MoveForbidReason.OTHER

  if (is_inventory_in_use(inventoryEid))
    return MoveForbidReason.OTHER

  return MoveForbidReason.NONE
}

function isSafepackDropForbidder(item) {
  let ret = isDropForbiddenCommon(item, SAFEPACK)
  if (ret != MoveForbidReason.NONE)
    return ret

  let inventoryEid = safepackEid.get()

  if (!checkVolume(item, inventoryEid) && !is_can_move_to_safepack_with_overflow(inventoryEid, item.eid))
    return MoveForbidReason.VOLUME

  if (!is_can_move_item_to_safepack(item.eid))
    return MoveForbidReason.OTHER

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
}