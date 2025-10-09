from "%ui/components/colors.nut" import BtnBgHover, BtnBdHover, BtnBgTransparent, ItemBgColor,
  ItemBdColor, noItemContainerBg
from "%ui/hud/menus/components/inventoryItem.nut" import chargesIndicator, corruptedItemImageBackground, addStorageType, mkStorageIcon
from "das.inventory" import is_item_inventory_move_blocked, is_item_pickup_blocked, is_on_equip_equipment_prev_can_fit, notify_equip_in_occupied_slot_failed,
  is_equip_to_slot_cause_inventory_overflow, is_equip_to_slot_cause_from_pocket_drop, move_item_from_ground_to_slot, move_item_from_inventory_to_slot,
  is_on_equip_equipment_mod_prev_can_fit, install_equipment_mod_to_slot
from "%ui/hud/menus/components/inventoryItemUtils.nut" import mergeNonUniqueItems, needShowQuickSlotPurchase, purchaseItemsToSlot,
  mkNoVolumeLog
from "math" import ceil
import "%ui/hud/menus/components/dropMarker.nut" as dropMarker
from "%ui/hud/state/equipment.nut" import getEquipmentModSlots, isEquipmentHasSlot
from "%ui/hud/menus/components/inventoryItemTooltip.nut" import buildInventoryItemTooltip
from "string" import startswith
from "%ui/hud/menus/components/inventoryItemImages.nut" import inventoryItemImage
from "%ui/components/cursors.nut" import setTooltip
from "%ui/components/msgbox.nut" import showMsgbox
from "%dngscripts/sound_system.nut" import sound_play
from "%ui/hud/menus/components/itemFromTemplate.nut" import getSlotFromTemplate
from "%ui/hud/state/inventory_eids_common.nut" import getInventoryEidByListType
from "%ui/mainMenu/currencyIcons.nut" import creditsIcon
from "%ui/hud/menus/components/inventoryItemsList.nut" import inventoryItemSorting
from "%ui/components/chocolateWnd.nut" import openChocolateWnd
from "%ui/hud/menus/components/inventoryItemRarity.nut" import mkRarityIconByItem
from "%ui/mainMenu/raid_preparation_window_state.nut" import mkWarningSign
from "%ui/mainMenu/market/inventoryToMarket.nut" import getItemPriceToShow, mkItemPrice
from "%ui/hud/state/entity_use_state.nut" import calcItemUseProgress
from "%ui/hud/menus/components/inventoryItemNexusPointPriceComp.nut" import nexusPointsCostComp
from "%ui/equipPresets/presetsState.nut" import previewPreset
from "%ui/state/allItems.nut" import allItems, stashVolume, stashMaxVolume
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
from "%ui/mainMenu/raid_preparation_window_state.nut" import getNexusStashItemsForChocolateMenu
from "%ui/popup/player_event_log.nut" import addPlayerLog

let { allCraftRecipes, marketItems, playerStats } = require("%ui/profile/profileState.nut")
let { focusedData, draggedData, isAltPressed, mutationForbidenDueToInQueueState } = require("%ui/hud/state/inventory_state.nut")
let { isSpectator } = require("%ui/hud/state/spectator_state.nut")
let { equipment } = require("%ui/hud/state/equipment.nut")
let { inventoryImageParams } = require("%ui/hud/menus/components/inventoryItemImages.nut")
let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")
let { canModifyInventory } = require("%ui/hud/state/inventory_common_es.nut")
let { GROUND, STASH, REFINER } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { isInPlayerSession } = require("%ui/hud/state/gametype_state.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { backpackItems, stashItems, inventoryItems, safepackItems } = require("%ui/hud/state/inventory_items_es.nut")
let { hoverHotkeysWatchedList } = require("%ui/components/pcHoverHotkeyHitns.nut")
let { hoverPcHotkeysPresentation } = require("%ui/hud/menus/components/inventoryActionsHints.nut")
let { slotsWithWarning, mintEditState } = require("%ui/mainMenu/raid_preparation_window_state.nut")
let { curTime } = require("%ui/hud/state/time_state.nut")
let { entityToUse } = require("%ui/hud/state/entity_use_state.nut")

let modFillDragColor = ItemBgColor
let modBorderColor = ItemBdColor
let modFillColor = BtnBgTransparent

function mkSuitPartModsPanel(slotsArray, halign = ALIGN_CENTER) {
  let itemsInRow = 2
  let modRows = ceil(slotsArray.len() / itemsInRow)

  if (modRows <= 1) {
    return {
      size = SIZE_TO_CONTENT
      flow = FLOW_HORIZONTAL
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      gap = -hdpx(1)
      children = slotsArray
    }
  }
  else {
    return {
      flow = FLOW_VERTICAL
      gap = hdpx(5)
      halign
      children = [
        {
          flow = FLOW_HORIZONTAL
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          gap = hdpx(5)
          children = slotsArray.slice(0, itemsInRow)
        }
        {
          flow = FLOW_HORIZONTAL
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          gap = hdpx(5)
          children = slotsArray.slice(itemsInRow)
        }
      ]
    }
  }
}

function getInventoryOverflowOnSwapLoc() {
  if (isInPlayerSession.get())
    return loc("consoleMessage/inventory_overflow_on_swap_drop_items_on_ground")
  return loc("consoleMessage/inventory_overflow_on_swap_drop_items_to_stash")
}

function showInventoryOverflowOnSwapToGroundMsgBox(item_eid, item_slot) {
  showMsgbox({ text = getInventoryOverflowOnSwapLoc(), buttons = [
    { text = "Yes",
      isCurrent = true,
      action=function() { move_item_from_ground_to_slot(item_eid, item_slot) }}
    { text = "No", isCancel = true }
  ]})
}

function showInventoryOverflowOnSwapToExMsgBox(item_eid, from_inventory_eid, item_slot) {
  showMsgbox({ text = getInventoryOverflowOnSwapLoc(), buttons = [
    { text = "Yes",
      isCurrent = true,
      action=function() {
        if (from_inventory_eid == ecs.INVALID_ENTITY_ID)
          move_item_from_ground_to_slot(item_eid, item_slot)
        else
          move_item_from_inventory_to_slot(item_eid, from_inventory_eid, item_slot)
      }}
    { text = "No", isCancel = true }
  ]})
}

function dropEquipmentModToSlot(item, slot) {
  let itemEid = item?.eid ?? ecs.INVALID_ENTITY_ID
  let equipmentEid = slot?.attachedToEquipment ?? ecs.INVALID_ENTITY_ID
  let slotName = slot.slotName

  if (!is_on_equip_equipment_mod_prev_can_fit(itemEid, slotName, equipmentEid, item?.inventoryEid ?? ecs.INVALID_ENTITY_ID)) {
    notify_equip_in_occupied_slot_failed(item?.inventoryEid ?? ecs.INVALID_ENTITY_ID)
    return
  }

  install_equipment_mod_to_slot(itemEid, item?.inventoryEid ?? ecs.INVALID_ENTITY_ID, slotName, equipmentEid)
}

function dropEquipmentToSlot(item, slot) {
  let slot_name = slot?.slotName
  if ( slot_name &&
      !is_on_equip_equipment_prev_can_fit(item.eid, slot_name, item?.inventoryEid ?? ecs.INVALID_ENTITY_ID) &&
      (item?.inventoryExtension ?? 0) == 0 &&
      (equipment.get()[slot_name]?.inventoryExtension ?? 0) == 0) {
    notify_equip_in_occupied_slot_failed(item?.inventoryEid ?? ecs.INVALID_ENTITY_ID)
    return
  }

  let isOverflow = (is_equip_to_slot_cause_inventory_overflow(item.eid, slot_name, (item?.inventoryEid ?? ecs.INVALID_ENTITY_ID)) ||
                    is_equip_to_slot_cause_from_pocket_drop(item.eid, slot_name, (item?.inventoryEid ?? ecs.INVALID_ENTITY_ID)))

  if (item?.inventoryEid == null || item.inventoryEid == ecs.INVALID_ENTITY_ID) {
    
    if (isOverflow)
      showInventoryOverflowOnSwapToGroundMsgBox(item.eid, slot_name)
    else
      move_item_from_ground_to_slot(item?.eid ?? item.id, slot_name)
  }
  else {
    
    if (isOverflow)
      showInventoryOverflowOnSwapToExMsgBox(item.eid, item.inventoryEid == controlledHeroEid.get() ?
        getInventoryEidByListType(isInPlayerSession.get() ? GROUND : STASH) : item.inventoryEid, slot_name)
    else
      move_item_from_inventory_to_slot(item.eid, item.inventoryEid, slot_name)
  }
}

function canDropToEquipment(item, slot) {
  return ("equipmentSlots" in item
    && item.equipmentSlots.indexof(slot?.slotName) != null
    && slot?.slotName != item?.slotName)
}

function canDropToModSlot(item, slot) {
  let itemEid = item?.eid

  return canModifyInventory.get()
    && !is_item_inventory_move_blocked(itemEid)
    && !(item?.fromList == GROUND && is_item_pickup_blocked(itemEid))
    && slot?.allowed_items.findindex(@(v) v == item?.itemTemplate) != null
}

function canDropItemToSlot(item, slot) {
  if (item?.fromList.name == REFINER.name)
    return false
  if (slot?.slotTemplateName && item?.slotTemplateName == slot?.slotTemplateName)
    return true
  return ( canDropToEquipment(item, slot) || canDropToModSlot(item, slot) )
}

function dropItemToSlot(item, slot) {
  if (mutationForbidenDueToInQueueState.get() || !canDropItemToSlot(item, slot))
    return
  if (slot?.slotTemplateName == "safepack_slot" && stashVolume.get() > stashMaxVolume.get()) {
    addPlayerLog(mkNoVolumeLog(loc("hint/equip_in_empty_slot_failed_capacity_exceeded")))
    return
  }
  if (slot?.attachedToEquipment == controlledHeroEid.get())
    dropEquipmentToSlot(item, slot)
  else
    dropEquipmentModToSlot(item, slot)
}

function findItemsForSlot(slot) {
  local sortedStash = []
  if (!isOnboarding.get())
    sortedStash = stashItems.get().sort(inventoryItemSorting)
  let sortedBackpack = backpackItems.get().sort(inventoryItemSorting)
  let sortedInventory = inventoryItems.get().sort(inventoryItemSorting)
  let sortedSafepack = safepackItems.get().sort(inventoryItemSorting)

  let it = [].extend(sortedInventory, sortedBackpack, sortedSafepack, sortedStash)
  let items = mergeNonUniqueItems(it)
    .filter(@(v) canDropItemToSlot(v, slot))
    .map(@(item) addStorageType(item, stashItems.get(), inventoryItems.get(), backpackItems.get(), safepackItems.get()))
  return items
}

let mkSlotWarning = @(slotName) function() {
  let watch = slotsWithWarning
  let { reason = null} = slotsWithWarning.get()?[slotName]
  if (reason == null)
    return { watch }
  return {
    watch
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    padding = hdpx(2)
    children = mkWarningSign($"inventory/{slotName}", reason)
  }
}

function mkPriceBlock(item, priceData) {
  let priceDataToUse = (priceData?.price ?? 0) > 0 ? priceData : getItemPriceToShow(item)
  let { price = 0 } = priceDataToUse
  if (price <= 0)
    return null
  return {
    hplace = ALIGN_RIGHT
    vplace = ALIGN_TOP
    pos = [-hdpx(1), hdpx(1)]
    children = mkItemPrice(priceDataToUse)
  }
}

function itemUseProgressComp(item) {
  let equipmentEid = item?.eid ?? ecs.INVALID_ENTITY_ID
  return function() {
    let showProgress = Computed(@() entityToUse.get() == equipmentEid && equipmentEid != ecs.INVALID_ENTITY_ID)
    let progressVal = showProgress.get() ? clamp(calcItemUseProgress(curTime.get()).tointeger(), 0, 100) : 0.0
    return {
      watch = showProgress ? [curTime, showProgress] : showProgress
      size = [pw(progressVal), pw(1) ]
      rendObj = ROBJ_SOLID
      color = Color(100,120,90,40)
      vplace = ALIGN_BOTTOM
      margin = fsh(0.1)
    }
  }
}

function mkEquipmentSlot(itemOrSlot, callbacks={}, itemIconParams=inventoryImageParams, list_type = null,
  isActionForbided = false, override = {}
) {
  let { itemTemplate = null, slotTooltip = null, borderless = false, isDragAndDropAvailable = true, isItemToPurchase = false,
    notInteractive = false, slotName = null, countKnown = true, itemStorage = null, noSuitableItemForPresetFoundCount = null
    marketPrice = -1, needTooltip = true, isStubItem = false, default_stub_item = null } = itemOrSlot

  let {
    canDrop = @(item) canDropItemToSlot(item, itemOrSlot), onDrop = @(item) dropItemToSlot(item, itemOrSlot)
    itemsForSlot = findItemsForSlot, rmbAction = null, lmbAltAction = null, onClick = @(_) null
  } = callbacks

  let hasItem = itemTemplate != null
  let itemTooltip = buildInventoryItemTooltip(itemOrSlot)
  let isUnloadable = !isDragAndDropAvailable

  let needDropMark = Computed(function() {
    if (draggedData.get() == null)
      return false
    else {
      return canDrop(draggedData.get())
    }
  })

  let onClickFunc = function(event) {
    if (mutationForbidenDueToInQueueState.get())
      return
    if (isActionForbided)
      return
    if (event.button == 1)
      rmbAction?(itemOrSlot, event)

    if (event.button == 0 && !isUnloadable && !isSpectator.get() && slotName != null) {
      if (isAltPressed.get() && lmbAltAction != null)
        lmbAltAction(itemOrSlot)
      else {
        local fittingItems = null
        if (!mintEditState.get())
          fittingItems = itemsForSlot(itemOrSlot)
        else {
          let openedRecipes = allCraftRecipes.get().filter(@(v) v?.isOpened)
          fittingItems = getNexusStashItemsForChocolateMenu(itemOrSlot, allItems.get(), openedRecipes, allCraftRecipes.get(),
            marketItems.get(), playerStats.get(), ["equipment", "medicines", "ammunition"])
              .filter(@(v) canDropItemToSlot(v, itemOrSlot))
              .sort(inventoryItemSorting)
        }
        if (previewPreset.get() && !mintEditState.get()) {
          if (previewPreset.get()?.presetIdx == "lastUsed")
            showMsgbox({ text = loc("playerPreset/cantChangeLastUsed") })
          else
            showMsgbox({ text = loc("playerPreset/rewritePresetToEdit") })
          return
        }
        openChocolateWnd({
          event,
          itemsDataArr = fittingItems,
          onClick = @(item, _actions) onDrop(item),
          itemInSlot = itemOrSlot
          shopData = mintEditState.get() ? null
            : needShowQuickSlotPurchase(itemOrSlot) ? purchaseItemsToSlot(itemOrSlot, event) : null
        })
      }
    }
    onClick(event)
  }

  let getFillColor = @(sf) isItemToPurchase ? BtnBgHover
    : noSuitableItemForPresetFoundCount ? noItemContainerBg
    : (sf & S_DRAG) ? modFillDragColor
    : (sf & S_HOVER) && isUnloadable ? BtnBgHover : modFillColor

  let needLowOpacity = default_stub_item || noSuitableItemForPresetFoundCount != null

  let stateFlags = Watched(0)
  return function() {
    let sf = stateFlags.get()
    return {
      watch = [stateFlags, needDropMark, mutationForbidenDueToInQueueState]
      onElemState = @(s) stateFlags.set(s)
      rendObj = ROBJ_BOX
      key = $"{itemOrSlot?.slotName}__{itemOrSlot?.slotTemplateName}"
      transform = {}
      fillColor = borderless ? 0 : getFillColor(sf)
      borderColor = (sf & S_HOVER) ? BtnBdHover : modBorderColor
      borderWidth = borderless ? 0 : hdpx(1)
      behavior = notInteractive ? null :
        !isSpectator.get() && !isActionForbided && isDragAndDropAvailable ? Behaviors.DragAndDrop : Behaviors.Button
      onClick = onClickFunc
      onDrop
      canDrop
      onHover = function(on) {
        callbacks?.onHover(on)
        if (!needTooltip)
          return

        if (on) {
          if (!hasItem && slotTooltip)
            setTooltip(loc(slotTooltip))
          else if (itemTooltip)
            setTooltip(itemTooltip)

          let pcHotkeysHints = isActionForbided ? null : hoverPcHotkeysPresentation?[list_type?.name]?(itemOrSlot)
          if (pcHotkeysHints)
            hoverHotkeysWatchedList.set(pcHotkeysHints)
          focusedData.set(itemOrSlot)
        }
        else {
          focusedData.set(null)
          setTooltip(null)
          hoverHotkeysWatchedList.set(null)
        }
      }
      onDragMode = function(on, item) {
        draggedData.set(on ? item : null)
        if (on)
          sound_play("ui_sounds/inventory_item_take")
      }
      dropData = !hasItem || isStubItem || mutationForbidenDueToInQueueState.get() || default_stub_item ? null : itemOrSlot.__merge({
        canDrop=true
        id=itemOrSlot?.itemPropsId
      })

      children = [
        itemOrSlot?.isCorrupted ? corruptedItemImageBackground : null
        !isItemToPurchase ? null : creditsIcon(hdpxi(40), {
          hplace = ALIGN_RIGHT
          pos = [-hdpx(2), -hdpx(25)]
        })
        inventoryItemImage(itemOrSlot, itemIconParams.__merge({ opacity = needLowOpacity ? 0.5 : 1 }))
        mkStorageIcon(itemStorage)
        mkRarityIconByItem(itemOrSlot)
        needDropMark.get() ? dropMarker(sf, mutationForbidenDueToInQueueState.get(), mutationForbidenDueToInQueueState.get() ? "" : null) : null
        default_stub_item ? null : chargesIndicator(
          itemOrSlot?.charges,
          itemOrSlot?.maxCharges,
          countKnown
        )
        hasItem ? null : mkSlotWarning(slotName)
        hasItem && (noSuitableItemForPresetFoundCount > 0 || marketPrice > 0)
          ? mkPriceBlock(itemOrSlot, marketPrice) : null
        itemUseProgressComp(itemOrSlot)
        nexusPointsCostComp(itemOrSlot?.nexusCost)
      ]
    }.__update(override)
  }
}

function mkSuitSlots(suit, part_name, list_type = null, custom_actions = {}, isActionForbided = false) {
  local modsData = []
  let suitModSlots = suit?.eid ? getEquipmentModSlots(suit) : null
  if (suitModSlots != null)
    foreach(key, value in suitModSlots)
      if (startswith(key, $"equipment_mod_{part_name}"))
        modsData.append(value)

  function mapModsData(modSlot){
    return mkEquipmentSlot(modSlot, custom_actions, inventoryImageParams, list_type, isActionForbided)
  }
  return modsData.map(mapModsData)
}

function mkSuitTemplatePreviewSlots(suitTemplateName, partName) {
  let suitTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(suitTemplateName)
  let slots = suitTemplate?.getCompValNullable("equipment_mods__slots")?.getAll() ?? []

  local modsData = []
  foreach(key, slotName in slots) {
    if (!startswith(key, $"equipment_mod_{partName}"))
      continue

    let fakeSlot = getSlotFromTemplate(slotName)

    modsData.append(fakeSlot.__update({
      canDrop = false
    }))
  }

  return modsData.map(@(slotData) mkEquipmentSlot(slotData, {}, inventoryImageParams))
}

return {
  mkSuitPartModsPanel
  mkSuitSlots
  mkSuitTemplatePreviewSlots
  isEquipmentHasSlot
  mkEquipmentSlot
  findItemsForSlot
}