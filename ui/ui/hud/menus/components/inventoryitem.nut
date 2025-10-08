from "das.inventory" import is_item_use_blocked, is_can_move_item_to_item_container, is_item_inventory_move_blocked, move_stack_to_inventory,
  is_equip_to_slot_cause_from_pocket_drop, is_equip_to_slot_cause_inventory_overflow, is_can_move_to_safepack_with_overflow, is_can_unfold_in_parent
from "%ui/hud/state/inventory_state.nut" import isWeaponModsForItem
from "%ui/hud/menus/components/inventoryItemUtils.nut" import mkUnloadAmmoButton, mkLoadAmmoButton, mkStopLoadUnloadAmmoButton, mkCheckAmmoButton,
  mkStopCheckAmmoButton, mkItemCheckAmmoProgress
from "%ui/hud/state/inventory_item_relations.nut" import isAmmoForWeapon, isItemForSlot, isItemForWeaponMod, isItemForHolder

from "%ui/fonts_style.nut" import tiny_txt
import "%ui/components/faComp.nut" as faComp
from "%ui/hud/menus/components/inventoryItemImages.nut" import inventoryItemImage
from "%ui/components/commonComponents.nut" import mkText
from "%ui/components/cursors.nut" import setTooltip
from "%ui/hud/state/entity_use_state.nut" import calcItemUseProgress
from "%ui/helpers/timers.nut" import mkCountdownTimer
from "dasevents" import RequestLoadItemHolder, RequestUnloadItemHolder, RqCheckAmmoItemHolder, sendNetEvent
from "%ui/hud/menus/components/moveMarker.nut" import moveMarker, moveMarkerWithTrigger
from "math" import fabs, ceil
from "%ui/hud/menus/components/inventoryItemTooltip.nut" import buildInventoryItemTooltip
from "%ui/hud/state/item_info.nut" import get_item_info
from "%ui/mainMenu/currencyIcons.nut" import creditsIcon
from "%ui/hud/menus/components/inventoryStyle.nut" import itemHeight
from "%ui/hud/menus/components/inventoryItemsListChecksCommon.nut" import MoveForbidReason, checkVolume, showInventoryOverflowOnUnequipToExMsgBox
from "%ui/hud/menus/components/dropMarkerConstructor.nut" import mkDropMarkerSmallArea
from "%ui/hud/menus/components/inventoryItemRarity.nut" import mkRarityIconByItem
from "%ui/mainMenu/market/inventoryToMarket.nut" import getItemPriceToShow, mkItemPrice, getLotFromItem, getPriceFromLot
from "%ui/hud/menus/components/itemFromTemplate.nut" import getSlotFromTemplate
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem
from "%dngscripts/sound_system.nut" import sound_play
from "%ui/hud/menus/components/splitStackWindow.nut" import openSplitStacksWindow, canSplitStack
from "%ui/hud/state/local_player.nut" import localPlayerTeam
from "%ui/hud/menus/components/inventoryItemNexusPointPriceComp.nut" import nexusPointsCostComp

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
import "%ui/components/colors.nut" as colors
import "%ui/hud/state/get_player_team.nut" as get_player_team
import "%ui/hud/state/is_teams_friendly.nut" as is_teams_friendly

let { BtnBgHover, BtnBdHover, BtnBdNormal, BtnBgDisabled, Inactive, noItemContainerBg,
  corruptedItemColor } = colors
let { inventoryImageParams } = require("%ui/hud/menus/components/inventoryItemImages.nut")
let { focusedData, draggedData, contextHoveredData, isShiftPressed, isAltPressed, mutationForbidenDueToInQueueState } = require("%ui/hud/state/inventory_state.nut")
let { isSpectator } = require("%ui/hud/state/spectator_state.nut")
let { maxVolume, carriedVolume, canPickupItems, canModifyInventory, canLoadCharges } = require("%ui/hud/state/inventory_common_es.nut")
let { curTime } = require("%ui/hud/state/time_state.nut")
let { entityToUse } = require("%ui/hud/state/entity_use_state.nut")
let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")
let { HERO_ITEM_CONTAINER, BACKPACK0, STASH, DEBRIEFING_ITEM, GENES_MAIN, SAFEPACK } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { getInventoryEidByListType } = require("%ui/hud/state/inventory_eids_common.nut")
let { itemCompExtraInfoQuery } = require("%ui/hud/state/item_info.nut")
let { hoverHotkeysWatchedList } = require("%ui/components/pcHoverHotkeyHitns.nut")
let { hoverPcHotkeysPresentation } = require("%ui/hud/menus/components/inventoryActionsHints.nut")
let { isListMutableDueQueue } = require("%ui/hud/menus/components/inventoryItemsListChecks.nut")
let { itemsInRefiner } = require("%ui/hud/menus/inventories/refinerInventoryCommon.nut")
let { selfMemberState } = require("%ui/squad/squadState.nut")

#allow-auto-freeze

enum RecognitionStages {  
  Queue
  Started
  Finished
}

let storageIconsData = {
  backpack0 = {
    hintLocId = loc("item/itemInBackpack")
    icon = "ui/skin#backpack_slot_icon.svg:{0}:{0}:K"
  }
  stash = {
    hintLocId = loc("item/itemInStash")
    icon = "ui/skin#storage_slot_icon.svg:{0}:{0}:K"  
  }
  inventory = {
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

function mkPriceBlock(item) {
  let priceData = getItemPriceToShow(item)
  if ((priceData?.price ?? 0) <= 0)
    return null
  return {
    vplace = ALIGN_TOP
    hplace = ALIGN_RIGHT
    padding = hdpx(2)
    children = mkItemPrice(priceData)
  }
}

let lockedIcon = faComp("lock", {
  color = Color(200, 200, 200, 255)
  fontSize = hdpx(42)
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
})

function lockedIconOnHover(stateFlags) {
  return function() {
    let sf = stateFlags.get()
    return {
      watch = [ stateFlags, mutationForbidenDueToInQueueState ]
      size = flex()
      children = ( mutationForbidenDueToInQueueState.get() && (sf & S_HOVER) ) ? lockedIcon : null
    }
  }
}


function isItemCanBeDroppedToContainerInInventory(item, container) {
  let containerEid = container.eid
  if (containerEid == item.eid)
    return MoveForbidReason.OTHER
  if (container?.inventoryEid != null
    && container?.inventoryEid != ecs.INVALID_ENTITY_ID
    && container?.inventoryEid == getInventoryEidByListType(STASH)
  )
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

  if (item?.refiner__fromList != null || !is_can_move_item_to_item_container(item?.eid ?? ecs.INVALID_ENTITY_ID))
    return MoveForbidReason.OTHER

  return MoveForbidReason.NONE
}

function canDropItem(dragged_item, target_item, list_type) {
  if (!is_can_unfold_in_parent(target_item.eid))
    return MoveForbidReason.PARENT_VOLUME_OVERFLOW

  if (! (list_type == HERO_ITEM_CONTAINER || list_type == BACKPACK0 || list_type == STASH ) &&
        (dragged_item?.fromList == HERO_ITEM_CONTAINER || dragged_item?.fromList == BACKPACK0 || dragged_item?.fromList == STASH) &&
        !is_item_use_blocked(dragged_item?.eid ?? ecs.INVALID_ENTITY_ID) && !is_item_use_blocked(target_item?.eid ?? ecs.INVALID_ENTITY_ID) )
    return MoveForbidReason.OTHER

  let notEmptyMagazine = dragged_item.maxAmmoCount <= 0 || dragged_item.ammoCount > 0

  if ( canLoadCharges.get() && (
        (isItemForHolder(dragged_item, target_item) && (target_item.maxCharges > target_item.charges || !(target_item?.countKnown ?? false))) ||
        (isItemForHolder(target_item, dragged_item) && ((dragged_item.count > 0 && notEmptyMagazine) || !(dragged_item?.countKnown ?? false)))
      )
    ) {
    if (mutationForbidenDueToInQueueState.get()) {
      if (selfMemberState.get()?.ready)
        return MoveForbidReason.FORBIDDEN_READY_STATUS
      else
        return MoveForbidReason.FORBIDDEN_QUEUE_STATUS
    }
    else
      return MoveForbidReason.NONE
  }

  if (target_item?.itemContainerItems == null)
    return MoveForbidReason.OTHER

  let canDropToInventory = isItemCanBeDroppedToContainerInInventory(dragged_item, target_item)

  if (canDropToInventory == MoveForbidReason.NONE && mutationForbidenDueToInQueueState.get()) {
    if (
        !isListMutableDueQueue(dragged_item?.fromList) || 
        list_type?.name == HERO_ITEM_CONTAINER.name ||
        list_type?.name == BACKPACK0.name ||
        list_type?.name == SAFEPACK.name
    ) {
      if (selfMemberState.get()?.ready)
        return MoveForbidReason.FORBIDDEN_READY_STATUS
      else
        return MoveForbidReason.FORBIDDEN_QUEUE_STATUS
    }
  }

  return canDropToInventory
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
    return item.__merge({ itemStorage = "backpack0" })

  let isInInventory = inventory.findvalue(@(v) v?.uniqueId == uniqueId) != null
  if (isInInventory)
    return item.__merge({ itemStorage = "inventory" })

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
  let stateFlags = Watched(0)
  return function() {
    let sf = stateFlags.get()
    return {
      watch = stateFlags
      onElemState = @(s) stateFlags.set(s)
      rendObj = ROBJ_IMAGE
      size = hdpxi(20)
      color = sf & S_HOVER ? Color(200, 200, 200) : Color(150, 150, 150)
      hplace = ALIGN_RIGHT
      keepAspect = true
      eventPassThrough = true
      skipDirPadNav = true
      margin = hdpx(4)
      behavior = Behaviors.Button
      onHover = @(on) setTooltip(on && hintLocId != "" ? loc(hintLocId) : null)
      image = Picture(icon.subst(hdpxi(20)))
    }
  }
}


let modTypeColors = {
  magazine = Color(120, 120, 60)
  silencer = Color(60, 120, 120)
  scope = Color(120, 60, 120)
  boxedAmmo = Color(120, 120, 60)
  hasItemsInside = Color(120, 120, 120)
  tactical_right = Color(125, 75, 50)
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
    skipDirPadNav = true
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
  #forbid-auto-freeze
  let modIconSize = hdpx(9)
  let firstRow = []
  let secondRow = []
  local additionalTooltip = {}
  local bulletIndicator = null
  #allow-auto-freeze
  if (item?.mods.magazine != null && (item?.gunAmmo ?? 0) > 0 && (item?.gunBoxedAmmoTemplate ?? "") != "") {
    additionalTooltip.__update({ hasBulletInBarrel = true })
    bulletIndicator = {
      rendObj = ROBJ_BOX
      size = static [ pw(50), ph(50) ]
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
  size = pw(50)
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
  size = hdpxi(76)
  color = corruptedItemColor
  image = Picture("ui/skin#corruptedBorder.svg:{0}:{0}:K".subst(hdpxi(76)))
})
let corticalVaultItemImageBackground = freeze({
  rendObj = ROBJ_IMAGE
  size = hdpxi(76)
  color = colors.OrangeHighlightColor
  opacity = 0.6
  transform = {}
  image = Picture("ui/skin#round_grad.svg:{0}:{0}:K".subst(hdpxi(76)))
  animations = [
    { prop=AnimProp.scale, from=[1.0, 1.0], to=[0.9, 0.9], duration=0.5, easing=InOutSine, trigger="scale_pulse_0", onExit="scale_pulse_1", play=true }
    { prop=AnimProp.scale, from=[0.9, 0.9], to=[1.0, 1.0], duration=0.5, easing=InOutSine, trigger="scale_pulse_1", onExit="scale_pulse_2" }
    { prop=AnimProp.scale, from=[1.0, 1.0], to=[0.9, 0.9], duration=0.5, easing=InOutSine, trigger="scale_pulse_2", onExit="scale_pulse_3" }
    { prop=AnimProp.scale, from=[0.9, 0.9], to=[1.0, 1.0], duration=0.5, easing=InOutSine, trigger="scale_pulse_3", onExit="scale_pulse_4" }
    { prop=AnimProp.scale, from=[1.0, 1.0], to=[1.0, 1.0], duration=0.5, easing=InOutSine, trigger="scale_pulse_4", onExit="scale_pulse_0" }
    { prop=AnimProp.opacity, from=0.6, to=0.2, duration=0.5, easing=InOutSine, trigger="opacity_pulse_0", onExit="opacity_pulse_1", play=true }
    { prop=AnimProp.opacity, from=0.2, to=0.6, duration=0.5, easing=InOutSine, trigger="opacity_pulse_1", onExit="opacity_pulse_2" }
    { prop=AnimProp.opacity, from=0.6, to=0.2, duration=0.5, easing=InOutSine, trigger="opacity_pulse_2", onExit="opacity_pulse_3" }
    { prop=AnimProp.opacity, from=0.2, to=0.6, duration=0.5, easing=InOutSine, trigger="opacity_pulse_3", onExit="opacity_pulse_4" }
    { prop=AnimProp.opacity, from=0.6, to=0.6, duration=0.5, easing=InOutSine, trigger="opacity_pulse_4", onExit="opacity_pulse_0" }
  ]
})
let corruptedWeaponImageBackground = freeze({
  rendObj = ROBJ_IMAGE
  size = static [flex(), hdpxi(76)]
  color = corruptedItemColor
  image = Picture("ui/skin#corruptedWeaponBorder.svg:{0}:{1}:K".subst(hdpxi(320), hdpxi(76)))
})

let highlightedItem = {
  rendObj = ROBJ_BOX
  borderColor = BtnBgHover
  borderWidth = hdpx(1)
  size = flex()
}

let isHovered = @(sf) (sf & (S_HOVER | S_DRAG)) > 0
let isItemDragged = @(item) draggedData.get()?.eid == item.eid

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
      padding = hdpx(3)
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
    if (isItemForSlot(item, focused_item?.currentWeaponSlotName ?? focused_item?.slotName, focused_item?.attachedToEquipment) || isItemForWeaponMod(item, focused_item?.allowed_items, focused_item?.weaponModAmmo))
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

  let triggerName = item.isBoxedItem ?
    $"inventory_item_count_anim_{item.boxTemplate}_ow_{item.inventoryEid}" :
    $"inventory_item_count_anim_{item.eid}"
  local itemCountLabel = null
  if (itemCount != 1 || item.alwaysShowCount){
    itemCountLabel = mkCountLabel(null, itemCount, item, triggerName)
  }

  let isFriendlyCorticalVault = item?.playerOwnerEid && item?.playerOwnerEid != ecs.INVALID_ENTITY_ID
    && is_teams_friendly(localPlayerTeam.get(), get_player_team(item.playerOwnerEid))

  let borders = item?.highlightedItem ? highlightedItem :
      item.isCorrupted ? corruptedItemImageBackground : null
  let friendlyCorticalVaultGlow= isFriendlyCorticalVault ? corticalVaultItemImageBackground : null

  return {
    size = flex()
    opacity = opacity
    children = [
      @() {
        watch = [stateFlags, carriedVolume, maxVolume, canPickupItems, entityToUse, mutationForbidenDueToInQueueState].append( item?.backgroundColor ? null : backgroundColor )
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
              friendlyCorticalVaultGlow,
              inventoryItemImage(item, itemIconParams.__merge(item?.iconParamsOverride ?? {})),
              mkRarityIconByItem(item),
              nexusPointsCostComp(item?.nexusCost),
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
                    "",
                    item?.noSuitableItemForPresetFoundCount ?? 0
                  )
              },
              borders,
              (item.isBoxedItem && item.countPerStack != 1) || (entityToUse.get() == item.eid && itemCount == 0) ? null : itemCountLabel,
              isActionForbided || !canLoadCharges.get() || (mutationForbidenDueToInQueueState.get() && !isListMutableDueQueue(list_type)) ? null :
                mkUnloadAmmoButton(item, list_type,
                  comps?.item_holder__customUiProps?.unloadAmmoTooltip ?? "Inventory/unload_ammo",
                  comps?.item_holder__customUiProps?.unloadAmmoIcon ?? "unload_magazine.svg"),
              isActionForbided || !canLoadCharges.get() || (mutationForbidenDueToInQueueState.get() && !isListMutableDueQueue(list_type)) ? null :
                mkLoadAmmoButton(item, list_type,
                  comps?.item_holder__customUiProps?.loadAmmoTooltip ?? "Inventory/load_ammo",
                  comps?.item_holder__customUiProps?.loadAmmoIcon ?? "load_magazine.svg"),
              isActionForbided || !canLoadCharges.get() || (mutationForbidenDueToInQueueState.get() && !isListMutableDueQueue(list_type)) ? null :
                mkStopLoadUnloadAmmoButton(item, list_type),
              isActionForbided ? null : mkCheckAmmoButton(item),
              isActionForbided ? null : mkStopCheckAmmoButton(item),
              !isListMutableDueQueue(list_type) ? lockedIconOnHover(stateFlags) : null
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

let unrecognizedItemInProgress = @(item, timeLeft, cb) {
  size = flex()
  children = [
    item.recognizeTime > 0.0 ? function() {
      cb?(RecognitionStages.Started)
      if (timeLeft.get() <= 0)
        cb?(RecognitionStages.Finished)
      return {
        watch = timeLeft
        rendObj = ROBJ_SOLID
        size = flex()
        color = Color(105, 105, 105, 55)
        transform = {
          scale = [clamp(1.0 - (timeLeft?.get() ?? 0.0) / item.recognizeTime, 0.0, 1.0), 1.0]
          pivot = static [0, 0]
        }
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

function itemRecognizingComp(item, cb = null) {
  return function() {
    let isRecognizingInProgress = fabs(item.recognizeTime - item.recognizeTimeLeft) > 1e-6

    let completeTimeLeft = isRecognizingInProgress ? Watched(item.syncTime + item.recognizeTimeLeft) : null
    let timeLeft = completeTimeLeft != null ? mkCountdownTimer(completeTimeLeft, item?.itemTemplate) : null
    return isRecognizingInProgress ? unrecognizedItemInProgress(item, timeLeft, cb) : unrecognizedItemQueued(item)
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
    draggedData.set(on ? it : null)
    if (on)
      sound_play("ui_sounds/inventory_item_take")
  }
  #forbid-auto-freeze
  
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
  #forbid-auto-freeze
  function onHover(on, elemPose) {
    custom_actions?.onHover(on, item)
    if (on) {
      descLoc = buildInventoryItemTooltip(ItemWithActions)
      focusedData.set(ItemWithActions)
      setTooltip(descLoc, elemPose)
      let pcHotkeysHints = isActionForbided ? null : hoverPcHotkeysPresentation?[list_type?.name](item)
      hoverHotkeysWatchedList.set(pcHotkeysHints)
    } else {
      setTooltip(null)
      focusedData.set(null)
      hoverHotkeysWatchedList.set(null)
    }
  }

  let uniqueKey = "".concat((item?.eid ?? item?.id ?? item?.itemName), "x", (item?.count ?? 0), (item?.countPerItem ?? 0))
  function itemUseProgressComp(){
    let showProgress = (entityToUse.get() == item.eid || item.eids.indexof(entityToUse.get()) != null) && !(item?.isDelayedMoveMod ?? false)
    let progressVal = showProgress ? clamp(calcItemUseProgress(curTime.get()).tointeger(), 0, 100) : 0.0
    return {
      size = [pw(progressVal), pw(1) ]
      rendObj=ROBJ_SOLID color=Color(100,120,90,40)
      vplace = ALIGN_BOTTOM
      margin = fsh(0.1)
      watch = showProgress ? [curTime, entityToUse] : entityToUse
    }
  }
  let xmbNode = XmbNode()

  let isRecognizingRequired = item.recognizeTimeLeft > 0.0

  function canDrop(data) {
    if (data == null)
      return null

    if (data.eid == ecs.INVALID_ENTITY_ID)
      return MoveForbidReason.OTHER
    return canDropItem(data, item, list_type)
  }

  function onDrop(data) {
    if (item?.itemContainerItems) {
      
      
      
      let isOverflow = (is_equip_to_slot_cause_inventory_overflow(ecs.INVALID_ENTITY_ID, data?.slotName, item.eid) ||
        is_equip_to_slot_cause_from_pocket_drop(ecs.INVALID_ENTITY_ID, data?.slotName, item.eid))
      if (isOverflow) {
        sound_play("ui_sounds/button_click_inactive")
        showInventoryOverflowOnUnequipToExMsgBox(@() move_stack_to_inventory(data?.eids ?? [data.eid], item.eid, 1))
      }
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
        sendNetEvent(controlledHeroEid.get(), RequestLoadItemHolder({targetItemEid=item.eid, containerEid=data.inventoryEid, searchOtherContainers=false}))
      else
        ecs.g_entity_mgr.sendEvent(controlledHeroEid.get(), RqCheckAmmoItemHolder({targetItemEid=item.eid, containerEid=item.inventoryEid}))
    }
    else if (isItemForHolder(item, data)) {
      if ((data?.charges ?? 0) > 0)
        sendNetEvent(controlledHeroEid.get(), RequestUnloadItemHolder({targetItemEid=data.eid, containerEid=item.inventoryEid}))
    }
  }
  let itemOpacity = item?.noSuitableItemForPresetFoundCount != null ? 0.5 : null
  return function() {
    let needBlink = (item?.isDelayedMoveMod ?? false)
    if (item?.inventoryEid == null)
      log($"Item has no onwer {item}")
    let isPickable = (item?.inventoryEid ?? ecs.INVALID_ENTITY_ID) != ecs.INVALID_ENTITY_ID || canPickupItems.get()
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
      sound = static {
        click  = "ui_sounds/button_click"
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
      transform = static {
        pivot = [0, 0.2]
      }
      children = [
        isRecognizingRequired ? itemRecognizingComp(item)
          : itemComp(stateFlags, item, opacity, list_type, itemIconParams, isActionForbided),
        (!isPickable || item?.forceLockIcon) && !(item?.isDelayedMoveMod ?? false) ? itemLockComp : null,
        itemUseProgressComp,
        mkItemCheckAmmoProgress(item),
        needBlink ? moveMarker(stateFlags.get(), opacity) : null,
        item.isBoxedItem ? moveMarkerWithTrigger(stateFlags.get(), 1.0, $"boxed_item_blink_{item.eid}") : null,
        mkDropMarkerSmallArea(stateFlags, canDrop, draggedData),
        (item?.noSuitableItemForPresetFoundCount ?? 0) > 0 ? mkPriceBlock(item) : null
      ]
      animations = itemAnims
    }
  }
}

function mkChocolatePriceBlock(item) {
  let lot = getLotFromItem(item)
  if (lot == null)
    return null
  let priceData = getPriceFromLot(lot)
  if ((priceData?.price ?? 0) <= 0)
    return null
  return {
    hplace = ALIGN_RIGHT
    vplace = ALIGN_TOP
    pos = [-hdpx(1), hdpx(1)]
    children = mkItemPrice(priceData)
  }
}

function chocolateItemComp(stateFlags, item) {
  let { isBoxedItem = false, ammoCount = 0, count = 0, alwaysShowCount = false, charges = null,
    iconParamsOverride = {}, isWeapon = false, isDelayedMoveMod = false, countPerStack = 0,
    maxCharges = 0, countKnown = true, noSuitableItemForPresetFoundCount = 0,
    eid = ecs.INVALID_ENTITY_ID, itemStorage = null, marketPrice = null,
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
        let idx = itemsInRefiner.get().findindex(@(v) v.eid == item.eid)
        if (idx == null)
          return charges

        let refiner = itemsInRefiner.get()
        return charges - (refiner[idx].ammoCount ?? 0)
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
            "",
            noSuitableItemForPresetFoundCount)
          @() {
            watch = entityToUse
            size = flex()
            children = (isBoxedItem && countPerStack != 1) || (entityToUse.get() == eid && itemCount == 0) ? null
              : itemCountLabel
          }
          nexusPointsCostComp(item?.nexusCost)
        ]
      }
      itemStorage == null ? null : mkStorageIcon(itemStorage)
      marketPrice == null ? null : mkChocolatePriceBlock(item)
    ]
  }
}

function chocolateInventoryItem(item) {
  #forbid-auto-freeze
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
  RecognitionStages

  itemFillColorHovered
  itemFillColorDef
  recognitionImagePattern

  mkCountLabel
  modsIndicator
}
