from "%sqstd/string.nut" import utf8ToUpper
import "utf8" as utf8

from "%ui/hud/menus/components/inventoryItemsHeroExtraInventories.nut" import mkHeroBackpackItemContainerItemsList, mkHeroSafepackItemContainerItemsList
from "%ui/hud/menus/components/inventoryItemsPresetPreview.nut" import mkSafepackInventoryPresetPreview, mkHeroInventoryPresetPreview, mkBackpackInventoryPresetPreview, inventoryCapacity
from "%ui/mainMenu/raid_preparation_window_state.nut" import checkImportantPresetSlotEmptiness, checkRaidAvailability

from "%ui/components/colors.nut" import TextDisabled, NexusPlayerPointsColor, RedWarningColor
from "%ui/hud/menus/components/damageModel.nut" import bodypartsPanel
from "%ui/hud/menus/components/chronogenesWidget.nut" import chronogenesWidget
from "%ui/components/commonComponents.nut" import bluredPanel, mkText, mkSelectPanelItem, BD_RIGHT, BD_NONE,
  mkTimeComp, mkTooltiped, mkTextArea
from "%dngscripts/sound_system.nut" import sound_play
from "%ui/hud/menus/components/inventoryCommon.nut" import mkInventoryHeaderText
from "%ui/fonts_style.nut" import body_txt, sub_txt, h2_txt, tiny_txt
from "%ui/hud/menus/components/inventoryItemsHeroWeapons.nut" import mkEquipmentWeapons
from "%ui/hud/menus/components/quickUsePanel.nut" import quickUsePanelEdit
from "%ui/hud/menus/components/inventoryItemsHeroItemContainer.nut" import mkHeroItemContainerItemsList
from "%ui/hud/menus/inventoryActions.nut" import moveItemWithKeyboardMode
from "%ui/equipPresets/presetsState.nut" import makePresetDataFromCurrentEquipment, unfoldCountItems, defaultFilterFunction
from "eventbus" import eventbus_send
from "%ui/components/button.nut" import textButton, button, buttonWithGamepadHotkey
from "%ui/equipPresets/convert_loadout_to_preset.nut" import loadoutToPreset, presetToLoadout
from "%ui/components/textInput.nut" import textInput
from "%ui/components/modalWindows.nut" import addModalWindow, removeModalWindow
from "%ui/mainMenu/stdPanel.nut" import mkCloseStyleBtn
from "%ui/mainMenu/startButton.nut" import startButton
import "dagor.random" as random
from "%ui/components/modalPopupWnd.nut" import addModalPopup, removeModalPopup
from "das.equipment" import generate_loadout_by_seed
from "%ui/helpers/timers.nut" import mkCountdownTimer
from "%ui/hud/menus/components/inventoryItemsList.nut" import itemsPanelList, setupPanelsData, inventoryItemSorting
from "%ui/hud/hud_menus_state.nut" import openMenu
from "%ui/hud/menus/components/inventoryItemsListChecksCommon.nut" import MoveForbidReason
from "das.nexus" import get_generator_indexes_bind
from "%ui/hud/menus/components/inventoryFilter.nut" import filterItemByInventoryFilter
from "%ui/hud/menus/components/inventoryStashFiltersWidget.nut" import inventoryFiltersWidget
from "das.inventory" import calc_stacked_item_volume
from "%ui/components/scrollbar.nut" import makeVertScroll
from "%ui/components/cursors.nut" import setTooltip
from "%ui/hud/menus/components/inventoryItemNexusPointPriceComp.nut" import nexusPointsIcon, nexusPointsIconSize
from "%ui/components/msgbox.nut" import showMsgbox, showMessageWithContent
from "%ui/mainMenu/clonesMenu/mainChronogeneSelection.nut" import MAIN_CHRONOGENE_UID
from "string" import startswith
import "%ui/components/faComp.nut" as faComp

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
from "%ui/mainMenu/raid_preparation_window_state.nut" import getNexusStashItems, bannedMintItem

let { shiftPressedMonitor, isAltPressedMonitor, isShiftPressed } = require("%ui/hud/state/inventory_state.nut")
let { safeAreaAmount } = require("%ui/options/safeArea.nut")
let { backpackEid, safepackEid, safepackYVisualSize } = require("%ui/hud/state/hero_extra_inventories_state.nut")
let { inventoryItemClickActions } = require("%ui/hud/menus/inventoryActions.nut")
let { HERO_ITEM_CONTAINER, BACKPACK0, SAFEPACK, NEXUS_ALTER_STASH } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { previewPreset, previewPresetCallbackOverride } = require("%ui/equipPresets/presetsState.nut")
let { alterMints, loadoutsAgency, allCraftRecipes, marketItems, playerStats, playerProfileNexusLoadoutStorageCount
} = require("%ui/profile/profileState.nut")
let { mintEditState, slotsWithWarning } = require("%ui/mainMenu/raid_preparation_window_state.nut")
let { agencyLoadoutGenerators, nexusItemCost, updateNexusCostsOfPreviewPreset, getCostOfPreset } = require("%ui/hud/menus/mintMenu/mintState.nut")
let { activeFilters } = require("%ui/hud/menus/components/inventoryStashFiltersWidget.nut")
let { weaponSlotsKeys } = require("%ui/types/weapon_slots.nut")
let { allItems } = require("%ui/state/allItems.nut")
let JB = require("%ui/control/gui_buttons.nut")

let currentMint = Watched(null)
let mintSelectionState = Watched(null)
let showNameWarning = Watched(false)
let editingAlterId = Watched(null)
let ALTER_CONTEXT_MENU_ID = "AlterContextMenu"
let iconHeight = hdpxi(18)

let selectedAlterIsFree = Computed(function() {
  let { seed = 0, count = 0 } = loadoutsAgency.get()
  if (count == 0)
    return false

  let generatorsCount = agencyLoadoutGenerators.get()?.len()
  if (!generatorsCount)
    return false
  let generatorIndexes = get_generator_indexes_bind(seed, generatorsCount, count)
  let freeListIdx = generatorIndexes?[mintSelectionState.get()]
  if (freeListIdx == null)
    return false

  return agencyLoadoutGenerators.get()?[freeListIdx].isFree
})

function resetMintState() {
  previewPreset.set(null)
  currentMint.set(null)
  mintSelectionState.set(null)
}

function showMintNamePopup(cb, currentMintName = null, isRenaming = false) {
  let weapons = previewPreset.get().weapons
  let weaponTemplateName =
    weapons?[0].itemTemplate ??
    weapons?[1].itemTemplate ??
    weapons?[2].itemTemplate ??
    weapons?[3].itemTemplate

  local weaponLoc = ""
  if (weaponTemplateName) {
    let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(weaponTemplateName)
    weaponLoc = loc(template.getCompValNullable("item__name"))
  }

  let offeredMintName = isRenaming ? currentMintName
    : $"{currentMintName ?? loc("clonesMenu/mainChronogenesTitle")} {weaponLoc} #{random.rnd_int(1, 10000)}"
  let alterName = Watched(offeredMintName)

  let options = {
    margin = 0
    onReturn = function() {
      cb(alterName.get())
      removeModalWindow("mintNamePopup")
    }
    setValue = function(v) {
      alterName.set(v)
      let nameChars = utf8(v)
      let charsCount = nameChars.charCount()
      if (charsCount < 3)
        showNameWarning.set(true)
      else
        showNameWarning.set(false)
    }
    maxChars = 16
    onAttach = @(elem) set_kb_focus(elem)
  }.__update(sub_txt)

  let noEnoughCharsWarning = @() {
    watch = showNameWarning
    size = static [flex(), hdpx(14)]
    children = !showNameWarning.get() ? null : mkTextArea(loc("mint/minNameLength"), {
      color = RedWarningColor
      transform = {}
      animations = [{ prop = AnimProp.opacity, from = 0.4, to = 1, duration = 1,
        play = true, easing = CosineFull, trigger = "noEnoughCharsWarning" }]
    }.__merge(tiny_txt))
  }

  addModalWindow({
    rendObj = ROBJ_WORLD_BLUR_PANEL
    key = "mintNamePopup"
    size = flex()
    onClick = @() null
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    onDetach = @() showNameWarning.set(false)
    children = {
      size = static [ hdpx(400), SIZE_TO_CONTENT ]
      flow = FLOW_VERTICAL
      gap = static hdpx(14)
      padding = static hdpx(10)
      children = [
        {
          size = FLEX_H
          flow = FLOW_HORIZONTAL
          valign = ALIGN_CENTER
          children = [
            mkText(utf8ToUpper(loc("mint/chooseName")), { size = FLEX_H }.__update(body_txt))
            mkCloseStyleBtn(@() removeModalWindow("mintNamePopup"))
          ]
        }
        textInput(alterName, options)
        noEnoughCharsWarning
        textButton(loc("Accept"), function() {
          if (showNameWarning.get()) {
            anim_start("noEnoughCharsWarning")
            sound_play("ui_sounds/button_click_inactive")
            return
          }
          cb(alterName.get())
          removeModalWindow("mintNamePopup")
        }, {
          hplace = ALIGN_CENTER
        })
      ]
    }.__merge(bluredPanel)
  })
}

let mkContextMenuBtn = @(locId, action, icon) button({
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  gap = static hdpx(4)
  valign = ALIGN_CENTER
  children = [
    {
      rendObj = ROBJ_IMAGE
      size = iconHeight
      image = Picture($"ui/skin#context_icons/{icon}:{0}:{0}:P".subst(iconHeight))
    }
    mkText(loc(locId), static { size = FLEX_H })
  ]
}, action, static {
  size = FLEX_H
  halign = ALIGN_CENTER
  padding = static [hdpx(4), hdpx(6)]
  borderWidth = 0
})

function setPreviewPresetFromMintPreset(mintPreset) {
  if (mintPreset == null)
    return
  let playerPreset = loadoutToPreset(mintPreset).__update({ overrideMainChronogeneDoll = true })
  previewPreset.set(playerPreset)
  updateNexusCostsOfPreviewPreset()
}

function setWeaponInPreviewPreset(item, weaponIdx) {
  let prevItem = previewPreset.get()?.weapons[weaponIdx].nexusCost

  previewPreset.mutate(function(v) {
    v.weapons[weaponIdx].itemTemplate <- item?.itemTemplate
    v.weapons[weaponIdx].attachments <- {}
    v.weapons[weaponIdx].nexusCost <- item?.nexusCost
  })

  if (prevItem)
    updateNexusCostsOfPreviewPreset()
}

function setWeaponModInPreviewPreset(item, weaponIdx, modSlotName) {
  let prevItem = previewPreset.get()?.weapons[weaponIdx].attachments[modSlotName].nexusCost

  previewPreset.mutate(function(v) {
    let itemTemplate = item?.itemTemplate
    if (itemTemplate) {
      v.weapons[weaponIdx].attachments[modSlotName] <- {
        itemTemplate
        nexusCost = item?.nexusCost
      }
    }
    else {
      if (modSlotName in v.weapons[weaponIdx].attachments)
        v.weapons[weaponIdx].attachments[modSlotName] = { itemTemplate }
    }
  })

  if (prevItem)
    updateNexusCostsOfPreviewPreset()
}

function setEquipmentInPreviewPreset(item, slotName) {
  let prevItem = previewPreset.get()?[slotName].nexusCost

  previewPreset.mutate(function(preview) {
    let itemTemplate = item?.itemTemplate
    if (itemTemplate) {
      preview[slotName] <- {
        itemTemplate = item.itemTemplate
        nexusCost = item?.nexusCost
      }
    }
    else {
      preview[slotName] <- null
    }

    let inventoryToClear = slotName == "pouch" ? "myItems" : slotName
    if (preview?.inventories[inventoryToClear]) {
      preview.inventories.rawdelete(inventoryToClear)
    }
  })

  if (prevItem)
    updateNexusCostsOfPreviewPreset()
}

function setEquipmentModInPreviewPreset(item, equipment, slotName) {
  let prevItem = previewPreset.get()?[equipment].attachments[slotName].nexusCost

  previewPreset.mutate(function(preview) {
    if ("attachments" not in preview[equipment]) {
      preview[equipment]["attachments"] <- {}
    }

    preview[equipment].attachments[slotName] <-
      (
        preview[equipment].attachments?[slotName] ?? {}).__merge({
          itemTemplate = item?.itemTemplate
          nexusCost = item?.nexusCost
        }
      )
  })

  if (prevItem)
    updateNexusCostsOfPreviewPreset()
}

function getEquipmentSlots(item) {
  if (item?.itemTemplate == null)
    return {}

  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(item.itemTemplate)
  return template.getCompValNullable("equipment_mods__slots")?.getAll() ?? {}
}

function setEquipmentMods(preset, presetCallbacks, equipments) {
  foreach (equipKey in equipments) {
    let equipVal = preset?[equipKey] ?? {}
    let equip = equipKey
    let tbl = {
      onDrop = @(item) setEquipmentInPreviewPreset(item, equip)
      attachments = {}
    }
    if (equipVal?.itemTemplate == null) {
      presetCallbacks[equip] <- tbl
      continue
    }

    let slots = getEquipmentSlots(equipVal)
    foreach (modKey, _modVal in slots) {
      let mod = modKey
      tbl.attachments[modKey] <- {
        onDrop = @(item) setEquipmentModInPreviewPreset(item, equip, mod)
      }
    }
    presetCallbacks[equip] <- tbl
  }
}


function setPrimaryChronogene(item) {
  if (!item?.mainChronogeneAvailable) {
    showMsgbox({text = loc("clonesMenu/notAvailableChronogene/msg")})
    return
  }
  previewPreset.mutate(function(v) {
    v.chronogene_primary_1.itemTemplate = item.itemTemplate
  })
  removeModalWindow(MAIN_CHRONOGENE_UID)
}


function setSuitModInPreviewPreset(item, slotName) {
  let prevItem = previewPreset.get()?.chronogene_primary_1[slotName].nexusCost

  previewPreset.mutate(function(preview) {
    if (item?.itemTemplate) {
      preview.chronogene_primary_1[slotName] <- (preview.chronogene_primary_1?[slotName] ?? {}).__merge({
        itemTemplate = item.itemTemplate
        charges = item?.isBoxedItem ? 1 : null
        nexusCost = item?.nexusCost
      })
    }
    else {
      preview.chronogene_primary_1[slotName] = null
    }
  })

  if (prevItem)
    updateNexusCostsOfPreviewPreset()
}


function setSuitMods(preset, presetCallbacks) {
  let suitSlotName = "chronogene_primary_1"
  let suit = preset?[suitSlotName]
  let slots = getEquipmentSlots(suit)

  let callbacks = { onDrop = @(item) setPrimaryChronogene(item) }
  foreach (modKey, _modVal in slots) {
    let keyToDrop = modKey
    callbacks[modKey] <- {
      onDrop = @(item) setSuitModInPreviewPreset(item, keyToDrop)
    }
  }
  presetCallbacks[suitSlotName] <- callbacks
}

function removeFromList(item, listName, shiftPresed) {
  previewPreset.mutate(function(preset) {
    
    if (shiftPresed) {
      preset.inventories[listName].items = preset.inventories[listName].items.filter(@(v) v.itemTemplate != item.itemTemplate)
      return
    }

    let idx = preset.inventories[listName].items.findindex(@(v) v?.itemTemplate == item?.itemTemplate)

    if (idx == null)
      return

    
    if (item.isBoxedItem) {
      preset.inventories[listName].items[idx].ammoCount -= item.countPerStack
      if (preset.inventories[listName].items[idx].ammoCount <= 0)
        preset.inventories[listName].items.remove(idx)
    }
    
    else {
      preset.inventories[listName].items.remove(idx)
    }

    updateNexusCostsOfPreviewPreset()
  })
}


function dropToInventory(item, inventoryName) {
  previewPreset.mutate(function(preview) {
    
    if (item?.fromList.name == HERO_ITEM_CONTAINER.name) {
      removeFromList(item, "myItems", false)
    }
    else if (item?.fromList.name == BACKPACK0.name) {
      removeFromList(item, "backpack", false)
    }

    if (preview?.inventories == null) {
      preview["inventories"] <- {}
    }
    if (preview.inventories?[inventoryName] == null) {
      preview.inventories[inventoryName] <- {
        capacity = 0
        items = []
      }
    }

    if (item.isBoxedItem) {
      let idx = preview.inventories[inventoryName].items.findindex(@(v) v.itemTemplate == item.itemTemplate)
      if (idx == null) {
        let cloned = clone(item)
        cloned.charges = cloned.countPerStack
        cloned.ammoCount = cloned.countPerStack

        preview.inventories[inventoryName].items.append(cloned)
      }
      else {
        let alreadyInItem = preview.inventories[inventoryName].items[idx]
        if (alreadyInItem?.charges != null)
          alreadyInItem.charges += item.countPerStack
        alreadyInItem.ammoCount += item.countPerStack
      }
    }
    else {
      let cloned = clone(item)
      cloned.count = 1
      cloned.eids = item.eid
      cloned.uniqueIds = [item.eid]

      preview.inventories[inventoryName].items.append(cloned)
    }
  })
}

function setInventoriesCallbacks(callbacksOverride, inventoriesName) {
  let inventories = {}
  foreach (inv in inventoriesName) {
    let inventoryName = inv
    inventories[inv] <- {
      on_item_dropped_to_list_cb = @(item, _list) dropToInventory(item, inventoryName)
    }
  }
  callbacksOverride["inventories"] <- inventories
}

function updatePreviewCallbacks(preview, isEditMode) {
  if (!isEditMode) {
    previewPresetCallbackOverride.set(null)
    return
  }
  if (!preview)
    return
  let callbacksOverride = { weapons = [] }
  for (local i = 0; i < min((preview?.weapons ?? 0).len(), 4); i++) {
    let idx = i
    callbacksOverride.weapons.append({
      onDropToSlot = function(item, _weapon) {
        setWeaponInPreviewPreset(item, idx)
      }
      onDropToMod = function(item, _weapon, modSlotName, _modSlot) {
        setWeaponModInPreviewPreset(item, idx, modSlotName)
      }
      canDropToMod = function(item, _weapon, _modSlotName, modSlot) {
        return modSlot.allowed_items.findindex(@(v) v == item.itemTemplate) != null
      }
    })
  }
  setEquipmentMods(preview, callbacksOverride, [
    "flashlight", "helmet", "safepack", "backpack", "pouch",
    "chronogene_secondary_1", "chronogene_secondary_2", "chronogene_secondary_3", "chronogene_secondary_4"
  ])
  setSuitMods(preview, callbacksOverride)
  setInventoriesCallbacks(callbacksOverride, [ "myItems", "backpack" ])
  previewPresetCallbackOverride.set(callbacksOverride)
}


function setMintEditState(isEditState) {
  mintEditState.set(isEditState)
  updatePreviewCallbacks(previewPreset.get(), isEditState)
}

function showAlterContextMenu(point, alterIdx) {
  let mint = alterMints.get()[alterIdx]

  let ranameMint = mkContextMenuBtn(loc("mint/rename"), function() {
    removeModalPopup(ALTER_CONTEXT_MENU_ID)
    showMintNamePopup(function(v) {
      eventbus_send("profile_server.rename_mint", { mint_id = mint.id.tostring(), mint_name = v })
    }, mint.name, true)
  }, "rename_alter.svg")

  let deleteMint = mkContextMenuBtn(loc("mint/delete"), function() {
    removeModalPopup(ALTER_CONTEXT_MENU_ID)
    eventbus_send("profile_server.delete_mint", mint.id.tostring())
  }, "trash.svg")

  let editMint = mkContextMenuBtn(loc("mint/edit"), function() {
    removeModalPopup(ALTER_CONTEXT_MENU_ID)
    setPreviewPresetFromMintPreset(mint)
    editingAlterId.set(mint.id.tostring())
    mintSelectionState.set(alterIdx)
    setMintEditState(true)
  }, "edit_alter.svg")

  addModalPopup(point, {
    size = static [hdpx(200), SIZE_TO_CONTENT]
    uid = ALTER_CONTEXT_MENU_ID
    flow = FLOW_VERTICAL
    popupValign = ALIGN_TOP
    padding = 0
    moveDuraton = 0
    children = [
      editMint
      ranameMint
      deleteMint
    ]
  })
}

let nexusStashItems = Computed(function() {
  let openedRecipes = allCraftRecipes.get().filter(@(v) v?.isOpened)
  let res = getNexusStashItems(allItems.get(), openedRecipes, allCraftRecipes.get(),
    marketItems.get(), playerStats.get())

  let nexusCost = nexusItemCost.get()
  return res.sort(inventoryItemSorting).map(function(itm) {
    if (itm?.item__nexusCost == null)
      return itm

    if (nexusCost?[itm.itemTemplate].cost == null)
      return itm.__merge({ nexusCost = itm.item__nexusCost })

    return itm.__merge({ nexusCost = nexusCost[itm.itemTemplate].cost })
  })
})

let nexusOpenedItemTemplates = Computed(function() {
  let openedRecipes = allCraftRecipes.get().filter(@(v) v?.isOpened)
  let items = getNexusStashItems(allItems.get(), openedRecipes, allCraftRecipes.get(),
    marketItems.get(), playerStats.get())

  let ret = {}
  foreach (item in items) {
    ret[item.itemTemplate] <- true
  }
  return ret
})

function currentPresetMissedItems() {
  let templates = nexusOpenedItemTemplates.get()
  let pp = previewPreset.get()

  let missed = {}

  function checkTemplate(templateToCheck) {
    if (templateToCheck == null)
      return

    if (!templates?[templateToCheck]) {
      missed[templateToCheck] <- true
    }
  }

  foreach (k, v in pp ?? {}) {
    if (startswith(k, "chronogene"))
      continue
    if (v?.itemTemplate)
      checkTemplate(v.itemTemplate)
  }

  foreach (_k, v in pp?.pouch.attachments ?? {})
    checkTemplate(v.itemTemplate)

  foreach (_k, v in pp?.helmet.attachments ?? {})
    checkTemplate(v.itemTemplate)

  foreach (_k, v in pp?.chronogene_primary_1 ?? {})
    checkTemplate(v?.itemTemplate)

  foreach (v in pp?.inventories.myItems.items ?? [])
    checkTemplate(v.itemTemplate)

  foreach (v in pp?.inventories.backpack.items ?? [])
    checkTemplate(v.itemTemplate)

  foreach (weap in pp?.weapons ?? []) {
    checkTemplate(weap?.itemTemplate)
    foreach (_k, v in weap?.attachments ?? {}) {
      checkTemplate(v?.itemTemplate)
    }
  }

  return missed
}

let stashItemsProceed = function(items) {
  return clone(items).filter(filterItemByInventoryFilter)
}

let stashRefineItemsPanelData = setupPanelsData(nexusStashItems,
                                4,
                                [nexusStashItems, activeFilters, nexusItemCost],
                                stashItemsProceed)

let fastMoveItemFromStash = function(item) {
  let preset = previewPreset.get()

  
  if (item?.equipmentSlots.len()) {
    if(preset?[item.equipmentSlots[0]]?.itemTemplate == null) {
      setEquipmentInPreviewPreset(item, item.equipmentSlots[0])
      return
    }
  }
  
  foreach(equipName in [ "pouch", "helmet" ]) {
    foreach (modSlotKey, slotTemplate in getEquipmentSlots(preset?[equipName])) {
      if (preset?[equipName].attachments[modSlotKey].itemTemplate != null)
        continue

      let itemTemplate = item?.templateName ? ecs.g_entity_mgr.getTemplateDB().getTemplateByName(slotTemplate) : null
      let fittedItems = itemTemplate?.getCompValNullable("slot_holder__availableItems")?.getAll() ?? []

      if (fittedItems.contains(item?.itemTemplate)){
        setEquipmentModInPreviewPreset(item, equipName, modSlotKey)
        return
      }
    }
  }
  
  foreach (modSlotKey, slotTemplate in getEquipmentSlots(preset?.chronogene_primary_1)) {
    if (preset?.chronogene_primary_1[modSlotKey].itemTemplate != null)
      continue

    let itemTemplate = item?.templateName ? ecs.g_entity_mgr.getTemplateDB().getTemplateByName(slotTemplate) : null
    let fittedItems = itemTemplate?.getCompValNullable("slot_holder__availableItems")?.getAll() ?? []

    if (fittedItems.contains(item?.itemTemplate)){
      setSuitModInPreviewPreset(item, modSlotKey)
      return
    }
  }
  
  for (local i = 0; i < min((preset?.weapons ?? 0).len(), 4); i++) {
    let weapon = preset?.weapons[i]
    let weaponTemplateName = weapon?.itemTemplate
    if (weaponTemplateName == null) {
      foreach (weapSlotName in (item?.validWeaponSlots ?? [])) {
        let idx = weaponSlotsKeys.findindex(@(v) v == weapSlotName)

        if (idx == i) {
          setWeaponInPreviewPreset(item, i)
          return
        }
      }
    }
    else {
      let weaponTemplate = item?.templateName ? ecs.g_entity_mgr.getTemplateDB().getTemplateByName(weaponTemplateName) : null
      let weaponSlots = weaponTemplate?.getCompValNullable("gun_mods__slots")?.getAll() ?? {}
      foreach (slotName, slotTemplateName in weaponSlots) {
        let slotTemplate = item?.templateName ? ecs.g_entity_mgr.getTemplateDB().getTemplateByName(slotTemplateName) : null
        let availableItems = slotTemplate?.getCompValNullable("slot_holder__availableItems")?.getAll() ?? []

        if (availableItems.findindex(@(v) v == item?.itemTemplate) != null) {
          setWeaponModInPreviewPreset(item, i, slotName)
          return
        }
      }
    }
  }

  function getItemVolume(itemToGetVol) {
    let itemTemplate = itemToGetVol.itemTemplate
    let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(itemTemplate)
    let isBoxed = template?.getCompValNullable("boxed_item__template") != null

    if (isBoxed) {
      let countPerStack = template?.getCompValNullable("item__countPerStack")
      let volumePerStack = template?.getCompValNullable("item__volumePerStack")
      let ammoCount = itemToGetVol?.ammoCount ?? 0
      return calc_stacked_item_volume(countPerStack, ammoCount, volumePerStack)
    }
    else {
      return (template?.getCompValNullable("item__volume") ?? 0)
    }
  }

  let itemVolume = getItemVolume(item)
  
  local currentMyItemsVolume = 0
  foreach (inventoryItem in (preset?.inventories.myItems.items ?? [])) {
    currentMyItemsVolume += (getItemVolume(inventoryItem))
  }

  let militant = ecs.g_entity_mgr.getTemplateDB().getTemplateByName("militant_inventory") 
  local myItemsCapacity = militant?.getCompValNullable("human_inventory__maxVolume") ?? 0

  let pouchTemplate = previewPreset.get()?.pouch.itemTemplate
  if (pouchTemplate) {
    let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(pouchTemplate)
    myItemsCapacity += (template?.getCompValNullable("item__inventoryExtension") ?? 0)
  }
  if (currentMyItemsVolume + itemVolume <= myItemsCapacity) {
    dropToInventory(item, "myItems")
    return
  }

  
  foreach (inventoryName in ["safepack", "backpack"]) {
    let inventoryCap = inventoryCapacity(inventoryName, preset)
    if (inventoryCap == 0)
      continue

    local inventoryVolume = 0
    foreach (inventoryItem in (preset?.inventories[inventoryName].items ?? [])) {
      inventoryVolume += getItemVolume(inventoryItem)
    }

    if (inventoryVolume + itemVolume <= inventoryCap) {
      dropToInventory(item, inventoryName)
      return
    }
  }
}

function selectAvaliableAlter() {
  let alterToSelect = alterMints.get()?[0]
  if (alterToSelect) {
    mintSelectionState.set(alterMints.get()?[0].id)
    setPreviewPresetFromMintPreset(alterMints.get()?[0])
    currentMint.set(alterMints.get()?[0])
  }
  else {
    let idx = 0
    let { seed = 0, count = 0 } = loadoutsAgency.get()
    let generatorIndexes = get_generator_indexes_bind(seed, agencyLoadoutGenerators.get().len(), count)
    let generatorIndex = generatorIndexes[0]
    let agencyLoadoutGenerator = agencyLoadoutGenerators.get()[generatorIndex]
    let generatorName = agencyLoadoutGenerator.generator

    let compArray = ecs.CompArray()
    let seedInt = seed.tointeger()
    generate_loadout_by_seed(generatorName, seedInt, compArray)
    let preset = loadoutToPreset({ items = compArray.getAll() }).__merge({ overrideMainChronogeneDoll = true })
    previewPreset.set(preset)
    mintSelectionState.set(idx)
  }
}

let stashContent = function() {
  let nexusPointPrice = Computed(function() {
    local cost = 0
    foreach (_k, v in nexusItemCost.get() ?? {}) {
      cost += v.overallCost
    }
    return cost
  })
  return function() {
    stashRefineItemsPanelData.resetScrollHandlerData()

    
    
    stashRefineItemsPanelData.onAttach()
    stashRefineItemsPanelData.updateItemsPanelData()

    return {
      watch = [ nexusStashItems, playerStats, marketItems, stashRefineItemsPanelData.numberOfPanels, activeFilters ]
      size = flex()
      halign = ALIGN_CENTER
      flow = FLOW_VERTICAL
      gap = hdpx(4)
      children = [
        @() {
          watch = [ nexusStashItems, activeFilters, nexusItemCost ]
          size = flex()
          children = itemsPanelList({
            outScrollHandlerInfo=stashRefineItemsPanelData.scrollHandlerData,
            itemsPanelData=stashRefineItemsPanelData.itemsPanelData,
            list_type=NEXUS_ALTER_STASH,
            on_item_dropped_to_list_cb=function(item, _list_type) {
              if (item?.fromList.name == HERO_ITEM_CONTAINER.name) {
                removeFromList(item, "myItems", isShiftPressed.get())
              }
              else if (item?.fromList.name == BACKPACK0.name) {
                removeFromList(item, "backpack", isShiftPressed.get())
              }
            },
            can_drop_dragged_cb = function(item) {
              if (item?.fromList.name == NEXUS_ALTER_STASH.name) {
                return MoveForbidReason.OTHER
              }
              return MoveForbidReason.NONE
            }
            item_actions = {
              lmbAction = @(item) fastMoveItemFromStash(item)
            }
            xSize = 4
          })
        }
        button({
            size = SIZE_TO_CONTENT
            flow = FLOW_HORIZONTAL
            margin = [fsh(1), fsh(3)]
            gap = hdpx(10)
            children = [
              mkText(loc("mint/save"), body_txt)
              @() {
                watch = nexusPointPrice
                children = {
                  rendObj = ROBJ_BOX
                  flow = FLOW_HORIZONTAL
                  gap = hdpx(4)
                  padding = [ 0, hdpx(10) ]
                  fillColor = NexusPlayerPointsColor
                  borderRadius = hdpx(2)
                  children = nexusPointPrice.get() > 0 ? [
                    {
                      rendObj = ROBJ_IMAGE
                      image = nexusPointsIcon
                      size = nexusPointsIconSize
                      vplace = ALIGN_CENTER
                    }
                    mkText(nexusPointPrice.get(), body_txt)
                  ] : null
                }
              }
            ]
          },
          function() {
              let curMissed = currentPresetMissedItems()
              if (curMissed.len() > 0) {
                showMessageWithContent({
                  content = {
                    size = [sw(80), SIZE_TO_CONTENT]
                    flow = FLOW_VERTICAL
                    halign = ALIGN_CENTER
                    gap = hdpx(10)
                    children = [
                      mkText(loc("mint/unavailableItems"), h2_txt)
                      {
                        flow = FLOW_VERTICAL
                        children = curMissed.keys().map(function(v) {
                          let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(v)
                          if (template == null)
                            throw null
                          return mkText(loc(template.getCompValNullable("item__name")), body_txt.__merge({color = RedWarningColor}))
                        })
                      }
                    ]
                  }
                })
                return
              }
              let items = presetToLoadout(previewPreset.get())
              if (editingAlterId.get() == null) {
                let alterTemplate = items.findvalue(@(v) v?.slotName == "equipment_chronogene_primary_1")?.templateName
                local alterName = null
                if (alterTemplate != null) {
                  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(alterTemplate)
                  alterName = loc(template.getCompValNullable("item__name"))
                }
                showMintNamePopup(function(name) {
                  eventbus_send("profile_server.create_mint", { items = items, name })
                  setMintEditState(false)
                  resetMintState()
                  editingAlterId.set(null)
                  selectAvaliableAlter()
                }, alterName)
              }
              else {
                eventbus_send("profile_server.change_mint", { items = items, mint_id = editingAlterId.get() })
                editingAlterId.set(null)
                setMintEditState(false)
              }
            },
            {
              size = FLEX_H
              halign = ALIGN_CENTER
            }
          )
          textButton(loc("Cancel"), function() {
            setMintEditState(false)
            resetMintState()
            selectAvaliableAlter()
          }, { size = FLEX_H, halign = ALIGN_CENTER })
      ]
    }.__update(bluredPanel)
  }
}

let stashTab = {
  flow = FLOW_HORIZONTAL
  size = flex()
  children = [
    stashContent()
    inventoryFiltersWidget
  ]
}

function removeFromInventory(inventoryName, item) {
  previewPreset.mutate(function(preset) {
    let items = preset.inventories[inventoryName].items
    let idx = items.findindex(@(v) v.itemTemplate == item.itemTemplate)
    if (idx == null)
      return
    if (item.isBoxedItem) {
      items[idx].ammoCount -= items[idx].countPerStack
      if (items[idx].ammoCount <= 0)
        items.remove(idx)
    }
    else {
      items[idx].count -= 1
      if (items[idx].count <= 0)
        items.remove(idx)
    }
  })
}

let mintsList = function() {
  return {
    watch = alterMints
    size = FLEX_H
    children = {
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap = hdpx(6)
      children = [
        {
          padding = hdpx(6)
          size = FLEX_H
          flow = FLOW_VERTICAL
          children = [
            mkText(loc("mint/mintListTitle"), { hplace = ALIGN_CENTER })
            mkText(loc("mint/mintCount", { currentMintCount=alterMints?.get().len(), maxMintCount=playerProfileNexusLoadoutStorageCount.get() }), { hplace = ALIGN_CENTER })
          ]
        },
        {
          size = FLEX_H
          flow = FLOW_VERTICAL
          gap = hdpx(4)
          children = alterMints.get().map(function(mint, idx) {
            let { name } = mint
            let playerPreset = loadoutToPreset(mint).__update({ overrideMainChronogeneDoll = true })

            return {
              flow = FLOW_HORIZONTAL
              size = FLEX_H
              children = [
                mkSelectPanelItem({
                  border_align = BD_NONE
                  children = @(...) {
                    size = flex()
                    gap = hdpx(10)
                    valign = ALIGN_CENTER
                    flow = FLOW_HORIZONTAL
                    children = [
                      mkText(name, {
                        size = FLEX_H
                        behavior = Behaviors.Marquee
                        speed = hdpx(50)
                      }.__update(h2_txt))
                      {
                        hplace = ALIGN_RIGHT
                        valign = ALIGN_CENTER
                        flow = FLOW_HORIZONTAL
                        rendObj = ROBJ_BOX
                        gap = hdpx(4)
                        padding = [ 0, hdpx(10) ]
                        fillColor = NexusPlayerPointsColor
                        size = FLEX_V
                        borderRadius = [ hdpx(2), 0, 0, hdpx(2) ]
                        children = [
                          {
                            rendObj = ROBJ_IMAGE
                            image = nexusPointsIcon
                            size = nexusPointsIconSize
                          }
                          mkText(getCostOfPreset(playerPreset), body_txt.__merge({ color = Color(255, 255, 255, 255) }))
                        ]
                      }
                    ]
                  }
                  idx = mint.id
                  state = mintSelectionState
                  onSelect = function(newIdx) {
                    previewPreset.set(playerPreset)
                    updateNexusCostsOfPreviewPreset()
                    currentMint.set(mint)
                    mintSelectionState.set(newIdx)
                  }
                  cb = function(event) {
                    if (event.button == 1) {
                      let { screenX, screenY } = event
                      showAlterContextMenu([ screenX, screenY ], idx)
                    }
                  }
                  visual_params = {
                    size = static [ flex(), hdpx(40) ]
                    padding = static [ 0, hdpx(2), 0, hdpx(10) ]
                    xmbNode = XmbNode()
                  }
                })
                button({
                    rendObj = ROBJ_IMAGE
                    size = hdpxi(22)
                    image = Picture($"!ui/skin#triple_dot.svg:{0}:{0}:K".subst(hdpxi(22)))
                  },
                  function(event) {
                    let { screenX, screenY } = event
                    showAlterContextMenu([ screenX, screenY ], idx)
                  },
                  {
                    halign = ALIGN_CENTER
                    valign = ALIGN_CENTER
                    size = static [hdpx(40), flex()]
                    stopMouse = true
                  }
                )
              ]
            }
          }).append(
            (alterMints.get()?.len() ?? 0) < playerProfileNexusLoadoutStorageCount.get() ? textButton(loc("mint/createNew"),
              function() {
                let prs = makePresetDataFromCurrentEquipment(function(item) {
                  return !bannedMintItem(item?.itemTemplate) && defaultFilterFunction(item)
                })
                prs.__update({ overrideMainChronogeneDoll = true })
                if (prs?.inventories.myItems.items)
                  prs.inventories.myItems.items = unfoldCountItems(prs.inventories.myItems.items)
                if (prs?.inventories.backpack.items)
                  prs.inventories.backpack.items = unfoldCountItems(prs.inventories.backpack.items)
                previewPreset.set(prs)
                setMintEditState(true)
                updateNexusCostsOfPreviewPreset()
              },
              {
                size = FLEX_H
                halign = ALIGN_CENTER
              }
            ) : null
          )
        }
      ]
    }
  }
}

let mintManage = {
  vplace = ALIGN_BOTTOM
  size = FLEX_H
  children = startButton()
}

let backButton = buttonWithGamepadHotkey(mkText(loc("mainmenu/btnBack"), { hplace = ALIGN_CENTER }.__merge(body_txt)),
  @() openMenu("Missions"),
  {
    size = FLEX_H
    halign = ALIGN_CENTER
    hotkeys = [[$"Esc | {JB.B}", { description = { skip = true } }]]
  })

function agencyAlters() {
  let updateAltersTimer = Computed(function() {
    if (loadoutsAgency.get()?.updateTimeAt) {
      return loadoutsAgency.get().updateTimeAt.tofloat()
    }
    return 0
  })

  return function() {
    let { seed = 0, count = 0 } = loadoutsAgency.get()
    let timer = mkCountdownTimer(updateAltersTimer)

    let agencyPanels = []
    if (agencyLoadoutGenerators.get().len() == 0)
      return { watch = agencyLoadoutGenerators }
    let generatorIndexes = get_generator_indexes_bind(seed, agencyLoadoutGenerators.get().len(), count)
    for (local i = 0; i < count; i++) {
      let idx = i
      let generatorIndex = generatorIndexes[i]
      let agencyLoadoutGenerator = agencyLoadoutGenerators.get()[generatorIndex]
      let generatorName = agencyLoadoutGenerator.generator
      let loadoutName = agencyLoadoutGenerator.name
      let isFree = agencyLoadoutGenerator.isFree

      
      let iter = i

      let compArray = ecs.CompArray()
      let seedInt = seed.tointeger() + iter
      generate_loadout_by_seed(generatorName, seedInt, compArray)
      let playerPreset = loadoutToPreset({ items = compArray.getAll() }).__merge({ overrideMainChronogeneDoll = true })

      agencyPanels.append(
        mkSelectPanelItem({
          border_align = BD_RIGHT
          children = {
            size = flex()
            flow = FLOW_HORIZONTAL
            gap = hdpx(10)
            valign = ALIGN_CENTER
            children = [
              mkText(loadoutName, {
                size = FLEX_H
                behavior = Behaviors.Marquee
                speed = hdpx(50)
              }.__update(h2_txt))
              isFree ? null : {
                flow = FLOW_HORIZONTAL
                hplace = ALIGN_RIGHT
                valign = ALIGN_CENTER
                padding = static [ 0, hdpx(10) ]
                gap = hdpx(4)
                rendObj = ROBJ_BOX
                fillColor = NexusPlayerPointsColor
                size = FLEX_V
                borderRadius = static [ hdpx(2), 0, 0, hdpx(2) ]
                children = [
                  {
                    rendObj = ROBJ_IMAGE
                    image = nexusPointsIcon
                    size = nexusPointsIconSize
                  }
                  mkText(getCostOfPreset(playerPreset), static body_txt.__merge({ color = Color(255, 255, 255, 255) }))
                ]
              }
            ]
          }
          idx
          state = mintSelectionState
          onSelect = function(...) {
            previewPreset.set(playerPreset)
            mintSelectionState.set(idx)

            if (!isFree) {
              updateNexusCostsOfPreviewPreset()
            }
          }
          visual_params = {
            size = static [ flex(), hdpx(40) ]
            padding = static [ 0, hdpx(2), 0, hdpx(10) ]
            xmbNode = XmbNode()
          }
        })
      )
    }
    return {
      watch = [ updateAltersTimer ]
      size = FLEX_H
      flow = FLOW_VERTICAL
      children = [
        {
          size = FLEX_H
          padding = hdpx(6)
          flow = FLOW_VERTICAL
          children = [
            {
              size = FLEX_H
              children = [
                mkText(loc("mint/agencyAltersTitle"), { hplace = ALIGN_CENTER })
              ]
            }
            @() {
              watch = timer
              size = FLEX_H
              halign = ALIGN_CENTER
              flow = FLOW_HORIZONTAL
              children = [
                mkText(loc("mint/agencyUpdateIn"), {color = TextDisabled}),
                mkTimeComp(timer.get())
              ]
            }
          ]
        }
        {
          size = FLEX_H
          flow = FLOW_VERTICAL
          gap = hdpx(4)
          children = agencyPanels
        }
      ]
    }
  }
}


let mkMintList = @(rotationTimer) {
  size = flex()
  flow = FLOW_VERTICAL
  gap = hdpx(12)
  children = [
    makeVertScroll({
      xmbNode = XmbContainer({
        canFocus = false
        wrap = false
        scrollSpeed = 5.0
      })
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap = hdpx(20)
      children = [
        mintsList
        agencyAlters()
      ]
    })
    {
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap = hdpx(4)
      vplace = ALIGN_BOTTOM
      children = [
        rotationTimer
        backButton
        mintManage
      ]
    }
  ]
}


function heroInventories() {
  local pouches = mkHeroItemContainerItemsList(moveItemWithKeyboardMode, inventoryItemClickActions[HERO_ITEM_CONTAINER.name])
  local backpack = backpackEid.get() == ecs.INVALID_ENTITY_ID ? null
    : mkHeroBackpackItemContainerItemsList(moveItemWithKeyboardMode, inventoryItemClickActions[BACKPACK0.name])
  if (previewPreset.get()) {
    pouches = mkHeroInventoryPresetPreview(mintEditState.get() ? { lmbAction = @(item) removeFromInventory("myItems", item) } : {})
    backpack = previewPreset.get()?.backpack.itemTemplate == null ? null
      : mkBackpackInventoryPresetPreview(mintEditState.get() ? { lmbAction = @(item) removeFromInventory("backpack", item) } : {})
  }

  return {
    watch = [ backpackEid, previewPreset, mintEditState ]
    size = FLEX_V
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      {
        size = FLEX_V
        children = pouches
      }.__update(bluredPanel)
      backpack == null ? null : {
        size = FLEX_V
        children = backpack
      }.__update(bluredPanel)
      function() {
        local safepack = safepackEid.get() == ecs.INVALID_ENTITY_ID ? null
          : mkHeroSafepackItemContainerItemsList(moveItemWithKeyboardMode, inventoryItemClickActions[SAFEPACK.name])
        if (previewPreset.get())
          safepack = previewPreset.get()?.safePack.itemTemplate == null ? null
            : mkSafepackInventoryPresetPreview(mintEditState.get() ? { lmbAction = @(item) removeFromInventory("safepack", item) } : {})
        let watch = [safepackYVisualSize, safepackEid, previewPreset]
        if (safepack == null)
          return { watch }
        return {
          watch
          size = [SIZE_TO_CONTENT, safepackYVisualSize.get() != null ? SIZE_TO_CONTENT : flex()]
          children = safepack
        }.__update(bluredPanel)
      }
    ]
  }
}


let weaponPanels = @() {
  watch = [ safeAreaAmount, mintEditState ]
  size = FLEX_V
  flow = FLOW_VERTICAL
  gap = safeAreaAmount.get() == 1 ? hdpx(6) : 0
  padding = safeAreaAmount.get() == 1 ? hdpx(10) : 0
  children = [
    mkInventoryHeaderText(loc("inventory/weapons"), {
        size = [ flex(), safeAreaAmount.get() == 1 ? hdpx(40) : hdpx(20)]
      }.__update(safeAreaAmount.get() == 1 ? body_txt : sub_txt))
    mkEquipmentWeapons()
    quickUsePanelEdit
  ]
}.__update(bluredPanel)


function priceTitle() {
  let nexusPointPrice = Computed(function() {
    local cost = 0
    foreach (_k, v in nexusItemCost.get() ?? {}) {
      cost += v.overallCost
    }
    return cost
  })

  return @() {
    watch = [ nexusPointPrice, selectedAlterIsFree ]
    rendObj = ROBJ_BOX
    borderRadius = [ 0, 0, 0, hdpx(5) ]
    fillColor = NexusPlayerPointsColor
    hplace = ALIGN_RIGHT
    vplace = ALIGN_TOP
    padding = hdpx(10)
    children = selectedAlterIsFree.get() || nexusPointPrice.get() == 0 ? null : {
      children = [
        mkTooltiped(
          {
            gap = hdpx(4)
            flow = FLOW_HORIZONTAL
            children = [
              mkText(loc("mint/nexusPointsTitle")),
              {
                size = nexusPointsIconSize
                rendObj = ROBJ_IMAGE
                image = nexusPointsIcon
              },
              mkText(nexusPointPrice.get()),
              faComp("question-circle", {
                padding = [ 0, hdpx(5) ]
                color = Color(255,255,255,255)
              })
            ]
          }
          loc("mint/nexusPointsTitleTooltip")
        )
      ]
    }
  }
}


let bodyPartsPanel = {
  size = FLEX_V
  valign = ALIGN_CENTER
  children = [
    {
      size = FLEX_V
      padding = [ 0, hdpx(10), hdpx(10), hdpx(10) ]
      children = [
        bodypartsPanel
        chronogenesWidget
      ]
    }
    priceTitle()
  ]
}.__update(bluredPanel)


let mkPresetStashTabs = @(rotationTimer) @() {
  watch = mintEditState
  size = static [hdpx(364), flex()]
  flow = FLOW_VERTICAL
  gap = hdpx(10)
  children = mintEditState.get() ? stashTab : mkMintList(rotationTimer)
}


function updateDataAfterPresetChange(preset) {
  updatePreviewCallbacks(preset, mintEditState.get())
  checkImportantPresetSlotEmptiness(preset)
}

function resetMintMenuState() {
  setMintEditState(false)
  resetMintState()
  selectAvaliableAlter()
}

function mkMintContent(rotationTimer) {
  previewPreset.subscribe_with_nasty_disregard_of_frp_update(@(preset) updateDataAfterPresetChange(preset))
  return {
    size = flex()
    flow = FLOW_HORIZONTAL
    gap = { size = flex() }
    padding = hdpx(4)
    onAttach = function() {
      gui_scene.setInterval(10, checkRaidAvailability)
      selectAvaliableAlter()
    }
    onDetach = function() {
      previewPreset.set(null)
      previewPreset.unsubscribe(updateDataAfterPresetChange)
      previewPresetCallbackOverride.set(null)
      mintEditState.set(false)
      editingAlterId.set(null)
      slotsWithWarning.set({})
      gui_scene.clearTimer(checkRaidAvailability)
    }
    children = [
      shiftPressedMonitor
      isAltPressedMonitor
      bodyPartsPanel
      weaponPanels
      heroInventories
      mkPresetStashTabs(rotationTimer)
    ]
  }
}

return {
  mkMintContent
  resetMintMenuState
}