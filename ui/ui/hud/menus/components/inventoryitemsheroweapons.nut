import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


let weaponSlots = require("%ui/types/weapon_slots.nut")
let { is_on_equip_weapon_prev_can_fit, move_weapon_from_inventory_to_slot, is_item_pickup_blocked, is_item_inventory_move_blocked,
      is_on_equip_weapon_mod_prev_can_fit, install_weapon_mod_to_slot, swap_weapons_in_slots,
      notify_equip_in_occupied_slot_failed } = require("das.inventory")
let { load_weapon_ammo_from_inventory } = require("das.human_weap")
let { weaponWidget, disabledWeaponWidget } = require("%ui/hud/menus/components/inventoryWeapon.nut")
let {draggedData} = require("%ui/hud/state/inventory_state.nut")
let {weaponsList, weaponSlotNames} = require("%ui/hud/state/hero_weapons.nut")
let dropMarker = require("%ui/hud/menus/components/dropMarker.nut")
let {canModifyInventory} = require("%ui/hud/state/inventory_common_es.nut")
let {GROUND} = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let {INVALID_ITEM_ID} = require("humaninv")
let { previewPreset, previewPresetCallbackOverride } = require("%ui/equipPresets/presetsState.nut")
let { mkFakeItem } = require("%ui/hud/menus/components/fakeItem.nut")
let { equipment } = require("%ui/hud/state/equipment.nut")
let { getSlotFromTemplate } = require("%ui/hud/menus/components/itemFromTemplate.nut")


function canDropDraggedItemToWeaponSlotDefault(item, weapon) {
  if (weapon?.currentWeaponSlotName == null)
    return false

  let itemEquipped = "currentWeaponSlotName" in item

  let alreadyEquippedInThisWeaponSlot = itemEquipped
    && item.currentWeaponSlotName == weapon.currentWeaponSlotName

  let validWeaponSlots = weapon?.validWeaponSlots
  let swapAvailable = !itemEquipped
    || validWeaponSlots == null
    || validWeaponSlots?.indexof(item.currentWeaponSlotName) != null

  return canModifyInventory.value
    && !is_item_inventory_move_blocked(item?.eid ?? ecs.INVALID_ENTITY_ID) && !is_item_inventory_move_blocked(weapon?.eid ?? ecs.INVALID_ENTITY_ID)
    && !(item?.fromList == GROUND && is_item_pickup_blocked(item?.eid ?? ecs.INVALID_ENTITY_ID))
    && (("validWeaponSlots" in item
        && swapAvailable
        && item.validWeaponSlots?.indexof(weapon.currentWeaponSlotName) != null
        && !alreadyEquippedInThisWeaponSlot))
}

function onItemDroppedToWeaponSlotDefault(item, weapon) {
  if (!is_on_equip_weapon_prev_can_fit(item.eid, weapon.currentWeaponSlotName, item.owner)) {
    notify_equip_in_occupied_slot_failed(item.owner)
    return
  }

  if ("currentWeaponSlotName" in item)
    
    swap_weapons_in_slots(item.currentWeaponSlotName, weapon.currentWeaponSlotName)
  else
    move_weapon_from_inventory_to_slot(item.eid, item.owner, weapon.currentWeaponSlotName)
}

function canDropDraggedItemToWeaponModSlotDefault(item, weapon, modSlotName, modSlot) {
  let alreadyAttachedHere = (item?.currentWeapModSlotName == modSlotName && item?.currentWeaponSlotName == weapon.currentWeaponSlotName)
  let isAttachedToWeapon = item?.currentWeapModSlotName != null
  
  return !isAttachedToWeapon
    && canModifyInventory.value
    && !alreadyAttachedHere
    && item?.weapModSlotName == modSlotName
    && (!("itemTemplate" in item) || modSlot.allowed_items.contains(item.itemTemplate))
    && !is_item_inventory_move_blocked(item?.eid ?? ecs.INVALID_ENTITY_ID)
    && !is_item_inventory_move_blocked(weapon?.eid ?? ecs.INVALID_ENTITY_ID)
    && !(item?.fromList == GROUND && is_item_pickup_blocked(item?.eid ?? ecs.INVALID_ENTITY_ID))
}

function onItemDroppedToWeaponModSlotDefault(item, weapon, modSlotName, _modSlot) {
  if (!is_on_equip_weapon_mod_prev_can_fit(item?.eid ?? ecs.INVALID_ENTITY_ID, modSlotName, weapon.eid, item?.inventoryEid ?? ecs.INVALID_ENTITY_ID)) {
    notify_equip_in_occupied_slot_failed(item?.inventoryEid ?? ecs.INVALID_ENTITY_ID)
    return
  }

  install_weapon_mod_to_slot(item?.eid ?? ecs.INVALID_ENTITY_ID, item?.inventoryEid ?? ecs.INVALID_ENTITY_ID, modSlotName, weapon.eid)
}

function canDropDraggedItemToAmmoSlot(item, weapon) {

  return ((item?.isBoxedItem ?? false)
    && !(item?.fromList == GROUND && is_item_pickup_blocked(item?.eid ?? ecs.INVALID_ENTITY_ID))
    && ((weapon?.ammoHolders ?? []).contains(item?.ammoId ?? INVALID_ITEM_ID) ||
        (weapon?.gunBoxedAmmoTemplate == item?.itemTemplate)))
}

function onItemDroppedToAmmoSlot(item, weapon) {
  load_weapon_ammo_from_inventory(item?.eid ?? ecs.INVALID_ENTITY_ID, weapon.currentWeaponSlotName)
}

function mkWeaponSlotWidget(weapon, callbacks = {}) {
  let {
    canDropToSLot = canDropDraggedItemToWeaponSlotDefault,
    onDropToSlot = onItemDroppedToWeaponSlotDefault,
    canDropToMod = canDropDraggedItemToWeaponModSlotDefault,
    onDropToMod = onItemDroppedToWeaponModSlotDefault,
    canDropAmmo = canDropDraggedItemToAmmoSlot,
    onDropAmmo = onItemDroppedToAmmoSlot
  } = callbacks

  let weap = weaponWidget(weapon,
    canDropToSLot, onDropToSlot,
    canDropToMod, onDropToMod,
    canDropAmmo, onDropAmmo)

  let stateFlags = Watched(0)
  return function() {
    let needMark = draggedData && draggedData.get() &&
      canDropToSLot?(draggedData.get(), weapon)
    let sf = stateFlags.get()
    return {
      behavior = Behaviors.DragAndDrop
      watch = [draggedData, stateFlags]
      onElemState = function(val) {stateFlags.set(val)}
      skipDirPadNav = true
      canDrop = @(item) (canDropToSLot?(item, weapon)
        || canDropAmmo?(item, weapon)
        || ((weapon?.mods ?? {}).findindex(@(modSlot, modSlotName) canDropToMod?(item, weapon, modSlotName, modSlot)) != null))
      onDrop = function(item) {
        if (canDropToSLot?(item, weapon))
          onDropToSlot?(item, weapon)
        else if (canDropAmmo?(item, weapon))
          onDropAmmo?(item, weapon)
        else {
          let mods = (weapon?.mods ?? {})
          let slotIdx = mods.findindex(@(modSlot, modSlotName) canDropToMod?(draggedData.get(), weapon, modSlotName, modSlot))
          if (slotIdx != null)
            onDropToMod?(item, weapon, slotIdx, weapon?.mods[slotIdx])
        }
      }

      children = [weap, needMark ? dropMarker(sf) : null]
    }
  }
}


function makePreviewWeaponSlot(weapon, slotIndex, overridedCallbacks, primaryChronogene) {
  
  if (slotIndex >= 4) {
    return null
  }

  let slotFields = weapon.__merge({
    isDragAndDropAvailable = false
    currentWeaponSlotName = weaponSlotNames[slotIndex]
    weaponSlotKey = weaponSlots.weaponSlotsKeys[slotIndex]
    name = ""
  })


  local templateName = null
  local template = null
  if (weapon?.itemTemplate) {
    templateName = weapon.itemTemplate
    template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
    let weapModsSlots = template?.getCompValNullable("gun_mods__slots").getAll() ?? {}
    let mods = {}

    foreach (k, v in weapModsSlots) {
      let presetSlot = weapon?.attachments[k]
      local mod = {}
      if (presetSlot?.itemTemplate) {
        mod = mkFakeItem(presetSlot.itemTemplate)
      }
      mod.__update({
        slotTemplateName = k
        noSuitableItemForPresetFoundCount = v?.noSuitableItemForPresetFoundCount ?? 0
      }, getSlotFromTemplate(v))

      mods[k] <- mod
    }

    slotFields["mods"] <- mods
  }
  else {
     if (slotIndex == weaponSlots.EWS_MELEE) {
      
      let currentAlter = primaryChronogene?.itemTemplate ?? equipment.get()?.chronogene_primary_1.itemTemplate
      let alterTemplate = currentAlter ? ecs.g_entity_mgr.getTemplateDB().getTemplateByName(currentAlter) : null
      templateName = alterTemplate?.getCompValNullable("equipment__setDefaultStubMeleeTemplate")
      if (templateName)
        template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
    }
  }

  if (!templateName)
    return mkWeaponSlotWidget(slotFields, overridedCallbacks)

  let inventoryWeaponVisuals = (template ? {
    iconYaw = template.getCompValNullable("weapon__iconYaw")
    iconPitch = template.getCompValNullable("weapon__iconPitch")
    iconRoll = template.getCompValNullable("weapon__iconRoll")
    iconOffsX = template.getCompValNullable("weapon__iconOffset")?.x
    iconOffsY = template.getCompValNullable("weapon__iconOffset")?.y
    iconScale = template.getCompValNullable("weapon__iconScale")
    iconRecalcAnimation = template.getCompValNullable("weapon__iconRecalcAnimation")
    lightZenith = 0
    lightAzimuth = 200
  } : {}).filter(@(v) v != null)

  let slotWithVisuals = inventoryWeaponVisuals.__update(slotFields)

  let fake = mkFakeItem(templateName, slotWithVisuals, weapon?.attachments.map(@(v) v?.itemTemplate))
  return {
    children =
      mkWeaponSlotWidget(fake, overridedCallbacks)
  }
}

function mkEquipmentWeapons() {
  
  return function() {
    let previewPresetVal = previewPreset.get()
    let isPreview = previewPresetVal != null
    let callbacks = previewPresetCallbackOverride.get()?["weapons"] ?? {}
    let { weapons = [], chronogene_primary_1 = null } = previewPresetVal
    let children = isPreview
      ? weapons.map(@(v, idx) makePreviewWeaponSlot(v, idx, callbacks?[idx] ?? {}, chronogene_primary_1))
      : weaponsList.get().map(@(weapon) mkWeaponSlotWidget(weapon))

    return {
      watch = [ weaponsList, previewPreset, previewPresetCallbackOverride ]
      flow = FLOW_VERTICAL
      size = [ SIZE_TO_CONTENT, flex() ]
      gap = hdpx(10)
      children
    }
  }
}

let disabledEquipmentWeapons = {
  size = [SIZE_TO_CONTENT, flex()]
  flow = FLOW_VERTICAL
  gap = hdpx(10)
  children = weaponSlotNames.map(disabledWeaponWidget)
}

return {
  mkEquipmentWeapons
  disabledEquipmentWeapons
}