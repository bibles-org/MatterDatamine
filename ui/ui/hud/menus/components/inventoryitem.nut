from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
import "%ui/components/colors.nut" as colors

let { BtnBgHover, BtnBdHover, BtnBdNormal, BtnBgDisabled, Inactive, noItemContainerBg,
  ContactOffline, corruptedItemColor } = colors
let { tiny_txt } = require("%ui/fonts_style.nut")
let faComp = require("%ui/components/faComp.nut")
let { is_item_use_blocked, is_can_move_item_to_item_container, is_item_inventory_move_blocked,
      move_stack_to_inventory, is_equip_to_slot_cause_from_pocket_drop,
      is_equip_to_slot_cause_inventory_overflow, is_can_move_to_safepack_with_overflow } = require("das.inventory")
let {inventoryItemImage, inventoryImageParams} = require("inventoryItemImages.nut")
let { focusedData, draggedData, isWeaponModsForItem, contextHoveredData,
      isShiftPressed, isAltPressed } = require("%ui/hud/state/inventory_state.nut")
let {setTooltip} = require("%ui/components/cursors.nut")
let {isSpectator} = require("%ui/hud/state/spectator_state.nut")
let { maxVolume, carriedVolume, canPickupItems,
      canModifyInventory, canLoadCharges } = require("%ui/hud/state/inventory_common_es.nut")
let { curTime } = require("%ui/hud/state/time_state.nut")
let {entityToUse, calcItemUseProgress} = require("%ui/hud/state/entity_use_state.nut")
let {syphoningItem, calcSyphoningProgress} = require("%ui/hud/state/am_storage_state.nut")
let {controlledHeroEid} = require("%ui/hud/state/controlled_hero.nut")
let { HERO_ITEM_CONTAINER, BACKPACK0, STASH, TRASH_BIN, DEBRIEFING_ITEM, GENES_MAIN
} = require("inventoryItemTypes.nut")
let {mkCountdownTimer} = require("%ui/helpers/timers.nut")
let {RequestLoadItemHolder, RequestUnloadItemHolder, RqCheckAmmoItemHolder, sendNetEvent} = require("dasevents")
let { moveMarker, moveMarkerWithTrigger} = require("%ui/hud/menus/components/moveMarker.nut")
let { fabs, ceil } = require("math")
let { buildInventoryItemTooltip } = require("%ui/hud/menus/components/inventoryItemTooltip.nut")
let { get_item_info, itemCompExtraInfoQuery } = require("%ui/hud/state/item_info.nut")
let { amTextIcon, creditsIcon } = require("%ui/mainMenu/currencyIcons.nut")
let { itemHeight } = require("%ui/hud/menus/components/inventoryStyle.nut")
let { isItemInTrashBin, trashBinItems } = require("%ui/hud/menus/components/trashBin.nut")
let { mkUnloadAmmoButton, mkLoadAmmoButton, mkStopLoadUnloadAmmoButton,
  mkCheckAmmoButton, mkStopCheckAmmoButton, mkItemCheckAmmoProgress
} = require("%ui/hud/menus/components/inventoryItemUtils.nut")
let { hoverHotkeysWatchedList } = require("%ui/components/pcHoverHotkeyHitns.nut")
let { hoverPcHotkeysPresentation } = require("%ui/hud/menus/components/inventoryActionsHints.nut")
let { MoveForbidReason, checkVolume, showInventoryOverflowOnUnequipToExMsgBox } = require("%ui/hud/menus/components/inventoryItemsListChecksCommon.nut")
let { mkDropMarkerFunc } = require("%ui/hud/menus/components/dropMarkerConstructor.nut")
let { mkRarityIconByItem } = require("%ui/hud/menus/components/inventoryItemRarity.nut")
let { isPreparationOpened } = require("%ui/mainMenu/raid_preparation_window_state.nut")
let { getItemPriceToShow, mkItemPrice } = require("%ui/mainMenu/market/inventoryToMarket.nut")
let { getSlotFromTemplate } = require("%ui/hud/menus/components/itemFromTemplate.nut")
let { mkFakeItem } = require("%ui/hud/menus/components/fakeItem.nut")
let { openSplitStacksWindow, canSplitStack } = require("%ui/hud/menus/components/splitStackWindow.nut")
let { mkText } = require("%ui/components/commonComponents.nut")
let {
  isAmmoForWeapon,
  isItemForSlot,
  isItemForWeaponMod,
  isItemForHolder
} = require("%ui/hud/state/inventory_item_relations.nut")

let storageIconsData = {
  backpack = {
    hintLocId = loc("item/itemInBackpack")
    icon = "ui/skin#backpack_slot_icon.svg:{0}:{0}:K"
  }
  stash = {
    hintLocId = loc("item/itemInStash")
    icon = "ui/skin#storage_slot_icon.svg:{0}:{0}:K"  
  }
  pouches = {
    hintLocId = loc("item/itemInPouches")
    icon = "ui/skin#pouches_slot_icon.svg:{0}:{0}:K"
  }
  safepack = {
    hintLocId = loc("item/itemInSafepack")
    icon = "ui/skin#safebox.svg:{0}:{0}:K"
  }
}

let itemBorderHoverColor = BtnBdHover
let itemFillColorActive = Color(20,20,20,205)
let itemFillColorRelevant = Color(85,65,45,180)
let itemFillColorHovered = BtnBgHover
let itemFillColorDef = colors.SelBgNormal



let itemShadedBg = @(opacity=null) {
  rendObj = ROBJ_SOLID
  color = Color(0,0,0,25)
  size = flex()
  opacity
}

let mkInventoryItemBlink = @(item){
  size = flex()
  children = {
    size = flex()
    rendObj = ROBJ_SOLID
    valign = ALIGN_CENTER
    color = Color(65,65,65,50)
  }
  opacity = 0.0

  animations = [
    { prop = AnimProp.opacity, from = 1.0, to = 0.0, duration = 0.475, trigger = $"inventory_item_blink_{item.eid}", easing = InOutBezier }
  ]
}

let mkPriceBlock = @(item) function() {
  let watch = isPreparationOpened
  if (!isPreparationOpened.get())
    return { watch }
  let price = getItemPriceToShow(item) ?? 0
  if (price <= 0)
    return { watch }
  return {
    watch
    vplace = ALIGN_TOP
    hplace = ALIGN_RIGHT
    padding = hdpx(2)
    children = mkItemPrice(price)
  }
}


function isItemCanBeDroppedToContainerInInventory(item, container) {
  let containerEid = container.eid
  if (containerEid == item.eid)
    return MoveForbidReason.OTHER

  if (item == null)
    return MoveForbidReason.OTHER
  if (
      !canModifyInventory.get() ||
      is_item_inventory_move_blocked(item?.eid ?? ecs.INVALID_ENTITY_ID)
    )
    return MoveForbidReason.OTHER

  if (!checkVolume(item, containerEid) && !is_can_move_to_safepack_with_overflow(containerEid, item.eid))
    return MoveForbidReason.VOLUME

  if (!is_can_move_item_to_item_container(item?.eid ?? ecs.INVALID_ENTITY_ID))
    return MoveForbidReason.OTHER

  return MoveForbidReason.NONE
}

function canDropItem(dragged_item, target_item, list_type) {
  if (! (list_type == HERO_ITEM_CONTAINER || list_type == BACKPACK0 || list_type == STASH ) &&
        (dragged_item?.fromList == HERO_ITEM_CONTAINER || dragged_item?.fromList == BACKPACK0 || dragged_item?.fromList == STASH) &&
        !is_item_use_blocked(dragged_item?.eid ?? ecs.INVALID_ENTITY_ID) && !is_item_use_blocked(target_item?.eid ?? ecs.INVALID_ENTITY_ID) )
    return MoveForbidReason.OTHER

  let notEmptyMagazine = dragged_item.maxAmmoCount <= 0 || dragged_item.ammoCount > 0

  if ( canLoadCharges.get() && (
        (isItemForHolder(dragged_item, target_item) && (target_item.maxCharges > target_item.charges || !(target_item?.countKnown ?? false))) ||
        (isItemForHolder(target_item, dragged_item) && ((dragged_item.count > 0 && notEmptyMagazine) || !(dragged_item?.countKnown ?? false)))
      )
    )
    return MoveForbidReason.NONE

  if (target_item?.itemContainerItems == null)
    return MoveForbidReason.OTHER

  return isItemCanBeDroppedToContainerInInventory(dragged_item, target_item)
}

function chargesIndicator(charges, maxVal, countKnown = true, mark = "", missedCount = 0) {
  if (charges == null || (charges == 0 && !maxVal))
    return null

  let current = ceil(charges).tointeger()
  let currentText = countKnown ? $"{current}" : "?"
  let firstVal = (maxVal == 0 && missedCount > 0) ? (charges - missedCount) : currentText
  let secondVal = maxVal > 0 ? maxVal
    : missedCount > 0 ? charges
    : null

  return mkText(secondVal ? $"{firstVal}/{secondVal}{mark}" : $"{currentText}{mark}", {
    padding = hdpx(3)
    hplace = ALIGN_CENTER
    vplace = ALIGN_BOTTOM
  }.__update(tiny_txt))
}

function addStorageType(item, stash, inventory, backpack, safepack) {
  let { uniqueId = null } = item
  if (uniqueId == null)
    return null
  let isInStash = stash.findvalue(@(v) v?.uniqueId == uniqueId) != null
  if (isInStash)
    return item.__merge({ itemStorage = "stash" })

  let isInBackpack = backpack.findvalue(@(v) v?.uniqueId == uniqueId) != null
  if (isInBackpack)
    return item.__merge({ itemStorage = "backpack" })

  let isInInventory = inventory.findvalue(@(v) v?.uniqueId == uniqueId) != null
  if (isInInventory)
    return item.__merge({ itemStorage = "pouches" })

  let isInSafepack = safepack.findvalue(@(v) v?.uniqueId == uniqueId) != null
  if (isInSafepack)
    return item.__merge({ itemStorage = "safepack" })
}

function mkStorageIcon(itemStorage) {
  if (itemStorage == null)
    return null
  let { hintLocId = "", icon = null } = storageIconsData?[itemStorage] ?? {}
  if (icon == null)
    return null

  return watchElemState(@(sf) {
    rendObj = ROBJ_IMAGE
    size = [hdpxi(20), hdpxi(20)]
    color = sf & S_HOVER ? Color(200, 200, 200) : Color(150, 150, 150)
    hplace = ALIGN_RIGHT
    keepAspect = true
    eventPassThrough = true
    margin = hdpx(4)
    behavior = Behaviors.Button
    onHover = @(on) setTooltip(on && hintLocId != "" ? loc(hintLocId) : null)
    image = Picture(icon.subst(hdpxi(20)))
  })
}


let modTypeColors = {
  magazine = Color(120, 120, 60)
  silencer = Color(60, 120, 120)
  scope = Color(120, 60, 120)
  boxedAmmo = Color(120, 120, 60)
  hasItemsInside = Color(120, 120, 120)
}


function mkModBox(mod_type, mod, icon_size, getTooltip, children=null) {
  let hasMod = mod != null
  let modColor = modTypeColors?[mod_type] ?? BtnBdNormal
  return {
    rendObj = ROBJ_BOX
    fillColor = hasMod ? modColor : Color(0,0,0,0)
    borderColor = modColor
    borderWidth = hdpx(1)
    size = [icon_size, icon_size]
    behavior = Behaviors.Button
    children
    function onHover(on) {
      if (on)
        setTooltip(getTooltip?())
      else
        setTooltip(null)
    }
  }
}

function modsIndicator(item) {
  let modIconSize = hdpx(9)
  let firstRow = []
  let secondRow = []
  local additionalTooltip = {}
  local bulletIndicator = null
  if (item?.mods.magazine != null && (item?.gunAmmo ?? 0) > 0 && (item?.gunBoxedAmmoTemplate ?? "") != "") {
    additionalTooltip.__update({ hasBulletInBarrel = true })
    bulletIndicator = {
      rendObj = ROBJ_BOX
      size = [ pw(50), ph(50) ]
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      fillColor = modTypeColors?["boxedAmmo"]
      borderColor = Color(0,0,0,100)
      borderWidth = hdpx(1)
    }
  }

  let isBuiltInAmmo = ((item?.gunDirectlyUseBoxedAmmo ?? false) && item?.gunBoxedAmmoTemplate != null)
  if (isBuiltInAmmo) {
    let hasAmmo = (item?.gunAmmo ?? 0) > 0
    firstRow.append(mkModBox(
                "boxedAmmo",
                hasAmmo ? {
                  itemName = $"items/{item.gunBoxedAmmoTemplate}"
                  ammoCount = item?.gunAmmo
                } : null,
                modIconSize,
                @() hasAmmo ?
                  buildInventoryItemTooltip(mkFakeItem(item.gunBoxedAmmoTemplate, {
                    ammoCount = item.gunAmmo
                    charges = item.gunAmmo
                  })) :
                  loc("slots/ammo")))
  }

  if ((item?.itemContainerItems?.len() ?? 0) > 0) {
    firstRow.append(mkModBox(
          "hasItemsInside",
          { itemName = "items/hasItemsInside"},
          modIconSize, @() additionalTooltip, bulletIndicator))
  }

  foreach (k, v in item?.mods ?? {}) {
    if (k in item?.fakeModes)
      continue
    let mod = item?.modInSlots[k].eid ?? ecs.INVALID_ENTITY_ID
    let isMagazine = k == "magazine"
    local getTooltip = null
    if (mod != ecs.INVALID_ENTITY_ID) {
      let info = get_item_info(mod)
      if (info?.itemProto.len())
        getTooltip = @() buildInventoryItemTooltip(info, isMagazine ? additionalTooltip : null)
    }
    else {
      let slotTemplName = v.slotTemplateName
      getTooltip = @() "\n".join([].append(
          loc(getSlotFromTemplate(slotTemplName)?.slotTooltip),
          bulletIndicator && isMagazine ? loc("Inventory/bullet_in_barrel") : null
        ).filter(@(str) str != null))
    }

    if (isMagazine) {
      firstRow.append(mkModBox(k, get_item_info(mod), modIconSize, getTooltip, bulletIndicator))
    }
    else {
      secondRow.append(mkModBox(k, get_item_info(mod), modIconSize, getTooltip))
    }
  }

  foreach (key, value in item?.fakeModes ?? {}) {
    let isMagazine = key == "magazine"
    let vItem = value
    let getTooltip = @() buildInventoryItemTooltip(vItem, isMagazine ? additionalTooltip : null)
    if (isMagazine)
      firstRow.append(mkModBox(key, value, modIconSize, getTooltip, bulletIndicator))
    else
      secondRow.append(mkModBox(key, value, modIconSize, getTooltip))
  }

  let gap = hdpx(1)
  let children = {
    flow = FLOW_VERTICAL
    gap
    children = [
      {
        flow = FLOW_HORIZONTAL
        children = firstRow
        gap
      }
      {
        flow = FLOW_HORIZONTAL
        children = secondRow
        gap
      }
    ]
  }
  return {
    flow = FLOW_HORIZONTAL
    gap = hdpx(2)
    padding = hdpx(2)
    hplace = ALIGN_LEFT
    vplace = ALIGN_BOTTOM
    size = SIZE_TO_CONTENT
    children
  }
}

let drawsPatternImage = {
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
  rendObj = ROBJ_IMAGE
  size = flex()
  color = Color(90, 90, 90, 50)
  image = Picture("!ui/skin#draws_pattern.svg:{0}:{0}:K".subst(sh(5)))
}

let magnifyingGlass = {
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
  rendObj = ROBJ_IMAGE
  size = [ pw(50), pw(50) ]
  color = Color(190, 190, 190)
  image = Picture("!ui/skin#magnifying_glass.svg:{0}:{0}:K".subst(sh(5)))

  animations = [
    { prop = AnimProp.opacity, from = 0.0, to = 1.0, duration = 0.35, play = true }
  ]
}

let recognizingComponent = {
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
  size = flex()
  children = magnifyingGlass
  transform = { }
  animations = [
    { prop = AnimProp.opacity, from = 1.0, to = 0.8, duration = 1.0, loop = true, play = true, easing = CosineFull }
    { prop = AnimProp.scale, from=[1.4,1.4], to=[1.1,1.1], duration=1.0, loop = true, play = true, easing=CosineFull }
  ]
}

let recognizingQueuedText = freeze({
  rendObj = ROBJ_TEXT
  text = "???"
  color = Color(110, 110, 110)
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
})


let corruptedItemImageBackground = freeze({
  rendObj = ROBJ_IMAGE
  size = [hdpxi(76), hdpxi(76)]
  color = corruptedItemColor
  image = Picture("ui/skin#corruptedBorder.svg:{0}:{0}:K".subst(hdpxi(76)))
})

let corruptedWeaponImageBackground = freeze({
  rendObj = ROBJ_IMAGE
  size = [flex(), hdpxi(76)]
  color = corruptedItemColor
  image = Picture("ui/skin#corruptedWeaponBorder.svg:{0}:{1}:K".subst(hdpxi(320), hdpxi(76)))
})

let highlightedItem = {
  rendObj = ROBJ_BOX
  borderColor = BtnBgHover
  borderWidth = hdpx(1)
  size = flex()
}

let zoneItemIcon = faComp("paw", {
  color = ContactOffline
  padding = hdpx(4)
  fontSize = hdpx(12)
  hplace = ALIGN_LEFT
  vplace = ALIGN_CENTER
  behavior = Behaviors.Button
  onHover = @(on) setTooltip(on ? loc("items/item_created_by_zone") : null)
  eventPassThrough = true
})

let isHovered = @(sf) (sf & (S_HOVER | S_DRAG)) > 0
let isItemDragged = @(item) draggedData.value?.eid == item.eid

let mkCountLabel = @(watchToTrack, itemCount, item, triggerName = null) function() {
  let { noSuitableItemForPresetFoundCount = 0, isCorrupted = false } = item
  let count = watchToTrack ? watchToTrack.get() : itemCount
  let text = noSuitableItemForPresetFoundCount > 0
    ? $"{count - noSuitableItemForPresetFoundCount}/{count}"
    : $"{loc("ui/multiply")}{count}"

  return {
    watch = watchToTrack
    rendObj = ROBJ_BOX
    fillColor = isCorrupted ? corruptedItemColor : Color(67, 67, 67)
    borderRadius = [0, 0, hdpx(5), 0]
    children = mkText(text, {
      padding = [ hdpx(3) ]
      transform = {}
      animations = triggerName == null ? null
        : [{ prop = AnimProp.scale, from = [1.33, 1.33], to = [1.0, 1.0], duration = 0.2,
            trigger = triggerName, easing = InOutBezier }]
    })
  }
}

function itemComp(stateFlags, item, opacity, list_type=null, itemIconParams=inventoryImageParams, isActionForbided = false) {
  let comps = itemCompExtraInfoQuery.perform(item?.eid ?? ecs.INVALID_ENTITY_ID, @(_eid, comp) comp)

  let itemCount = item.isBoxedItem ? item.ammoCount : item.count

  let backgroundColor = Computed(function() {
    if (item?.staticHoverViual == true || list_type?.name == DEBRIEFING_ITEM.name)
      return itemFillColorDef
    let focused_item = focusedData.get() ?? contextHoveredData.get()
    if (isItemForSlot(item, focused_item?.slot ?? focused_item?.slotName, focused_item?.attachedToEquipment) || isItemForWeaponMod(item, focused_item?.weaponModItems, focused_item?.weaponModAmmo))
      return itemFillColorRelevant
    if (isWeaponModsForItem(item, focused_item?.mods) || isWeaponModsForItem(focused_item, item?.mods))
      return itemFillColorRelevant
    if (isItemForHolder(focused_item, item)|| isItemForHolder(item, focused_item))
      return itemFillColorRelevant
    if (isAmmoForWeapon(focused_item, item) || isAmmoForWeapon(item, focused_item))
      return itemFillColorRelevant
    if (item?.forceLockIcon || item?.backgoundDisabled)
      return BtnBgDisabled
    if (item?.isItemToPurchase)
      return BtnBgHover
    if ((item?.noSuitableItemForPresetFoundCount ?? 0) > 0)
      return noItemContainerBg
    let isFocused = item.eid != 0 ? (focused_item?.eid ?? 0) == item.eid : (focused_item?.id ?? 0) == item.id
    
    let isActive = (stateFlags.get() & S_ACTIVE)
    return isActive ? itemFillColorActive
      : isFocused ? itemFillColorHovered : itemFillColorDef
  })

  let triggerName = item.isBoxedItem ? $"inventory_item_count_anim_{item.boxId}_ow_{item.owner}" : $"inventory_item_count_anim_{item.eid}"
  local itemCountLabel = null
  if (itemCount != 1 || item.alwaysShowCount){
    local wtch = null
    if (item.isBoxedItem && list_type != TRASH_BIN) {
      wtch = Computed(function() {
        let charges = item?.charges
        if (!charges)
          return itemCount
        let idx = isItemInTrashBin(item)
        if (idx == null)
          return charges

        let trash = trashBinItems.get()
        return charges - trash[idx].ammoCount
      })
    }
    itemCountLabel = mkCountLabel(wtch, itemCount, item, triggerName)
  }
  let borders = item?.highlightedItem ? highlightedItem :
    item.isCorrupted ? corruptedItemImageBackground : null

  return {
    size = flex()
    opacity = opacity
    children = [
      @() {
        watch = [stateFlags, carriedVolume, maxVolume, canPickupItems, entityToUse].append( item?.backgroundColor ? null : backgroundColor )
        size = flex()
        rendObj = ROBJ_BOX
        valign = ALIGN_CENTER
        fillColor = item?.backgroundColor ?? backgroundColor.get()
        borderColor = isItemDragged(item) || isHovered(stateFlags.get()) ? itemBorderHoverColor : 0
        borderWidth = isItemDragged(item) || isHovered(stateFlags.get()) ? hdpx(2.0) : 0
        children = [
          {
            size = flex()
            children = [
              inventoryItemImage(item, itemIconParams.__merge(item?.iconParamsOverride ?? {})),
              mkRarityIconByItem(item),
              !item?.isItemToPurchase ? null : creditsIcon(hdpxi(40), {
                hplace = ALIGN_RIGHT
                pos = [-hdpx(2), -hdpx(25)]
              }),
              list_type == GENES_MAIN ? null : modsIndicator(item),
              item.countPerStack == 1 || item?.isWeapon || (item?.isDelayedMoveMod ?? false) ? null : {
                size = flex()
                children = chargesIndicator(
                    item.isBoxedItem ? item.ammoCount : item.charges,
                    item.isBoxedItem ? 0 : item.maxCharges,
                    item?.countKnown ?? true,
                    item.isCorticalVault ? amTextIcon : "",
                    item?.noSuitableItemForPresetFoundCount ?? 0
                  )
              },
              borders,
              (item.isBoxedItem && item.countPerStack != 1) || (entityToUse.get() == item.eid && itemCount == 0) ? null : itemCountLabel,
              isActionForbided || !canLoadCharges.get() ? null : mkUnloadAmmoButton(item, list_type,
                comps?.item_holder__customUiProps?.unloadAmmoTooltip ?? "Inventory/unload_ammo",
                comps?.item_holder__customUiProps?.unloadAmmoIcon ?? "unload_magazine.svg"),
              isActionForbided || !canLoadCharges.get() ? null : mkLoadAmmoButton(item, list_type,
                comps?.item_holder__customUiProps?.loadAmmoTooltip ?? "Inventory/load_ammo",
                comps?.item_holder__customUiProps?.loadAmmoIcon ?? "load_magazine.svg"),
              isActionForbided || !canLoadCharges.get() ? null : mkStopLoadUnloadAmmoButton(item, list_type),
              isActionForbided ? null : mkCheckAmmoButton(item),
              isActionForbided ? null : mkStopCheckAmmoButton(item),
              item?.createdByZone ? zoneItemIcon : null
            ]
          }
        ]
      },
      mkStorageIcon(item?.itemStorage),
      mkInventoryItemBlink(item)
    ]
  }
}

let recognitionImagePattern = {
  size = flex()
  rendObj = ROBJ_BOX
  valign = ALIGN_CENTER
  fillColor = itemFillColorActive

  children = [
    {
      size = flex()
      children = [
        drawsPatternImage
      ]
    }
    recognizingQueuedText
  ]
}

let unrecognizedItemQueued = @(item) {
  size = flex()
  children = [
    recognitionImagePattern,
    mkInventoryItemBlink(item)
  ]
}

let unrecognizedItemInProgress = @(item, timeLeft) {
  size = flex()
  children = [
    item.recognizeTime > 0.0 ? @() {
      watch = timeLeft
      size = flex()
      rendObj = ROBJ_SOLID
      color = Color(105, 105, 105, 55)
      transform = {
        scale = [clamp(1.0 - (timeLeft?.get() ?? 0.0) / item.recognizeTime, 0.0, 1.0), 1.0]
        pivot = [0, 0]
      }
    } : null,
    {
      size = flex()
      rendObj = ROBJ_BOX
      valign = ALIGN_CENTER
      fillColor = itemFillColorActive

      children = [
        {
          size = flex()
          children = [
            drawsPatternImage
            recognizingComponent
          ]
        }
      ]
    },
    mkInventoryItemBlink(item)
  ]
}

function itemRecognizingComp(item) {
  return function() {
    let isRecognizingInProgress = fabs(item.recognizeTime - item.recognizeTimeLeft) > 1e-6

    let completeTimeLeft = isRecognizingInProgress ? Watched(item.syncTime + item.recognizeTimeLeft) : null
    let timeLeft = completeTimeLeft != null ? mkCountdownTimer(completeTimeLeft) : null

    return isRecognizingInProgress ? unrecognizedItemInProgress(item, timeLeft) : unrecognizedItemQueued(item)
  }
}

let itemAnims = [
  { prop=AnimProp.scale, from=[1,0.01], to=[1,1], duration=0.1, play=true, easing=OutCubic }
  { prop=AnimProp.opacity, from=0, to=1, duration=0.1, play=true, easing=OutCubic }
  { prop=AnimProp.scale, from=[1,1], to=[1,0.01], duration=0.1, playFadeOut=true, easing=OutCubic }
  { prop=AnimProp.opacity, from=1, to=0, duration=0.1, playFadeOut=true, easing=OutCubic }
]

let itemLockComp = faComp("lock", {
  color = Inactive
  padding = hdpx(4)
  fontSize = hdpx(11)
  hplace = ALIGN_RIGHT
  vplace = ALIGN_TOP
})

function inventoryItem(item, list_type, custom_actions = {}, inventoryItemSize=[itemHeight,itemHeight],
  itemIconParams=inventoryImageParams, isActionForbided = false
) {
  function dragMode(on, it) {
    draggedData.update(on ? it : null)
  }

  
  let stateFlags = Watched(0)
  let group = ElemGroup()

  let contextItem = item.__merge({fromList=list_type})

  function onClickAction(event) {
    if (isActionForbided)
      return
    if (event.button == 0) {
      if (isShiftPressed.get())
        custom_actions?.lmbShiftAction(item)
      else if (isAltPressed.get())
        custom_actions?.lmbAltAction(item)
      else
        custom_actions?.lmbAction(item)
    }
    else if (event.button == 1) {
      if (isShiftPressed.get())
        custom_actions?.rmbShiftAction(item)
      else if (isAltPressed.get())
        custom_actions?.rmbAltAction(item)
      else
        custom_actions?.rmbAction(item, event)
    }
  }

  local descLoc = null

  let ItemWithActions = contextItem.__merge(custom_actions)

  function onHover(on, elemPose) {
    custom_actions?.onHover(on, item)
    if (on) {
      descLoc = buildInventoryItemTooltip(ItemWithActions)
      focusedData.update(ItemWithActions)
      setTooltip(descLoc, elemPose)
      let pcHotkeysHints = isActionForbided ? null : hoverPcHotkeysPresentation?[list_type?.name](item)
      hoverHotkeysWatchedList.set(pcHotkeysHints)
    } else {
      setTooltip(null)
      focusedData.update(null)
      hoverHotkeysWatchedList.set(null)
    }
  }

  let uniqueKey = "".concat((item?.eid ?? item?.id ?? item?.itemName), "x", (item?.count ?? 0), (item?.countPerItem ?? 0))
  function itemUseProgressComp(){
    let showProgress = entityToUse.get() == item.eid || item.eids.indexof(entityToUse.get()) != null
    let progressVal = showProgress ? clamp(calcItemUseProgress(curTime.get()).tointeger(), 0, 100) : 0.0
    return {
      size = [pw(progressVal), pw(1) ]
      rendObj=ROBJ_SOLID color=Color(100,120,90,40)
      vplace = ALIGN_BOTTOM
      margin = fsh(0.1)
      watch = showProgress ? [curTime, entityToUse] : entityToUse
    }
  }
  function itemSyphoningTickComp(){
    let progressNeeded = syphoningItem.get() == item.eid || item.eids.indexof(syphoningItem.get()) != null
    let itemSyphoningProgressVal = progressNeeded ? clamp(calcSyphoningProgress(curTime.get()).tointeger(), 0, 100) : 0.0
    return {
      size = [pw(itemSyphoningProgressVal), pw(1) ]
      rendObj=ROBJ_SOLID color=Color(100,120,90,40)
      vplace = ALIGN_BOTTOM
      margin = fsh(0.1)
      watch = !progressNeeded ? syphoningItem : [curTime, syphoningItem]
    }
  }
  let xmbNode = XmbNode()

  let isRecognizingRequired = item.recognizeTimeLeft > 0.0

  function canDrop(data) {
    if (data.eid == ecs.INVALID_ENTITY_ID)
      return MoveForbidReason.OTHER
    return canDropItem(data, item, list_type)
  }

  function onDrop(data) {
    if (item?.itemContainerItems) {
      
      
      
      let isOverflow = (is_equip_to_slot_cause_inventory_overflow(ecs.INVALID_ENTITY_ID, data?.slotName, item.eid) ||
        is_equip_to_slot_cause_from_pocket_drop(ecs.INVALID_ENTITY_ID, data?.slotName, item.eid))
      if (isOverflow)
        showInventoryOverflowOnUnequipToExMsgBox(@() move_stack_to_inventory(data?.eids ?? [data.eid], item.eid, 1))
      else {
        local itemCount = 1
        if (isShiftPressed.get()) {
          itemCount = (data?.isBoxedItem ?? false) ? data.ammoCount : data?.count ?? 0
        }
        else if (isAltPressed.get()) {
          if (canSplitStack(data)) {
            openSplitStacksWindow(data, @(count) move_stack_to_inventory(data?.eids ?? [data.eid], item.eid, count))
            return
          }
        }
        move_stack_to_inventory(data?.eids ?? [data.eid], item.eid, itemCount)
      }
    }
    else if (isItemForHolder(data, item)) {
      if ((item?.charges ?? 0) < item.maxCharges)
        sendNetEvent(controlledHeroEid.value, RequestLoadItemHolder({targetItemEid=item.eid, containerEid=data.owner, searchOtherContainers=false}))
      else
        ecs.g_entity_mgr.sendEvent(controlledHeroEid.value, RqCheckAmmoItemHolder({targetItemEid=item.eid, containerEid=item.owner}))
    }
    else if (isItemForHolder(item, data)) {
      if ((data?.charges ?? 0) > 0)
        sendNetEvent(controlledHeroEid.value, RequestUnloadItemHolder({targetItemEid=data.eid, containerEid=item.owner}))
    }
  }
  let itemOpacity = item?.noSuitableItemForPresetFoundCount != null ? 0.5 : null
  return function() {
    let needBlink = (item?.isDelayedMoveMod ?? false)
    if (item?.owner == null)
      log($"Item has no onwer {item}")
    let isPickable = (item?.owner ?? ecs.INVALID_ENTITY_ID) != ecs.INVALID_ENTITY_ID || canPickupItems.get()
    let needDragAndDrop = (item?.isDragAndDropAvailable ?? true) && isPickable
    let isStubItem = item?.isStubItem ?? false
    let opacity = itemOpacity ?? (!(item?.inactiveItem ?? false) ? 1.0 : 0.3)
    return {
      key = uniqueKey
      size = inventoryItemSize
      watch = canPickupItems

      function onElemState(sf) {
        stateFlags.set(sf)
      }

      behavior = isRecognizingRequired ? null
        : isSpectator.get() || !needDragAndDrop || isActionForbided ? Behaviors.Button
        : Behaviors.DragAndDrop
      group
      sound = const {
        click  = "ui_sounds/button_click_inactive"
        hover  = "ui_sounds/menu_highlight"
      }
      xmbNode = xmbNode
      onHover = onHover
      dropData = !isStubItem ? contextItem : null
      onDragMode = dragMode
      dragMouseButton = 0
      onClick = onClickAction
      canDrop = @(v) canDrop(v) == MoveForbidReason.NONE,
      onDrop = onDrop,
      transform = const {
        pivot = [0, 0.2]
      }
      children = [
        isRecognizingRequired ? itemRecognizingComp(item)
          : itemComp(stateFlags, item, opacity, list_type, itemIconParams, isActionForbided),
        (!isPickable || item?.forceLockIcon) ? itemLockComp : null,
        itemUseProgressComp,
        mkItemCheckAmmoProgress(item),
        itemSyphoningTickComp,
        needBlink ? moveMarker(stateFlags.get(), opacity) : null,
        item.isBoxedItem ? moveMarkerWithTrigger(stateFlags.get(), 1.0, $"boxed_item_blink_{item.eid}") : null,
        mkDropMarkerFunc(stateFlags, canDrop, draggedData, ""),
        (item?.noSuitableItemForPresetFoundCount ?? 0) > 0 ? mkPriceBlock(item) : null
      ]
      animations = itemAnims
    }
  }
}

function mkChocolatePriceBlock(item, price) {
  let priceToShow = price > 0 ? price : getItemPriceToShow(item)
  if (priceToShow <= 0)
    return null
  return {
    hplace = ALIGN_RIGHT
    vplace = ALIGN_TOP
    pos = [-hdpx(1), hdpx(1)]
    children = mkItemPrice(priceToShow)
  }
}

function chocolateItemComp(stateFlags, item) {
  let { isBoxedItem = false, ammoCount = 0, count = 0, alwaysShowCount = false, charges = null,
    iconParamsOverride = {}, isWeapon = false, isDelayedMoveMod = false, countPerStack = 0,
    maxCharges = 0, countKnown = true, isCorticalVault = false, noSuitableItemForPresetFoundCount = 0,
    eid = ecs.INVALID_ENTITY_ID, createdByZone = false, itemStorage = null, marketPrice = null,
    isCorrupted = false
  } = item

  let itemCount = isBoxedItem ? ammoCount : count
  local itemCountLabel = null
  if (itemCount != 1 || alwaysShowCount) {
    local watchedToTrack = null
    if (isBoxedItem) {
      watchedToTrack = Computed(function() {
        if (!charges)
          return itemCount
        let idx = isItemInTrashBin(item)
        if (idx == null)
          return charges

        let trash = trashBinItems.get()
        return charges - trash[idx].ammoCount
      })
    }
    itemCountLabel = mkCountLabel(watchedToTrack, itemCount, item)
  }
  let borders = isCorrupted ? corruptedItemImageBackground : null
  return {
    size = flex()
    children = [
      @() {
        watch = stateFlags
        rendObj = ROBJ_SOLID
        size = flex()
        color = stateFlags.get() & S_HOVER ? itemFillColorHovered : itemFillColorDef
      }
      {
        size = flex()
        children = [
          borders
          inventoryItemImage(item, inventoryImageParams.__merge(iconParamsOverride))
          mkRarityIconByItem(item)
          modsIndicator(item)
          countPerStack == 1 || isWeapon || isDelayedMoveMod ? null : chargesIndicator(
            isBoxedItem ? ammoCount : charges,
            isBoxedItem ? 0 : maxCharges,
            countKnown ?? true,
            isCorticalVault ? amTextIcon : "",
            noSuitableItemForPresetFoundCount)
          @() {
            watch = entityToUse
            size = flex()
            children = (isBoxedItem && countPerStack != 1) || (entityToUse.get() == eid && itemCount == 0) ? null
              : itemCountLabel
          }
          createdByZone ? zoneItemIcon : null
        ]
      }
      itemStorage == null ? null : mkStorageIcon(itemStorage)
      marketPrice == null ? null : mkChocolatePriceBlock(item, marketPrice)
    ]
  }
}

function chocolateInventoryItem(item) {
  let stateFlags = Watched(0)
  return {
    size = [itemHeight,itemHeight]
    onElemState = @(sf) stateFlags.set(sf)
    children = chocolateItemComp(stateFlags, item)
  }
}

function inventoryItemPanel(panelData, list_type, custom_actions = {}, inventoryItemSize=[itemHeight,itemHeight],
  itemIconParams=inventoryImageParams, isActionForbided  = false
) {
  let isVisible = panelData.isVisible
  let itemDataGeneration = panelData.itemDataGeneration
  return @()
    {
      size = inventoryItemSize
      watch = isVisible

      children = !isVisible.get() ? null : @() {
        size = inventoryItemSize
        children = panelData.itemData == null ? itemShadedBg(0.5)
          : inventoryItem(panelData.itemData, list_type, custom_actions, inventoryItemSize, itemIconParams, isActionForbided)
        watch = itemDataGeneration
      }
    }
}

return {
  inventoryItem
  inventoryItemPanel
  chargesIndicator
  itemShadedBg
  corruptedItemImageBackground
  corruptedWeaponImageBackground
  addStorageType
  mkStorageIcon
  itemRecognizingComp
  itemComp
  chocolateInventoryItem

  itemFillColorHovered
  itemFillColorDef
  recognitionImagePattern
}
