from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
let { canModifyInventory } = require("%ui/hud/state/inventory_common_es.nut")
let { is_item_inventory_move_blocked, is_item_pickup_blocked, is_inventory_have_free_volume_for_boxed_item_eid,
      is_inventory_have_free_volume_for_boxed_item_template, is_inventory_have_free_volume, is_inventory_in_use } = require("das.inventory")
let { isShiftPressed } = require("%ui/hud/state/inventory_state.nut")
let { GROUND } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { showMsgbox } = require("%ui/components/msgbox.nut")
let { isInPlayerSession } = require("%ui/hud/state/gametype_state.nut")

enum MoveForbidReason {
  NONE = 0
  VOLUME = 1
  ITEM_ALREADY_IN = 2
  OTHER = 3

  REFINER_IN_USE = 4
  TRYING_PUT_INTO_ITSELF = 5
}

function isDropForbiddenCommon(item, list_type) {
  if (item == null)
    return MoveForbidReason.OTHER
  if (item?.fromList == list_type)
    return MoveForbidReason.ITEM_ALREADY_IN
  if (item?.trashBinItemOrigin && item.trashBinItemOrigin != list_type)
    return MoveForbidReason.OTHER
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
    return is_inventory_have_free_volume_for_boxed_item_template(containerEid, item.template)
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