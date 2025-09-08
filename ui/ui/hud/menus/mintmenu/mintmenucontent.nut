from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
from "%ui/mainMenu/raid_preparation_window_state.nut" import getNexusStashItems, bannedMintItem

let { TextDisabled } = require("%ui/components/colors.nut")
let { shiftPressedMonitor, isAltPressedMonitor, isShiftPressed } = require("%ui/hud/state/inventory_state.nut")
let { bodypartsPanel } = require("%ui/hud/menus/components/damageModel.nut")
let { secondaryChronogenesWidget } = require("%ui/hud/menus/components/secondaryChronogenesWidget.nut")
let { bluredPanel, mkText, mkSelectPanelItem, BD_RIGHT, mkMonospaceTimeComp } = require("%ui/components/commonComponents.nut")
let { mkInventoryHeaderText } = require("%ui/hud/menus/components/inventoryCommon.nut")
let { safeAreaAmount } = require("%ui/options/safeArea.nut")
let { body_txt, sub_txt, h2_txt } = require("%ui/fonts_style.nut")
let { mkEquipmentWeapons } = require("%ui/hud/menus/components/inventoryItemsHeroWeapons.nut")
let { quickUsePanelEdit } = require("%ui/hud/menus/components/quickUsePanel.nut")
let { mkHeroItemContainerItemsList } = require("%ui/hud/menus/components/inventoryItemsHeroItemContainer.nut")
let { backpackEid, safepackEid, safepackYVisualSize } = require("%ui/hud/state/hero_extra_inventories_state.nut")
let { moveItemWithKeyboardMode, inventoryItemClickActions } = require("%ui/hud/menus/inventoryActions.nut")
let { HERO_ITEM_CONTAINER, BACKPACK0, SAFEPACK, NEXUS_ALTER_STASH } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { mkHeroBackpackItemContainerItemsList,
  mkHeroSafepackItemContainerItemsList } = require("%ui/hud/menus/components/inventoryItemsHeroExtraInventories.nut")
let { mkSafepackInventoryPresetPreview, mkHeroInventoryPresetPreview, mkBackpackInventoryPresetPreview,
      inventoryCapacity } = require("%ui/hud/menus/components/inventoryItemsPresetPreview.nut")
let { previewPreset, previewPresetCallbackOverride, makePresetDataFromCurrentEquipment, unfoldCountItems } = require("%ui/equipPresets/presetsState.nut")
let { alterMints, loadoutsAgency, playerProfileOpenedRecipes, allCraftRecipes, marketItems, playerStats
      playerProfileNexusLoadoutStorageCount } = require("%ui/profile/profileState.nut")
let { eventbus_send } = require("eventbus")
let { textButton, button } = require("%ui/components/button.nut")
let { loadoutToPreset, presetToLoadout } = require("%ui/equipPresets/convert_loadout_to_preset.nut")
let { textInput } = require("%ui/components/textInput.nut")
let { addModalWindow, removeModalWindow } = require("%ui/components/modalWindows.nut")
let { mkCloseStyleBtn } = require("%ui/mainMenu/stdPanel.nut")
let { startButton } = require("%ui/mainMenu/startButton.nut")
let random = require("dagor.random")
let { mintEditState, checkImportantPresetSlotEmptiness, slotsWithWarning
} = require("%ui/mainMenu/raid_preparation_window_state.nut")
let { utf8ToUpper } = require("%sqstd/string.nut")
let { addModalPopup, removeModalPopup } = require("%ui/components/modalPopupWnd.nut")
let { generate_loadout_by_seed } = require("%ui/profile/server_game_profile.nut")
let { mkCountdownTimer } = require("%ui/helpers/timers.nut")
let { itemsPanelList, setupPanelsData, inventoryItemSorting } = require("%ui/hud/menus/components/inventoryItemsList.nut")
let { stashItems } = require("%ui/hud/state/inventory_items_es.nut")
let { openMenu } = require("%ui/hud/hud_menus_state.nut")
let { MoveForbidReason } = require("%ui/hud/menus/components/inventoryItemsListChecksCommon.nut")
let { get_generator_indexes_bind } = require("das.nexus")
let { agencyLoadoutGenerators } = require("%ui/hud/menus/mintMenu/mintState.nut")
let { filterItemByInventoryFilter } = require("%ui/hud/menus/components/inventoryFilter.nut")
let { inventoryFiltersWidget, activeFilters } = require("%ui/hud/menus/components/inventoryStashFiltersWidget.nut")
let { weaponSlotsKeys } = require("%ui/types/weapon_slots.nut")
let { defaultMaxVolume } = require("%ui/hud/state/inventory_common_es.nut")
let { calc_stacked_item_volume } = require("das.inventory")
let { makeVertScroll } = require("%ui/components/scrollbar.nut")

let currentMint = Watched(null)
let mintSelectionState = Watched(null)
let editingAlterId = Watched(null)
let ALTER_CONTEXT_MENU_ID = "AlterContextMenu"
let iconHeight = hdpxi(18)

function resetMintState() {
  previewPreset.set(null)
  currentMint.set(null)
  mintSelectionState.set(null)
}

function showMintNamePopup(cb, currentMintName = null) {
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

  let offeredMintName = currentMintName ?? $"Alter {weaponLoc} #{random.rnd_int(1, 10000)}"
  let alterName = Watched(offeredMintName)

  let options = {
    margin = 0
    onReturn = function() {
      cb(alterName.get())
      removeModalWindow("mintNamePopup")
    }
    maxChars = 16
    onAttach = @(elem) set_kb_focus(elem)
  }.__update(sub_txt)
  addModalWindow({
    rendObj = ROBJ_WORLD_BLUR_PANEL
    key = "mintNamePopup"
    size = flex()
    onClick = @() null
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = {
      size = const [ hdpx(400), SIZE_TO_CONTENT ]
      flow = FLOW_VERTICAL
      gap = const hdpx(14)
      padding = const hdpx(10)
      children = [
        {
          size = [flex(), SIZE_TO_CONTENT]
          flow = FLOW_HORIZONTAL
          valign = ALIGN_CENTER
          children = [
            mkText(utf8ToUpper(loc("mint/chooseName")), { size = [flex(), SIZE_TO_CONTENT] }.__update(body_txt))
            mkCloseStyleBtn(@() removeModalWindow("mintNamePopup"))
          ]
        }
        textInput(alterName, options)
        textButton(loc("Accept"), function() {
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
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  gap = const hdpx(4)
  valign = ALIGN_CENTER
  children = [
    {
      rendObj = ROBJ_IMAGE
      size = [iconHeight, iconHeight]
      image = Picture($"ui/skin#context_icons/{icon}:{0}:{0}:P".subst(iconHeight))
    }
    mkText(loc(locId), { size = [flex(), SIZE_TO_CONTENT] })
  ]
}, action, {
  size = [flex(), SIZE_TO_CONTENT]
  halign = ALIGN_CENTER
  padding = const [hdpx(4), hdpx(6)]
  borderWidth = 0
})

function setPreviewPresetFromMintPreset(mintPreset) {
  if (mintPreset == null)
    return
  let playerPreset = loadoutToPreset(mintPreset).__update({ overrideMainChronogeneDoll = true })
  previewPreset.set(playerPreset)
}

function showAlterContextMenu(point, alterIdx) {
  let mint = alterMints.get()[alterIdx]

  let ranameMint = mkContextMenuBtn(loc("mint/rename"), function() {
    removeModalPopup(ALTER_CONTEXT_MENU_ID)
    showMintNamePopup(function(v) {
      eventbus_send("profile_server.rename_mint", { mint_id = mint.id.tostring(), mint_name = v })
    }, currentMint.get().name)
  }, "rename_alter.svg")

  let deleteMint = mkContextMenuBtn(loc("mint/delete"), function() {
    removeModalPopup(ALTER_CONTEXT_MENU_ID)
    eventbus_send("profile_server.delete_mint", mint.id.tostring())
  }, "trash.svg")

  let editMint = mkContextMenuBtn(loc("mint/edit"), function() {
    removeModalPopup(ALTER_CONTEXT_MENU_ID)
    setPreviewPresetFromMintPreset(mint)
    editingAlterId.set(mint.id.tostring())
    mintEditState.set(true)
  }, "edit_alter.svg")

  addModalPopup(point, {
    size = [hdpx(200), SIZE_TO_CONTENT]
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
  })
}

function setWeaponInPreviewPreset(item, weaponIdx) {
  previewPreset.mutate(function(v) {
    v.weapons[weaponIdx]["itemTemplate"] <- item?.itemTemplate
    v.weapons[weaponIdx]["attachments"] <- {}
  })
}

function setWeaponModInPreviewPreset(item, weaponIdx, modSlotName) {
  previewPreset.mutate(function(v) {
    let itemTemplate = item?.itemTemplate
    if (itemTemplate) {
      v.weapons[weaponIdx].attachments[modSlotName] <- {
        itemTemplate
      }
    }
    else {
      if (modSlotName in v.weapons[weaponIdx].attachments)
        v.weapons[weaponIdx].attachments[modSlotName] = { itemTemplate }
    }
  })
}

function setPrimaryChronogene(item) {
  previewPreset.mutate(function(v) {
    v.chronogene_primary_1.itemTemplate = item.itemTemplate
  })
}

function setEquipmentInPreviewPreset(item, slotName) {
  previewPreset.mutate(function(preview) {
    let itemTemplate = item?.itemTemplate
    if (itemTemplate) {
      preview[slotName] <- { itemTemplate = item.itemTemplate }
    }
    else {
      preview[slotName] = null
    }
  })
}

function setEquipmentModInPreviewPreset(item, equipment, slotName) {
  previewPreset.mutate(function(preview) {
    if ("attachments" not in preview[equipment]) {
      preview[equipment]["attachments"] <- {}
    }

    preview[equipment].attachments[slotName] <- (preview[equipment].attachments?[slotName] ?? {}).__merge({ itemTemplate = item?.itemTemplate })
  })
}


function setSuitModInPreviewPreset(item, slotName) {
  previewPreset.mutate(function(preview) {
    if (item?.itemTemplate) {
      preview.chronogene_primary_1[slotName] <- (preview.chronogene_primary_1?[slotName] ?? {}).__merge({
        itemTemplate = item.itemTemplate
        charges = item?.isBoxedItem ? 1 : null
      })
    }
    else {
      preview.chronogene_primary_1[slotName] = null
    }
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

let nexusStashItems = Computed(function() {
  let res = getNexusStashItems(stashItems.get(), playerProfileOpenedRecipes.get(), allCraftRecipes.get(),
    marketItems.get(), playerStats.get())
  return res.sort(inventoryItemSorting)
})

let stashItemsProceed = function(items) {
  return clone(items).filter(filterItemByInventoryFilter)
}

let stashRefineItemsPanelData = setupPanelsData(nexusStashItems,
                                4,
                                [nexusStashItems, activeFilters],
                                stashItemsProceed)

function getEquipmentSlots(item) {
  if (item?.itemTemplate == null)
    return {}

  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(item.itemTemplate)
  return template.getCompValNullable("equipment_mods__slots")?.getAll() ?? {}
}

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
      return (template?.getCompValNullable("item__volume") ?? 0) * 10.0
    }
  }

  let itemVolume = getItemVolume(item) / 10.0
  
  local currentMyItemsVolume = 0
  foreach (inventoryItem in (preset?.inventories.myItems.items ?? [])) {
    currentMyItemsVolume += (getItemVolume(inventoryItem) / 10.0)
  }
  local myItemsCapacity = defaultMaxVolume.get() * 10.0
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
      inventoryVolume += (getItemVolume(inventoryItem) / 10.0)
    }

    if (inventoryVolume + itemVolume <= inventoryCap) {
      dropToInventory(item, inventoryName)
      return
    }
  }
}

let stashContent = function() {
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
          watch = [ nexusStashItems, activeFilters ]
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
        textButton(loc("mint/save"), function() {
          let items = presetToLoadout(previewPreset.get())
          if (editingAlterId.get() == null) {
            showMintNamePopup(function(name) {
              eventbus_send("profile_server.create_mint", { items = items, name })
              mintEditState.set(false)
              resetMintState()
              editingAlterId.set(null)
            })
          }
          else {
            eventbus_send("profile_server.change_mint", { items = items, mint_id = editingAlterId.get() })
            editingAlterId.set(null)
            mintEditState.set(false)
          }
        }, { size = [ flex(), SIZE_TO_CONTENT ], halign = ALIGN_CENTER })
        textButton(loc("Cancel"), function() {
          mintEditState.set(false)
          resetMintState()
        }, { size = [ flex(), SIZE_TO_CONTENT ], halign = ALIGN_CENTER })
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

let mintsList = function() {
  return {
    watch = alterMints
    size = [ flex(), SIZE_TO_CONTENT ]
    children = {
      size = [ flex(), SIZE_TO_CONTENT ]
      flow = FLOW_VERTICAL
      gap = hdpx(6)
      children = [
        {
          padding = hdpx(6)
          size = [ flex(), SIZE_TO_CONTENT ]
          flow = FLOW_VERTICAL
          children = [
            mkText(loc("mint/mintListTitle"), { hplace = ALIGN_CENTER })
            mkText(loc("mint/mintCount", { currentMintCount=alterMints?.get().len(), maxMintCount=playerProfileNexusLoadoutStorageCount.get() }), { hplace = ALIGN_CENTER })
          ]
        },
        {
          size = [ flex(), SIZE_TO_CONTENT ]
          flow = FLOW_VERTICAL
          gap = hdpx(4)
          children = alterMints.get().map(function(mint, idx) {
            let { name } = mint

            return mkSelectPanelItem({
              border_align = BD_RIGHT
              children = @(...) {
                size = flex()
                flow = FLOW_HORIZONTAL
                gap = hdpx(10)
                valign = ALIGN_CENTER
                children = [
                  mkText(name, {
                    size = [flex(), SIZE_TO_CONTENT]
                    behavior = Behaviors.Marquee
                    speed = hdpx(50)
                  }.__update(h2_txt))
                  button({
                      rendObj = ROBJ_IMAGE
                      size = [hdpxi(22), hdpxi(22)]
                      image = Picture($"!ui/skin#triple_dot.svg:{0}:{0}:K".subst(hdpxi(22)))
                    },
                    function(event) {
                      let { screenX, screenY } = event
                      showAlterContextMenu([ screenX, screenY ], idx)
                    },
                    {
                      halign = ALIGN_CENTER
                      valign = ALIGN_CENTER
                      size = [hdpx(40), flex()]
                      margin = [0, hdpx(4),0,0]
                      stopMouse = true
                    }
                  )
                ]
              }
              idx = mint.id
              state = mintSelectionState
              onSelect = function(newIdx) {
                setPreviewPresetFromMintPreset(mint)
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
                size = [ flex(), hdpx(40) ]
                padding = [ 0, hdpx(2), 0, hdpx(10) ]
              }
            })
          }).append(
            (alterMints.get()?.len() ?? 0) < playerProfileNexusLoadoutStorageCount.get() ? textButton(loc("mint/createNew"),
              function() {
                let prs = makePresetDataFromCurrentEquipment(@(item) !bannedMintItem(item?.itemTemplate))
                prs.__update({ overrideMainChronogeneDoll = true })
                if (prs?.inventories.myItems.items)
                  prs.inventories.myItems.items = unfoldCountItems(prs.inventories.myItems.items)
                if (prs?.inventories.backpack.items)
                  prs.inventories.backpack.items = unfoldCountItems(prs.inventories.backpack.items)
                previewPreset.set(prs)
                mintEditState.set(true)
              },
              {
                size = [ flex(), SIZE_TO_CONTENT ]
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
  size = [ flex(), SIZE_TO_CONTENT ]
  children = startButton
}

let backButton = textButton(loc("mainmenu/btnBack"), @() openMenu("Raid") {
  size = [flex(), SIZE_TO_CONTENT]
  halign = ALIGN_CENTER
  hotkeys = [["Esc", { description = loc("mainmenu/btnBack") }]]
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
      let idx = $"agency_{i}"
      let generatorIndex = generatorIndexes[i]
      let agencyLoadoutGenerator = agencyLoadoutGenerators.get()[generatorIndex]
      let generatorName = agencyLoadoutGenerator.generator
      let loadoutName = agencyLoadoutGenerator.name

      
      let iter = i

      agencyPanels.append(
        mkSelectPanelItem({
          border_align = BD_RIGHT
          children = @(...) {
            size = flex()
            flow = FLOW_HORIZONTAL
            gap = hdpx(10)
            valign = ALIGN_CENTER
            children = [
              mkText(loadoutName, {
                size = [flex(), SIZE_TO_CONTENT]
                behavior = Behaviors.Marquee
                speed = hdpx(50)
              }.__update(h2_txt))
            ]
          }
          idx
          state = mintSelectionState
          onSelect = function(...) {
            let compArray = ecs.CompArray()
            let seedInt = seed.tointeger() + iter
            generate_loadout_by_seed(generatorName, seedInt, compArray)
            let preset = loadoutToPreset({ items = compArray.getAll() }).__merge({ overrideMainChronogeneDoll = true })
            previewPreset.set(preset)
            mintSelectionState.set(idx)
          }
          visual_params = {
            size = [ flex(), hdpx(40) ]
            padding = [ 0, hdpx(2), 0, hdpx(10) ]
          }
        })
      )
    }
    return {
      watch = updateAltersTimer
      size = [ flex(), SIZE_TO_CONTENT ]
      flow = FLOW_VERTICAL
      children = [
        {
          size = [ flex(), SIZE_TO_CONTENT ]
          padding = hdpx(6)
          flow = FLOW_VERTICAL
          children = [
            {
              size = [ flex(), SIZE_TO_CONTENT ]
              children = [
                mkText(loc("mint/agencyAltersTitle"), { hplace = ALIGN_CENTER })
              ]
            }
            @() {
              watch = timer
              size = [ flex(), SIZE_TO_CONTENT ]
              halign = ALIGN_CENTER
              flow = FLOW_HORIZONTAL
              children = [
                mkText(loc("mint/agencyUpdateIn"), {color = TextDisabled}),
                mkMonospaceTimeComp(timer.get())
              ]
            }
          ]
        }
        {
          size = [ flex(), SIZE_TO_CONTENT ]
          flow = FLOW_VERTICAL
          gap = hdpx(4)
          children = agencyPanels
        }
      ]
    }
  }
}


let mintList = {
  size = flex()
  flow = FLOW_VERTICAL
  gap = hdpx(12)
  children = [
    makeVertScroll({
      size = [ flex(), SIZE_TO_CONTENT ]
      flow = FLOW_VERTICAL
      gap = hdpx(20)
      children = [
        mintsList
        agencyAlters()
      ]
    })
    {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap = hdpx(4)
      vplace = ALIGN_BOTTOM
      children = [
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
    size = [SIZE_TO_CONTENT, flex()]
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      {
        size = [SIZE_TO_CONTENT, flex()]
        children = pouches
      }.__update(bluredPanel)
      backpack == null ? null : {
        size = [SIZE_TO_CONTENT, flex()]
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
  size = [SIZE_TO_CONTENT, flex()]
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


let bodyPartsPanel = {
  size = [SIZE_TO_CONTENT, flex()]
  valign = ALIGN_CENTER
  padding = hdpx(10)
  children = [
    bodypartsPanel
    secondaryChronogenesWidget
  ]
}.__update(bluredPanel)


function presetStashTabs() {
  return {
    watch = mintEditState
    size = [hdpx(364), flex()]
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = mintEditState.get() ?
      stashTab : mintList
  }
}

function mintContent() {
  previewPreset.subscribe(function(preset) {
    updatePreviewCallbacks(preset, mintEditState.get())
    checkImportantPresetSlotEmptiness(preset)
  })
  mintEditState.subscribe(@(isEditState) updatePreviewCallbacks(previewPreset.get(), isEditState))
  return {
    size = flex()
    flow = FLOW_HORIZONTAL
    gap = { size = flex() }
    padding = hdpx(4)
    onAttach = function() {
      let alterToSelect = alterMints.get()?[0]
      if (alterToSelect) {
        mintSelectionState.set(alterMints.get()?[0].id)
        setPreviewPresetFromMintPreset(alterMints.get()?[0])
        currentMint.set(alterMints.get()?[0])
      }
      else {
        let idx = $"agency_0"
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
    onDetach = function() {
      previewPreset.set(null)
      previewPresetCallbackOverride.set(null)
      mintEditState.set(false)
      editingAlterId.set(null)
      slotsWithWarning.set({})
    }
    children = [
      shiftPressedMonitor
      isAltPressedMonitor
      bodyPartsPanel
      weaponPanels
      heroInventories
      presetStashTabs
    ]
  }
}

return {
  mintContent
}