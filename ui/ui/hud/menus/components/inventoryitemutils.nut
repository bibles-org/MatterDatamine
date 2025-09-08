from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { h2_txt } = require("%ui/fonts_style.nut")
let {get_sync_time} = require("net")
let faComp = require("%ui/components/faComp.nut")
let {setTooltip} = require("%ui/components/cursors.nut")
let {controlledHeroEid} = require("%ui/hud/state/controlled_hero.nut")
let {entityToUse} = require("%ui/hud/state/entity_use_state.nut")
let {isSpectator} = require("%ui/hud/state/spectator_state.nut")
let { HERO_ITEM_CONTAINER, BACKPACK0, STASH, GROUND } = require("inventoryItemTypes.nut")
let {RequestLoadItemHolder, RequestUnloadItemHolder, RequestInterruptUseItemHolder, RqCheckAmmoItemHolder, RqStopCheckAmmoItemHolder,
  sendNetEvent} = require("dasevents")
let {isItemForHolder} = require("%ui/hud/state/inventory_item_relations.nut")
let {inventoryItems, stashItems, backpackItems} = require("%ui/hud/state/inventory_items_es.nut")
let {inspectingAmmoCountAffectEid} = require("%ui/hud/state/ammo_count_knowledge_state.nut")
let {Alert, Inactive} = require("%ui/components/colors.nut")
let { getLotFromItem, isLotAvailable, getPriceFromLot } = require("%ui/mainMenu/market/inventoryToMarket.nut")
let { selectedItem, selectedItemsCategory } = require("%ui/mainMenu/market/marketState.nut")
let { eventbus_send, eventbus_subscribe_onehit } = require("eventbus")
let { lerp, ceil, truncateToMultiple } = require("%sqstd/math.nut")
let { isOnPlayerBase, isInPlayerSession } = require("%ui/hud/state/gametype_state.nut")
let { inShootingRange } = require("%ui/hud/state/shooting_range_state.nut")
let { get_weapon_slot_for_item,  get_equipped_item_for_installing_mod, is_inventory_have_free_volume,
  get_equipment_slot_for_item, get_slot_and_equipment_for_mod, ceil_volume, unequip_weapon_from_slot,
  move_equipped_weapon_mod_to_inventory, move_stack_to_inventory, move_equipped_item_to_inventory,
  move_equipped_item_to_ground,move_equipped_equipment_mod_to_inventory } = require("das.inventory")
let { inventoryChecksByList, isHeroInventoryDropForbidden, isBackpackDropForbidder
} = require("%ui/hud/menus/components/inventoryItemsListChecks.nut")
let { MoveForbidReason, showInventoryOverflowOnUnequipToExMsgBox
} = require("%ui/hud/menus/components/inventoryItemsListChecksCommon.nut")
let { curWeapon } = require("%ui/hud/state/hero_weapons.nut")
let { mkFakeItem } = require("%ui/hud/menus/components/fakeItem.nut")
let { marketItems, repairRelativePrice, playerProfileCreditsCount, playerStats } = require("%ui/profile/profileState.nut")
let { startswith } = require("string")
let { showMsgbox, showMessageWithContent } = require("%ui/components/msgbox.nut")
let { marketIsAvailable, setSectionToReturn } = require("%ui/mainMenu/marketMenu.nut")
let { customFilter, weaponRelated } = require("%ui/mainMenu/market/marketItems.nut")
let { currentMenuId } = require("%ui/hud/hud_menus_state.nut")
let { logerr } = require("dagor.debug")
let { workbenchRepairInProgress, workbenchItemContainer,
} = require("%ui/hud/menus/inventories/workbenchInventory.nut")
let { get_item_info } = require("%ui/hud/state/item_info.nut")
let { sound_play } = require("%dngscripts/sound_system.nut")
let { backpackEid, safepackEid, backpackUniqueId, safepackUniqueId
} = require("%ui/hud/state/hero_extra_inventories_state.nut")
let { stashEid, stashVolume, stashMaxVolume } = require("%ui/state/allItems.nut")
let { canModifyInventory } = require("%ui/hud/state/inventory_common_es.nut")
let { getInventoryEidByListType } = require("%ui/hud/state/inventory_eids_common.nut")
let { inventoryMaxVolume, inventoryCurrentVolume } = require("%ui/hud/state/inventory_state.nut")
let { REFINER_KEY_ITEM } = require("%ui/hud/menus/components/slotTypes.nut")
let { addPlayerLog, mkPlayerLog, playerLogsColors } = require("%ui/popup/player_event_log.nut")
let { showNoEnoughStashSpaceMsgbox } = require("%ui/mainMenu/stashSpaceMsgbox.nut")

let loadUnloadAmmoPic = @(img) Picture($"ui/skin#{img}:{0}:{0}:P".subst(hdpxi(15)))
let BtnInactiveColor = Color(128, 128, 128)
let BtnActiveColor = Color(255, 255, 255)

let currentKeyItem = Watched(null)

function stopLoadUnloadAmmoClick(){
  sendNetEvent(controlledHeroEid.value, RequestInterruptUseItemHolder())
}

function unloadAmmoClick(item){
  
  if (curWeapon.get()?.isReloading)
    return
  if ((item?.charges ?? 0) > 0)
    sendNetEvent(controlledHeroEid.value, RequestUnloadItemHolder({targetItemEid=item.eid, containerEid=item.owner}))
  else
    ecs.g_entity_mgr.sendEvent(controlledHeroEid.value, RqCheckAmmoItemHolder({targetItemEid=item.eid, containerEid=item.owner}))
}

function loadAmmoClick(item) {
  
  if (curWeapon.get()?.isReloading)
    return
  if ((item?.charges ?? 0) < item.maxCharges)
    sendNetEvent(controlledHeroEid.value, RequestLoadItemHolder({targetItemEid=item.eid, containerEid=item.owner, searchOtherContainers = true}))
  else
  ecs.g_entity_mgr.sendEvent(controlledHeroEid.value, RqCheckAmmoItemHolder({targetItemEid=item.eid, containerEid=item.owner}))
}

function checkAmmoClick(item) {
  ecs.g_entity_mgr.sendEvent(controlledHeroEid.value, RqCheckAmmoItemHolder({targetItemEid=item.eid, containerEid=item.owner}))
}

function stopCheckAmmoClick() {
  ecs.g_entity_mgr.sendEvent(controlledHeroEid.value, RqStopCheckAmmoItemHolder())
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
      behavior = Behaviors.Button
      onElemState = @(s) unloadBtnStateFlags(s)
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
          size = [ hdpx(15), hdpx(15) ]
          color = (unloadBtnStateFlags.get() & S_HOVER) ? BtnActiveColor : BtnInactiveColor
        }
      } : null
    }
  }
}

function canItemBeUnload(item) {
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

function unloadItemAmmo(item) {
  unloadAmmoClick(item)
}

function canItemBeLoad(item) {
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

function loadItemAmmo(item) {
  loadAmmoClick(item)
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
    let isWeaponMod = item?.isWeaponMod ?? false
    let needHighlight = !needWatched ? null : Computed(@() isWeaponMod &&
                                  (inventoryItems.get().findindex(@(i) isItemForHolder(i, item)) != null ||
                                  backpackItems.get().findindex(@(i) isItemForHolder(i, item)) != null ||
                                  stashItems.get().findindex(@(i) isItemForHolder(i, item)) != null))

    return {
      watch = [ loadBtnStateFlags, entityToUse, needHighlight, inspectingAmmoCountAffectEid, curWeapon ]
      onClick =  @() loadAmmoClick(item)
      behavior = Behaviors.Button
      onElemState = @(s) loadBtnStateFlags(s)
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
          size = [ hdpx(15), hdpx(15) ]
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

  let isMagazineTypeHolder = (item?.boxedItemTemplate ?? "") != ""

  return function() {
    let inspectingAmmoCountItemEid = getInspectingAmmoCountInfo(inspectingAmmoCountAffectEid.get())[0]
    let showStopButton = isMagazineTypeHolder
                        && (listType == HERO_ITEM_CONTAINER || listType == BACKPACK0 || listType == STASH)
                        && !isSpectator.get()
                        && (item?.charges ?? 0) > 0
                        && !(item?.isDelayedMoveMod ?? false)
                        && inspectingAmmoCountItemEid != item?.eid

    return {
      watch = [ stopBtnStateFlags, entityToUse, inspectingAmmoCountAffectEid ]
      onClick = @() stopLoadUnloadAmmoClick()
      behavior = Behaviors.Button
      onElemState = @(s) stopBtnStateFlags(s)
      onHover = @(on) setTooltip(on ? loc("Inventory/stop_ammo_action") : null)
      sound = {
        click  = "ui_sounds/button_click"
      }
      padding = hdpx(3)
      vplace = ALIGN_BOTTOM
      hplace = ALIGN_RIGHT
      children = showStopButton ? {
        children = entityToUse.get() == item.eid ? faComp("close", {
          color = (stopBtnStateFlags.get() & S_HOVER) ? BtnActiveColor : BtnInactiveColor
          fontSize = hdpx(15)
        }) : null
      } : null
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
      behavior = Behaviors.Button
      margin = [fsh(0.2), fsh(0.2), 0, 0]
      onElemState = @(s) checkAmmoBtnStateFlags(s)
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
          size = [ hdpx(15), hdpx(15) ]
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
      behavior = Behaviors.Button
      onElemState = @(s) stopCheckAmmoBtnStateFlags(s)
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
      size = [flex(), pw(1)]
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

let needShowMarketSlotLink = @(itemOrSlot) marketIsAvailable.get()
  && isOnPlayerBase.get() && !inShootingRange.get()
  && (getLotFromItem(itemOrSlot) != 0 || resSlotsFromAllowedItems(itemOrSlot?.allowed_items ?? []).len() > 0)

function showItemInMarket(item) {
  let marketId = getLotFromItem(item)
  let toShopAction = function() {
    selectedItemsCategory.set(null)  
    selectedItem.set(marketId)
    setSectionToReturn(currentMenuId.get())
    eventbus_send("hud_menus.open", const { id = "Market" })
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
}

function showItemsForSlotInMarket(itemOrSlot) {
  let { allowed_items = [], itemTemplate = null, itemType = null, slotTooltip = null, itemName = null,
    currentWeaponSlotName = null, filterType = null, weapModSlotName = null, parentWeaponName = null,
    slotName = "inventory", uniqueId = "0", weapUniqueId = null, mods = {}
  } = itemOrSlot
  let isEquipment = slotName in equipmentSlots
  if (allowed_items.len() <= 0 && !itemTemplate)
    return

  local resLots = {}
  local itemToSelect = null
  if (itemType == "weapon") {
    let item = { itemTemplate, itemType }
    let lot = getLotFromItem(item)
    if (currentWeaponSlotName != "melee") {
      if (lot == null || lot == ecs.INVALID_ENTITY_ID)
        return
      let marketItem = marketItems.get()?[lot]
      if (marketItem != null) {
        itemToSelect = lot
        weaponRelated(marketItem, lot, resLots, marketItems.get())
      }
    }
  }

  if (itemToSelect == null) {
    resLots = resSlotsFromAllowedItems(allowed_items)
    if (resLots.len() <= 0)
      return
    let lotToSelect = itemTemplate != null ? getLotFromItem({ itemTemplate }) : 0
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
      itemTemplate
      mods
    }
  }))

  selectedItemsCategory.set(null)  
  selectedItem.set(itemToSelect)
  setSectionToReturn(currentMenuId.get())
  eventbus_send("hud_menus.open", { id = "Market" })
}

function isFastEquipItemPossible(item) {
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
    && !itemA.isAmStorage && !itemB.isAmStorage
    && itemA?.ownerNickname == null && itemB?.ownerNickname == null
    && itemA.countPerItem == itemB.countPerItem
    && (itemA.charges == itemB.charges || (itemA.isBoxedItem && itemB.isBoxedItem))
    && (itemA?.countKnown ?? true) == (itemB?.countKnown ?? true)
    && itemA.gunAmmo == itemB.gunAmmo
    && itemA?.isReplica == itemB?.isReplica
    && itemA.isCorrupted == itemB.isCorrupted
    && itemA?.createdByZone == itemB?.createdByZone
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
  { eid = controlledHeroEid, parentId = Watched("0"), i = 0 },
  { eid = backpackEid, parentId = backpackUniqueId, i = 1 },
  { eid = safepackEid, parentId = safepackUniqueId, i = 2 }
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

      if (!isLotAvailable(marketItem, playerStat))
        return null
      return marketItem
    })
    .filter(@(item) item != null)

  return itemsToShow.len() > 0
}


function purchaseItemsToSlot(slot, event) {
  let { currentWeaponSlotName = null, allowed_items = [], slotName = "stash", uniqueId = "0",
    weapUniqueId = null, weapModSlotName = null } = slot
  let isEquipment = slotName in equipmentSlots
  let itemInSlotVolume = slot?.volume ?? 0
  let curStashEid = stashEid.get()
  let curStashVolume = stashVolume.get()
  let curStashMaxVolume = stashMaxVolume.get()
  let playerStat = playerStats.get()
  let itemsToShow = allowed_items
    .filter(@(itemTemplate) !startswith(itemTemplate, "damage"))
    .map(function(itemTemplate) {
      let lot = getLotFromItem({ itemTemplate })
      if (!lot)
        return null
      let marketItem = marketItems.get()?[lot]
      if (!(isLotAvailable(marketItem, playerStat)))
        return null
      let fakeModes = marketItem?.children.items.slice(1)
        .reduce(@(res, v) res.__update({ [v.insertIntoSlot] = mkFakeItem(v.templateName) }), {})
      return mkFakeItem(itemTemplate, { fakeModes, marketPrice = getPriceFromLot(lot), lotId = lot })
    })
    .filter(@(item) item != null)
    .sort(@(a, b) a.marketPrice <=> b.marketPrice)

  return {
    event
    itemsDataArr = itemsToShow,
    onClick = function(item, creditsCount, isPurchaseInProgress, inventoryDefVolume, inventoryCurVolume) {
      if (!item?.marketPrice) {
        showMsgbox({ text = loc("shop/playerPreset/nothingToBuy") })
        return
      }
      if (item.marketPrice > creditsCount) {
        showMsgbox({ text = loc("responseStatus/Not enough money") })
        return
      }
      if (itemInSlotVolume > 0 && !is_inventory_have_free_volume(curStashEid, itemInSlotVolume)) {
        let needMore = truncateToMultiple(itemInSlotVolume - (curStashMaxVolume - curStashVolume), 0.1)
        showNoEnoughStashSpaceMsgbox(needMore)
        sound_play("ui_sounds/item_insufficient_funds")
        return
      }
      if (!isPurchaseInProgress.get()) {
        if (isEquipment) {
          if ((item?.inventoryExtension ?? 0) != 0) {
            let newMaxVolume = (item?.inventoryExtension ?? 0.0) + ((inventoryDefVolume ?? 100) / 10)
            let isOverflow = inventoryCurVolume > newMaxVolume
            if (isOverflow) {
              showInventoryOverflowOnUnequipToExMsgBox(function() {
                eventbus_send("profile_server.buyLotInSlot", [{
                  id = item.lotId
                  slot = weapModSlotName ?? weaponSlots?[currentWeaponSlotName] ?? equipmentSlots?[slotName] ?? slotName
                  parentId = isEquipment || (weaponSlots?[currentWeaponSlotName] != null && weapModSlotName == null) ? "0"
                    : weapUniqueId ?? uniqueId
                }])
                isPurchaseInProgress.set(true)
              })
              return
            }
          }
        }
        if (item?.isAmmo && item?.isBoxedItem) {
          let volume = ceil_volume((item?.countPerStack ?? 0) > 0
            ? max(item?.volumePerStack ?? 0, item?.volume ?? 0)
            : item?.volume ?? 0)
          let inventory = inventories.findvalue(@(inv) is_inventory_have_free_volume(inv.eid.get(), volume))
          if (!inventory) {
            showMsgbox({ text = loc("purchaseAndEquip/noSpace") })
            return
          }
          eventbus_send("profile_server.buyLotInSlot", [{
            id = item.lotId
            slot = "inventory"
            parentId = inventory.parentId.get()
          }])
          isPurchaseInProgress.set(true)
          return
        }
        eventbus_send("profile_server.buyLotInSlot", [{
          id = item.lotId
          slot = weapModSlotName ?? weaponSlots?[currentWeaponSlotName] ?? equipmentSlots?[slotName] ?? slotName
          parentId = isEquipment || (weaponSlots?[currentWeaponSlotName] != null && weapModSlotName == null) ? "0"
            : weapUniqueId ?? uniqueId
        }])
        isPurchaseInProgress.set(true)
      }
    }
  }
}

function itemRepairPrice(item) {
  return item?.itemMarketPrice
}

function repairCost(items) {
  return items.reduce(function(acc, val) {
    let marketPrice = itemRepairPrice(val)
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
    sound_play("ui_sounds/button_ok_reward")
  })
  eventbus_send("profile_server.repair_item", {
    unique_item_ids_int64 = itemsToRepair.reduce(@(acc, v) acc.append(v.uniqueId), [])
  })
}

let noVolumeLog = {
  id = "noVolumeItemMove"
  content = mkPlayerLog({
    titleText = loc("pieMenu/actionUnavailable")
    bodyText = loc("hint/equip_in_occupied_slot_failed_capacity_exceeded")
    logColor = playerLogsColors.warningLog
  })
}

function fastUnequipItem(item) {
  if (item?.slotName == REFINER_KEY_ITEM.name) {
    currentKeyItem.set(null)
    return
  }
  if (!canModifyInventory.get())
    return false
  local targetInventoryEid = ecs.INVALID_ENTITY_ID
  if (!isHeroInventoryDropForbidden(item) && item?.slotName != "backpack")
    targetInventoryEid = getInventoryEidByListType(HERO_ITEM_CONTAINER)
  else if (!isBackpackDropForbidder(item))
    targetInventoryEid = getInventoryEidByListType(BACKPACK0)
  else if (isOnPlayerBase.get())
    targetInventoryEid = getInventoryEidByListType(STASH)
  let itemInSlotVolume = item?.volume ?? 0
  if (itemInSlotVolume > 0 && !is_inventory_have_free_volume(targetInventoryEid, itemInSlotVolume)) {
    addPlayerLog(noVolumeLog)
    return
  }
  if (item?.isWeapon)
    unequip_weapon_from_slot(item.currentWeaponSlotName, targetInventoryEid)
  else if (item?.isWeaponMod) {
    if (targetInventoryEid != ecs.INVALID_ENTITY_ID)
      move_equipped_weapon_mod_to_inventory(item.currentWeaponSlotName, item.attachedItemModSlotName, targetInventoryEid)
    else
      move_equipped_weapon_mod_to_inventory(item.currentWeaponSlotName, item.currentWeapModSlotName, ecs.INVALID_ENTITY_ID)
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

function checkInventoryVolume(items, inventoryEid = stashEid.get(), inventoryMaxVol = stashMaxVolume.get(),
inventoryVolume = stashVolume.get()
) {
  local missingVolume = 0
  foreach (item in items) {
    let { templateName } = item
    let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
    let volume = ceil_volume(
      (template?.getCompValNullable("item__countPerStack") ?? 0) > 0
        ? max(template?.getCompValNullable("item__volumePerStack") ?? 0, template?.getCompValNullable("item__volume") ?? 0)
        : (template?.getCompValNullable("item__volume") ?? 0)
    )
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
  unloadItemAmmo
  loadItemAmmo
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
}
