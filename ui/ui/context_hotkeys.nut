from "string" import startswith

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { hoverPcHotkeysPresentation } = require("%ui/hud/menus/components/inventoryActionsHints.nut")
let { joyAHintOverrideText } = require("%ui/hotkeysPanelStateComps.nut")
let { POCKETS, ON_BODY_SLOT, WEAPON, WEAPON_MOD } = require("%ui/hud/menus/components/slotTypes.nut")
let { isSpectator } = require("%ui/hud/state/spectator_state.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let { inventoryItemClickActions } = require("%ui/hud/menus/inventoryActions.nut")
let { focusedData } = require("%ui/hud/state/inventory_state.nut")

const rmbGamepadHotkey = "^J:X"

function slotToList(item) {
  let isWeaponModSlot = item?.weapModSlotName
  if (isWeaponModSlot)
    return WEAPON_MOD.name

  let isWeaponSlot = item?.currentWeaponSlotName
  if (isWeaponSlot)
    return WEAPON.name

  let slotName = item?.slotName
  if (slotName) {
    if (slotName && startswith(slotName, "equipment_mod_pocket"))
      return POCKETS.name
    else
      return ON_BODY_SLOT.name
  }
  return null
}

function contextHotkeys() {
  if (isSpectator.get() || !isGamepad.get())
    return { watch = [isSpectator, isGamepad] }
  let children = []
  let item = focusedData.get()
  let listName = item?.fromList.name ?? slotToList(item)
  let actions = inventoryItemClickActions?[listName]

  let pcHints = hoverPcHotkeysPresentation?[listName](item)
  function getAction(actionName) {
    return pcHints?.findvalue(@(act) act?.hotkeys.findindex(@(v) v == actionName) != null)
  }

  if (actions?.rmbAction) {
    children.append({ hotkeys = [[rmbGamepadHotkey, {
          action = @() actions.rmbAction(item, null),
          description=loc(getAction("RMB")?.locId)
        }
      ]]})
  }

  
  if (actions?.lmbAction) {
    joyAHintOverrideText.set(loc(getAction("LMB")?.locId))
  }
  else {
    joyAHintOverrideText.set(null)
  }

  return {
    watch = [focusedData, isSpectator, isGamepad]
    children = children
  }
}

return {
  contextHotkeys
  rmbGamepadHotkey
}