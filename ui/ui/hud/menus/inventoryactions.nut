import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
from "math" import min, ceil

let { weaponSlotsKeys } = require("%ui/types/weapon_slots.nut")
let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")
let { GROUND, STASH, EXTERNAL_ITEM_CONTAINER, BACKPACK0, REFINER, REFINER_STASH, HERO_ITEM_CONTAINER,
  TRASH_BIN, SAFEPACK, WORKBENCH, WORKBENCH_STASH, WORKBENCH_ITEMS_ON_PLAYER
} = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { POCKETS, REPAIR, ON_BODY_SLOT, WEAPON, WEAPON_MOD } = require("%ui/hud/menus/components/slotTypes.nut")
let { getInventoryEidByListType } = require("%ui/hud/state/inventory_eids_common.nut")
let { isShiftPressed, isAltPressed, contextHoveredData } = require("%ui/hud/state/inventory_state.nut")
let { get_weapon_slot_for_item, move_weapon_from_inventory_to_slot,
      get_equipped_item_for_installing_mod, install_weapon_mod_to_slot,
      get_equipment_slot_for_item, move_item_from_inventory_to_slot,
      get_slot_and_equipment_for_mod, install_equipment_mod_to_slot,
      move_item_from_ground_to_slot,
      move_stack_to_inventory, is_equip_to_slot_cause_from_pocket_drop,
      is_equip_to_slot_cause_inventory_overflow,
      check_item_can_be_used } = require("das.inventory")
let { isOnPlayerBase, isInPlayerSession } = require("%ui/hud/state/gametype_state.nut")
let { sendNetEvent, TryUseItem, CmdUseExternalInventoryAccesspointRequest, CmdDropAllItemsFromInventory, EventQuickUseItemUsed } = require("dasevents")
let { itemCompExtraInfoQuery } = require("%ui/hud/state/item_info.nut")
let { trashBinItems } = require("%ui/hud/menus/components/trashBin.nut")
let { addModalPopup, removeModalPopup } = require("%ui/components/modalPopupWnd.nut")
let { unloadItemAmmo, canItemBeUnload, canItemBeLoad, loadItemAmmo, needShowMarketLink,
  showItemInMarket, isFastEquipItemPossible, getInventoryToMove, canCheckAmmoInMagazine,
  checkAmmoClick, loadIsEnabled, unloadIsEnabled, needShowMarketSlotLink,
  showItemsForSlotInMarket, repairCost, repairItems, fastUnequipItem, checkInventoryVolume
} = require("%ui/hud/menus/components/inventoryItemUtils.nut")
let { button } = require("%ui/components/button.nut")
let { mkText, mkTextArea } = require("%ui/components/commonComponents.nut")
let { choose_weapon } = require("das.human_weap")
let { unloadAmmoAction } = require("%ui/hud/menus/components/inventoryBulletInBarrel.nut")
let { itemCanBeRepaired, removeFromWorkbench, dropToWorkbench } = require("%ui/hud/menus/inventories/workbenchInventory.nut")
let { dropToRefiner, removeFromRefiner } = require("%ui/hud/menus/inventories/refinerInventory.nut")
let { openSplitStacksWindow, canSplitStack } = require("%ui/hud/menus/components/splitStackWindow.nut")
let { showInventoryOverflowOnUnequipToExMsgBox } = require("%ui/hud/menus/components/inventoryItemsListChecksCommon.nut")
let { isSpectator } = require("%ui/hud/state/spectator_state.nut")
let { canModifyInventory } = require("%ui/hud/state/inventory_common_es.nut")
let { previewPreset } = require("%ui/equipPresets/presetsState.nut")
let { shopPresetToPurchase, patchPresetItems } = require("%ui/equipPresets/presetsButton.nut")
let { marketItems, playerProfileCreditsCount, playerStats } = require("%ui/profile/profileState.nut")
let { getLotFromItem, isLotAvailable, getWeaponModsPrice } = require("%ui/mainMenu/market/inventoryToMarket.nut")
let { eventbus_send, eventbus_subscribe } = require("eventbus")
let { RedWarningColor, TextNormal } = require("%ui/components/colors.nut")
let { deep_clone } = require("%sqstd/underscore.nut")
let { equipment } = require("%ui/hud/state/equipment.nut")
let { mkFakeItem } = require("%ui/hud/menus/components/fakeItem.nut")
let { stashEid } = require("%ui/state/allItems.nut")
let { currencyMap } = require("%ui/mainMenu/currencyIcons.nut")
let { showNoEnoughStashSpaceMsgbox } = require("%ui/mainMenu/stashSpaceMsgbox.nut")

const CONTEXT_MENU_WND_UID = "itemContextMenu"
let iconHeight = hdpxi(18)

function fastEquipItem(item) {
  if (!canModifyInventory.get())
    return false
  if (item?.isWeapon) {
    let weap = get_weapon_slot_for_item(controlledHeroEid.get(), item.eid)
    if (weap == -1)
      return false
    let slotName = weaponSlotsKeys[weap]
    move_weapon_from_inventory_to_slot(item.eid, item.owner, slotName)
  }
  else if (item?.isWeaponMod) {
    let weapId = get_equipped_item_for_installing_mod(controlledHeroEid.get(), item.eid)
    if (weapId == ecs.INVALID_ENTITY_ID)
      return false
    install_weapon_mod_to_slot(item.eid, item?.inventoryEid ?? ecs.INVALID_ENTITY_ID, item.weapModSlotName, weapId)
  }
  else if (item?.isEquipment) {
    let slot = get_equipment_slot_for_item(controlledHeroEid.get(), item.eid)
    if (slot == "")
      return false
    if (item?.inventoryEid == null || item.inventoryEid == ecs.INVALID_ENTITY_ID)
      move_item_from_ground_to_slot(item.eid, slot)
    else
      move_item_from_inventory_to_slot(item.eid, item.inventoryEid, slot)
  }
  else {
    let result = ecs.CompObject()
    get_slot_and_equipment_for_mod(result, controlledHeroEid.get(), item.eid)
    let resTable = result.getAll()
    if ((resTable?["slot"] ?? "") == "" || (resTable?["equipment"] ?? ecs.INVALID_ENTITY_ID) == ecs.INVALID_ENTITY_ID)
      return false
    install_equipment_mod_to_slot(item.eid, item?.inventoryEid ?? ecs.INVALID_ENTITY_ID, resTable["slot"], resTable["equipment"])
  }
  return true
}

function removeFromTrashBin(item) {
  let isAmmo = (item?.ammoCount ?? 0) > 0 && (item?.countPerStack ?? 0) > 0
  local idx = -1
  idx = trashBinItems.get().findindex(@(trash) trash.eids.findindex(@(eid) eid==item.eid) != null)

  if(idx == null) {
    return
  }

  if (isShiftPressed.get()) {
    trashBinItems.mutate(function(v) {
      v.remove(idx)
    })
    return
  }

  if (isAmmo) {
    let ammo = trashBinItems.get()[idx].ammoCount - item.countPerStack
    trashBinItems.mutate(function(v) {
      if (ammo <= 0) {
        v.remove(idx)
      }
      else {
        v[idx].ammoCount -= item.countPerStack
      }
    })
  }
  else if (trashBinItems.get()[idx].eids.len() <= 1) {
    trashBinItems.mutate(@(v) v.remove(idx))
  }
  else {
    trashBinItems.mutate(function(v) {
      
      v[idx].eids.remove(0)
      v[idx].eid = v[idx].eids[0]
      v[idx].uniqueIds.remove(0)
      v[idx].count--
    })
  }
}

function moveItemToInventory(data, wishList, wishCount = 1) {
  if (data?.fromList?.name == "trashBin") {
    removeFromTrashBin(data)

    if(data.trashBinItemOrigin == wishList) {
      return
    }
  }

  let list = (wishList == GROUND && !isInPlayerSession.get()) ? STASH : wishList

  if (data?.onDropInInventory) {
    data.onDropInInventory(data, list)
    return
  }

  let targetInventoryEid = getInventoryEidByListType(list)

  let isOverflow = (is_equip_to_slot_cause_inventory_overflow(ecs.INVALID_ENTITY_ID, data?.slotName, targetInventoryEid) ||
    is_equip_to_slot_cause_from_pocket_drop(ecs.INVALID_ENTITY_ID, data?.slotName, targetInventoryEid))

  if (isOverflow) {
    let dropToOnOverflowEid = targetInventoryEid == controlledHeroEid.get() ?
      getInventoryEidByListType(isInPlayerSession.get() ? GROUND : STASH) :
      targetInventoryEid
    showInventoryOverflowOnUnequipToExMsgBox(@() move_stack_to_inventory([data.eid], dropToOnOverflowEid, wishCount))
  }
  else
    move_stack_to_inventory(data?.eids ?? [data.eid], targetInventoryEid, wishCount)
}

function moveItemWithKeyboardMode(item, list_type) {
  local itemCount = (item?.isBoxedItem ?? false) ? item.countPerStack : 1
  if (isShiftPressed.get())
    itemCount = (item?.isBoxedItem ?? false) ? item?.ammoCount : item?.count ?? 0
  else if (isAltPressed.get()) {
    if (canSplitStack(item)) {
      openSplitStacksWindow(item, @(count) moveItemToInventory(item, list_type, count))
      return
    }
    else
      itemCount = 1
  }
  moveItemToInventory(item, list_type, itemCount)
}

function moveItemToOneOfInventories(item, inventories, count) {
  local inventory = getInventoryToMove(item, inventories)
  if (inventory == null)
    return

  moveItemToInventory(item, inventory, count)
}

function equipOrPickUp(item, inventories, count) {
  if (isFastEquipItemPossible(item)) {
    fastEquipItem(item)
    return
  }
  moveItemToOneOfInventories(item, inventories, count)
}

function getEquipOrInventoryOrBackpack(item) {
  if (isFastEquipItemPossible(item))
    return null
  let inventory = getInventoryToMove(item, [HERO_ITEM_CONTAINER, BACKPACK0])
  if (inventory == null)
    return null
  return { locId = $"item/action/moveTo{inventory.name}", icon = "context_icons/move.svg" }
}

function getPickUpToEquipOrBackpack(item) {
  if (isFastEquipItemPossible(item))
    return null
  let inventory = getInventoryToMove(item, [BACKPACK0])
  if (inventory == null)
    return null
  return { locId = $"item/action/moveTo{inventory.name}", icon = "context_icons/move.svg" }
}

function getPickUpToEquipOrHeroInventory(item) {
  if (isFastEquipItemPossible(item))
    return null
  let inventory = getInventoryToMove(item, [HERO_ITEM_CONTAINER])
  if (inventory == null)
    return null
  return { locId = $"item/action/moveTo{inventory.name}", icon = "context_icons/move.svg" }
}

let stackCountOf = @(item) (item?.isBoxedItem ?? false) ? item.countPerStack : 1
let totalCountOf = @(item) (item?.isBoxedItem ?? false) ? item.ammoCount : item.count

let pickUpToEquipOrInventoryOrBackpack = function(item, count = null) {
  if (item?.itemType == "other") {
    equipOrPickUp(item, [BACKPACK0, HERO_ITEM_CONTAINER], count ?? stackCountOf(item))
  }
  else {
    equipOrPickUp(item, [HERO_ITEM_CONTAINER, BACKPACK0], count ?? stackCountOf(item))
  }
}
let pickUpToEquipOrBackpack = @(item, count = null )
  equipOrPickUp(item, [BACKPACK0], count ?? stackCountOf(item))
let pickUpToEquipOrHeroInventory = @(item, count = null)
  equipOrPickUp(item, [HERO_ITEM_CONTAINER], count ?? stackCountOf(item))
let moveToStashOnBase = @(item) !isOnPlayerBase.get() || item?.itemTemplate == null ? null
  : moveItemToInventory(item, STASH, totalCountOf(item))

function tryUse(item) {
  if (item?.isHealkit && item?.eid)
    ecs.g_entity_mgr.sendEvent(item.eid, EventQuickUseItemUsed({ userEid = controlledHeroEid.get() }))
  else if (item?.isHealkit || (item?.isUsable ?? false) || item?.itemType == "grenade")
    ecs.g_entity_mgr.sendEvent(item.eid, TryUseItem({userEid = controlledHeroEid.get(), targetEid=controlledHeroEid.get()}))
}

function canUseItem(item) {
  let { isHealkit = false, isUsable = false, itemType = "" } = item
  return (isHealkit || isUsable || itemType == "grenade") && check_item_can_be_used(controlledHeroEid.get(), item.eid)
}

function inspectItemsContainers(item, _event) {
  if ((item?.itemContainerItems ?? []).len() < 0)
    return null
  sendNetEvent(item.eid, CmdUseExternalInventoryAccesspointRequest({heroEid = controlledHeroEid.get()}))
}

function dropAllFromContainer(item) {
  if ((item?.itemContainerItems ?? []).len() < 0)
    return null
  
  sendNetEvent(controlledHeroEid.get(), CmdDropAllItemsFromInventory({fromInventoryEid = item.eid, toInventoryEid = stashEid.get()}))
}

function canUnequipItem(item) {
  if (!item?.itemTemplate || item.itemTemplate == "")
    return false
  local defaultItem = null
  if (item?.validWeaponSlots.contains("melee")) {
    let suitTpl = equipment.get()?["chronogene_primary_1"].itemTemplate
    if (suitTpl != null) {
      let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(suitTpl)
      let defWeapon = template?.getCompValNullable("equipment__setDefaultStubMeleeTemplate")
      if (defWeapon != null)
        defaultItem = mkFakeItem(defWeapon)
    }
  }
  return defaultItem?.itemTemplate != item.itemTemplate
}

function getUnloadItemInfo(item) {
  if (item?.canLoadOnlyOnBase && !isOnPlayerBase.get()) {
    return { locId = "Inventory/can_unload_only_on_base", icon = "context_icons/ammo_no.svg" }
  }
  let comps = itemCompExtraInfoQuery.perform(item?.eid ?? ecs.INVALID_ENTITY_ID, @(_eid, comp) comp)
  let locId = comps?.item_holder__customUiProps?.unloadAmmoTooltip ?? "Inventory/unload_ammo"
  let icon = comps?.item_holder__customUiProps?.unloadAmmoIcon ?? "context_icons/ammo_no.svg"
  return { locId, icon }
}

function getLoadItemInfo(item) {
  if (item?.canLoadOnlyOnBase && !isOnPlayerBase.get()) {
    return { locId = "Inventory/can_load_only_on_base", icon = "context_icons/ammo_yes.svg" }
  }
  let comps = itemCompExtraInfoQuery.perform(item?.eid ?? ecs.INVALID_ENTITY_ID, @(_eid, comp) comp)
  let locId = comps?.item_holder__customUiProps?.loadAmmoTooltip ?? "Inventory/load_ammo"
  let icon = comps?.item_holder__customUiProps?.loadAmmoIcon ?? "context_icons/ammo_yes.svg"
  return { locId, icon }
}

function getToMarketSlotInfo(itemOrSlot) {
  let locId = itemOrSlot?.itemType == "weapon" && (itemOrSlot?.mods ?? {}).len() > 0
    ? "item/action/ammoAndModsPurchase"
    : "slot/action/slotEquipmentPurchase"
  let icon = "context_icons/store_fast.svg"
  return { locId, icon }
}

let getRepairItemInfo = @(reqMoney) {
  locId = "inventory/directRepair"
  icon = "context_icons/repair.svg"
  additionalText = $" {currencyMap["CREDITS"]}{reqMoney}"
  color = reqMoney <= playerProfileCreditsCount.get() ? TextNormal : RedWarningColor
}

let itemContainerItemsQuery = ecs.SqQuery("itemContainerItemsQuery", {
  comps_ro = [["itemContainer", ecs.TYPE_EID_LIST, []]]
})

let canInspectItem = function(item) {
  if (item?.eid == null)
    return false
  local itemsInside = []
  itemContainerItemsQuery.perform(item.eid, function(_eid, comps) {
    itemsInside = comps.itemContainer
  })
  return itemsInside.len() > 0
}

let showChangeWeapon = @(item) item?.itemTemplate != null && !(item?.isCurrent ?? false)
let chooseWeaponAction = @(weapon) choose_weapon(weapon.currentWeaponSlotName)
let unloadWeaponAmmoAction = @(weapon) unloadAmmoAction(weapon, weapon.currentWeaponSlotName)
function showUnloadWeaponAction(weapon) {
  let { mods = null, curAmmo = 0, gunBoxedAmmoTemplate = "" } = weapon
  let magazine = mods?.magazine
  let canUnload = curAmmo == 1
  return canUnload && magazine != null && curAmmo > 0 && gunBoxedAmmoTemplate != ""
}

let isStackSplitEquipToHeroPossible = @(item) canSplitStack(item) && getInventoryToMove(item, [HERO_ITEM_CONTAINER])!=null
let isStackSplitEquipToBackpackPossible = @(item) canSplitStack(item) && getInventoryToMove(item, [BACKPACK0])!=null

let showSplitStackToHero = @(item) openSplitStacksWindow(item, @(count) moveItemToInventory(item, HERO_ITEM_CONTAINER, count))
let showSplitStackToBackpack = @(item) openSplitStacksWindow(item, @(count) moveItemToInventory(item, BACKPACK0, count))
let showSplitStackToGround = @(item) openSplitStacksWindow(item, @(count) moveItemToInventory(item, GROUND, count))

let actionShowSplitStackBackpack = {
  needToShow = isStackSplitEquipToBackpackPossible
  locId = "item/action/moveSomeToBackpack"
  icon = "context_icons/move.svg"
  action = showSplitStackToBackpack
}
let actionShowSplitStackHero = {
  needToShow = isStackSplitEquipToHeroPossible
  locId = "item/action/moveSomeToHero"
  icon = "context_icons/move.svg"
  action = showSplitStackToHero
}

let actionShowSplitStackGround  = {
  needToShow = canSplitStack
  locId = "item/action/moveSomeAway"
  icon = "context_icons/move.svg"
  action = showSplitStackToGround
}
let actionEquipOrInventoryOrBackpack = {
  getCustomData = getEquipOrInventoryOrBackpack
  action = pickUpToEquipOrInventoryOrBackpack
}

let actionInspectContaner = {
  needOnclickEventData = true
  locId = "item/action/inspectContainer"
  action = inspectItemsContainers
  needToShow = canInspectItem
  icon = "context_icons/look.svg"
}

let actionDropAllFromContaner = {
  locId = "item/action/dropFromContainer"
  action = dropAllFromContainer
  needToShow = canInspectItem
  icon = "context_icons/drop_out_1.svg"
}

let actionUse = {
  locId = "item/action/use"
  action = tryUse
  needToShow = canUseItem
  icon = "context_icons/use.svg"
}

let actionFastEquip = {
  locId = "action/backpack_equip"
  needToShow = isFastEquipItemPossible
  action = fastEquipItem
  icon = "context_icons/equip.svg"
}

let actionToMarket = {
  locId = "inventory/toMarket"
  needToShow = needShowMarketLink
  action = showItemInMarket
  icon = "context_icons/store.svg"
}

let actionToMarketForSlot = {
  getCustomData = getToMarketSlotInfo
  needToShow = needShowMarketSlotLink
  action = showItemsForSlotInMarket
}

let actionLoadAmmo = {
  needToShow = canItemBeLoad
  getCustomData = getLoadItemInfo
  action = loadItemAmmo
  icon = "context_icons/ammo_yes.svg"
  getEnabled = loadIsEnabled
}

let actionUnloadAmmo = {
  needToShow = canItemBeUnload
  getCustomData = getUnloadItemInfo
  action = unloadItemAmmo
  icon = "context_icons/ammo_no.svg"
  getEnabled = unloadIsEnabled
}

let actionCheckMagazineAmmo = {
  needToShow = @(item) canCheckAmmoInMagazine(item, isSpectator.get())
  action = checkAmmoClick
  icon = "context_icons/look.svg"
  locId = "Inventory/check_ammo"
}

let fastUnequipItemAction = {
  locId = "item/action/unequip"
  action = fastUnequipItem
  needToShow = canUnequipItem
  icon = "context_icons/unequip.svg"
}

let repairItemAction = {
  action = @(item) repairItems([item])
  getCustomData = @(item) getRepairItemInfo(repairCost([item]))
  needToShow = itemCanBeRepaired
}

let contextMenuActionsByListType = freeze({
  [GROUND.name] = [
    actionUse
    actionFastEquip
    actionEquipOrInventoryOrBackpack
    actionShowSplitStackHero
    actionShowSplitStackBackpack
    actionInspectContaner
    actionDropAllFromContaner
  ],
  [EXTERNAL_ITEM_CONTAINER.name] = [
    actionUse
    actionFastEquip
    actionEquipOrInventoryOrBackpack
    actionShowSplitStackHero
    actionShowSplitStackBackpack
    actionInspectContaner
    actionDropAllFromContaner
  ],
  [STASH.name] = [
    actionUse
    actionCheckMagazineAmmo
    actionFastEquip
    actionEquipOrInventoryOrBackpack
    actionShowSplitStackHero
    actionShowSplitStackBackpack
    actionInspectContaner
    actionDropAllFromContaner
    actionLoadAmmo
    actionUnloadAmmo
    actionToMarket
    repairItemAction
  ],
  [BACKPACK0.name] = [
    actionUse
    actionCheckMagazineAmmo
    actionFastEquip
    {
      getCustomData = getPickUpToEquipOrHeroInventory
      action = pickUpToEquipOrHeroInventory
    }
    actionShowSplitStackHero
    actionShowSplitStackGround
    actionInspectContaner
    actionDropAllFromContaner
    actionLoadAmmo
    actionUnloadAmmo
    actionToMarket
    repairItemAction
  ],
  [HERO_ITEM_CONTAINER.name] = [
    actionUse
    actionCheckMagazineAmmo
    actionFastEquip
    {
      getCustomData = getPickUpToEquipOrBackpack
      action = pickUpToEquipOrBackpack
    }
    actionShowSplitStackBackpack
    actionShowSplitStackGround
    actionInspectContaner
    actionDropAllFromContaner
    actionLoadAmmo
    actionUnloadAmmo
    actionToMarket
    repairItemAction
  ],
  [SAFEPACK.name] = [
    actionUse
    actionCheckMagazineAmmo
    actionFastEquip
    {
      getCustomData = getPickUpToEquipOrBackpack
      action = pickUpToEquipOrBackpack
    }
    actionShowSplitStackBackpack
    actionShowSplitStackGround
    actionInspectContaner
    actionLoadAmmo
    actionUnloadAmmo
    actionToMarket
    repairItemAction
  ],
  [POCKETS.name] = [
    actionUse
    fastUnequipItemAction
    repairItemAction
    actionToMarketForSlot
  ],
  [REPAIR.name] = [
    actionToMarket
  ],
  [ON_BODY_SLOT.name] = [
    fastUnequipItemAction
    actionDropAllFromContaner
    repairItemAction
    actionToMarketForSlot
  ],
  [WEAPON.name] = [
    {
      locId = "weapon/action/switch"
      needToShow = showChangeWeapon
      action = chooseWeaponAction
      icon = "context_icons/equip.svg"
    }
    fastUnequipItemAction
    {
      locId = "Inventory/unload_bullet_from_barrel"
      needToShow = showUnloadWeaponAction
      action = unloadWeaponAmmoAction
      icon = "context_icons/barrel.svg"
    }
    actionToMarketForSlot
  ],
  [WEAPON_MOD.name] = [
    fastUnequipItemAction
    actionToMarketForSlot
  ],
  [REFINER.name] = [
    {
      locId = "inventory/removeFromRefiner"
      action = removeFromRefiner
      icon = "context_icons/drag_out.svg"
    }
    actionToMarket
  ],
  [REFINER_STASH.name] = [
    {
      locId = "inventory/dropToRefiner"
      action = @(item) dropToRefiner(item, REFINER_STASH)
      icon = "context_icons/drag_in.svg"
    }
    actionToMarket
  ],
  [WORKBENCH.name] = [
    {
      locId = "inventory/removeFromWorkbench"
      action = removeFromWorkbench
      icon = "context_icons/drag_out.svg"
    }
    actionToMarket
  ],
  [WORKBENCH_STASH.name] = [
    {
      locId = "inventory/dropToWorkbench"
      needToShow = itemCanBeRepaired
      action = @(item) dropToWorkbench(item, WORKBENCH_STASH)
      icon = "context_icons/drag_in.svg"
    }
    actionToMarket
  ],
  [WORKBENCH_ITEMS_ON_PLAYER.name] = [
    {
      locId = "inventory/dropToWorkbench"
      needToShow = itemCanBeRepaired
      action = @(item) dropToWorkbench(item, WORKBENCH_ITEMS_ON_PLAYER)
      icon = "context_icons/drag_in.svg"
    }
    actionToMarket
  ],
  [TRASH_BIN.name] = [
    actionInspectContaner
  ]
})

function mkContextMenuRow(rowData, item, event) {
  let { action = null, icon = null, locId = "", getCustomData = null,
    needToShow = null, needOnclickEventData = false, getEnabled = null } = rowData
  if (action == null || (needToShow != null && !needToShow(item)))
    return null
  let castomData = getCustomData?(item)
  let isEnabled = getEnabled?(item) ?? true
  let locIdToUse = castomData?.locId ?? locId
  let iconToUse = castomData?.icon ?? icon
  let additionalText = castomData?.additionalText ?? ""

  if (locIdToUse == "" && iconToUse == null)
    return null

  return button({
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    gap = hdpx(4)
    valign = ALIGN_CENTER
    children = [
      iconToUse == null ? { size = [iconHeight, iconHeight] } : {
        rendObj = ROBJ_IMAGE
        size = [iconHeight, iconHeight]
        image = Picture($"ui/skin#{iconToUse}:{iconHeight}:{iconHeight}:P")
      }
      mkTextArea($"{loc(locIdToUse)}{additionalText}", { color = castomData?.color ?? TextNormal })
    ]
  }, function() {
    removeModalPopup(CONTEXT_MENU_WND_UID)
    contextHoveredData.set(null)
    if (needOnclickEventData)
      action(item, event)
    else
      action(item)
  }, {
    size = [flex(), SIZE_TO_CONTENT]
    halign = ALIGN_CENTER
    padding = [hdpx(4), hdpx(6)]
    borderWidth = 0
    isEnabled
  })
}

let noActionsRow = {
  locId = "action/noAction"
  icon = "context_icons/cross.svg"
}

function mkDummyContextMenuRow(rowData) {
  let { icon, locId } = rowData
  return button({
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    gap = hdpx(4)
    valign = ALIGN_CENTER
    children = [
      {
        rendObj = ROBJ_IMAGE
        size = [iconHeight, iconHeight]
        image = Picture($"ui/skin#{icon}:{0}:{0}:P".subst(iconHeight))
      }
      mkText(loc(locId), {
        size = [flex(), SIZE_TO_CONTENT]
      })
    ]
  }, function() {
    removeModalPopup(CONTEXT_MENU_WND_UID)
    contextHoveredData.set(null)
  }, {
    size = [flex(), SIZE_TO_CONTENT]
    halign = ALIGN_CENTER
    padding = [hdpx(4), hdpx(6)]
    borderWidth = 0
  })
}

function getPurchaseItem(item, playerStat) {
  let { noSuitableItemForPresetFoundCount = 0, attachments = {} } = item
  if (noSuitableItemForPresetFoundCount == 0)
    return null
  let lot = getLotFromItem(item)
  if (lot == null)
    return null
  let marketItem = marketItems.get()?[lot]
  local { reqMoney = -1 } = marketItem
  if (reqMoney <= 0)
    return null
  if (!isLotAvailable(marketItem, playerStat))
    return null
  if (attachments.len() > 0)
    reqMoney += getWeaponModsPrice(marketItem, attachments, playerStat)
  return { reqMoney, lot }
}

function directPurchase(item, id, itemsToPurchase, canPurchase) {
  if (canPurchase) {
    let missingVolume = checkInventoryVolume([item])
    if (missingVolume > 0) {
      showNoEnoughStashSpaceMsgbox(missingVolume)
      return
    }
    eventbus_send("profile_server.buyLots", [ { id, count = itemsToPurchase } ])
    eventbus_subscribe("profile_server.buyLots.result", function(_) {
      let clonedPreset = deep_clone(previewPreset.get())
      patchPresetItems(clonedPreset)
      previewPreset.set(clonedPreset)
      previewPreset.trigger()
    })
  }
}

let getPurchaseItemText = @(canPurchase, reqMoney) {
  locId = "inventory/directPurchase"
  icon = "context_icons/store.svg"
  additionalText = $" {currencyMap["CREDITS"]}{reqMoney}"
  color = canPurchase ? TextNormal : RedWarningColor
}

let mkPurchaseItemActionData = @(id, reqMoney, itemsToPurchase, canPurchase) {
  action = @(item) directPurchase(item, id, itemsToPurchase, canPurchase)
  getCustomData = @(_item) getPurchaseItemText(canPurchase, reqMoney)
}

function showItemContextMenu(item, listTypeName, event = null) {
  if (isSpectator.get() || shopPresetToPurchase.get() != null)
    return
  contextHoveredData.set(item)
  let playerStat = playerStats.get()
  
  let funcList = []
  if (previewPreset.get() != null) {
    let { lot = null, reqMoney = 0 } = getPurchaseItem(item, playerStat)
    let { countPerStack = 1, noSuitableItemForPresetFoundCount = 0 } = item
    if (noSuitableItemForPresetFoundCount != null) {
      let itemsToPurchase = countPerStack > 1 ?
      ceil(noSuitableItemForPresetFoundCount.tofloat() / countPerStack.tofloat()) :
      noSuitableItemForPresetFoundCount
      if (lot != null && reqMoney > 0)
        funcList.append(mkContextMenuRow(
          mkPurchaseItemActionData(lot, reqMoney * itemsToPurchase, itemsToPurchase, playerProfileCreditsCount.get() >= reqMoney),
            item, event))
    }
  }
  else {
    foreach (data in contextMenuActionsByListType?[listTypeName] ?? []) {
      let row = mkContextMenuRow(data, item, event)
      if (row != null)
        funcList.append(row)
    }
  }
  if (funcList.len() == 0)
    funcList.append(mkDummyContextMenuRow(noActionsRow))

  let cursorPos = get_mouse_cursor_pos()
  addModalPopup([cursorPos.x, cursorPos.y + 1], {
    size = [hdpx(300), SIZE_TO_CONTENT]
    uid = CONTEXT_MENU_WND_UID
    flow = FLOW_VERTICAL
    popupValign = ALIGN_TOP
    padding = 0
    moveDuraton = 0
    onDetach = @() contextHoveredData.set(null)
    children = funcList
  })
}

let inventoryItemClickActions = {
  [GROUND.name] = {
    lmbAction = @(item) pickUpToEquipOrInventoryOrBackpack(item, stackCountOf(item))
    lmbShiftAction = @(item) pickUpToEquipOrInventoryOrBackpack(item, totalCountOf(item))
    rmbAction = @(item, event) showItemContextMenu(item, GROUND.name, event)
  },
  [EXTERNAL_ITEM_CONTAINER.name] = {
    lmbAction = @(item) pickUpToEquipOrInventoryOrBackpack(item, stackCountOf(item))
    lmbShiftAction = @(item) pickUpToEquipOrInventoryOrBackpack(item, totalCountOf(item))
    rmbAction = @(item, event) showItemContextMenu(item, EXTERNAL_ITEM_CONTAINER.name, event)
  },
  [STASH.name] = {
    lmbAction = @(item) pickUpToEquipOrInventoryOrBackpack(item, stackCountOf(item))
    lmbShiftAction = @(item) pickUpToEquipOrInventoryOrBackpack(item, totalCountOf(item))
    rmbAction = @(item, event) showItemContextMenu(item, STASH.name, event)
  },
  [BACKPACK0.name] = {   
    lmbAction = @(item) pickUpToEquipOrHeroInventory(item, stackCountOf(item))
    lmbShiftAction = @(item) pickUpToEquipOrHeroInventory(item, totalCountOf(item))
    lmbAltAction = @(item) moveToStashOnBase(item)
    rmbAction = @(item, event) showItemContextMenu(item, BACKPACK0.name, event)
  },
  [HERO_ITEM_CONTAINER.name] = {   
    lmbAction = @(item) pickUpToEquipOrBackpack(item, stackCountOf(item))
    lmbShiftAction = @(item) pickUpToEquipOrBackpack(item, totalCountOf(item))
    lmbAltAction = @(item) moveToStashOnBase(item)
    rmbAction = @(item, _event) showItemContextMenu(item, HERO_ITEM_CONTAINER.name)
  },
  [POCKETS.name] = {
    rmbAction = @(item, event) showItemContextMenu(item, POCKETS.name, event)
    lmbAltAction = @(item) moveToStashOnBase(item)
  },
  [REPAIR.name] = { rmbAction = @(item, _event) showItemContextMenu(item, REPAIR.name) },
  [ON_BODY_SLOT.name] = {
    rmbAction = @(item, event) showItemContextMenu(item, ON_BODY_SLOT.name, event)
    lmbAltAction = @(item) moveToStashOnBase(item)
  },
  [WEAPON.name] = {
    rmbAction = @(item, event) showItemContextMenu(item, WEAPON.name, event)
    lmbAltAction = @(item) moveToStashOnBase(item)
  },
  [WEAPON_MOD.name] = {
    rmbAction = @(item, event) showItemContextMenu(item, WEAPON_MOD.name, event)
    lmbAltAction = @(item) moveToStashOnBase(item)
  },
  [SAFEPACK.name] = {
    rmbAction = @(item, _event) showItemContextMenu(item, SAFEPACK.name)
    lmbAltAction = @(item) moveToStashOnBase(item)
  },
  [REFINER.name] = { rmbAction = @(item, _event) showItemContextMenu(item, REFINER.name) },
  [REFINER_STASH.name] = { rmbAction = @(item, _event) showItemContextMenu(item, REFINER_STASH.name) },
  [WORKBENCH.name] = { rmbAction = @(item, _event) showItemContextMenu(item, WORKBENCH.name) },
  [WORKBENCH_STASH.name] = { rmbAction = @(item, _event) showItemContextMenu(item, WORKBENCH_STASH.name) },
  [WORKBENCH_ITEMS_ON_PLAYER.name] = { rmbAction = @(item, _event) showItemContextMenu(item, WORKBENCH_ITEMS_ON_PLAYER.name) },
  [TRASH_BIN.name] = {
    lmbAction = @(item) removeFromTrashBin(item)
    rmbAction = @(item, event) showItemContextMenu(item, TRASH_BIN.name, event)
  }
}

return {
  fastEquipItem
  moveItemToInventory
  moveItemWithKeyboardMode
  inventoryItemClickActions
  CONTEXT_MENU_WND_UID
}