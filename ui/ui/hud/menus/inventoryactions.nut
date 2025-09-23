from "%sqstd/underscore.nut" import deep_clone

from "das.inventory" import get_weapon_slot_for_item, move_weapon_from_inventory_to_slot, get_equipped_item_for_installing_mod, install_weapon_mod_to_slot,
  get_equipment_slot_for_item, move_item_from_inventory_to_slot, get_slot_and_equipment_for_mod, install_equipment_mod_to_slot,
  move_item_from_ground_to_slot, move_stack_to_inventory, is_equip_to_slot_cause_from_pocket_drop, is_equip_to_slot_cause_inventory_overflow,
  check_item_can_be_used
from "%ui/hud/menus/components/inventoryItemUtils.nut" import unloadAmmoClick, canItemBeUnload, canItemBeLoad,
  loadAmmoClick, needShowMarketLink, showItemInMarket, isFastEquipItemPossible, getInventoryToMove,
  getInspectingAmmoCountInfo, canCheckAmmoInMagazine, checkAmmoClick, loadIsEnabled, unloadIsEnabled,
  stopLoadUnloadAmmoClick, needShowMarketSlotLink, showItemsForSlotInMarket, repairCost, repairItems, inventories,
  findInventoryWithFreeVolume, fastUnequipItem, checkInventoryVolume, actionForbiddenDueToQueueState

from "%ui/fonts_style.nut" import sub_txt
from "%ui/hud/state/inventory_eids_common.nut" import getInventoryEidByListType
from "dasevents" import sendNetEvent, TryUseItem, CmdUseExternalInventoryAccesspointRequest, CmdDropAllItemsFromInventory, EventQuickUseItemUsed
from "%ui/components/modalPopupWnd.nut" import addModalPopup, removeModalPopup
from "%ui/components/button.nut" import button
from "%ui/components/commonComponents.nut" import mkText, mkTextArea
from "das.human_weap" import choose_weapon
from "%ui/hud/menus/components/inventoryBulletInBarrel.nut" import unloadAmmoAction
from "%ui/hud/menus/inventories/workbenchInventory.nut" import itemCanBeRepaired, removeFromWorkbench, dropToWorkbench
from "%ui/hud/menus/inventories/refinerInventory.nut" import dropToRefiner, removeFromRefiner
from "%ui/hud/menus/components/splitStackWindow.nut" import openSplitStacksWindow, canSplitStack, canAddSplitStackToInventory
from "%ui/hud/menus/components/inventoryItemsListChecksCommon.nut" import showInventoryOverflowOnUnequipToExMsgBox
from "%ui/equipPresets/presetsButton.nut" import patchPresetItems
from "%ui/mainMenu/market/inventoryToMarket.nut" import getLotFromItem, isLotAvailable, getWeaponModsPrice
from "eventbus" import eventbus_send, eventbus_subscribe
from "%ui/components/colors.nut" import RedWarningColor, TextNormal, InfoTextValueColor
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem
from "%ui/mainMenu/currencyIcons.nut" import currencyMap
from "%ui/mainMenu/stashSpaceMsgbox.nut" import showNoEnoughStashSpaceMsgbox
from "%ui/state/appState.nut" import isInBattleState
from "dasevents" import CmdShowUiMenu
from "%ui/popup/player_event_log.nut" import addPlayerLog, mkPlayerLog, playerLogsColors
from "%dngscripts/sound_system.nut" import sound_play
from "%ui/components/msgbox.nut" import showMsgbox
from "%ui/hud/state/hero_extra_inventories_state.nut" import backpackEid, safepackEid
from "%ui/hud/state/inventory_items_es.nut" import stashItems
from "%ui/hud/menus/components/inventoryItemUtils.nut" import mergeNonUniqueItems
import "%ui/components/colorize.nut" as colorize

import "%ui/components/gamepadImgByKey.nut" as gamepadImgByKey
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
from "math" import min, ceil

let { weaponSlotsKeys } = require("%ui/types/weapon_slots.nut")
let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")
let { GROUND, STASH, EXTERNAL_ITEM_CONTAINER, BACKPACK0,
      REFINER, REFINER_STASH, REFINER_ON_PLAYER,
      HERO_ITEM_CONTAINER, SAFEPACK, WORKBENCH,
      WORKBENCH_STASH, WORKBENCH_ITEMS_ON_PLAYER } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { POCKETS, REPAIR, ON_BODY_SLOT, WEAPON, WEAPON_MOD } = require("%ui/hud/menus/components/slotTypes.nut")
let { isShiftPressed, isAltPressed, contextHoveredData, mutationForbidenDueToInQueueState } = require("%ui/hud/state/inventory_state.nut")
let { isOnPlayerBase, isInPlayerSession } = require("%ui/hud/state/gametype_state.nut")
let { itemCompExtraInfoQuery } = require("%ui/hud/state/item_info.nut")
let { isSpectator } = require("%ui/hud/state/spectator_state.nut")
let { canModifyInventory } = require("%ui/hud/state/inventory_common_es.nut")
let { previewPreset } = require("%ui/equipPresets/presetsState.nut")
let { shopPresetToPurchase } = require("%ui/equipPresets/presetsButton.nut")
let { marketItems, playerProfileCreditsCount, playerStats, playerBaseState, trialData } = require("%ui/profile/profileState.nut")
let { equipment } = require("%ui/hud/state/equipment.nut")
let { stashEid } = require("%ui/state/allItems.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { inspectingAmmoCountAffectEid } = require("%ui/hud/state/ammo_count_knowledge_state.nut")
let { entityToUse } = require("%ui/hud/state/entity_use_state.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { WEAPON_SHOWROOM_MENU_ID, inventoryShowroomItem } = require("%ui/hud/menus/weaponShowroom/weaponShowroom.nut")
let { inShootingRange } = require("%ui/hud/state/shooting_range_state.nut")
let { selfMemberState } = require("%ui/squad/squadState.nut")
let { isListMutableDueQueue } = require("%ui/hud/menus/components/inventoryItemsListChecks.nut")

const CONTEXT_MENU_WND_UID = "itemContextMenu"
let iconHeight = hdpxi(18)

function fastEquipItem(item) {
  if (!canModifyInventory.get() || mutationForbidenDueToInQueueState.get())
    return false
  if (item?.isWeapon) {
    let weap = get_weapon_slot_for_item(controlledHeroEid.get(), item.eid)
    if (weap == -1)
      return false
    let slotName = weaponSlotsKeys[weap]
    move_weapon_from_inventory_to_slot(item.eid, item.inventoryEid, slotName)
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

function moveItemToInventory(data, wishList, wishCount = 1) {
  if (data?.refiner__fromList) {
    removeFromRefiner(data, wishCount)
    return
  }

  if (wishList == REFINER) {
    dropToRefiner(data, data?.fromList, wishCount)
    return
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
  else {
    let eidsList = data?.eids ?? []
    move_stack_to_inventory(eidsList.len() > 0 ? eidsList : [data.eid], targetInventoryEid, wishCount)
  }
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

function moveItemToOneOfInventories(item, inventoriesList, count) {
  local inventory = getInventoryToMove(item, inventoriesList)
  if (inventory == null) {

    sound_play("ui_sounds/button_click_inactive")
    addPlayerLog({
      id = $"NoFreeVolumeLeft"
      
      content = mkPlayerLog({
        titleText = loc("inventory/overwhelmed")
        titleFaIcon = "close"
        bodyText = loc(item?.itemName)
        logColor = playerLogsColors.warningLog
      })
    })
    return
  }

  moveItemToInventory(item, inventory, count)
}

function equipOrPickUp(item, inventoriesList, count) {
  if (isFastEquipItemPossible(item)) {
    fastEquipItem(item)
    return
  }
  moveItemToOneOfInventories(item, inventoriesList, count)
}

function getEquipOrInventoryOrBackpack(item) {
  if (isFastEquipItemPossible(item))
    return null
  let inventory = getInventoryToMove(item, [HERO_ITEM_CONTAINER, BACKPACK0])
  if (inventory == null)
    return null
  return { locId = $"item/action/moveTo{inventory.name}", icon = "context_icons/move.svg" }
}

function queueStatusBlockedItem(item) {
  if (!isOnPlayerBase.get())
    return false
  return actionForbiddenDueToQueueState(item)
}

function moveAwayToStashOrGround(_item) {
  local locId = "item/action/moveAway"
  if (isOnPlayerBase.get())
    locId = "item/action/moveToStashHint"
  return { locId, icon = "context_icons/drag_out.svg" }
}

function moveAwayStackToStashOrGround(_item) {
  local locId = "item/action/moveSomeAway"
  if (isOnPlayerBase.get())
    locId = "item/action/moveSomeToStash"
  return { locId, icon = "context_icons/drag_out.svg" }
}

function showSplitStackOrJustMoveToInventory(item, showSuitableAmmo = false, inventoriesList = null) {
  local locId = showSuitableAmmo || item?.isBoxedItem
    ? item?.isHealkit ? "item/action/moveSomeAmpoulesInventory" : "item/action/moveSomeAmmoInventory"
    : "item/action/moveSomeToInventory"
  local additionalText = ""
  let { itemTemplate = null, boxedItemTemplate = null, ammo = null } = item
  let itemToSearch = showSuitableAmmo
    ? ammo != null ? ammo?.template : boxedItemTemplate
    : itemTemplate
  let resItems = []
  foreach (stashItem in stashItems.get()) {
    if (stashItem.itemTemplate == itemToSearch)
      resItems.append(stashItem)
    if (resItems.len() >= 2)
      break
  }
  if (resItems.len() == 0)
    return { locId = "???", icon = "context_icons/drag_in.svg" }
  let { isBoxedItem = false, ammoCount = -1, count = -1 } = resItems[0]
  if (inventoriesList != null) {
    let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(resItems[0].itemTemplate)
    let volume = template?.getCompValNullable("item__volume") ?? 0
    let inventoryToMove = findInventoryWithFreeVolume(volume)?.data.name
    let name = inventoryToMove == SAFEPACK.name ? loc("inventory/toSafepack")
      : inventoryToMove == BACKPACK0.name ? loc("inventory/backpack")
      : loc("inventory/toMyItems")
    if (inventoryToMove != null) {
      additionalText = $" {loc("move/to", { inventory = colorize(InfoTextValueColor, name) })}"
      if (!showSuitableAmmo)
        locId = "item/action/moveSomeToInventoryShort"
    }
  }
  let countToUse = isBoxedItem ? ammoCount : max(count, resItems.len())
  if (countToUse == 1 && !showSuitableAmmo)
    locId = inventoriesList == null ? "item/action/moveOneItemToInventory" : "item/action/moveOneItemToInventoryShort"
  return { locId, additionalText, icon = "context_icons/drag_in.svg" }
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

let stackCountOf = @(item) (item?.isBoxedItem ?? false) ? (item?.countPerStack ?? 1) : 1
let totalCountOf = @(item) (item?.isBoxedItem ?? false) ? (item?.ammoCount ?? 1) : (item?.count ?? 1)

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
  else if (item?.isHealkit || (item?.isUsable ?? false) || item?.itemType == "grenade" || item?.itemProto == "cortical_vault")
    ecs.g_entity_mgr.sendEvent(item.eid, TryUseItem({userEid = controlledHeroEid.get(), targetEid=controlledHeroEid.get()}))
}

function canUseItem(item) {
  if (actionForbiddenDueToQueueState(item))
    return false
  let { isHealkit = false, isUsable = false, itemType = "", itemProto = "" } = item
  return (isHealkit || isUsable || itemType == "grenade" || itemProto == "cortical_vault")
    && check_item_can_be_used(controlledHeroEid.get(), item.eid)
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
  if (!item?.itemTemplate || item.itemTemplate == "" || item?.isDefaultStubItem)
    return false

  if ((item?.slotName.contains("signal_grenade") || item?.slotName.contains("safepack")) && isInBattleState.get())
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

function getQuickRefineItemInfo(_item) {
  let isRefinerEnabled = (playerBaseState.get()?.openedAMCleaningDevices ?? 0) > 0
  let locId = isRefinerEnabled ? "inventory/refineItemsTitle" : "inventory/destroyItems"
  let icon = isRefinerEnabled ? "context_icons/drop_out_2.svg" : "context_icons/trash.svg"
  return { locId, icon }
}

let itemContainerItemsQuery = ecs.SqQuery("itemContainerItemsQuery", {
  comps_ro = [["itemContainer", ecs.TYPE_EID_LIST, null]]
})

let canInspectItem = function(item) {
  if (item?.eid == null)
    return false
  local itemsInside = null
  itemContainerItemsQuery.perform(item.eid, function(_eid, comps) {
    itemsInside = comps.itemContainer
  })
  return itemsInside != null && itemsInside.getAll().len() > 0
}

let canDropAllFromContainer = @(item) canInspectItem(item) && !actionForbiddenDueToQueueState(item)

let showChangeWeapon = function(item) {
  return item?.itemTemplate != null && !(item?.isCurrent ?? false)
}
let chooseWeaponAction = @(weapon) choose_weapon(weapon.currentWeaponSlotName)
let unloadWeaponAmmoAction = @(weapon) unloadAmmoAction(weapon, weapon.currentWeaponSlotName)
function showUnloadWeaponAction(weapon) {
  let { mods = null, curAmmo = 0, gunBoxedAmmoTemplate = "" } = weapon
  let magazine = mods?.magazine
  let canUnload = curAmmo == 1
  return canUnload && magazine != null && curAmmo > 0 && gunBoxedAmmoTemplate != ""
}

let isStackSplitEquipToHeroPossible = @(item) canSplitStack(item) && (getInventoryToMove(item, [HERO_ITEM_CONTAINER])!=null)
let isStackSplitEquipToBackpackPossible = @(item) canSplitStack(item) && (getInventoryToMove(item, [BACKPACK0])!=null)

let showSplitStackToHero = @(item) openSplitStacksWindow(item, @(count) moveItemToInventory(item, HERO_ITEM_CONTAINER, count))
let showSplitStackToBackpack = @(item) openSplitStacksWindow(item, @(count) moveItemToInventory(item, BACKPACK0, count))

function showSplitStackToGround(item) {
  if (isOnPlayerBase.get())
    openSplitStacksWindow(item, @(count) moveItemToInventory(item, STASH, count))
  else
    openSplitStacksWindow(item, @(count) moveItemToInventory(item, GROUND, count))
}

function showSplitStackToInventory(item, showSuitableAmmo = false, inventoriesList = null) {
  let { itemTemplate, inventoryEid = 0, boxedItemTemplate = null, ammo = null } = item
  local inventoryToMove = inventoryEid == backpackEid.get() ? BACKPACK0
    : inventoryEid == safepackEid.get() ? SAFEPACK
    : HERO_ITEM_CONTAINER
  let itemToSearch = showSuitableAmmo
    ? ammo != null ? ammo?.template : boxedItemTemplate
    : itemTemplate
  let itemsInStash = stashItems.get()
    .filter(@(v) v?.itemTemplate != null && v.itemTemplate == itemToSearch)
  let itemInStash = mergeNonUniqueItems(itemsInStash)?[0].__merge({ count = itemsInStash.len() })
  let { isBoxedItem = false, ammoCount = -1, count = -1 } = itemInStash
  if (inventoriesList != null && itemInStash?.itemTemplate != null) {
    let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(itemInStash.itemTemplate)
    let volume = template?.getCompValNullable("item__volume") ?? 0
    inventoryToMove = findInventoryWithFreeVolume(volume)?.data
  }
  if (inventoryToMove == null)
    return null
  let countToUse = isBoxedItem ? ammoCount : count
  if (countToUse == 1 && itemsInStash.len() == 1)
    moveItemToInventory(itemInStash, inventoryToMove, countToUse)
  else
    openSplitStacksWindow(itemInStash, function(countToMove) {
      if (itemsInStash.len() == 1) {
        moveItemToInventory(itemInStash, inventoryToMove, countToMove)
        return
      }
      let list = itemsInStash.sort(@(a, b) (b?.charges ?? 0) <=> (a?.charges ?? 0))
      for (local i = 0; i <= countToMove - 1; i++) {
        moveItemToInventory(list[i], inventoryToMove, 1)
      }
    })
}

let dropItemAway = function(item) {
  let count = item?.isBoxedItem ? item.countPerStack : 1
  if (!isOnPlayerBase.get())
    moveItemToInventory(item, GROUND, count)
  else
    moveItemToInventory(item, STASH, count)
}

let openItemShowroom = function(item) {
  inventoryShowroomItem.set(item)
  ecs.g_entity_mgr.broadcastEvent(CmdShowUiMenu({menuName = WEAPON_SHOWROOM_MENU_ID}))
}

let needOpenWeaponShowroomAction = function(item) {
  return isOnPlayerBase.get() && item?.isWeapon && !inShootingRange.get()
}

let needOpenItemShowroomAction = function(item) {
  if (needOpenWeaponShowroomAction(item))
    return false
  return isOnPlayerBase.get() && item?.itemTemplate
}

function needShowMagazineStopAction(item) {
  let { boxedItemTemplate = "", charges = 0, isDelayedMoveMod = false, eid = ecs.INVALID_ENTITY_ID } = item
  let isMagazineTypeHolder = boxedItemTemplate != ""

  let inspectingAmmoCountItemEid = getInspectingAmmoCountInfo(inspectingAmmoCountAffectEid.get())[0]
  return isMagazineTypeHolder
    && !isSpectator.get()
    && charges > 0
    && !isDelayedMoveMod
    && inspectingAmmoCountItemEid != eid
    && entityToUse.get() == eid
}

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
  getCustomData = moveAwayStackToStashOrGround
  action = showSplitStackToGround
}

let actionShowSplitStackToInventory  = {
  needToShow = canAddSplitStackToInventory
  getCustomData = showSplitStackOrJustMoveToInventory
  action = showSplitStackToInventory
}

let actionShowSuitableAmmoToInvenory  = {
  needToShow = @(item) canAddSplitStackToInventory(item, true)
  getCustomData = @(item) showSplitStackOrJustMoveToInventory(item, true)
  action = @(item) showSplitStackToInventory(item, true)
}

let actionShowSplitStackToSuitableInventory  = {
  needToShow = @(item) canAddSplitStackToInventory(item, false, inventories)
  getCustomData = @(item) showSplitStackOrJustMoveToInventory(item, false, inventories)
  action = @(item) showSplitStackToInventory(item, false, inventories)
}

let actionShowSuitableAmmoToSuitableInvenory  = {
  needToShow = @(item) canAddSplitStackToInventory(item, true, inventories)
  getCustomData = @(item) showSplitStackOrJustMoveToInventory(item, true, inventories)
  action = @(item) showSplitStackToInventory(item, true, inventories)
}

let actionDropItemOnGround  = {
  getCustomData = moveAwayToStashOrGround
  action = dropItemAway
  needToShow = @(item) !queueStatusBlockedItem(item)
}

let actionEquipOrInventoryOrBackpack = {
  needToShow = @(item) !queueStatusBlockedItem(item)
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
  needToShow = canDropAllFromContainer
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

let actionStopLoadUnloadAmmo = {
  locId = "Inventory/stop_ammo_action"
  needToShow = needShowMagazineStopAction
  action = @(_item) stopLoadUnloadAmmoClick()
  icon = "context_icons/stop.svg"
}

let actionLoadAmmo = {
  needToShow = canItemBeLoad
  getCustomData = getLoadItemInfo
  action = loadAmmoClick
  icon = "context_icons/ammo_yes.svg"
  getEnabled = loadIsEnabled
}

let actionUnloadAmmo = {
  needToShow = canItemBeUnload
  getCustomData = getUnloadItemInfo
  action = unloadAmmoClick
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

let quickRefineGamepadAction = {
  action = @(item) moveItemWithKeyboardMode(item, REFINER)
  getCustomData = getQuickRefineItemInfo
  needToShow = @(_item) isOnPlayerBase.get()
    && isGamepad.get()
    && !isOnboarding.get()
}

function tryUseSignalGrenade(item) {
  if (item?.eid)
    ecs.g_entity_mgr.sendEvent(item.eid, TryUseItem({userEid = controlledHeroEid.get(), targetEid=controlledHeroEid.get()}))
}

let useSignalGrenade = {
  locId = "Inventory/useSignalGrenade"
  action = tryUseSignalGrenade
  needToShow = @(item) item?.slotName == "signal_grenade" && item?.itemTemplate
}

let actionOpenWeaponInShowroom = {
  locId = "item/action/actionOpenWeaponInShowroom"
  action = openItemShowroom
  needToShow = needOpenWeaponShowroomAction
  icon = "context_icons/weapon_showroom.svg"
}

let actionOpenItemInShowroom = {
  locId = "item/action/inspect"
  action = openItemShowroom
  needToShow = needOpenItemShowroomAction
  icon = "context_icons/look.svg"
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
    actionOpenWeaponInShowroom
    actionOpenItemInShowroom
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
    quickRefineGamepadAction
    actionOpenWeaponInShowroom
    actionOpenItemInShowroom
  ],
  [BACKPACK0.name] = [
    actionUse
    actionStopLoadUnloadAmmo
    actionCheckMagazineAmmo
    actionFastEquip
    {
      getCustomData = getPickUpToEquipOrHeroInventory
      action = pickUpToEquipOrHeroInventory
    }
    actionShowSplitStackHero
    actionInspectContaner
    actionDropAllFromContaner
    actionLoadAmmo
    actionUnloadAmmo
    actionToMarket
    repairItemAction
    actionShowSuitableAmmoToInvenory
    actionShowSplitStackToInventory
    actionDropItemOnGround
    actionShowSplitStackGround
    quickRefineGamepadAction
    actionOpenWeaponInShowroom
    actionOpenItemInShowroom
  ],
  [HERO_ITEM_CONTAINER.name] = [
    actionUse
    actionStopLoadUnloadAmmo
    actionCheckMagazineAmmo
    actionFastEquip
    {
      getCustomData = getPickUpToEquipOrBackpack
      action = pickUpToEquipOrBackpack
    }
    actionShowSplitStackBackpack
    actionInspectContaner
    actionDropAllFromContaner
    actionLoadAmmo
    actionUnloadAmmo
    actionToMarket
    repairItemAction
    actionShowSuitableAmmoToInvenory
    actionShowSplitStackToInventory
    actionDropItemOnGround
    actionShowSplitStackGround
    quickRefineGamepadAction
    actionOpenWeaponInShowroom
    actionOpenItemInShowroom
  ],
  [SAFEPACK.name] = [
    actionUse
    actionStopLoadUnloadAmmo
    actionCheckMagazineAmmo
    actionFastEquip
    {
      getCustomData = getPickUpToEquipOrBackpack
      action = pickUpToEquipOrBackpack
    }
    actionShowSplitStackBackpack
    actionInspectContaner
    actionLoadAmmo
    actionUnloadAmmo
    actionToMarket
    repairItemAction
    actionShowSuitableAmmoToInvenory
    actionShowSplitStackToInventory
    actionDropItemOnGround
    actionShowSplitStackGround
    actionOpenWeaponInShowroom
    actionOpenItemInShowroom
  ],
  [POCKETS.name] = [
    actionUse
    fastUnequipItemAction
    actionStopLoadUnloadAmmo
    actionLoadAmmo
    actionUnloadAmmo
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
    useSignalGrenade
  ],
  [WEAPON.name] = [
    {
      locId = "weapon/action/switch"
      needToShow = showChangeWeapon
      action = chooseWeaponAction
      icon = "context_icons/equip.svg"
    }
    actionShowSuitableAmmoToSuitableInvenory
    fastUnequipItemAction
    {
      locId = "Inventory/unload_bullet_from_barrel"
      needToShow = showUnloadWeaponAction
      action = unloadWeaponAmmoAction
      icon = "context_icons/barrel.svg"
    }
    actionToMarketForSlot
    actionOpenWeaponInShowroom
  ],
  [WEAPON_MOD.name] = [
    actionShowSplitStackToSuitableInventory
    actionShowSuitableAmmoToSuitableInvenory
    fastUnequipItemAction
    actionToMarketForSlot
    actionLoadAmmo
  ],
  [REFINER.name] = [
    {
      locId = "inventory/removeFromRefiner"
      action = @(item) removeFromRefiner(item, item?.isBoxedItem ? item.countPerStack : 1)
      icon = "context_icons/drag_out.svg"
    }
    actionToMarket
  ],
  [REFINER_STASH.name] = [
    {
      locId = "inventory/dropToRefiner"
      action = @(item) dropToRefiner(item, item?.fromList, item?.isBoxedItem ? item.countPerStack : 1)
      icon = "context_icons/drag_in.svg"
    }
    actionToMarket
  ],
  [REFINER_ON_PLAYER.name] = [
    {
      locId = "inventory/dropToRefiner"
      action = @(item) dropToRefiner(item, item?.fromList, item?.isBoxedItem ? item.countPerStack : 1)
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
  ]
})

function mkContextMenuRow(rowData, item, event, idx) {
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
  let activeBtn = gamepadImgByKey.mkImageCompByDargKey(JB.A,
    { height = sub_txt.fontSize, hplace = ALIGN_RIGHT, vplace = ALIGN_CENTER})
  let stateFlags = Watched(0)
  return button({
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    gap = flex()
    valign = ALIGN_CENTER
    children = [
      {
        size = FLEX_H
        flow = FLOW_HORIZONTAL
        gap = static hdpx(4)
        valign = ALIGN_CENTER
        children = [
          iconToUse == null ? { size = iconHeight } : {
            rendObj = ROBJ_IMAGE
            size = iconHeight
            image = Picture($"ui/skin#{iconToUse}:{iconHeight}:{iconHeight}:P")
          }
          mkTextArea($"{loc(locIdToUse)}{additionalText}", { color = castomData?.color ?? TextNormal })
        ]
      }
      @() {
        watch = [isGamepad, stateFlags]
        children = isGamepad.get() && (stateFlags.get() & S_HOVER) ? activeBtn : null
      }
    ]
  }, function() {
    removeModalPopup(CONTEXT_MENU_WND_UID)
    contextHoveredData.set(null)
    if (needOnclickEventData)
      action(item, event)
    else
      action(item)
  }, {
    size = FLEX_H
    halign = ALIGN_CENTER
    padding = static [hdpx(4), hdpx(6)]
    borderWidth = 0
    isEnabled
    stateFlags
    key = $"context_menu_{idx}"
  })
}

let noActionsRow = {
  locId = "action/noAction"
  icon = "context_icons/cross.svg"
}

function mkDummyContextMenuRow(rowData) {
  let { icon, locId } = rowData
  return button({
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    gap = hdpx(4)
    valign = ALIGN_CENTER
    children = [
      {
        rendObj = ROBJ_IMAGE
        size = iconHeight
        image = Picture($"ui/skin#{icon}:{0}:{0}:P".subst(iconHeight))
      }
      mkText(loc(locId), {
        size = FLEX_H
      })
    ]
  }, function() {
    removeModalPopup(CONTEXT_MENU_WND_UID)
    contextHoveredData.set(null)
  }, static {
    size = FLEX_H
    halign = ALIGN_CENTER
    padding = static [hdpx(4), hdpx(6)]
    borderWidth = 0
  })
}

function getPurchaseItem(item, playerStat, trial) {
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
  if (!isLotAvailable(marketItem, playerStat, trial))
    return null
  if (attachments.len() > 0)
    reqMoney += getWeaponModsPrice(marketItem, attachments, playerStat, trial)
  return { reqMoney, lot }
}

function directPurchase(item, id, itemsToPurchase, canPurchase) {
  if (canPurchase) {
    let missingVolume = checkInventoryVolume([item])
    if (missingVolume > 0) {
      showNoEnoughStashSpaceMsgbox(missingVolume)
      return
    }
    eventbus_send("profile_server.buyLots", [ { id, count = itemsToPurchase, usePremium = false } ])
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
  let trial = trialData.get()
  
  let funcList = []
  if (previewPreset.get() != null) {
    let { lot = null, reqMoney = 0 } = getPurchaseItem(item, playerStat, trial)
    let { countPerStack = 1, noSuitableItemForPresetFoundCount = 0 } = item
    if (noSuitableItemForPresetFoundCount != null) {
      let itemsToPurchase = countPerStack > 1 ?
      ceil(noSuitableItemForPresetFoundCount.tofloat() / countPerStack.tofloat()) :
      noSuitableItemForPresetFoundCount
      if (lot != null && reqMoney > 0)
        funcList.append(mkContextMenuRow(
          mkPurchaseItemActionData(lot, reqMoney * itemsToPurchase, itemsToPurchase, playerProfileCreditsCount.get() >= reqMoney),
            item, event, funcList.len()))
    }
  }
  else {
    foreach (data in contextMenuActionsByListType?[listTypeName] ?? []) {
      let row = mkContextMenuRow(data, item, event, funcList.len())
      if (row != null)
        funcList.append(row)
    }
  }
  if (funcList.len() == 0)
    funcList.append(mkDummyContextMenuRow(noActionsRow))

  let cursorPos = get_mouse_cursor_pos()
  addModalPopup([cursorPos.x, cursorPos.y + 1], {
    size = static [hdpx(320), SIZE_TO_CONTENT]
    uid = CONTEXT_MENU_WND_UID
    flow = FLOW_VERTICAL
    popupValign = ALIGN_TOP
    padding = 0
    moveDuraton = 0
    onDetach = @() contextHoveredData.set(null)
    onAttach = @() isGamepad.get() ? move_mouse_cursor("context_menu_0", false) : null
    children = funcList
  })
}

function checkIsAvaliableDuringRaidSearch(list, folowFunc) {
  if (!isListMutableDueQueue(list)) {
    if (mutationForbidenDueToInQueueState.get()) {
      if (selfMemberState.get()?.ready)
        showMsgbox({ text = loc("inventory/cannotPutToContainerDuringReady") })
      else
        showMsgbox({ text = loc("inventory/cannotPutToContainerDuringSearch") })
      return
    }
  }
  folowFunc()
}




let inventoryItemClickActions = freeze({
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
    lmbAction = @(item) checkIsAvaliableDuringRaidSearch(BACKPACK0, @() pickUpToEquipOrHeroInventory(item, stackCountOf(item)))
    lmbShiftAction = @(item) checkIsAvaliableDuringRaidSearch(BACKPACK0, @() pickUpToEquipOrHeroInventory(item, totalCountOf(item)))
    lmbAltAction = @(item) checkIsAvaliableDuringRaidSearch(BACKPACK0, @() moveToStashOnBase(item))
    rmbAction = @(item, event) showItemContextMenu(item, BACKPACK0.name, event)
  },
  [HERO_ITEM_CONTAINER.name] = {   
    lmbAction = @(item) checkIsAvaliableDuringRaidSearch(HERO_ITEM_CONTAINER, @() pickUpToEquipOrBackpack(item, stackCountOf(item)))
    lmbShiftAction = @(item) checkIsAvaliableDuringRaidSearch(HERO_ITEM_CONTAINER, @() pickUpToEquipOrBackpack(item, totalCountOf(item)))
    lmbAltAction = @(item) checkIsAvaliableDuringRaidSearch(HERO_ITEM_CONTAINER, @() moveToStashOnBase(item))
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
    lmbAltAction = @(item) checkIsAvaliableDuringRaidSearch(HERO_ITEM_CONTAINER, @() moveToStashOnBase(item))
  },
  [REFINER.name] = {
    lmbAction = @(item) removeFromRefiner(item, item?.isBoxedItem ? item.countPerStack : 1)
    lmbShiftAction = @(item) removeFromRefiner(item, item?.isBoxedItem ? item.ammoCount : item.eids.len())
    rmbAction = @(item, event) showItemContextMenu(item, REFINER.name, event)
  },
  [REFINER_ON_PLAYER.name] = {
    rmbAction = @(item, event) showItemContextMenu(item, REFINER_ON_PLAYER.name, event)
    lmbAction = @(item) dropToRefiner(item, REFINER_ON_PLAYER, item?.isBoxedItem ? item.countPerStack : 1)
    lmbShiftAction = @(item) dropToRefiner(item, REFINER_ON_PLAYER, item?.isBoxedItem ? item.ammoCount : item.eids.len())
  },
  [REFINER_STASH.name] = {
    rmbAction = @(item, event) showItemContextMenu(item, REFINER_ON_PLAYER.name, event)
    lmbAction = @(item) dropToRefiner(item, REFINER_STASH, item?.isBoxedItem ? item.countPerStack : 1)
    lmbShiftAction = @(item) dropToRefiner(item, REFINER_STASH, item?.isBoxedItem ? item.ammoCount : item.eids.len())
  },
  [WORKBENCH.name] = { rmbAction = @(item, _event) showItemContextMenu(item, WORKBENCH.name) },
  [WORKBENCH_STASH.name] = { rmbAction = @(item, _event) showItemContextMenu(item, WORKBENCH_STASH.name) },
  [WORKBENCH_ITEMS_ON_PLAYER.name] = { rmbAction = @(item, _event) showItemContextMenu(item, WORKBENCH_ITEMS_ON_PLAYER.name) }
})

return freeze({
  fastEquipItem
  moveItemToInventory
  moveItemWithKeyboardMode
  inventoryItemClickActions
  CONTEXT_MENU_WND_UID
})
