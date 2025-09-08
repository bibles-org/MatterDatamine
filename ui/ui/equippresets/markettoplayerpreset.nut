from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { mkFakeItem } = require("%ui/hud/menus/components/fakeItem.nut")
let { equipment } = require("%ui/hud/state/equipment.nut")
let { calc_stacked_item_volume, convert_volume_to_int } = require("das.inventory")
let { weaponSlotNames } = require("%ui/hud/state/hero_weapons.nut")
let { logerr } = require("dagor.debug")

let WEAPON_SLOTS_COUNT = weaponSlotNames.len()


function getModsTable(itemTable, shopItems) {
  let mods = itemTable?.mods ?? {}
  let attachments = {}
  foreach (slotName, slotParams in mods) {
    let modItem = shopItems.findvalue(function(v) {
      let hasUnusedBoxedCharges = v.isBoxedItem ?
        (v.charges - (v?.marketToPresetBoxedCounted ?? 0)) > 0 :
        true 
      return !v?.marketToPresetCounted && hasUnusedBoxedCharges &&
        slotParams.allowed_items.findindex(@(v2) v2 == v.templateName) != null
    })
    if (modItem) {
      if (modItem.isBoxedItem) {
        modItem.__update({ marketToPresetBoxedCounted = (modItem?.marketToPresetBoxedCounted ?? 0) + 1 })
      }
      else {
        modItem.__update({ marketToPresetCounted = true })
      }
    }
    attachments[slotName] <- modItem?.itemTemplate
  }
  return attachments
}


function setWeapon(presetTable, weaponIdx, shopItems) {
  let weaponSlotName = weaponSlotNames[weaponIdx]
  foreach (item in shopItems) {
    if (!item.isWeapon || item?.marketToPresetCounted)
      continue

    let suitsIdx = item.validWeaponSlots.findindex(@(v) v == weaponSlotName)
    if (suitsIdx == null)
      continue

    let attachments = getModsTable(item, shopItems)

    item.__update({ marketToPresetCounted = true })
    presetTable.weapons[weaponIdx] = {
      itemTemplate = item.itemTemplate
      attachments
    }
    break;
  }
}


function setSuitMods(presetTable, currentChronogene, shopItems) {
  let attachmentMods = getModsTable(currentChronogene, shopItems)
  let attachments = {}
  foreach (k, itemTemplate in attachmentMods) {
    attachments[k] <- {
      itemTemplate
      slotTemplateName = currentChronogene?.mods[k].slotTemplateName
    }
  }
  presetTable.chronogene_primary_1 = {
    itemTemplate = currentChronogene?.itemTemplate
  }.__update(attachments)
}


function setSuitEquipment(presetTable, equipmentName, shopItems) {
  let suitEquipmentItem = shopItems.findvalue(@(v) v.equipmentSlots.findindex(@(v2) v2 == equipmentName) != null && !v?.marketToPresetCounted )
  if (suitEquipmentItem == null) {
    presetTable[equipmentName] <- {}
    return null
  }

  suitEquipmentItem.__update({ marketToPresetCounted = true })

  let attachmentMods = getModsTable(suitEquipmentItem, shopItems)
  let attachments = {}
  foreach (k, itemTemplate in attachmentMods) {
    attachments[k] <- {
      itemTemplate
      slotTemplateName = suitEquipmentItem?.mods[k].slotTemplateName
    }
  }
  presetTable[equipmentName] <- {
    itemTemplate = suitEquipmentItem?.itemTemplate
  }.__update(attachments)

  return suitEquipmentItem
}

function setInventory(presetTable, shopItems, inventoryName, inventoryMaxVolume, filterFunc=null) {
  let intMaxVolume = convert_volume_to_int(inventoryMaxVolume)
  let filteredItems = filterFunc ? shopItems.filter(filterFunc) : shopItems
  let itemsArr = []
  local currentVolume = 0
  foreach (item in filteredItems) {
    if (item.isBoxedItem) {
      let itemsCount = item.charges - (item?.marketToPresetBoxedCounted ?? 0)
      let itemVolume = calc_stacked_item_volume(item.countPerStack, itemsCount, item.volumePerStack)
      if (itemsCount==0 || currentVolume + itemVolume >= intMaxVolume)
        continue
      currentVolume += itemVolume

      item.__update({ marketToPresetBoxedCounted = item.charges })
      itemsArr.append({
        count = 1
        ammoCount = itemsCount
        ammoId = item?.ammoId
        countPerStack = item.countPerStack
        itemTemplate = item.itemTemplate
        isBoxedItem = item.isBoxedItem
      })
    }
    else {
      let itemVolume = convert_volume_to_int(item?.volume ?? 0)
      if (item?.marketToPresetCounted || currentVolume + itemVolume > intMaxVolume)
        continue
      currentVolume += itemVolume

      item.__update({ marketToPresetCounted = true })
      itemsArr.append({
        count = 1
        ammoCount = item.ammoCount
        ammoId = item?.ammoId
        countPerStack = null
        itemTemplate = item.itemTemplate
        isBoxedItem = item.isBoxedItem
      })
    }
  }
  if (presetTable.inventories?[inventoryName]) {
    presetTable.inventories?[inventoryName].items.extend(itemsArr)
  }
  else {
    presetTable.inventories[inventoryName] <- {
      capacity = inventoryMaxVolume
      items = itemsArr
    }
  }
}

function mkPresetDataFromMarket(items) {
  let currentChronogene = equipment.get()?.chronogene_primary_1

  if (currentChronogene == null) {
    logerr("[Market preset to player preset] Current player's chronogene is null")
    return null
  }

  let fakedItems = items.map(@(v) mkFakeItem(v?.templateName,
    {
      isItemToPurchase = true
      charges = v?.charges ?? 0
      ammoCount = v?.ammoCount ?? v?.charges
    }
  ))

  let preset = { weapons = array(WEAPON_SLOTS_COUNT, {}), chronogene_primary_1 = {} }

  
  setWeapon(preset, 0, fakedItems)
  setWeapon(preset, 1, fakedItems)
  setWeapon(preset, 2, fakedItems)
  setWeapon(preset, 3, fakedItems)

  
  setSuitMods(preset, currentChronogene, fakedItems)

  
  setSuitEquipment(preset, "helmet", fakedItems)
  let pouchItem = setSuitEquipment(preset, "pouch", fakedItems)
  setSuitEquipment(preset, "flashlight", fakedItems)
  let backpackItem = setSuitEquipment(preset, "backpack", fakedItems)

  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName("militant_inventory")
  let humanInventoryCommonVoume = template?.getCompValNullable("human_inventory__maxVolume") ?? 0
  let pouchesVolume = humanInventoryCommonVoume + (pouchItem?.inventoryExtension ?? 0) 
  let backpackVolume = backpackItem?.inventoryMaxVolumeFloat ?? 0

  preset["inventories"] <- {}
  
  setInventory(preset, fakedItems, "myItems", pouchesVolume, @(v) v.isBoxedItem || v.item__currentBoxedItemCount)
  
  setInventory(preset, fakedItems, "backpack", backpackVolume, null)
  
  setInventory(preset, fakedItems, "myItems", pouchesVolume, null)

  return preset
}

return {
  mkPresetDataFromMarket
}