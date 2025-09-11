from "das.inventory" import is_on_equip_weapon_prev_can_fit, move_weapon_from_inventory_to_slot, is_item_pickup_blocked, is_item_inventory_move_blocked,
  is_on_equip_weapon_mod_prev_can_fit, install_weapon_mod_to_slot, swap_weapons_in_slots, notify_equip_in_occupied_slot_failed, install_equipment_mod_to_slot, move_item_from_inventory_to_slot
from "dasevents" import RequestLoadItemHolder, sendNetEvent
from "das.human_weap" import load_weapon_ammo_from_inventory
from "%ui/hud/menus/components/inventoryWeapon.nut" import weaponWidget, disabledWeaponWidget
import "%ui/hud/menus/components/dropMarker.nut" as dropMarker
from "humaninv" import INVALID_ITEM_ID
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem, mkFakeAttachments
from "%ui/hud/menus/components/itemFromTemplate.nut" import getSlotFromTemplate
from "%ui/hud/state/inventory_item_relations.nut" import isItemForHolder
from "%dngscripts/sound_system.nut" import sound_play
from "%ui/hud/menus/components/inventoryItemUtils.nut" import fastUnequipItem
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


let weaponSlots = require("%ui/types/weapon_slots.nut")
let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")
let { draggedData, mutationForbidenDueToInQueueState } = require("%ui/hud/state/inventory_state.nut")
let { weaponsList, weaponSlotNames } = require("%ui/hud/state/hero_weapons.nut")
let { canModifyInventory, canLoadCharges } = require("%ui/hud/state/inventory_common_es.nut")
let { GROUND } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { previewPreset, previewPresetCallbackOverride } = require("%ui/equipPresets/presetsState.nut")
let { equipment } = require("%ui/hud/state/equipment.nut")
let { equipMeleeChoronogeneItem } = require("%ui/mainMenu/clonesMenu/cloneMenuState.nut")

#allow-auto-freeze

function canDropDraggedItemToWeaponSlotDefault(item, weapon) {
  if (weapon?.currentWeaponSlotName == null)
    return false

  if (weapon.weaponSlotKey == "melee" && item?.filterType == "stub_melee_weapon")
    return true

  let itemEquipped = "currentWeaponSlotName" in item

  let alreadyEquippedInThisWeaponSlot = itemEquipped
    && item.currentWeaponSlotName == weapon.currentWeaponSlotName

  let validWeaponSlots = weapon?.validWeaponSlots
  let swapAvailable = !itemEquipped
    || validWeaponSlots == null
    || validWeaponSlots?.indexof(item.currentWeaponSlotName) != null

  return canModifyInventory.get()
    && !is_item_inventory_move_blocked(item?.eid ?? ecs.INVALID_ENTITY_ID) && !is_item_inventory_move_blocked(weapon?.eid ?? ecs.INVALID_ENTITY_ID)
    && !(item?.fromList == GROUND && is_item_pickup_blocked(item?.eid ?? ecs.INVALID_ENTITY_ID))
    && (("validWeaponSlots" in item
        && swapAvailable
        && item.validWeaponSlots?.indexof(weapon.currentWeaponSlotName) != null
        && !alreadyEquippedInThisWeaponSlot))
}

function onItemDroppedToWeaponSlotDefault(item, weapon) {

  
  if (item?.filterType == "stub_melee_weapon") {
    if (weapon?.filterType != "stub_melee_weapon")
      fastUnequipItem(weapon)

    equipMeleeChoronogeneItem(item)
    return
  }

  if (mutationForbidenDueToInQueueState.get()) {
    sound_play("ui_sounds/button_click_inactive")
    return
  }
  if (!is_on_equip_weapon_prev_can_fit(item.eid, weapon.currentWeaponSlotName)) {
    notify_equip_in_occupied_slot_failed(item.inventoryEid)
    sound_play("ui_sounds/button_click_inactive")
    return
  }
  if ("currentWeaponSlotName" in item)
    
    swap_weapons_in_slots(item.currentWeaponSlotName, weapon.currentWeaponSlotName)
  else
    move_weapon_from_inventory_to_slot(item.eid, item.inventoryEid, weapon.currentWeaponSlotName)
}

function canDropDraggedItemToWeaponModSlotDefault(item, weapon, modSlotName, modSlot) {
  if ( canLoadCharges.get()
    && isItemForHolder(item, modSlot)
    && ((modSlot?.maxCharges ?? 0) > (weapon.gunAmmo - weapon.maxAmmo) || !(modSlot?.countKnown ?? false)))
    return true

  let alreadyAttachedHere = (item?.currentWeapModSlotName == modSlotName && item?.currentWeaponSlotName == weapon.currentWeaponSlotName)
  let isAttachedToWeapon = item?.currentWeapModSlotName != null
  
  return !isAttachedToWeapon
    && canModifyInventory.get()
    && !alreadyAttachedHere
    && item?.weapModSlotName == modSlotName
    && (!("itemTemplate" in item) || modSlot.allowed_items.contains(item.itemTemplate))
    && !is_item_inventory_move_blocked(item?.eid ?? ecs.INVALID_ENTITY_ID)
    && !is_item_inventory_move_blocked(weapon?.eid ?? ecs.INVALID_ENTITY_ID)
    && !(item?.fromList == GROUND && is_item_pickup_blocked(item?.eid ?? ecs.INVALID_ENTITY_ID))
}

function onItemDroppedToWeaponModSlotDefault(item, weapon, modSlotName, modSlot) {
  if (mutationForbidenDueToInQueueState.get()) {
    sound_play("ui_sounds/button_click_inactive")
    return
  }

  if (isItemForHolder(item, modSlot)) {
    sendNetEvent(controlledHeroEid.get(), RequestLoadItemHolder({targetItemEid=modSlot.eid, containerEid=item.inventoryEid, searchOtherContainers=false}))
    return
  }

  if (!is_on_equip_weapon_mod_prev_can_fit(item?.eid ?? ecs.INVALID_ENTITY_ID, modSlotName, weapon.eid, item?.inventoryEid ?? ecs.INVALID_ENTITY_ID)) {
    notify_equip_in_occupied_slot_failed(item?.inventoryEid ?? ecs.INVALID_ENTITY_ID)
    sound_play("ui_sounds/button_click_inactive")
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
  if (mutationForbidenDueToInQueueState.get()) {
    sound_play("ui_sounds/button_click_inactive")
    return
  }

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
      watch = [ draggedData, stateFlags, mutationForbidenDueToInQueueState ]
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

      children = [
        weap,
        needMark ?
          mutationForbidenDueToInQueueState.get() ?
            dropMarker(sf, true, "") :
            dropMarker(sf)
          : null
      ]
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
    curAmmo = 1
  })


  local templateName = null
  local template = null
  if (weapon?.itemTemplate) {
    #forbid-auto-freeze
    templateName = weapon.itemTemplate
    template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
    let weapModsSlots = template?.getCompValNullable("gun_mods__slots").getAll() ?? {}
    let mods = {}

    slotFields["maxAmmo"] <- template?.getCompValNullable("gun__maxAmmo")
    slotFields["usesBoxedAmmo"] <- template?.getCompValNullable("gun_boxed_ammo_reload__reloadState") != null

    foreach (k, v in weapModsSlots) {
      let presetSlot = weapon?.attachments[k]
      local mod = {}
      if (presetSlot?.itemTemplate) {
        mod = mkFakeItem(presetSlot.itemTemplate, presetSlot)
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

  let slotWithVisuals = inventoryWeaponVisuals.__update(slotFields, weapon)

  let fake = mkFakeItem(templateName, slotWithVisuals, weapon?.attachments.map(@(v) v?.itemTemplate))

  fake["ammo"] <- {
    template = fake?.gunBoxedAmmoTemplate[0]
    fakeAmmo = true
  }
  

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
      size = FLEX_V
      gap = hdpx(10)
      children
    }
  }
}

function mkEquipmentWeaponsSmall(data) {
  let res = data.map(function(weapon) {
    let { itemTemplate = "", isCurrent = false, name = "", mods = {},
      currentWeaponSlotName = "", weaponSlotKey = null } = weapon
    let resMods = mods.map(function(mod) {
      let { slotTemplateName = "", attachedItemModSlotName = "" } = mod
      if (mod?.itemTemplate == "" || mod?.itemTemplate == null) {
        let slotTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(slotTemplateName)
        let defaultIcon = slotTemplate?.getCompValNullable("mod_slot__icon") ?? ""
        return mkFakeItem(mod?.itemTemplate ?? "", { slotTemplateName, defaultIcon, attachedItemModSlotName })
      }
      return mkFakeItem(mod.itemTemplate, { slotTemplateName })
    })
    local inventoryWeaponVisuals = {}
    if (itemTemplate != "" && itemTemplate != null) {
      let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(itemTemplate)
      inventoryWeaponVisuals = (template ? {
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
    }

    #forbid-auto-freeze
    let attachments = mods.reduce(function(res, v) {
      let templateName = v?.itemTemplate
      if (templateName != null)
        res.append(templateName)
      return res
    }, [])

    #allow-auto-freeze
    let resWeapon = mkFakeItem(itemTemplate,
      inventoryWeaponVisuals.__merge({ isCurrent, name, currentWeaponSlotName, mods = resMods }), attachments)
    if (weaponSlotKey != null)
      resWeapon.__update({ weaponSlotKey })
    return resWeapon
  })
  return {
    flow = FLOW_VERTICAL
    size = FLEX_V
    gap = hdpx(10)
    children = res.map(@(weapon) weaponWidget(weapon, null, null, null, null, null, null))
  }
}

let disabledEquipmentWeapons = {
  size = FLEX_V
  flow = FLOW_VERTICAL
  gap = hdpx(10)
  children = weaponSlotNames.map(disabledWeaponWidget)
}

return {
  mkEquipmentWeapons
  disabledEquipmentWeapons
  mkEquipmentWeaponsSmall
}