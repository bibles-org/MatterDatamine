from "das.inventory" import is_item_inventory_move_blocked, is_item_pickup_blocked, is_inventory_have_free_volume_for_boxed_item_eid, is_inventory_have_free_volume_for_boxed_item_template,
  is_inventory_have_free_volume, is_inventory_in_use, is_can_unfold_in_parent
from "%ui/hud/state/inventory_eids_common.nut" import getInventoryEidByListType

from "%ui/components/msgbox.nut" import showMsgbox

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
let { canModifyInventory } = require("%ui/hud/state/inventory_common_es.nut")
let { isShiftPressed } = require("%ui/hud/state/inventory_state.nut")
let { GROUND } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { isInPlayerSession } = require("%ui/hud/state/gametype_state.nut")

enum MoveForbidReason {
  NONE = 0
  VOLUME = 1
  ITEM_ALREADY_IN = 2
  OTHER = 3
  FORBIDDEN = 4

  REFINER_IN_USE = 5
  TRYING_PUT_INTO_ITSELF = 6

  FORBIDDEN_QUEUE_STATUS = 7
  FORBIDDEN_READY_STATUS = 8
  FORBIDDEN_REFINER_IN_PROGRESS = 9

  PARENT_VOLUME_OVERFLOW = 10

  FORBIDDEN_FOR_CONTAINER = 11
}

function isDropForbiddenCommon(item, list_type) {
  if (item == null)
    return MoveForbidReason.OTHER
  if (item?.fromList == list_type)
    return MoveForbidReason.ITEM_ALREADY_IN
  if (item?.trashBinItemOrigin && item.trashBinItemOrigin != list_type)
    return MoveForbidReason.OTHER
  if (!is_can_unfold_in_parent(getInventoryEidByListType(list_type)))
    return MoveForbidReason.PARENT_VOLUME_OVERFLOW
  if (is_inventory_in_use(item.eid))
    return MoveForbidReason.OTHER
  if (
      !canModifyInventory.get() ||
      is_item_inventory_move_blocked(item?.eid ?? ecs.INVALID_ENTITY_ID) ||
      (item?.fromList == GROUND && is_item_pickup_blocked(item?.eid ?? ecs.INVALID_ENTITY_ID))
    )
    return MoveForbidReason.OTHER

  return MoveForbidReason.NONE
}

function checkVolume(item, containerEid) {
  if (item?.isBuiltInAmmo ?? false) {
    return is_inventory_have_free_volume_for_boxed_item_template(containerEid, item.itemTemplate)
  }
  else if (item?.isBoxedItem ?? false) {
    return is_inventory_have_free_volume_for_boxed_item_eid(containerEid, item.eid)
  }
  else {
    let volume = isShiftPressed.get() ? (item?.volume ?? 0) : (item?.currentStackVolume ?? 0)
    return is_inventory_have_free_volume(containerEid, volume)
  }
}

function getInventoryOverflowOnDropLoc() {
  if (isInPlayerSession.get())
    return loc("consoleMessage/inventory_overflow_on_unequip_drop_items_on_ground")
  return loc("consoleMessage/inventory_overflow_on_unequip_drop_items_to_stash")
}

function showInventoryOverflowOnUnequipToExMsgBox(func) {
  showMsgbox({ text = getInventoryOverflowOnDropLoc(), buttons = [
    {
      text = loc("Yes"),
      isCurrent = true,
      action = func
    }
    { text = loc("No"), isCancel = true }
  ]})
}

return {
  MoveForbidReason
  checkVolume
  isDropForbiddenCommon
  showInventoryOverflowOnUnequipToExMsgBox
}