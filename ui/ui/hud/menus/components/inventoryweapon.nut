import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
from "%ui/mainMenu/raid_preparation_window_state.nut" import getNexusStashItems

let { sub_txt, body_txt } = require("%ui/fonts_style.nut")
let { playerProfileOpenedRecipes, allCraftRecipes, marketItems, playerStats } = require("%ui/profile/profileState.nut")
let { unload_ammo_from_gun_to_inventory } = require("das.human_weap")
let { draggedData, isWeaponModsForItem, focusedData, requestData, requestItemData, unremovableSlots, isAltPressed
} = require("%ui/hud/state/inventory_state.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let { inventoryItemImage, iconWeapon, weaponModIconParams } = require("inventoryItemImages.nut")
let { mkWeaponModWidget, mkModsToggler } = require("inventoryWeaponMod.nut")
let { BtnBdHover, BtnBdSelected, BtnBdTransparent, BtnBgFocused, BtnBgHover, BtnBgTransparent,
  TextHighlight, TextNormal, noItemContainerBg, RedWarningColor, BtnTextHover } = require("%ui/components/colors.nut")
let { isSpectator } = require("%ui/hud/state/spectator_state.nut")
let { buildInventoryItemTooltip } = require("%ui/hud/menus/components/inventoryItemTooltip.nut")
let { getInventoryEidByListType } = require("%ui/hud/state/inventory_eids_common.nut")
let { bulletInBarrelIndicator, unloadableBulletInBarrelIndicator } = require("inventoryBulletInBarrel.nut")
let {
  isAmmoForWeapon,
  isItemForWeaponMod,
  isItemForHolder
} = require("%ui/hud/state/inventory_item_relations.nut")
let { weaponSlotsKeys } = require("%ui/types/weapon_slots.nut")
let { itemHeight } = require("%ui/hud/menus/components/inventoryStyle.nut")
let { hoverHotkeysWatchedList } = require("%ui/components/pcHoverHotkeyHitns.nut")
let { hoverPcHotkeysPresentation } = require("%ui/hud/menus/components/inventoryActionsHints.nut")
let { WEAPON } = require("%ui/hud/menus/components/slotTypes.nut")
let { openChocolateWnd } = require("%ui/components/chocolateWnd.nut")
let { backpackItems, stashItems, inventoryItems, safepackItems
} = require("%ui/hud/state/inventory_items_es.nut")
let { inventoryItemSorting } = require("%ui/hud/menus/components/inventoryItemsList.nut")
let { mergeNonUniqueItems, needShowQuickSlotPurchase, purchaseItemsToSlot
} = require("%ui/hud/menus/components/inventoryItemUtils.nut")
let { corruptedWeaponImageBackground, addStorageType } = require("%ui/hud/menus/components/inventoryItem.nut")
let { inventoryItemClickActions } = require("%ui/hud/menus/inventoryActions.nut")
let { mkText } = require("%ui/components/commonComponents.nut")
let { creditsIcon } = require("%ui/mainMenu/currencyIcons.nut")
let { slotsWithWarning, mkWarningSign, isPreparationOpened, mintEditState
} = require("%ui/mainMenu/raid_preparation_window_state.nut")
let { getItemPriceToShow, mkItemPrice } = require("%ui/mainMenu/market/inventoryToMarket.nut")
let { equipment } = require("%ui/hud/state/equipment.nut")
let { mkFakeItem } = require("%ui/hud/menus/components/fakeItem.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")

let curBorderColor = BtnBdSelected
let weaponTextCurColor = TextHighlight
let weaponTextColor = TextNormal
let weaponBgColor = BtnBgTransparent
let weaponBgCurColor = BtnBgFocused
let weaponBgHoverColor = BtnBgHover
let weaponBorderHoverColor = BtnBdHover
let weaponBorderNormalColor = BtnBdTransparent
let weaponFillColorRelevant = Color(85,65,45,180)
let weaponSize = [hdpx(406), hdpx(157)]

let slotMarkPxSize = [ hdpx(20), hdpx(30) ]
let weaponSlotMarks = array(4, null).apply(@(_val, idx) @(color) {
  rendObj = ROBJ_IMAGE
  image = Picture("!ui/skin#weap_slot_mark_{0}.svg:{1}:{2}:K".subst(idx, slotMarkPxSize[0], slotMarkPxSize[1]))
  color = color
  size = [ hdpx(20), hdpx(30) ]
} )

function teamRequest(weapon){
  let requestAmmo = weapon.currentWeaponSlotName == "grenade" ? "request/weapon/moreGrenade" : "request/weapon/ammo"
  let requestWeapon = "request/weapon/{0}".subst(weapon.currentWeaponSlotName)
  return (weapon.name == "" || weapon.currentWeaponSlotName == "melee") ? requestWeapon : requestAmmo
}

let mkWeaponText = @(text, color) {
  rendObj = ROBJ_TEXT
  text = loc(text)
  color = color
  padding = hdpx(6)
  fontFx = FFT_GLOW
  fontFxColor = Color(0, 0, 0, 255)
}.__update(sub_txt)

function mkBackground(weapon, isCurrent, sf) {
  let isRelevant = Computed(function() {
    let focused_item = focusedData.get()
    return ("id" in weapon)
      && (isItemForWeaponMod(weapon, focused_item?.weaponModItems, focused_item?.weaponModAmmo)
      || isWeaponModsForItem(focused_item, weapon?.mods)
      || isItemForHolder(focused_item, weapon)
      || isAmmoForWeapon(focused_item, weapon))
  })
  return @(){
    watch = [sf, isRelevant]
    rendObj = ROBJ_SOLID
    size = flex()
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    color = sf.get() & S_HOVER ? weaponBgHoverColor
      : isRelevant.get() ? weaponFillColorRelevant
      : isCurrent ? weaponBgCurColor
      : weapon?.isItemToPurchase ? BtnBgHover
      : (weapon?.noSuitableItemForPresetFoundCount ?? 0) > 0 ? noItemContainerBg
      : weaponBgColor
  }
}

function mkBorder(weapon, isCurrent, sf) {
  let isRelevant = Computed(function() {
    let focused_item = focusedData.get()
    return ("id" in weapon)
      && (isItemForWeaponMod(weapon, focused_item?.weaponModItems, focused_item?.weaponModAmmo)
      || isWeaponModsForItem(focused_item, weapon?.mods)
      || isItemForHolder(focused_item, weapon)
      || isAmmoForWeapon(focused_item, weapon))
  })
  return @(){
    watch = [sf, isRelevant]
    rendObj = ROBJ_FRAME
    size = weaponSize
    borderWidth = hdpx(1)
    color = (sf.get() & S_HOVER) || (sf.get() & S_DRAG)
      ? weaponBorderHoverColor
      : isCurrent ? curBorderColor : weaponBorderNormalColor
  }
}


function mkBulletInBarrelButton(weapon) {
  let magazine = weapon?.mods.magazine
  let canUnload = (weapon?.curAmmo ?? 0) == 1
  if (magazine != null && ((weapon?.curAmmo ?? 0) > 0 && !(weapon?.isJammed ?? false)) && (weapon?.gunBoxedAmmoTemplate ?? "") != "") {
    return !canUnload ? bulletInBarrelIndicator() : unloadableBulletInBarrelIndicator(weapon, weapon.currentWeaponSlotName)
  }
  return null
}

function mkFiringMode(weapon) {
  let firingMode = weapon?.firingMode
  if (!firingMode || firingMode == "")
    return null
  return mkText(loc($"firing_mode/{firingMode}"))
}

let firingMode = @(weapon) {
  vplace = ALIGN_TOP
  hplace = ALIGN_RIGHT
  flow = FLOW_HORIZONTAL
  padding = hdpx(6)
  gap = hdpx(10)
  children = mkFiringMode(weapon)
}

function getFittingAmmo(weapon, canDropAmmoToWeapon) {
  let sortedStash = stashItems.get().sort(inventoryItemSorting)
  let sortedBackpack = backpackItems.get().sort(inventoryItemSorting)
  let sortedInventory = inventoryItems.get().sort(inventoryItemSorting)
  let sortedSafepack = safepackItems.get().sort(inventoryItemSorting)

  let it = [].extend(sortedInventory, sortedBackpack, sortedSafepack, sortedStash)
  let fittingMods = mergeNonUniqueItems(it)
    .filter(@(item) canDropAmmoToWeapon?(item, weapon))
    .map(@(item) addStorageType(item, stashItems.get(), inventoryItems.get(), backpackItems.get(), safepackItems.get()))
  return fittingMods
}


function mkBuiltInAmmo(weapon, can_drop_dragged_item_to_ammo_slot_cb, on_drop_item_in_ammo_slot_cb) {
  function onDropInInventory(_data, list_type) {
    unload_ammo_from_gun_to_inventory(weapon.currentWeaponSlotName, getInventoryEidByListType(list_type))
  }

  let isCountKnown = weapon?.curAmmoCountKnown ?? true

  let dropData = weapon?.ammo.__merge({
    eid = ecs.INVALID_ENTITY_ID
    owner = weapon?.owner ?? ecs.INVALID_ENTITY_ID
    weaponEid = weapon?.eid ?? ecs.INVALID_ENTITY_ID
    isBuiltInAmmo = true
    canDrop=true
    itemName = weapon?.ammo?.name
    onDropInInventory
    countKnown = isCountKnown
    ammoCount = weapon?.curAmmo
    maxAmmoCount = weapon?.maxAmmo
    inactiveItem = (weapon?.curAmmo ?? 0) > 0
    slotTooltip = "slots/ammo"
    ammoHolders = weapon?.ammoHolders ?? []
  })

  let curAmmoText = isCountKnown ? $"{weapon.curAmmo}" : "?"

  return mkWeaponModWidget({
    slotData = dropData
    dropData = (weapon?.curAmmo ?? 0) > 0 ? dropData : null,
    image = inventoryItemImage(weapon.ammo, weaponModIconParams),
    canDropDragged = @(item) can_drop_dragged_item_to_ammo_slot_cb(item, weapon),
    onDrop = @(item) on_drop_item_in_ammo_slot_cb(item, weapon),
    text = "{0}/{1}".subst(curAmmoText, weapon.usesBoxedAmmo ? weapon.maxAmmo : weapon.maxMagazineAmmo),
    getFittingMods = @() getFittingAmmo(weapon, can_drop_dragged_item_to_ammo_slot_cb)
    isUnloadable = (weapon.curAmmo > 0 || !weapon.usesBoxedAmmo) && weapon?.isUnloadable,
    weapon
  })
}

let mkSlotWarning = @(slotName) function() {
  let watch = slotsWithWarning
  let { reason = null, weapon = null } = slotsWithWarning.get()?[slotName]
  if (reason == null)
    return { watch }
  return {
    watch
    vplace = weapon == null ? ALIGN_CENTER : ALIGN_TOP
    hplace = weapon == null ? ALIGN_CENTER : ALIGN_LEFT
    pos = weapon == null ? [0,0] : [hdpx(20), hdpx(20)]
    padding = hdpx(4)
    children = mkWarningSign($"weaponSlot/{slotName}", reason, weapon)
  }
}

let modSlotVisual = @(isCurrent, slotItemComp){
  children = [
    slotItemComp,
    {
      rendObj = ROBJ_BOX
      size = flex()
      borderColor = isCurrent ? curBorderColor : Color(67, 67, 67)
      borderWidth = hdpx(1)
    }
  ]
}

function getFittingMods(weapon, modSlotName, modSlot, canDropToModSlot) {
  local sortedStash = []
  if (!isOnboarding.get())
    sortedStash = stashItems.get().sort(inventoryItemSorting)
  let sortedBackpack = backpackItems.get().sort(inventoryItemSorting)
  let sortedInventory = inventoryItems.get().sort(inventoryItemSorting)
  let sortedSafepack = safepackItems.get().sort(inventoryItemSorting)

  let it = [].extend(sortedInventory, sortedBackpack, sortedSafepack, sortedStash)
  let fittingMods = mergeNonUniqueItems(it)
    .filter(@(item) canDropToModSlot?(item, weapon, modSlotName, modSlot))
    .map(@(item) addStorageType(item, stashItems.get(), inventoryItems.get(), backpackItems.get(), safepackItems.get()))
  return fittingMods
}

function mkMods(weapon, isCurrent, can_drop_dragged_item_to_mod_slot_cb, on_drop_item_in_mod_slot_cb) {
  let mods = []
  let modsData = []
  let ammo = []
  let isActionForbided = can_drop_dragged_item_to_mod_slot_cb == null && on_drop_item_in_mod_slot_cb == null
  foreach (modSlotName_, modSlot_ in weapon?.mods ?? {}) {
    let modSlotName = modSlotName_
    let modSlot = modSlot_
    let dropData = isActionForbided || (modSlot.itemPropsId == 0) ? null : modSlot.__update({
      canDrop=true
      
      currentWeaponSlotName=weapon.currentWeaponSlotName
      currentWeapModSlotName=modSlotName
      
      id=modSlot.itemPropsId
      weapModSlotName=modSlot?.attachedItemModSlotName
      isDelayedMoveMod = (modSlot?.isDelayedMoveMod ?? false)
      inactiveItem = (modSlot?.inactiveItem ?? false)
    })
    let slot = mkWeaponModWidget({
      slotData = modSlot,
      dropData,
      image=inventoryItemImage(modSlot, weaponModIconParams),
      canDropDragged = @(item) can_drop_dragged_item_to_mod_slot_cb?(item, weapon, modSlotName, modSlot),
      onDrop = @(item) on_drop_item_in_mod_slot_cb?(item, weapon, modSlotName, modSlot),
      isUnloadable = (modSlot.itemPropsId ?? 0) != 0
      getFittingMods = function() {
        local res = null
        if (!mintEditState.get())
          res = getFittingMods(weapon, modSlotName, modSlot, can_drop_dragged_item_to_mod_slot_cb)
        else {
          res = getNexusStashItems(stashItems.get(), playerProfileOpenedRecipes.get(), allCraftRecipes.get(),
            marketItems.get(), playerStats.get(), ["weapon_mods", "ammunition"])
              .filter(@(v) can_drop_dragged_item_to_mod_slot_cb?(v, weapon, modSlotName, modSlot))
              .sort(inventoryItemSorting)
        }
        return res
      }
      isActionForbided,
      weapon,
      modSlotName
    })
    let listToAppend = modSlotName == "magazine" ? ammo : mods
    if (modSlotName != "magazine")
      modsData.append({ dropData, isCurrent,
        canDropDragged = @(item) can_drop_dragged_item_to_mod_slot_cb(item, weapon, modSlotName, modSlot)
        onDrop = @(item) on_drop_item_in_mod_slot_cb(item, weapon, modSlotName, modSlot),
      })
    listToAppend.append(modSlotVisual(isCurrent, slot))
  }
  return { ammo, mods, modsData }
}

let weapNameWithIdx = @(slotIdx, slotName, isCurrent = false, stateFlags = Watched(0)) function() {
  let textColor = isCurrent ? weaponTextCurColor
    : stateFlags.get() & S_HOVER ? BtnTextHover
    : weaponTextColor
  let slotColor = isCurrent ? curBorderColor
    : stateFlags.get() & S_HOVER ? BtnTextHover
    : Color(69, 69, 68)
  return {
    watch = stateFlags
    flow = FLOW_HORIZONTAL
    hplace = ALIGN_RIGHT
    vplace = ALIGN_BOTTOM
    halign = ALIGN_RIGHT
    valign = ALIGN_BOTTOM
    gap = hdpx(11)
    children = [
      mkWeaponText(slotName, textColor)
      weaponSlotMarks?[slotIdx](slotColor)
    ]
  }
}

function getFittingItems(weapon, canDropToWeaponSlot) {
  local sortedStash = []
  if (!isOnboarding.get())
    sortedStash = stashItems.get().sort(inventoryItemSorting)
  let sortedBackpack = backpackItems.get().sort(inventoryItemSorting)
  let sortedInventory = inventoryItems.get().sort(inventoryItemSorting)
  let sortedSafepack = safepackItems.get().sort(inventoryItemSorting)

  let it = [].extend(sortedInventory, sortedBackpack, sortedSafepack, sortedStash)
  let fittingItems = mergeNonUniqueItems(it)
    .filter(@(item) canDropToWeaponSlot?(item, weapon))
    .map(@(item) addStorageType(item, stashItems.get(), inventoryItems.get(), backpackItems.get(), safepackItems.get()))
  return fittingItems
}

let mkPriceBlock = @(weapon) function() {
  let watch = isPreparationOpened
  if (!isPreparationOpened.get())
    return { watch }
  let price = getItemPriceToShow(weapon) ?? 0
  if (price <= 0)
    return { watch }
  return {
    watch
    hplace = ALIGN_RIGHT
    padding = hdpx(1)
    children = mkItemPrice(price, { padding = [hdpx(2), hdpx(4)] }.__update(body_txt) )
  }
}

function mkMainFrame(weapon, canDropToWeaponSlot, onDropToWeaponSlot, hasAmmo) {
  let isCurrent = (weapon?.isEquiping ?? false ) || ((weapon?.isCurrent ?? false) && !(weapon?.isHolstering ?? false))
  let isRemovableWeapon = unremovableSlots?.value?.indexof(weapon.currentWeaponSlotName) == null && !weapon?.isDefaultStubItem
  let controllable = isRemovableWeapon
    && weapon?.isWeapon
    && !isSpectator.get()
    && (weapon?.isDragAndDropAvailable ?? true)
    && canDropToWeaponSlot != null
    && onDropToWeaponSlot != null

  let slotIdx = weaponSlotsKeys.findindex(@(v) v == weapon.currentWeaponSlotName)

  let stateFlags = Watched(0)
  function onElemState(sf) {
    stateFlags(sf)
  }
  function onHover(on){
    requestData.update(on ? teamRequest(weapon) : "")
    requestItemData.update(on ? weapon.name : "")
    if (isRemovableWeapon && weapon?.isWeapon)
      focusedData.set(on ? weapon.__merge({canDrop=true}) : null)
    else
      focusedData.set(on ? {slot = weapon.currentWeaponSlotName} : null)
    setTooltip(on && weapon?.isWeapon ? buildInventoryItemTooltip(weapon) : null)
    let pcHotkeysHints = canDropToWeaponSlot == null && onDropToWeaponSlot == null ? null
      : hoverPcHotkeysPresentation?[WEAPON.name](weapon)
    hoverHotkeysWatchedList.set(on ? pcHotkeysHints : [])
  }
  let { rmbAction = null, lmbAltAction = null } = inventoryItemClickActions?[WEAPON.name]
  function onClick(event) {
    if (canDropToWeaponSlot == null && onDropToWeaponSlot == null)
      return
    if (event.button == 1 && !isSpectator.get())
      rmbAction?(weapon, event)
    if(event.button == 0 && !isSpectator.get()) {
      if (isAltPressed.get() && lmbAltAction != null) {
        if (!(weapon?.canDrop ?? true))
          return
        lmbAltAction(weapon)
      }
      else {
        local fittingItems = null
        if (!mintEditState.get())
          fittingItems = getFittingItems(weapon, canDropToWeaponSlot)
        else {
          fittingItems = getNexusStashItems(stashItems.get(), playerProfileOpenedRecipes.get(), allCraftRecipes.get(),
            marketItems.get(), playerStats.get(), ["weapons"])
              .filter(@(v) canDropToWeaponSlot(v, weapon))
              .sort(inventoryItemSorting)
        }
        local defaultItem = null
        if (weapon?.validWeaponSlots.contains("melee")) {
          let suitTpl = equipment.get()?["chronogene_primary_1"].itemTemplate
          if (suitTpl != null) {
            let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(suitTpl)
            let defWeapon = template?.getCompValNullable("equipment__setDefaultStubMeleeTemplate")
            if (defWeapon != null)
              defaultItem = mkFakeItem(defWeapon)
          }
        }
        openChocolateWnd({
          event,
          itemsDataArr = fittingItems
          onClick = @(item, actions) actions?.weapons[slotIdx].onDropToSlot(item, weapon)
            ?? onDropToWeaponSlot(item, weapon)
          itemInSlot = weapon
          defaultItem
          shopData = mintEditState.get() ? null
            : needShowQuickSlotPurchase(weapon) ? purchaseItemsToSlot(weapon, event) : null
        })
      }
    }
  }

  let slotName = "weaponSlotKey" in weapon ? loc($"weaponSlot/{weapon.weaponSlotKey}") : weapon.name
  let needShowPrice = (weapon?.noSuitableItemForPresetFoundCount ?? 0) > 0

  return @(content) {
    size = [flex(), weaponSize[1]]
    key = weapon?.eid ?? ecs.INVALID_ENTITY_ID

    onElemState
    transform = {}
    behavior = controllable ? Behaviors.DragAndDrop : Behaviors.Button
    dropData = controllable ? weapon.__merge({canDrop = true}) : null
    onDragMode = controllable ? @(on, item) draggedData.update(on ? item : null) : null
    onClick
    onHover
    children = [
      mkBackground(weapon, isCurrent, stateFlags)
      !weapon?.isItemToPurchase ? null : creditsIcon(hdpxi(60), {
        hplace = ALIGN_RIGHT
        pos = [-hdpx(5), -hdpx(58)]
      })
      weapon?.isCorrupted ? corruptedWeaponImageBackground.__merge(hasAmmo ? {margin = [0,0,0, hdpx(76)]} : {}) : null
      iconWeapon(weapon).__update({
        pos=[ -hdpx(10), hdpx(10) ]
        opacity = weapon?.noSuitableItemForPresetFoundCount != null ? 0.5 : 1
      })
      weapNameWithIdx(slotIdx, slotName, isCurrent, stateFlags)
      content
      mkBorder(weapon, isCurrent, stateFlags)
      mkSlotWarning(weapon?.currentWeaponSlotName)
      needShowPrice ? mkPriceBlock(weapon) : null
    ]
  }
}

function mkWeaponWidget(mainFrame, ammoWidgets, afterAmmoWidget, modsWidgets, modsData, additionalChildrens=null, weaponSlot = null) {
  let widgetRows = @(v) {
    minHeight = itemHeight
    flow = FLOW_HORIZONTAL
    gap = hdpx(5)
    children = v
  }
  let mods = {
    hplace = ALIGN_LEFT
    vplace = ALIGN_BOTTOM
    flow = FLOW_VERTICAL
    gap = hdpx(5)
    size = SIZE_TO_CONTENT
    children = [
      {
        flow = FLOW_HORIZONTAL
        children = [
          widgetRows(ammoWidgets)
          afterAmmoWidget
        ]
      }
      modsWidgets.len() > 2 ? mkModsToggler(modsWidgets, modsData, weaponSlot) : widgetRows(modsWidgets)
    ]
  }
  let content = {
    size = flex()
    children = [
      mods
      additionalChildrens
    ]
  }
  return {
    size = weaponSize
    children = mainFrame(content)
  }
}

function weaponWidget(weapon, canDropToWeaponSlot, onDropToWeaponSlot,
                      canDropToModSlot, onDropToModSlot,
                      canDropToAmmoSlot, onDropToAmmoSlot) {
  let isBuiltInMagazine = weapon?.ammo && weapon?.mods.magazine == null && weapon?.ammoHolders && weapon.ammoHolders.len() != 0
  let isCurrent = (weapon?.isEquiping ?? false ) || ((weapon?.isCurrent ?? false) && !(weapon?.isHolstering ?? false))
  let { ammo, mods, modsData } = mkMods(weapon, isCurrent, canDropToModSlot, onDropToModSlot)

  if (isBuiltInMagazine)
    ammo.append(modSlotVisual(isCurrent, mkBuiltInAmmo(weapon, canDropToAmmoSlot, onDropToAmmoSlot)))
  let hasAmmon = ammo.len() > 0
  let mainFrame = mkMainFrame(weapon, canDropToWeaponSlot, onDropToWeaponSlot, hasAmmon)
  let firing = firingMode(weapon)
  let bulletInBarrel = {
    vplace = ALIGN_TOP
    padding = hdpx(5)
    children = mkBulletInBarrelButton(weapon)
  }

  return mkWeaponWidget(mainFrame, ammo, bulletInBarrel, mods, modsData, firing, weapon?.currentWeaponSlotName)
}


let disabledWeaponWidget = @(slot, slotIdx) {
  rendObj = ROBJ_SOLID
  size = weaponSize
  color = BtnBgTransparent
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  behavior = Behaviors.Button
  onHover = @(on) setTooltip(on ? loc("inventory/monsterDisabledTip") : null)
  children = [
    {
      vplace = ALIGN_BOTTOM
      hplace = ALIGN_RIGHT
      valign = ALIGN_CENTER
      children = [
        weapNameWithIdx(slotIdx, slot)
        {
          rendObj = ROBJ_SOLID
          size = [flex(), hdpx(2)]
          pos = [0, hdpx(1)]
          color = RedWarningColor
        }
      ]
    }
    mkText(loc("slot/disabled"), { color = RedWarningColor }.__update(body_txt))
  ]
}

return {
  weaponWidget
  disabledWeaponWidget
}
