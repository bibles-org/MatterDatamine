from "%ui/options/mkOnlineSaveData.nut" import mkOnlineSaveData
from "dagor.debug" import logerr
import "utf8" as utf8
from "%ui/hud/menus/components/inventoryItemUtils.nut" import mergeNonUniqueItems
from "das.inventory" import load_player_preset, get_preset_unequip_volume_int
from "%ui/components/msgbox.nut" import showMsgbox
from "%ui/ui_library.nut" import *
from "%ui/state/appState.nut" import isInBattleState, levelIsLoading
import "console" as console
import "%dngscripts/ecs.nut" as ecs

let { equipment } = require("%ui/hud/state/equipment.nut")
let { onlineSettingUpdated } = require("%ui/options/onlineSettings.nut")
let { weaponsList } = require("%ui/hud/state/hero_weapons.nut")
let { inventoryItems, backpackItems, safepackItems } = require("%ui/hud/state/inventory_items_es.nut")
let { maxVolume } = require("%ui/hud/state/inventory_common_es.nut")
let { backpackMaxVolume, backpackEid, safepackMaxVolume, safepackEid } = require("%ui/hud/state/hero_extra_inventories_state.nut")
let { get_controlled_hero } = require("%dngscripts/common_queries.nut")
let { stashVolume, stashMaxVolume } = require("%ui/state/allItems.nut")
let { tostring_r } = require("%sqstd/string.nut")

const PLAYER_PRESETS_IN_ONLINE_SETTINGS = "player_presets"
const MAX_PRESETS_COUNT = 10
const MAX_NAME_CHARS_COUNT = 16
const PRESET_PREFIX = "playerPreset"
const LAST_USED_EQUIPMENT = "lastUsed"
const AGENCY_PRESET_UID = "agencyPreset"
const PRESET_VERSION = 5
const PRESET_VERSION_KEY = "preset_version"

let playerPresetStorage = mkOnlineSaveData(PLAYER_PRESETS_IN_ONLINE_SETTINGS, @() {})
let playerPresetWatch = playerPresetStorage.watch
let playerPresetSetDirect = playerPresetStorage.setValue
let previewPreset = Watched(null)
let previewPresetCallbackOverride = Watched(null)
let previewPresetOverrideRibbons = Watched(null)
let useAgencyPreset = Watched(false)

levelIsLoading.subscribe_with_nasty_disregard_of_frp_update(@(v) v ? useAgencyPreset.set(false) : null)
isInBattleState.subscribe_with_nasty_disregard_of_frp_update(function(v) {
  if (v) {
    previewPreset.set(null)
    previewPreset.trigger()
  }
})

function setPlayerPreset(presetIdx, data, needChangeName = false) {
  if (!onlineSettingUpdated.get()) {
    showMsgbox({ text = loc("playerPreset/cantSavePresetRightNow") })
    logerr("Trying to save player presets while settings is unavailable")
    return
  }
  if (presetIdx < 0 || presetIdx >= MAX_PRESETS_COUNT) {
    logerr($"PRESETERROR: Trying to save player presets with idx {presetIdx}")
    return
  }
  local dataToSave = data
  if (!needChangeName) {
    let { presetName = null } = playerPresetWatch.get()?[$"{PRESET_PREFIX}_{presetIdx}"]
    if (presetName != null)
      dataToSave = data.__merge({ presetName, notDefaultPreset = true })
  }
  playerPresetSetDirect(playerPresetWatch.get().__merge({[$"playerPreset_{presetIdx}"] = dataToSave}))
}

function renamePreset(oldName, newName, presetIdx, presetData) {
  local nameToSave = newName
  let nameChars = utf8(newName)
  let charsCount = nameChars.charCount()
  if (oldName == newName || charsCount <= 0)
    return
  if (charsCount > MAX_NAME_CHARS_COUNT)
    nameToSave = nameChars.slice(0, MAX_NAME_CHARS_COUNT)
  let newData = presetData.__merge({ presetName = nameToSave, notDefaultPreset = true })
  setPlayerPreset(presetIdx, newData, true)
}

function saveSuitMods(preset, filterFunction) {
  let mods = equipment.get()?["chronogene_primary_1"].modInSlots ?? {}
  let slots = equipment.get()?["chronogene_primary_1"].mods ?? {}

  let suitMods = {
    itemTemplate = equipment.get()?["chronogene_primary_1"].itemTemplate
  }
  foreach (k, v in slots) {
    if (mods?[k].itemTemplate == null || !filterFunction(mods[k]))
      continue
    suitMods[k] <- {
      itemTemplate = mods?[k].itemTemplate
      slotTemplateName = v.slotTemplateName
    }
  }
  preset["chronogene_primary_1"] <- suitMods
}

function equipPreset(data) {
  if (!data)
    return

  let neededVolumeInt = get_preset_unequip_volume_int(get_controlled_hero(), backpackEid.get(), safepackEid.get())
  if (stashVolume.get() + neededVolumeInt > stashMaxVolume.get()) {
    showMsgbox({text=loc("playerPreset/notEnoughStashVolume")})
    return
  }

  let ecsData = ecs.CompObject()
  foreach (key, val in data)
    ecsData[key] <- val
  load_player_preset(ecsData)
}

function addEquipmentPresetsTable(arr, slot, item) {
  if (item?.itemTemplate == null || item?.default_stub_item)
    return
  arr[slot] <- {
    itemTemplate = item?.itemTemplate
    attachments = ( item?.mods ?? {} ).map(function(value, key){
      if (item?.modInSlots[key].itemTemplate == null)
        throw null
      return {
        itemTemplate = item?.modInSlots[key].itemTemplate
        slotTemplateName = value.slotTemplateName
      }
    })
  }
}

function addInventoryItems(preset, itemsInInventory, inventoryName, capacity) {
  let merged = mergeNonUniqueItems(itemsInInventory)

  let items = []

  foreach (item in merged) {
    if (item?.itemType == null)
      continue
    items.append({
      itemTemplate = item.itemTemplate
      count = item.count
      isBoxedItem = item.isBoxedItem
      ammoCount = item.ammoCount
      charges = item.ammoCount
      ammoId = item?.ammoId
      countPerStack = item.countPerStack
    })
  }

  if ("inventories" not in preset)
    preset["inventories"] <- {}
  preset["inventories"][inventoryName] <- {
    capacity
    items
  }
}

function defaultFilterFunction(item) {
  if (item?.filterType == "dog_tags")
    return false

  return true
}

function makePresetDataFromCurrentEquipment(filterFunction = defaultFilterFunction) {
  let preset = {}
  let weapons = weaponsList.get() ?? []
  preset["weapons"] <- []
  weapons.each(function(weap, _idx) {
    let weapTable = (weap?.itemTemplate && !weap?.isDefaultStubItem && filterFunction(weap))? {
      itemTemplate = weap.itemTemplate
      attachments = ( weap?.mods ?? {} ).filter(@(mod) filterFunction(mod)).map(function(value) {
        if (value.itemTemplate == "" || value?.itemTemplate == null)
          throw null
        return {
          itemTemplate = value.itemTemplate
        }
      })
    } : {}
    preset["weapons"].append(weapTable)
  })
  if (filterFunction(equipment.get()?.helmet))
    addEquipmentPresetsTable(preset, "helmet", equipment.get()?.helmet)
  if (filterFunction(equipment.get()?.flashlight))
    addEquipmentPresetsTable(preset, "flashlight", equipment.get()?.flashlight)
  if (filterFunction(equipment.get()?.pouch))
    addEquipmentPresetsTable(preset, "pouch", equipment.get()?.pouch)
  if (filterFunction(equipment.get()?.backpack)) {
    addEquipmentPresetsTable(preset, "backpack", equipment.get()?.backpack)
    addInventoryItems(preset, backpackItems.get().filter(@(item) filterFunction(item)), "backpack", backpackMaxVolume.get())
  }
  if (filterFunction(equipment.get()?.safepack)) {
    addEquipmentPresetsTable(preset, "safepack", equipment.get()?.safepack)
    addInventoryItems(preset, safepackItems.get().filter(@(item) filterFunction(item)), "safepack", safepackMaxVolume.get())
  }

  addInventoryItems(preset, inventoryItems.get().filter(@(item) filterFunction(item)), "myItems", maxVolume.get())

  saveSuitMods(preset, filterFunction)

  return preset
}

function unfoldCountItems(itemsArr) {
  if (!itemsArr?.len())
    return itemsArr
  let newArr = []
  foreach(item in itemsArr) {
    for (local i = 0; i < (item?.count ?? 1); i++) {
      newArr.append(item.__merge( { count = 1 } ))
    }
  }
  return newArr
}

function makeDataToSave() {
  let preset = makePresetDataFromCurrentEquipment()

  preset[PRESET_VERSION_KEY] <- PRESET_VERSION
  return preset
}

console.register_command(function() {
  let preset = makePresetDataFromCurrentEquipment()
  log(tostring_r(preset, { maxdeeplevel = 6 }))

}, "playerPresets.printCurrentEquip")


function saveLastEquipmentPreset() {
  let presetData = makeDataToSave().__merge({ presetName = loc("playerPreset/lastUsed")})
  playerPresetSetDirect(playerPresetWatch.get().__merge({[$"{PRESET_PREFIX}_{LAST_USED_EQUIPMENT}"] = presetData}))
}

return {
  AGENCY_PRESET_UID
  PRESET_PREFIX
  MAX_PRESETS_COUNT
  MAX_NAME_CHARS_COUNT
  LAST_USED_EQUIPMENT
  PLAYER_PRESETS_IN_ONLINE_SETTINGS
  PRESET_VERSION
  PRESET_VERSION_KEY

  previewPreset
  previewPresetCallbackOverride
  previewPresetOverrideRibbons
  setPlayerPreset
  playerPresetWatch
  renamePreset
  makeDataToSave
  equipPreset
  saveLastEquipmentPreset
  addEquipmentPresetsTable
  addInventoryItems
  saveSuitMods
  useAgencyPreset
  makePresetDataFromCurrentEquipment
  unfoldCountItems
  defaultFilterFunction
}
