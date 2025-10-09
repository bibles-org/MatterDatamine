from "%dngscripts/sound_system.nut" import sound_play

from "%sqstd/math.nut" import lerp, ceil, truncateToMultiple

from "dasevents" import RequestLoadItemHolder, RequestUnloadItemHolder, RequestInterruptUseItemHolder, RqCheckAmmoItemHolder,
  RqStopCheckAmmoItemHolder, sendNetEvent
from "das.inventory" import get_weapon_slot_for_item, get_equipped_item_for_installing_mod, is_inventory_have_free_volume, get_equipment_slot_for_item,
  get_slot_and_equipment_for_mod, unequip_weapon_from_slot, move_equipped_weapon_mod_to_inventory,
  move_stack_to_inventory, move_equipped_item_to_inventory, move_equipped_item_to_ground, move_equipped_equipment_mod_to_inventory
from "%ui/hud/menus/components/inventoryItemsListChecks.nut" import isHeroInventoryDropForbidden, isBackpackDropForbidder
from "%ui/hud/menus/components/inventoryItemsListChecksCommon.nut" import MoveForbidReason, showInventoryOverflowOnUnequipToExMsgBox

from "%ui/fonts_style.nut" import h2_txt
from "net" import get_sync_time
import "%ui/components/faComp.nut" as faComp
from "%ui/components/cursors.nut" import setTooltip
from "%ui/hud/state/inventory_item_relations.nut" import isItemForHolder
from "%ui/components/colors.nut" import Alert, Inactive, ItemIconBlocked
from "%ui/mainMenu/market/inventoryToMarket.nut" import getLotFromItem, isLotAvailable, getPriceFromLot
from "eventbus" import eventbus_send, eventbus_subscribe_onehit
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem
from "string" import startswith
from "%ui/components/msgbox.nut" import showMsgbox, showMessageWithContent
from "%ui/components/purchase_confirm_msgbox.nut" import showCurrencyPurchaseMsgBox, showNotEnoughPremiumMsgBox
from "%ui/mainMenu/marketMenu.nut" import setSectionToReturn
from "%ui/mainMenu/market/marketItems.nut" import weaponRelated
from "dagor.debug" import logerr
from "%ui/hud/state/item_info.nut" import get_item_info
from "%ui/hud/state/inventory_eids_common.nut" import getInventoryEidByListType
from "%ui/popup/player_event_log.nut" import addPlayerLog, mkPlayerLog, marketIconSize
from "%ui/mainMenu/stashSpaceMsgbox.nut" import showNoEnoughStashSpaceMsgbox
from "%ui/components/itemIconComponent.nut" import itemIconNoBorder
from "%ui/profile/profileState.nut" import playerProfilePremiumCredits, marketItems, repairRelativePrice,
  playerProfileCreditsCount, playerStats, trialData
from "%ui/hud/menus/components/inventoryItemTypes.nut" import HERO_ITEM_CONTAINER, BACKPACK0, STASH, GROUND, SAFEPACK

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")
let { entityToUse } = require("%ui/hud/state/entity_use_state.nut")
let { isSpectator } = require("%ui/hud/state/spectator_state.nut")
let { inventoryItems, stashItems, backpackItems } = require("%ui/hud/state/inventory_items_es.nut")
let { inspectingAmmoCountAffectEid } = require("%ui/hud/state/ammo_count_knowledge_state.nut")
let { selectedItem, selectedItemsCategory } = require("%ui/mainMenu/market/marketState.nut")
let { isOnPlayerBase, isInPlayerSession } = require("%ui/hud/state/gametype_state.nut")
let { inShootingRange } = require("%ui/hud/state/shooting_range_state.nut")
let { inventoryChecksByList } = require("%ui/hud/menus/components/inventoryItemsListChecks.nut")
let { curWeapon } = require("%ui/hud/state/hero_weapons.nut")
let { marketIsAvailable } = require("%ui/mainMenu/marketMenu.nut")
let { customFilter } = require("%ui/mainMenu/market/marketItems.nut")
let { currentMenuId } = require("%ui/hud/hud_menus_state.nut")
let { workbenchRepairInProgress, workbenchItemContainer } = require("%ui/hud/menus/inventories/workbenchInventory.nut")
let { backpackEid, safepackEid, backpackUniqueId, safepackUniqueId } = require("%ui/hud/state/hero_extra_inventories_state.nut")
let { stashEid, stashVolume, stashMaxVolume } = require("%ui/state/allItems.nut")
let { canModifyInventory } = require("%ui/hud/state/inventory_common_es.nut")
let { inventoryMaxVolume, inventoryCurrentVolume, mutationForbidenDueToInQueueState } = require("%ui/hud/state/inventory_state.nut")
let { REFINER_KEY_ITEM } = require("%ui/hud/menus/components/slotTypes.nut")
let { playerLogsColors } = require("%ui/popup/player_event_log.nut")
let { externalInventoryEid, externalInventoryContainerOwnerEid } = require("%ui/hud/state/hero_external_inventory_state.nut")

let loadUnloadAmmoPic = @(img) Picture($"ui/skin#{img}:{0}:{0}:P".subst(hdpxi(15)))
let BtnInactiveColor = Color(128, 128, 128)
let BtnActiveColor = Color(255, 255, 255)

let currentKeyItem = Watched(null)

function actionForbiddenDueToQueueState(item) {
  if (!mutationForbidenDueToInQueueState.get()) {
    return false
  }
  let itemInInventoryEid = item.inventoryEid

  return (
    itemInInventoryEid == safepackEid.get() ||
    itemInInventoryEid == backpackEid.get() ||
    itemInInventoryEid == controlledHeroEid.get() ||
    (
      itemInInventoryEid == externalInventoryEid.get() &&
      (
        externalInventoryContainerOwnerEid.get() == safepackEid.get() ||
        externalInventoryContainerOwnerEid.get() == backpackEid.get() ||
        externalInventoryContainerOwnerEid.get() == controlledHeroEid.get()
      )
    )
  )
}

function stopLoadUnloadAmmoClick(){
  sendNetEvent(controlledHeroEid.get(), RequestInterruptUseItemHolder())
}

function unloadAmmoClick(item){
  
  if (curWeapon.get()?.isReloading)
    return
  if ((item?.charges ?? 0) > 0) {
    let containerEid = item?.slotTemplateName == "pocket_slot" ? controlledHeroEid.get() : item.inventoryEid
    sendNetEvent(controlledHeroEid.get(), RequestUnloadItemHolder({targetItemEid=item.eid, containerEid}))
  }
  else
    ecs.g_entity_mgr.sendEvent(controlledHeroEid.get(), RqCheckAmmoItemHolder({targetItemEid=item.eid, containerEid=item.inventoryEid}))
}

function loadAmmoClick(item) {
  
  if (curWeapon.get()?.isReloading)
    return
  if ((item?.charges ?? 0) < item.maxCharges) {
    let containerEid = (item?.slotTemplateName == "pocket_slot" || item?.attachedItemModSlotName == "magazine") ? controlledHeroEid.get() : item.inventoryEid
    sendNetEvent(controlledHeroEid.get(), RequestLoadItemHolder({targetItemEid=item.eid, containerEid, searchOtherContainers = true}))
  }
  else
    ecs.g_entity_mgr.sendEvent(controlledHeroEid.get(), RqCheckAmmoItemHolder({targetItemEid=item.eid, containerEid=item.inventoryEid}))
}

function checkAmmoClick(item) {
  ecs.g_entity_mgr.sendEvent(controlledHeroEid.get(), RqCheckAmmoItemHolder({targetItemEid=item.eid, containerEid=item.inventoryEid}))
}

function stopCheckAmmoClick() {
  ecs.g_entity_mgr.sendEvent(controlledHeroEid.get(), RqStopCheckAmmoItemHolder())
}

let inspectingAmmoCountAffectQuery = ecs.SqQuery("inspectingAmmoCountAffectQuery", {
  comps_ro=[
    ["ammo_count_knowledge_inspecting__startTimestamp", ecs.TYPE_FLOAT],
    ["game_effect__timeToDestroy", ecs.TYPE_FLOAT],
    ["ammo_count_knowledge_inspecting__itemEid", ecs.TYPE_EID]
  ]
})

let getInspectingAmmoCountInfo = memoize(function(eid){
  if (eid == ecs.INVALID_ENTITY_ID) {
    return [ecs.INVALID_ENTITY_ID, 0.0, 0.0]
  }
  else {
    let comp = inspectingAmmoCountAffectQuery.perform(eid, @(_, comp) comp)
    return [comp.ammo_count_knowledge_inspecting__itemEid,
      comp.ammo_count_knowledge_inspecting__startTimestamp,
      comp.ammo_count_knowledge_inspecting__startTimestamp + comp.game_effect__timeToDestroy
    ]
  }
})


function mkUnloadAmmoButton(item, listType, unloadTooltipKey, unloadAmmoIcon) {
  let unloadBtnStateFlags = Watched(0)

  let isMagazineTypeHolder = (item?.boxedItemTemplate ?? "") != ""

  return function() {
    let inspectingAmmoCountItemEid = getInspectingAmmoCountInfo(inspectingAmmoCountAffectEid.get())[0]
    let showUnloadButton = isMagazineTypeHolder
                        && (listType == HERO_ITEM_CONTAINER || listType == BACKPACK0 || listType == STASH)
                        && !isSpectator.get()
                        && ((item?.charges ?? 0) > 0 || !(item?.countKnown ?? false)  )
                        && !(item?.isDelayedMoveMod ?? false)
                        && inspectingAmmoCountItemEid != item?.eid
                        && !curWeapon.get()?.isReloading
                        && (!item.canLoadOnlyOnBase || isOnPlayerBase.get())
    return {
      watch = [ unloadBtnStateFlags, entityToUse, inspectingAmmoCountAffectEid, curWeapon, isOnPlayerBase ]
      onClick = @() unloadAmmoClick(item)
      skipDirPadNav = true
      behavior = Behaviors.Button
      onElemState = @(s) unloadBtnStateFlags.set(s)
      onHover = @(on) setTooltip(on ? loc(unloadTooltipKey) : null)
      sound = {
        click  = "ui_sounds/button_click"
      }
      padding = hdpx(3)
      vplace = ALIGN_BOTTOM
      hplace = ALIGN_RIGHT
      children = showUnloadButton ? {
        children = entityToUse.get() == item.eid ? null : {
          rendObj = ROBJ_IMAGE
          image = loadUnloadAmmoPic(unloadAmmoIcon)
          size = hdpx(15)
          color = (unloadBtnStateFlags.get() & S_HOVER) ? BtnActiveColor : BtnInactiveColor
        }
      } : null
    }
  }
}

function canItemBeUnload(item) {
  if (actionForbiddenDueToQueueState(item))
    return false

  let { boxedItemTemplate = null, countKnown = false, isDelayedMoveMod = false,
    eid = ecs.INVALID_ENTITY_ID, charges = 0} = item

  let isMagazineTypeHolder = boxedItemTemplate != null
  let inspectingAmmoCountItemEid = getInspectingAmmoCountInfo(inspectingAmmoCountAffectEid.get())[0]
  let canBeUnload = isMagazineTypeHolder
    && !isSpectator.get()
    && (charges > 0 || !countKnown)
    && !isDelayedMoveMod
    && inspectingAmmoCountItemEid != eid
  return canBeUnload
}

function unloadIsEnabled(item) {
  let { canLoadOnlyOnBase = false } = item
  return (!canLoadOnlyOnBase || isOnPlayerBase.get())
}

function canItemBeLoad(item) {
  if (actionForbiddenDueToQueueState(item))
    return false

  let { boxedItemTemplate = null, countKnown = false, isDelayedMoveMod = false,
    eid = ecs.INVALID_ENTITY_ID, charges = 0, maxCharges = 0} = item

  let isMagazineTypeHolder = boxedItemTemplate != null
  let inspectingAmmoCountItemEid = getInspectingAmmoCountInfo(inspectingAmmoCountAffectEid.get())[0]
  let canBeLoad = isMagazineTypeHolder
    && !isSpectator.get()
    && (charges < maxCharges || !countKnown)
    && !isDelayedMoveMod
    && inspectingAmmoCountItemEid != eid
  return canBeLoad
}

function loadIsEnabled(item) {
  let { canLoadOnlyOnBase = false } = item
  return (!canLoadOnlyOnBase || isOnPlayerBase.get())
}

function mkLoadAmmoButton(item, listType, loadTooltipKey, loadAmmoIcon) {
  let loadBtnStateFlags = Watched(0)

  let isMagazineTypeHolder = (item?.boxedItemTemplate ?? "") != ""

  return function() {
    let inspectingAmmoCountItemEid = getInspectingAmmoCountInfo(inspectingAmmoCountAffectEid.get())[0]
    let showLoadButton = isMagazineTypeHolder
                      && (listType == HERO_ITEM_CONTAINER || listType == BACKPACK0 || listType == STASH)
                      && !isSpectator.get()
                      && ((item?.charges ?? 0) < item.maxCharges || !(item?.countKnown ?? false))
                      && !(item?.isDelayedMoveMod ?? false)
                      && inspectingAmmoCountItemEid != item?.eid
                      && !curWeapon.get()?.isReloading
                      && (!item.canLoadOnlyOnBase || isOnPlayerBase.get())
    let needWatched = showLoadButton && entityToUse.get() != item.eid
    let { isWeaponMod = false, isHealkit = false } = item
    let needHighlight = !needWatched ? null : Computed(@() (isWeaponMod || isHealkit) &&
                                  (inventoryItems.get().findindex(@(i) isItemForHolder(i, item)) != null ||
                                  backpackItems.get().findindex(@(i) isItemForHolder(i, item)) != null ||
                                  stashItems.get().findindex(@(i) isItemForHolder(i, item)) != null))

    return {
      watch = [ loadBtnStateFlags, entityToUse, needHighlight, inspectingAmmoCountAffectEid, curWeapon ]
      onClick =  @() loadAmmoClick(item)
      skipDirPadNav = true
      behavior = Behaviors.Button
      onElemState = @(s) loadBtnStateFlags.set(s)
      onHover = @(on) setTooltip(on ? loc(loadTooltipKey) : null)
      sound = {
        click  = "ui_sounds/button_click"
      }
      padding = hdpx(3)
      vplace = ALIGN_BOTTOM
      hplace = ALIGN_LEFT
      children = showLoadButton ? {
        children = (entityToUse.get() == item.eid) || ((needHighlight == null)) ? null : {
          rendObj = ROBJ_IMAGE
          image = loadUnloadAmmoPic(loadAmmoIcon)
          size = hdpx(15)
          color = (loadBtnStateFlags.get() & S_HOVER) ? BtnActiveColor : BtnInactiveColor
          animations = needHighlight.get() ? [{prop = AnimProp.color, from = Inactive, to = Alert, duration = 1.3, loop = true, play=true, easing = CosineFull}] : null
          key = needHighlight.get()
        }
      } : null
    }
  }
}


function mkStopLoadUnloadAmmoButton(item, listType) {
  let stopBtnStateFlags = Watched(0)
  let { boxedItemTemplate = "", charges = 0, isDelayedMoveMod = false, eid = ecs.INVALID_ENTITY_ID } = item
  let isMagazineTypeHolder = boxedItemTemplate != ""

  return function() {
    let inspectingAmmoCountItemEid = getInspectingAmmoCountInfo(inspectingAmmoCountAffectEid.get())[0]
    let showStopButton = isMagazineTypeHolder
                        && (listType == HERO_ITEM_CONTAINER || listType == BACKPACK0 || listType == STASH)
                        && !isSpectator.get()
                        && charges > 0
                        && !isDelayedMoveMod
                        && inspectingAmmoCountItemEid != eid
                        && entityToUse.get() == item.eid

    return {
      watch = [ stopBtnStateFlags, entityToUse, inspectingAmmoCountAffectEid ]
      onClick = @() stopLoadUnloadAmmoClick()
      behavior = Behaviors.Button
      skipDirPadNav = true
      onElemState = @(s) stopBtnStateFlags.set(s)
      onHover = @(on) setTooltip(on ? loc("Inventory/stop_ammo_action") : null)
      sound = {
        click  = "ui_sounds/button_click"
      }
      padding = hdpx(3)
      vplace = ALIGN_BOTTOM
      hplace = ALIGN_RIGHT
      children = !showStopButton ? null : faComp("close", {
        color = (stopBtnStateFlags.get() & S_HOVER) ? BtnActiveColor : BtnInactiveColor
        fontSize = hdpx(15)
      })
    }
  }
}

function canCheckAmmoInMagazine(item, isSpectating) {
  let { countKnown = false, isWeapon = false, isDelayedMoveMod = false, eid = ecs.INVALID_ENTITY_ID } = item
  let inspectingAmmoCountItemEid = getInspectingAmmoCountInfo(inspectingAmmoCountAffectEid.get())[0]
  return !isSpectating
    && !countKnown
    && !isWeapon
    && !isDelayedMoveMod
    && inspectingAmmoCountItemEid != eid
}


function mkCheckAmmoButton(item) {
  let checkAmmoBtnStateFlags = Watched(0)

  let checkAmmoTooltipKey = "Inventory/check_ammo"
  let checkAmmoIcon = "check_magazine.svg"

  return function() {
    let showCheckAmmoButton = canCheckAmmoInMagazine(item, isSpectator.get())
    return {
      watch = [isSpectator, checkAmmoBtnStateFlags, inspectingAmmoCountAffectEid ]
      onClick =  @() checkAmmoClick(item)
      skipDirPadNav = true
      behavior = Behaviors.Button
      margin = static [fsh(0.2), fsh(0.2), 0, 0]
      onElemState = @(s) checkAmmoBtnStateFlags.set(s)
      onHover = @(on) setTooltip(on ? loc(checkAmmoTooltipKey) : null)
      sound = {
        click  = "ui_sounds/button_click"
      }
      padding = hdpx(3)
      vplace = ALIGN_TOP
      hplace = ALIGN_RIGHT
      children = showCheckAmmoButton ? {
        children = (item?.eid == null || entityToUse.get() == item.eid) ? null : {
          rendObj = ROBJ_IMAGE
          image = loadUnloadAmmoPic(checkAmmoIcon)
          size = hdpx(15)
          color = (checkAmmoBtnStateFlags.get() & S_HOVER) ? BtnActiveColor : BtnInactiveColor
        }
      } : null
    }
  }
}

function mkStopCheckAmmoButton(item) {
  let stopCheckAmmoBtnStateFlags = Watched(0)

  return function() {
    let inspectingAmmoCountItemEid = getInspectingAmmoCountInfo(inspectingAmmoCountAffectEid.get())[0]
    let showStopCheckAmmoButton = (!isSpectator.get() &&
                                  (item?.eid ?? ecs.INVALID_ENTITY_ID) != ecs.INVALID_ENTITY_ID &&
                                  inspectingAmmoCountItemEid == item.eid)

    return {
      watch = [ stopCheckAmmoBtnStateFlags, inspectingAmmoCountAffectEid]
      onClick =  @() stopCheckAmmoClick()
      skipDirPadNav = true
      behavior = Behaviors.Button
      onElemState = @(s) stopCheckAmmoBtnStateFlags.set(s)
      onHover = @(on) setTooltip(on ? loc("Inventory/stop_ammo_action") : null)
      sound = {
        click  = "ui_sounds/button_click"
      }
      padding = hdpx(3)
      vplace = ALIGN_BOTTOM
      hplace = ALIGN_RIGHT
      children = showStopCheckAmmoButton ? faComp("close", {
        color = (stopCheckAmmoBtnStateFlags.get() & S_HOVER) ? BtnActiveColor : BtnInactiveColor
        fontSize = hdpx(15)
      }) : null
    }
  }
}

let getCheckAmmoProgress = @(ct, inspectingAmmoCountItemStartTimestamp, inspectingAmmoCountItemFinishTimestamp)
  lerp(inspectingAmmoCountItemStartTimestamp, inspectingAmmoCountItemFinishTimestamp, 0.0, 1.0, ct)

function mkItemCheckAmmoProgress(item) {
  return function() {
    let [inspectingAmmoCountItemEid, inspectingAmmoCountItemStartTimestamp, inspectingAmmoCountItemFinishTimestamp] = getInspectingAmmoCountInfo(inspectingAmmoCountAffectEid.get())
    let progressValNeeded = item?.eid != ecs.INVALID_ENTITY_ID &&
      (inspectingAmmoCountItemEid == item?.eid || item?.eids?.indexof(inspectingAmmoCountItemEid) != null)
    return {
      size = static [flex(), pw(1)]
      transform = {
        scale = [progressValNeeded ? getCheckAmmoProgress(get_sync_time(), inspectingAmmoCountItemStartTimestamp, inspectingAmmoCountItemFinishTimestamp) : 0.0, 1.0]
        pivot = [0, 0]
      }
      behavior = progressValNeeded ? Behaviors.RtPropUpdate : null
      key = progressValNeeded
      update = function(){
        return {
          transform = {
            scale = [getCheckAmmoProgress(get_sync_time(), inspectingAmmoCountItemStartTimestamp, inspectingAmmoCountItemFinishTimestamp), 1.0]
          }
        }
      }
      rendObj = ROBJ_SOLID
      color = Color(100, 120, 90, 40)
      vplace = ALIGN_BOTTOM
      margin = fsh(0.1)
      watch = inspectingAmmoCountAffectEid
    }
  }
}

function needShowMarketLink(item) {
  if (!marketIsAvailable.get())
    return false
  let { isWeapon = false, filterType = "" } = item
  let marketId = getLotFromItem(item)
  let canHaveRelatedItems = isWeapon || filterType == "ammunition" || filterType == "weapon_mods"
  return isOnPlayerBase.get()
    && filterType != "alters"
    && filterType != "chronogene"
    && (canHaveRelatedItems || marketId != 0)
}

function resSlotsFromAllowedItems(allowed_items) {
  return allowed_items
    .filter(@(tpl) !startswith(tpl, "damage"))
    .map(function(tpl) {
      let lot = getLotFromItem({ itemTemplate = tpl })
      let price = lot ? getPriceFromLot(lot) : null
      return (lot && price) ? lot : null
    })
    .filter(@(lot) lot != null)
    .reduce(@(acc, lot) acc.__update({ [lot] = true }), {})
}

let needShowMarketSlotLink = function(itemOrSlot) {
  return marketIsAvailable.get()
    && isOnPlayerBase.get() && !inShootingRange.get()
    && (getLotFromItem(itemOrSlot) != 0 || resSlotsFromAllowedItems(itemOrSlot?.allowed_items ?? []).len() > 0)
}

function showItemInMarket(item) {
  let marketId = getLotFromItem(item)
  let toShopAction = function() {
    selectedItemsCategory.set(null)  
    selectedItem.set(marketId)
    setSectionToReturn(currentMenuId.get())
    eventbus_send("hud_menus.open", static { id = "Market" })
  }
  toShopAction()
}

let weaponSlots = {
  primary = "weapon_0"
  secondary = "weapon_1"
  tertiary = "weapon_2"
  melee = "weapon_3"
}

let equipmentSlots = {
  pouch = "equipment_pouch"
  backpack = "equipment_backpack"
  safepack = "equipment_safepack"
  helmet = "equipment_helmet"
  flashlight = "equipment_flashlight"
  signal_grenade = "equipment_signal_grenade"
}

function showItemsForSlotInMarket(itemOrSlot) {
  let { allowed_items = [], itemTemplate = null, template = null, itemType = null, slotTooltip = null, itemName = null,
    currentWeaponSlotName = null, filterType = null, weapModSlotName = null, parentWeaponName = null,
    slotName = "inventory", uniqueId = "0", weapUniqueId = null, mods = {}
  } = itemOrSlot
  let templateToUse = itemTemplate ?? template
  let isEquipment = slotName in equipmentSlots
  if (allowed_items.len() <= 0 && !templateToUse)
    return

  local resLots = {}
  local itemToSelect = null
  if (itemType == "weapon") {
    let item = { itemTemplate = templateToUse, itemType }
    let lot = getLotFromItem(item)
    if (currentWeaponSlotName != "melee") {
      if (lot == null || lot == ecs.INVALID_ENTITY_ID)
        return
      let marketItem = marketItems.get()?[lot]
      if (marketItem != null) {
        itemToSelect = lot
        weaponRelated(marketItem, lot, resLots, marketItems.get())
        resLots = resLots.filter(@(_v, k) marketItems.get()?[k]?.buyable)
      }
    }
  }

  if (itemToSelect == null) {
    resLots = resSlotsFromAllowedItems(allowed_items)
    if (resLots.len() <= 0)
      return
    let lotToSelect = templateToUse != null ? getLotFromItem({ itemTemplate }) : 0
    if (lotToSelect != 0)
      itemToSelect = lotToSelect
    else {
      let sortedList = resLots.keys()
        .map(@(v) marketItems.get()?[v].__merge({ id = v }))
        .sort(@(a, b) a?.reqMoney <=> b?.reqMoney)
      itemToSelect = sortedList[0].id
    }
  }
  if (resLots.len() <= 0)
    return
  local activeFilter = parentWeaponName != null
    ? $"{loc(slotTooltip ?? $"weaponSlot/{currentWeaponSlotName}")} ({loc(parentWeaponName)})"
    : loc(slotTooltip ?? $"weaponSlot/{currentWeaponSlotName}")

  if (itemType == "weapon" && currentWeaponSlotName != "melee")
    activeFilter = loc("filter/allFor", { item = loc(itemName)})
  else if (filterType == "weapon_mods" || filterType == "ammunition")
    activeFilter = loc("filter/allItemFor", { items = loc(weapModSlotName), weapon = loc(parentWeaponName) })

  customFilter.mutate(@(v) v.__update({
    filterToUse = @(lot) lot in resLots
    activeFilter
    slotData = {
      slot = weapModSlotName ?? weaponSlots?[currentWeaponSlotName] ?? equipmentSlots?[slotName] ?? slotName
      parentId = isEquipment || (weaponSlots?[currentWeaponSlotName] != null && weapModSlotName == null) ? "0"
        : weapUniqueId ?? uniqueId
      itemTemplate = templateToUse
      mods
    }
  }))

  selectedItemsCategory.set(null)  
  selectedItem.set(itemToSelect)
  setSectionToReturn(currentMenuId.get())
  eventbus_send("hud_menus.open", { id = "Market" })
}

function isFastEquipItemPossible(item) {
  if (mutationForbidenDueToInQueueState.get() || (item?.isDelayedMoveMod ?? false))
    return false

  if (item?.isWeapon) {
    let weap = get_weapon_slot_for_item(controlledHeroEid.get(), item.eid)
    if (weap == -1)
      return false
  }
  else if (item?.isWeaponMod) {
    let weapId = get_equipped_item_for_installing_mod(controlledHeroEid.get(), item.eid)
    if (weapId == ecs.INVALID_ENTITY_ID)
      return false
  }
  else if (item?.isEquipment) {
    let slot = get_equipment_slot_for_item(controlledHeroEid.get(), item.eid)
    if (slot == "")
      return false
  }
  else if (item?.eid){
    let result = ecs.CompObject()
    get_slot_and_equipment_for_mod(result, controlledHeroEid.get(), item.eid)
    let resTable = result.getAll()
    if ((resTable?["slot"] ?? "") == "" || (resTable?["equipment"] ?? ecs.INVALID_ENTITY_ID) == ecs.INVALID_ENTITY_ID)
      return false
  }
  return true
}

function getInventoryToMove(item, inventories) {
  if (actionForbiddenDueToQueueState(item) || (item?.isDelayedMoveMod ?? false)) {
    return null
  }

  local inventory = null
  foreach (inv in inventories) {
    if (inventoryChecksByList[inv.name](item) == MoveForbidReason.NONE) {
      inventory = inv
      break
    }
  }
  return inventory
}

function isSameWeaponMods(weapA, weapB) {
  if(weapA.modInSlots == weapB.modInSlots)
    return true

  if(weapA.modInSlots.len() != weapB.modInSlots.len())
    return false

  foreach(k, v in weapA.modInSlots) {
    if(weapB.modInSlots?[k]?.name != v?.name)
      return false
  }
  return true
}

function backpackIdentical(bpA, bpB) {
  if((bpA?.itemContainerItems?.len() ?? -1) > 0 || (bpB?.itemContainerItems?.len() ?? -1) > 0)
    return false
  return true
}

function isItemIdentical(itemA, itemB) {
  return itemA.id == itemB.id
    && itemA?.highlightedItem != true && itemB?.highlightedItem != true
    && itemA.countPerItem == itemB.countPerItem
    && (itemA.charges == itemB.charges || (itemA.isBoxedItem && itemB.isBoxedItem))
    && (itemA?.countKnown ?? true) == (itemB?.countKnown ?? true)
    && itemA.gunAmmo == itemB.gunAmmo
    && itemA?.isReplica == itemB?.isReplica
    && itemA.isCorrupted == itemB.isCorrupted
    && isSameWeaponMods(itemA, itemB)
    && backpackIdentical(itemA, itemB)
    && itemA.stacks && itemB.stacks
    && itemA?.noSuitableItemForPresetFoundCount == itemB?.noSuitableItemForPresetFoundCount
    && itemA?.itemStorage == itemB?.itemStorage
    && itemA?.sortAfterEid == itemB?.sortAfterEid 
}

function findItemInListByKey(itemList, checkItem) {
  foreach (_idx, item in itemList) {
    if ( checkItem?.inTrashBin == item?.inTrashBin && isItemIdentical(item, checkItem)) {
      return item
    }
  }
  return null
}

function mergeNonUniqueItems(items) {
  let outputList = []
  foreach (item in items) {
    let existItem = item.stacks ? findItemInListByKey(outputList, item) : null
    if (existItem == null) {
      outputList.append(item.__merge({ 
        eids = [item.eid]
        uniqueIds = [item.uniqueId]
      }))
      continue
    }
    existItem.eids.append(item.eid)
    existItem.uniqueIds.append(item.uniqueId)
    existItem.recognizeTime += item.recognizeTime
    existItem.recognizeTimeLeft += item.recognizeTimeLeft
    existItem.count = existItem.eids.len()
    if (existItem?.nexusCost != null) {
      existItem.nexusCost = existItem.nexusCost + item.nexusCost
    }

    
    
    if (existItem?.itemProtoFields &&
        existItem?.itemOverridedWithProto != true &&
        existItem.itemProto != existItem.itemTemplate)
      existItem.__update(existItem.itemProtoFields, { itemOverridedWithProto = true })

    
    
    
    if (item.isBoxedItem)
      existItem.ammoCount += item.ammoCount

    if ("sortingPriority" in existItem)
      existItem.sortingPriority = max(existItem.sortingPriority, item?.sortingPriority ?? 0)
  }
  return outputList
}

let inventories = [
  { eid = controlledHeroEid, parentId = Watched("0"), i = 0, data = HERO_ITEM_CONTAINER },
  { eid = backpackEid, parentId = backpackUniqueId, i = 1, data = BACKPACK0 },
  { eid = safepackEid, parentId = safepackUniqueId, i = 2, data = SAFEPACK }
]

function needShowQuickSlotPurchase(slot) {
  if (!isOnPlayerBase.get()
    || inShootingRange.get()
    || !marketIsAvailable.get()
    || (slot?.allowed_items ?? []).len() <= 0
  )
    return false
  let itemsToShow = slot.allowed_items
    .filter(@(itemTemplate) !startswith(itemTemplate, "damage"))
    .map(function(itemTemplate) {
      let lot = getLotFromItem({ itemTemplate })
      if (!lot)
        return null

      let marketItem = marketItems.get()?[lot]
      let playerStat = playerStats.get()

      if (!isLotAvailable(marketItem, playerStat, trialData.get()))
        return null
      return marketItem
    })
    .filter(@(item) item != null)

  return itemsToShow.len() > 0
}

let hasEnoughVolume = @(volume) is_inventory_have_free_volume(stashEid.get(), volume)

function handleOverflow(item, invDefVol, invCurVol, sendBuyFn) {
  let ext = item?.inventoryExtension ?? 0
  if (ext == 0)
    return false

  let newMax = ext + ((invDefVol ?? 100) / 10)
  if (invCurVol <= newMax)
    return false

  showInventoryOverflowOnUnequipToExMsgBox(sendBuyFn)
  return true
}

let findInventoryWithFreeVolume = @(volume) inventories
  .filter(@(inv) inv.eid.get() != ecs.INVALID_ENTITY_ID)
  .findvalue(@(inv) is_inventory_have_free_volume(inv.eid.get(), volume))

function sendBuy(item, price, slot, parentId, isPremium, isPurchaseInProgress) {
  if (isPurchaseInProgress.get())
    return
  if (isPremium) {
    showCurrencyPurchaseMsgBox({
      item
      currency = "premium"
      name = loc(item?.name ?? "")
      price
      cb = function() {
        eventbus_send("profile_server.buyLotInSlot", [{ id = item.lotId, slot, parentId, usePremium = isPremium }])
        isPurchaseInProgress.set(true)
      }
    })
  }
  else {
    eventbus_send("profile_server.buyLotInSlot", [{ id = item.lotId, slot, parentId, usePremium = isPremium }])
    isPurchaseInProgress.set(true)
  }
}

let handleClick = function(data) {
  let { item, credits, premiumCredits, isPurchaseInProgress, invDefVol, invCurVol, slotName, currentWeaponSlotName,
    weapModSlotName, uniqueId, weapUniqueId, isEquipment, itemInSlotVolume } = data

  if ((item?.marketPrice ?? {}).len() <= 0) {
    showMsgbox({ text = loc("shop/playerPreset/nothingToBuy") })
    return
  }

  let { price, isPremium } = item.marketPrice
  if (isPremium && price > premiumCredits) {
    showNotEnoughPremiumMsgBox()
    return
  }

  if (!isPremium && price > credits) {
    showMsgbox({ text = loc("responseStatus/Not enough money") })
    return
  }

  if (itemInSlotVolume > 0 && !hasEnoughVolume(itemInSlotVolume)) {  
    let curVol = stashVolume.get()
    let maxVol = stashMaxVolume.get()
    let need = truncateToMultiple(itemInSlotVolume - (maxVol - curVol), 0.1)
    showNoEnoughStashSpaceMsgbox(need)
    sound_play("ui_sounds/item_insufficient_funds")
    return
  }

  let finalSlot = weapModSlotName
    ?? weaponSlots?[currentWeaponSlotName]
    ?? equipmentSlots?[slotName]
    ?? slotName

  let parentId = (isEquipment || (weaponSlots?[currentWeaponSlotName] != null && weapModSlotName == null))
    ? "0"
    : weapUniqueId ?? uniqueId

  let send = @() sendBuy(item, price, finalSlot, parentId, isPremium, isPurchaseInProgress)

  if (isEquipment && handleOverflow(item, invDefVol, invCurVol, send))
    return

  if (item?.isAmmo && item?.isBoxedItem) {  
    let volume = (item?.countPerStack ?? 0) > 0
      ? max(item?.volumePerStack ?? 0, item?.volume ?? 0)
      : item?.volume ?? 0
    let inventory = findInventoryWithFreeVolume(volume)
    if (!inventory) { 
      showMsgbox({ text = loc("purchaseAndEquip/noSpace") })
      return
    }
    sendBuy(item, price, "inventory", inventory.parentId.get(), isPremium, isPurchaseInProgress)
    return
  }
  send()
}

let prepareItemsToShow = @(allowedItems) allowedItems
  .filter(@(tpl) !startswith(tpl, "damage"))
  .map(function(tpl) {
    let lot = getLotFromItem({ itemTemplate = tpl })
    if (lot == null)
      return null

    let marketItem = marketItems.get()?[lot]
    if (!isLotAvailable(marketItem, playerStats.get(), trialData.get()))
      return null

    let fakeModes = marketItem?.children.items.slice(1)
      .reduce(@(res, v) res.__update({ [v.insertIntoSlot] = mkFakeItem(v.templateName) }), {})

    return mkFakeItem(tpl, {
      fakeModes,
      marketPrice = getPriceFromLot(lot),
      lotId = lot
    })
  })
  .filter(@(x) x != null)
  .sort(@(a, b) a.marketPrice.price <=> b.marketPrice.price)

function purchaseItemsToSlot(slot, event) {
  let { currentWeaponSlotName = null, allowed_items = [], slotName = "stash", uniqueId = "0",
  weapUniqueId = null, weapModSlotName = null } = slot

  let isEquipment = slotName in equipmentSlots
  let itemInSlotVolume = slot?.volume ?? 0
  let itemsDataArr = prepareItemsToShow(allowed_items)

  return {
    event
    itemsDataArr
    onClick = @(item, credits, premiumCredits, isPurchaseInProgress, invDefVol, invCurVol)
      handleClick({
        item, credits, premiumCredits, isPurchaseInProgress, invDefVol, invCurVol,
        slotName, currentWeaponSlotName, weapModSlotName, uniqueId, weapUniqueId,
        isEquipment, itemInSlotVolume
      })
  }
}

function repairCost(items) {
  return items.reduce(function(acc, val) {
    let marketPrice = val?.itemMarketPrice
    if (!marketPrice) {
      logerr($"BASE WORKBENCH: item {val?.itemTemplate} with null price")
      return acc
    }
    let repairValue = val.maxCharges - val.charges
    let count = val?.count ?? 1
    acc += ceil(repairRelativePrice.get() * marketPrice * repairValue / val.maxCharges.tofloat() * count)
    return acc
  }, 0)
}

function repairItems(items, itemsCost = null) {
  if (items.len() <= 0) {
    let nothTorepairLog = {
      id = "nothTorepairLog"
      idToIgnore = "nothTorepairLog"
      content = mkPlayerLog({
        logColor = playerLogsColors.warningLog
        titleText = loc("pieMenu/actionUnavailable")
        titleFaIcon = "close"
        bodyText = loc("inventory/nothingTorepair")
      })
    }
    addPlayerLog(nothTorepairLog)
    return
  }
  let cost = itemsCost ?? repairCost(items)
  if (cost > playerProfileCreditsCount.get()) {
    showMessageWithContent({
      content = {
        rendObj = ROBJ_TEXT
        text = loc("workbench/notEnoghMoney")
      }.__update(h2_txt)
    })
    return
  }
  let itemsToRepair = []
  foreach (item in items) {
    for (local i = 0; i < (item?.count ?? 1); i++) {
      let additionalFields = {
        uniqueId = item.uniqueIds[i]
        uniqueIds = [ item.uniqueIds[i] ]
        eid = item.eids[i]
        eids = [ item.eids[i] ]
        count = 1
      }
      itemsToRepair.append( item?.itemOverridedWithProto ?
        get_item_info(item.eids[i]).__update(additionalFields) :
        item.__merge(additionalFields)
      )
    }
  }
  workbenchRepairInProgress.set(true)
  eventbus_subscribe_onehit($"profile_server.repair_item.result", function(_) {
    workbenchRepairInProgress.set(false)
    workbenchItemContainer.set([])
    items.each(function(v) {
      let { itemTemplate = null, itemName = null, uniqueId = "" } = v
      let image = itemTemplate == null ? null : itemIconNoBorder(itemTemplate,
        {
          width = marketIconSize[0]
          height = marketIconSize[1]
          silhouette = ItemIconBlocked
          shading = "full"
          vplace = ALIGN_CENTER
          margin = static [hdpx(4), 0, hdpx(4), hdpx(8)]
        })

      let repairLog = {
        id = $"repair_item_{uniqueId}"
        content = mkPlayerLog({
          titleText = loc("inventory/itemRepaires")
          titleFaIcon = "wrench"
          bodyText = itemName == null ? null : loc(itemName)
          bodyIcon = image
        })
      }
      addPlayerLog(repairLog)
    })
    sound_play("ui_sounds/button_ok_reward")
  })
  eventbus_send("profile_server.repair_item", {
    unique_item_ids_int64 = itemsToRepair.reduce(@(acc, v) acc.append(v.uniqueId), [])
  })
}

let mkNoVolumeLog = @(bodyText) {
  id = bodyText
  content = mkPlayerLog({
    titleFaIcon = "close"
    titleText = loc("pieMenu/actionUnavailable")
    bodyText = bodyText
    logColor = playerLogsColors.warningLog
  })
}

function fastUnequipItem(item) {
  if (mutationForbidenDueToInQueueState.get())
    return false

  if (item?.slotName == REFINER_KEY_ITEM.name) {
    currentKeyItem.set(null)
    return
  }
  if (!canModifyInventory.get())
    return false

  local targetInventoryEid = ecs.INVALID_ENTITY_ID
  if (isOnPlayerBase.get())
    targetInventoryEid = getInventoryEidByListType(STASH)
  else if (!isHeroInventoryDropForbidden(item) && item?.slotName != "backpack"){
    targetInventoryEid = getInventoryEidByListType(HERO_ITEM_CONTAINER)}
  else if (!isBackpackDropForbidder(item))
    targetInventoryEid = getInventoryEidByListType(BACKPACK0)

  let itemInSlotVolume = item?.volume ?? 0
  if (itemInSlotVolume > 0 && !is_inventory_have_free_volume(targetInventoryEid, itemInSlotVolume)) {
    addPlayerLog(mkNoVolumeLog(loc("hint/equip_in_occupied_slot_failed_capacity_exceeded")))
    return
  }
  if (item?.isWeapon)
    unequip_weapon_from_slot(item.currentWeaponSlotName, targetInventoryEid)
  else if (item?.isWeaponMod) {
    if (targetInventoryEid != ecs.INVALID_ENTITY_ID)
      move_equipped_weapon_mod_to_inventory(item.attachedTo, item.attachedItemModSlotName, targetInventoryEid)
    else
      move_equipped_weapon_mod_to_inventory(item.attachedTo, item.currentWeapModSlotName, ecs.INVALID_ENTITY_ID)
  }
  else if (item?.isEquipment) {
    if ((item?.inventoryExtension ?? 0) != 0) {
      let newMaxVolume = inventoryMaxVolume.get() - (item?.inventoryExtension ?? 0.0)
      let maxVolumeDiff = newMaxVolume - inventoryMaxVolume.get()
      let extraVolume = inventoryCurrentVolume.get() - newMaxVolume
      if (maxVolumeDiff < 0 && extraVolume > 0) {
        showInventoryOverflowOnUnequipToExMsgBox(@() move_stack_to_inventory([item.eid], getInventoryEidByListType(isInPlayerSession.get() ? GROUND : STASH), 1))
        return
      }
    }
    if (targetInventoryEid != ecs.INVALID_ENTITY_ID) {
      move_equipped_item_to_inventory(item.slotName, targetInventoryEid)}
    else
      move_equipped_item_to_ground(item.slotName)
  }
  else if (item?.isEquipmentMod)
    move_equipped_equipment_mod_to_inventory(item.attachedToEquipment, item.slotName, targetInventoryEid)
  else if (item?.onDropInInventory != null) {
    local inventoryToDrop = null
    if (!isHeroInventoryDropForbidden(item) && item?.slotName != "backpack")
      inventoryToDrop = HERO_ITEM_CONTAINER
    else if (!isBackpackDropForbidder(item))
      inventoryToDrop = BACKPACK0
    else if (isOnPlayerBase.get())
      inventoryToDrop = STASH

    if (inventoryToDrop != null)
      item.onDropInInventory(item, inventoryToDrop)
  }
  else
    return false
  return true
}

function checkInventoryVolume(items, inventoryEid = stashEid.get(), inventoryMaxVol = stashMaxVolume.get(), inventoryVolume = stashVolume.get()) {
  local missingVolume = 0
  foreach (item in items) {
    let { templateName } = item
    let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
    let volume = (template?.getCompValNullable("item__countPerStack") ?? 0) > 0
      ? max(template?.getCompValNullable("item__volumePerStack") ?? 0, template?.getCompValNullable("item__volume") ?? 0)
      : (template?.getCompValNullable("item__volume") ?? 0)
    if (!is_inventory_have_free_volume(inventoryEid, volume)) {
      let needMore = truncateToMultiple(volume - (inventoryMaxVol - inventoryVolume), 0.1)
      missingVolume += needMore
    }
  }
  return missingVolume
}

return {
  mkUnloadAmmoButton
  mkLoadAmmoButton
  mkStopLoadUnloadAmmoButton
  mkCheckAmmoButton
  mkStopCheckAmmoButton
  mkItemCheckAmmoProgress
  canItemBeUnload
  canItemBeLoad
  unloadIsEnabled
  loadIsEnabled
  unloadAmmoClick
  loadAmmoClick
  needShowMarketLink
  showItemInMarket
  showItemsForSlotInMarket
  needShowMarketSlotLink
  isFastEquipItemPossible
  getInventoryToMove
  mergeNonUniqueItems
  canCheckAmmoInMagazine
  checkAmmoClick
  purchaseItemsToSlot
  repairCost
  repairItems
  fastUnequipItem
  needShowQuickSlotPurchase
  currentKeyItem
  checkInventoryVolume
  actionForbiddenDueToQueueState
  stopLoadUnloadAmmoClick
  getInspectingAmmoCountInfo
  findInventoryWithFreeVolume
  inventories
  mkNoVolumeLog
}
