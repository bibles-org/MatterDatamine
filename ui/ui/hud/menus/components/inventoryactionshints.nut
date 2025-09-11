from "%ui/hud/menus/components/inventoryItemUtils.nut" import isFastEquipItemPossible, getInventoryToMove

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { GROUND, STASH, EXTERNAL_ITEM_CONTAINER, BACKPACK0, HERO_ITEM_CONTAINER, REFINER_STASH,
  REFINER, GENES_SECONDARY, GENES_MAIN, WORKBENCH, WORKBENCH_STASH, WORKBENCH_ITEMS_ON_PLAYER,
  LOOTBOX_SHOW_RESULT, REPLICATOR_ITEM
} = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { POCKETS, REPAIR, WEAPON, WEAPON_MOD, ITEM_PICKER, ON_BODY_SLOT } = require("%ui/hud/menus/components/slotTypes.nut")
let { currentChronogenes } = require("%ui/mainMenu/clonesMenu/cloneMenuState.nut")
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")

let contextMenuHint = static {
  hotkeys = ["RMB"]
  locId = "item/action/contextMenuHint"
  order = 1
  showInTooltip = true
}

let inspectItemHint = static {
  hotkeys = ["RMB"]
  locId = "item/action/inspectContainer"
  order = 1
}

let pickupHint = static {
  hotkeys = ["LMB"]
  locId = "item/action/pickup"
  order = 0
  showInTooltip = true
}

let equipHint = static {
  hotkeys = ["LMB"]
  locId = "action/backpack_equip"
  order = 0
  showInTooltip = true
}

function mkMoveHint(item, inventories) {
  
  if (item?.inventoryEid == null)
    return null
  local inventory = getInventoryToMove(item, inventories)
  if (inventory == null)
    return null

  return {
    hotkeys = ["LMB"]
    locId = $"item/action/moveTo{inventory.name}"
    order = 0
    showInTooltip = true
  }
}

let stackedItemsHints = static [
  {
    locId = "item/action/moveAllHint"
    hotkeys = ["Shift", "LMB"]
    order = 2
  },
  {
    locId = "item/action/moveSomeHint"
    hotkeys = ["Alt", "LMB"]
    faIcon = "hand-grab-o"
    order = 3
  }
]

let moveToStashHint = {
  locId = "item/action/moveToStashHint"
  hotkeys = ["Alt", "LMB"]
  order = 4
}

let canInspect = @(item) (item?.itemContainerItems ?? []).len() > 0
let needContextHint = @(item) item?.itemTemplate != null
let needMoveToStashHint = @(item) isOnPlayerBase.get() && item?.itemTemplate != null && item?.canDrop

function isMultyHintNeeded(item) {
  let { count = 1, ammoCount = 1, itemType = "", isBoxedItem = false } = item
  return count > 1 || (itemType == "ammo" && ammoCount > 1 && isBoxedItem)
}

let mkStackedItemsHints = @(item) isMultyHintNeeded(item) ? stackedItemsHints : []

let mkCommonHeroInventoryHints = @(item, inventories) []
  .extend(
    needContextHint(item) ? [isFastEquipItemPossible(item) ? equipHint : mkMoveHint(item, inventories), contextMenuHint]
      : canInspect(item) ? [inspectItemHint, contextMenuHint]
      : [isFastEquipItemPossible(item) ? equipHint : mkMoveHint(item, inventories)]
    mkStackedItemsHints(item)
    needMoveToStashHint(item) ? [moveToStashHint] : [])

let mkOuterInventoryHints = @(item) [pickupHint]
  .extend(
    canInspect(item) ? [inspectItemHint] : []
    mkStackedItemsHints(item))

let mkCommonRefinerHints = @(item) [
  {
    locId = "item/action/move_to_refiner"
    hotkeys = ["LMB"]
    order = 0
  }
].extend(mkStackedItemsHints(item), [contextMenuHint])

let mkCommonWorkbenchHints = @(item) [
  {
    locId = "item/action/move_to_workbench"
    hotkeys = ["LMB"]
    order = 0
  }
].extend(mkStackedItemsHints(item), [contextMenuHint])

let mkRepairHints = @(_item) [
  {
    locId = "item/action/repair_item"
    hotkeys = ["LMB"]
    order = 0
  }
]

let mkPocketsHints = @(item) item?.isLocked ? [] : [
  {
    locId = item?.itemTemplate == null ? "item/action/equip" : "item/action/replace"
    hotkeys = ["LMB"]
    order = 0
  }
  contextMenuHint
].append(needMoveToStashHint(item) ? moveToStashHint : null)

let mkRefeinerHints = @(item) [
  {
    locId = "item/action/removeFromRefiner"
    hotkeys = ["LMB"]
    order = 0
  }
  contextMenuHint
].extend(mkStackedItemsHints(item))

let mkWorkbenchHints = @(item) [
  {
    locId = "item/action/removeFromWorkbench"
    hotkeys = ["LMB"]
    order = 0
  }
].extend(mkStackedItemsHints(item))

let useChronogenHint = {
  showInTooltip = true
  locId = "item/action/useChronogen"
  hotkeys = ["LMB"]
  order = 0
}

let removeChronogenHint = {
  locId = "item/action/removeChronogen"
  hotkeys = ["LMB"]
  order = 0
}

let mainChronogenHint = {
  locId = "clonesMenu/selectEquipAlter"
  hotkeys = ["LMB"]
  additionalText = $"{loc("ui/multiply")}2"
  order = 0
}

let mkMainChorogenHints = @(item) item?.mainChronogeneAvailable ? [mainChronogenHint] : []
let mkSecondoryChronogenHints = @(item) item?.itemTemplate == null || item?.uniqueId == 0 ? []
  : [currentChronogenes.get()?.secondaryChronogenes.contains(item?.uniqueId)
      ? removeChronogenHint
      : useChronogenHint]

let equipWeaponHint =  {
  locId = "weapon/action/equip"
  hotkeys = ["LMB"]
  order = 0
}

let switchWeaponHint = {
  locId = "weapon/action/equip"
  hotkeys = ["LMB"]
  order = 0
  showInTooltip = true
}

function mkWeaponHints(item) {
  let { isCurrent = false, itemTemplate = "" } = item
  let res = [contextMenuHint]
  if (itemTemplate == "")
    return res.append(equipWeaponHint)
  if (!isCurrent)
    res.append(switchWeaponHint)
  if (needMoveToStashHint(item))
    res.append(moveToStashHint)
  return res
}

let equipWeaponModHint =  {
  locId = "weaponMod/action/equip"
  hotkeys = ["LMB"]
  order = 0
}

let loadWeaponModHint =  {
  locId = "weaponMod/action/loadWeapon"
  hotkeys = ["LMB"]
  order = 0
}

let unloadWeaponModHint =  {
  locId = "weaponMod/action/unloadWeapon"
  hotkeys = ["LMB"]
  order = 0
}

let changeWeaponModHint = {
  locId = "weaponMod/action/change"
  hotkeys = ["LMB"]
  order = 0
}

let unequipWeaponHint = {
  locId = "item/action/moveToLoadVest"
  hotkeys = ["RMB"]
  order = 1
}

function mkWeaponModsHint(item) {
  let { itemTemplate = "", isBuiltInAmmo = false, ammoCount = -1 } = item
  let res = []
  if (isBuiltInAmmo) {
    if (ammoCount == 0)
      return res.append(loadWeaponModHint)
    else
      return res.append(unloadWeaponModHint)
  }
  else if (itemTemplate == "")
    return res.append(equipWeaponModHint)
  else
    res.append(changeWeaponModHint, unequipWeaponHint)
  if (needMoveToStashHint(item))
    res.append(moveToStashHint)
  return res
}

let unequipSlotHint = static {
  locId = "item/action/unequip"
  hotkeys = ["LMB"]
  order = 0
}

let noActionSlotHint = static {
  locId = "action/noAction"
  hotkeys = ["LMB"]
  order = 0
}

let replaceItemHint = static {
  locId = "item/action/replace"
  hotkeys = ["LMB"]
  order = 0
}

let compareItemHint = static {
  locId = "item/action/compare"
  hotkeys = ["L.Alt"]
  order = 1
}

let moreInfoHint = static {
  locId = "item/action/moreInfo"
  hotkeys = ["LMB"]
  order = 1
  showInTooltip = true
}

let doubleClickReplicationHint = static {
  locId = "item/action/startFastestReplication"
  hotkeys = ["LMB"]
  order = 1
  additionalText = $"{loc("ui/multiply")}2"
  showInTooltip = true
}

function mkReplicatorHints(recipe) {
  if (recipe == null)
    return []
  return [doubleClickReplicationHint]
}

function mkItemPickerHint(item) {
  let { itemTemplate = "", needCompareHint = true, isNoActionBtn = false } = item
  let res = []
  if (itemTemplate == "")
    return res.append(isNoActionBtn ? noActionSlotHint : unequipSlotHint)
  else if (!needCompareHint)
    return res.append(replaceItemHint)
  else {
    res.append(replaceItemHint)
    res.append(compareItemHint)
  }
  return res
}

function mkMoreInfoHint(...) {
  return [ moreInfoHint ]
}

let hoverPcHotkeysPresentation = freeze({
  [GROUND.name] = mkOuterInventoryHints,
  [EXTERNAL_ITEM_CONTAINER.name] = mkOuterInventoryHints,
  [STASH.name] = @(item) mkCommonHeroInventoryHints(item, [HERO_ITEM_CONTAINER, BACKPACK0]),
  [REFINER_STASH.name] =  mkCommonRefinerHints,
  [BACKPACK0.name] = @(item) mkCommonHeroInventoryHints(item, [HERO_ITEM_CONTAINER]),
  [HERO_ITEM_CONTAINER.name] = @(item) mkCommonHeroInventoryHints(item, [BACKPACK0]),
  [POCKETS.name] = mkPocketsHints,
  [ON_BODY_SLOT.name] = mkPocketsHints,
  [REPAIR.name] = mkRepairHints,
  [REFINER.name] = mkRefeinerHints,
  [GENES_MAIN.name] = mkMainChorogenHints,
  [GENES_SECONDARY.name] = mkSecondoryChronogenHints,
  [WEAPON.name] = mkWeaponHints,
  [WEAPON_MOD.name] = mkWeaponModsHint,
  [WORKBENCH.name] = mkWorkbenchHints,
  [WORKBENCH_STASH.name] = mkCommonWorkbenchHints,
  [WORKBENCH_ITEMS_ON_PLAYER.name] = mkCommonWorkbenchHints,
  [ITEM_PICKER.name] = mkItemPickerHint,
  [LOOTBOX_SHOW_RESULT.name] = mkMoreInfoHint,
  [REPLICATOR_ITEM.name] = mkReplicatorHints
})

return freeze({
  hoverPcHotkeysPresentation
})
