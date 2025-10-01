from "%sqstd/string.nut" import startsWith
from "%sqstd/underscore.nut" import range

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs


function findAllItemChildren(loadoutItems, parentItemId) {
  return loadoutItems.filter(@(item) (item?.parentItemId) == parentItemId)
}

let convertLoadoutWeapons = function(loadout, preset) {
  preset["weapons"] <- []
  let loadoutWeapons = []
  foreach(item in loadout) {
    if (item == null) {
      continue
    }
    if (startsWith(item.slotName, "weapon_")) {
      loadoutWeapons.append(item)
    }
  }
  foreach (weapIdx in range(6)){
    let slot = $"weapon_{weapIdx}"

    let loadoutWeapon = loadoutWeapons.findvalue(@(v) v.slotName == slot)

    if (loadoutWeapon == null) {
      preset.weapons.append({})
      continue
    }

    let itemTemplate = loadoutWeapon.templateName ?? ""
    let presetWeapon = { itemTemplate }

    let presetAttachments = {}
    let weaponId = loadoutWeapon?.itemId
    if (weaponId == null) {
      continue
    }
    findAllItemChildren(loadout, weaponId).each(function(item) {
      presetAttachments[item.slotName] <- {
        itemTemplate = item.templateName
      }
    })
    presetWeapon["attachments"] <- presetAttachments

    preset.weapons.append(presetWeapon)
  }
}

let convertItemList = function(loadoutList, presetList) {
  foreach (item in loadoutList) {
    let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(item.templateName)
    let isBoxedItem = template?.getCompValNullable("boxed_item__template") != null
    let isAmmoHolder = template?.getCompValNullable("item_holder__maxItemCount") != null
    let ammoCount = (isBoxedItem || isAmmoHolder) ? item?.charges : null
    presetList.append({
      itemTemplate = item.templateName
      count = 1
      countPerStack = template?.getCompValNullable("item__countPerStack") ?? 0
      isCorrupted = item?.isCorrupted ?? false
      isBoxedItem
      ammoCount
      ammoId = null
    })
  }
}

let convertLoadoutBackpack = function(loadout, preset) {
  preset.inventories["backpack"] <- {
    capacity = 0
    items = []
  }
  foreach(item in loadout) {
    if (item.slotName == "equipment_backpack") {
      convertItemList(findAllItemChildren(loadout, item.itemId), preset.inventories.backpack.items)
      break
    }
  }
}

let convertLoadoutItems = function(loadout, preset) {
  preset.inventories["myItems"] <- {
    capacity = 0
    items = []
  }
  let pouchesItems = findAllItemChildren(loadout, "0").filter(@(item) item.slotName == "inventory")
  convertItemList(pouchesItems, preset.inventories.myItems.items)
}

let convertEquipment = function(loadout, preset) {
  let equipmentToConvert = [
    "flashlight", "pouch", "helmet", "backpack",
    "chronogene_secondary_1", "chronogene_secondary_2", "chronogene_secondary_3", "chronogene_secondary_4"
  ]
  let equipmentPrefix = "equipment_"
  foreach(item in loadout) {
    let slot = item.slotName
    if (startsWith(slot, equipmentPrefix)) {
      let equipmentName = slot.slice(equipmentPrefix.len())
      if (!equipmentToConvert.contains(equipmentName)) {
        continue
      }

      let itemTemplate = item?.templateName ? ecs.g_entity_mgr.getTemplateDB().getTemplateByName(item.templateName) : null
      let slots = itemTemplate?.getCompValNullable("equipment_mods__slots")?.getAll() ?? []
      let id = item.itemId
      preset[equipmentName] <- {
        itemTemplate = item.templateName
        attachments = slots.map(function(slotTemplateName, slotKey) {
          return {
            slotTemplateName
            itemTemplate = loadout.findvalue(@(loadoutItem) (loadoutItem.parentItemId == id) && (loadoutItem.slotName == slotKey))?.templateName
          }
        })
      }
    }
  }
}

let convertSuit = function(loadout, preset) {
  local suitTemplateName = null
  local suitId = null
  foreach(item in loadout) {
    if (item.slotName == "equipment_chronogene_primary_1") {
      suitTemplateName = item.templateName
      suitId = item.itemId
      break
    }
  }

  if (suitTemplateName == null)
    return

  let suitTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(suitTemplateName)
  let slots = suitTemplate?.getCompValNullable("equipment_mods__slots")?.getAll() ?? []

  local equip = {}
  findAllItemChildren(loadout, suitId).each(function(item) {
    
    
    if (!startsWith(item.slotName, "equipment_mod"))
      return
    equip[item.slotName] <- {
      slotTemplateName = slots?[item.slotName]
      itemTemplate = item.templateName
    }
  })

  preset["chronogene_primary_1"] <- {
    itemTemplate = suitTemplateName
  }.__update(equip)
}


let loadoutToPreset = function(loadout) {
  if (loadout == null || loadout.len()==0)
    return null

  let preset = { inventories = {} }
  convertLoadoutWeapons(loadout.items, preset)
  convertEquipment(loadout.items, preset)
  convertLoadoutBackpack(loadout.items, preset)
  convertLoadoutItems(loadout.items, preset)
  convertSuit(loadout.items, preset)

  return preset
}


function convertPresetWeapons(preset, items, id) {
  let weaponsArr = preset.weapons
  local currentId = id
  foreach (idx, weapon in weaponsArr) {
    if (weapon.len() == 0 || weapon?.itemTemplate == null)
      continue

    let weaponId = currentId
    items.append({
      isCorrupted = false,
      itemId = $"{weaponId}",
      parentItemId = "0",
      slotName = $"weapon_{idx}",
      templateName = weapon.itemTemplate
      charges = weapon?.charges
    })
    let attachments = weapon?.attachments ?? {}
    currentId++
    foreach (slotName, slotValue in attachments) {
      if (slotValue.itemTemplate == null)
        continue
      items.append({
        isCorrupted = false,
        itemId = $"{currentId}",
        parentItemId = $"{weaponId}",
        slotName,
        templateName = slotValue.itemTemplate
        charges = slotValue?.charges ?? slotValue?.ammoCount
      })
      currentId++
    }
  }
  return currentId
}

function converPresettSuit(preset, items, id) {
  let suitBranch = preset.chronogene_primary_1
  local currentId = id
  items.append({
    isCorrupted = false,
    itemId = $"{currentId}",
    parentItemId = "0",
    slotName = "equipment_chronogene_primary_1",
    templateName = suitBranch.itemTemplate
    charges = suitBranch?.charges
  })
  let suitId = currentId
  currentId++

  foreach (slotName, slotValue in suitBranch) {
    if (type(slotValue) != "table")
      continue

    local isBoxed = false

    if (slotValue?.itemTemplate) {
      let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(slotValue.itemTemplate)
      isBoxed = template.getCompValNullable("boxed_item__template") != null
    }

    items.append({
      isCorrupted = false
      slotName
      itemId = $"{currentId}"
      templateName = slotValue.itemTemplate
      parentItemId = $"{suitId}"
      charges = slotValue?.charges ?? (isBoxed ? 1 : null)
    })
    currentId++
  }
  return currentId
}

function convertPresetEquipment(preset, items, id, equipmentIds) {
  let equipmentKeys = [
    "flashlight", "helmet", "safepack", "backpack", "pouch",
    "chronogene_secondary_1", "chronogene_secondary_2", "chronogene_secondary_3", "chronogene_secondary_4"
  ]
  local currentId = id
  foreach (eqKey in equipmentKeys) {
    let equip = preset?[eqKey]
    if (!equip)
      continue

    let equipId = currentId
    equipmentIds[eqKey] <- equipId
    items.append({
      isCorrupted = false
      slotName = $"equipment_{eqKey}"
      itemId = $"{equipId}"
      templateName = equip.itemTemplate
      parentItemId = "0"
      charges = equip?.charges ?? equip?.ammoCount
    })
    currentId++

    let attachments = equip?.attachments ?? {}
    foreach(slotName, slotValue in attachments) {
      if (slotValue?.itemTemplate == null) {
        continue
      }

      let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(slotValue.itemTemplate)
      let isBoxed = template.getCompValNullable("boxed_item__template") != null
      items.append({
        isCorrupted = false
        slotName = slotName
        itemId = $"{currentId}"
        templateName = slotValue.itemTemplate
        parentItemId = $"{equipId}"
        charges = (slotValue?.charges ?? equip?.ammoCount) ?? (isBoxed ? 1 : null)
      })
      currentId++
    }
  }
  return currentId
}

function convertPresetInventory(preset, items, id, inventoriesId) {
  let inventories = preset?.inventories
  if (inventories == null)
    return id

  local currentId = id

  let myItems = inventories?["myItems"].items ?? []
  foreach (item in myItems) {
    items.append({
      isCorrupted = false
      slotName = "inventory"
      itemId = $"{currentId}"
      templateName = item.itemTemplate
      parentItemId = "0"
      charges = item?.charges ?? item?.ammoCount
    })
    let mainItemId = currentId
    currentId++

    foreach (slotName, mod in item?.modInSlots ?? {}) {
      items.append({
        isCorrupted = false
        slotName
        itemId = $"{currentId}"
        templateName = mod.itemTemplate
        parentItemId = $"{mainItemId}"
        charges = mod?.charges ?? item?.ammoCount
      })
    }
    currentId++
  }

  let backpackItems = inventories?["backpack"].items ?? []
  foreach (item in backpackItems) {
    items.append({
      isCorrupted = false
      slotName = "inventory"
      itemId = $"{currentId}"
      templateName = item.itemTemplate
      parentItemId = $"{inventoriesId.backpack}"
      charges = item?.charges ?? item?.ammoCount
    })
    let mainItemId = currentId
    currentId++

    foreach (slotName, mod in item?.modInSlots ?? {}) {
      items.append({
        isCorrupted = false
        slotName
        itemId = $"{currentId}"
        templateName = mod.itemTemplate
        parentItemId = $"{mainItemId}"
        charges = mod?.charges ?? mod?.ammoCount
      })
    }
    currentId++
  }

  let safepackItems = inventories?["safepack"].items ?? []
  foreach (item in safepackItems) {
    items.append({
      isCorrupted = false
      slotName = "inventory"
      itemId = $"{currentId}"
      templateName = item.itemTemplate
      parentItemId = $"{inventoriesId.safepack}"
      charges = item?.charges ?? item?.ammoCount
    })
    let mainItemId = currentId
    currentId++

    foreach (slotName, mod in item?.modInSlots ?? {}) {
      items.append({
        isCorrupted = false
        slotName
        itemId = $"{currentId}"
        templateName = mod.itemTemplate
        parentItemId = $"{mainItemId}"
        charges = mod?.charges ?? mod?.ammoCount
      })
    }
    currentId++
  }
  return currentId
}


function presetToLoadout(preset) {
  if (preset == null)
    return null

  let items = []
  local id = 1

  let equipmentIds = {}
  id = converPresettSuit(preset, items, id)
  id = convertPresetWeapons(preset, items, id)
  id = convertPresetEquipment(preset, items, id, equipmentIds)
  id = convertPresetInventory(preset, items, id, equipmentIds)

  return items
}

return {
  loadoutToPreset
  presetToLoadout
}