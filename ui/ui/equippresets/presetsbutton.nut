from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { BtnBgNormal, BtnBgSelected, BtnBgHover, BtnBdTransparent, InfoTextValueColor, TextDisabled } = require("%ui/components/colors.nut")
let { button } = require("%ui/components/button.nut")
let { previewPreset, playerPresetWatch, setPlayerPreset, PRESET_PREFIX, MAX_NAME_CHARS_COUNT,
  MAX_PRESETS_COUNT, renamePreset, LAST_USED_EQUIPMENT, makeDataToSave, equipPreset, AGENCY_PRESET_UID,
  useAgencyPreset } = require("%ui/equipPresets/presetsState.nut")
let { mkText, mkSelectPanelItem, mkMonospaceTimeComp, BD_LEFT } = require("%ui/components/commonComponents.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let { stashItems } = require("%ui/hud/state/inventory_items_es.nut")
let faComp = require("%ui/components/faComp.nut")
let { textInputUnderlined } = require("%ui/components/textInput.nut")
let { addModalPopup } = require("%ui/components/modalPopupWnd.nut")
let { showMsgbox } = require("%ui/components/msgbox.nut")
let { startswith } = require("string")
let { find_suitable_weapon, find_suitable_item, collect_available_boxed_items } = require("das.inventory")
let { stashEid } = require("%ui/state/allItems.nut")
let { backpackEid, safepackEid } = require("%ui/hud/state/hero_extra_inventories_state.nut")
let { get_controlled_hero } = require("%dngscripts/common_queries.nut")
let { deep_clone } = require("%sqstd/underscore.nut")
let { mkPresetDataFromMarket } = require("%ui/equipPresets/marketToPlayerPreset.nut")
let { makeVertScroll } = require("%ui/components/scrollbar.nut")
let { marketItems, mindtransferSeed, currentContractsUpdateTimeleft } = require("%ui/profile/profileState.nut")
let { generate_loadout_by_seed } = require("%ui/profile/server_game_profile.nut")
let { loadoutToPreset } = require("%ui/equipPresets/convert_loadout_to_preset.nut")
let { mkCountdownTimerPerSec } = require("%ui/helpers/timers.nut")
let { body_txt, tiny_txt } = require("%ui/fonts_style.nut")
let { selectedRaid } = require("%ui/gameModeState.nut")

let currentPreset = Watched(null)
let isPlayerPresetOpened = Watched(false)
let shopPresetToPurchase = Watched(null)
let editingPresetNameIdx = Watched(-1)
let renameTextWatch = Watched("")
let selectedPreset = Watched("")

const CURRENT_PRESET_UID = "curPreset"
const PRESET_WND_UID = "PRESETS_WND"

let presetRowSize = [hdpx(340), hdpx(34)]
let btnParams = {
  size = [presetRowSize[1], presetRowSize[1]]
  halign = ALIGN_CENTER
}

function isBoxed(templateName) {
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
  return template?.getCompValNullable("boxedItem") != null
}

let weaponInstalledModsQuery = ecs.SqQuery("weaponInstalledModsQuery", {
  comps_ro =[["gun_mods__curModInSlots", ecs.TYPE_OBJECT, null]]
})

let equipmentInstalledModsQuery = ecs.SqQuery("weaponInstalledModsQuery", {
  comps_ro =[["equipment_mods__curModInSlots", ecs.TYPE_OBJECT, null]]
})

function getItemTemplateName(itemEid) {
  return ecs.g_entity_mgr.getEntityTemplateName(itemEid)?.split("+")[0]
}

function patchPresetItems(preset) {
  if (!preset)
    return

  let availableBoxedItems = collect_available_boxed_items(stashEid.get(), get_controlled_hero(), backpackEid.get(), safepackEid.get())
  let banned = []

  function writeMissedBoxedCount(item) {
    let count = item?.ammoCount ?? 1
    let templateName = item.itemTemplate

    local missed = 0

    if (availableBoxedItems?[templateName]) {
      availableBoxedItems[templateName] -= count
      if (availableBoxedItems[templateName] < 0) {
        missed = min(-availableBoxedItems[templateName], count)
      }
    }
    else {
      missed = count
    }

    item.__update({noSuitableItemForPresetFoundCount = missed })
  }

  function writeMissedItemCount(item) {
    let count = item?.count ?? 1
    let templateName = item.itemTemplate

    item.__update({ noSuitableItemForPresetFoundCount = 0 })

    for (local i=0; i < count; i++) {
      let itemEid = find_suitable_item(stashEid.get(), get_controlled_hero(), backpackEid.get(), safepackEid.get(), templateName, banned)

      if (itemEid != ecs.INVALID_ENTITY_ID) {
        banned.append(itemEid)
        item.__update({ noSuitableItemForPresetFoundCount = 0 })
      }
      else {
        item.noSuitableItemForPresetFoundCount += 1
      }
    }
  }

  
  let primaryChronogene = preset?["chronogene_primary_1"] ?? {}

  foreach (_, v in primaryChronogene) {
    let slotName = v?.slotTemplateName ?? ""
    let templateName = v?.itemTemplate
    
    if (!startswith(slotName, "armorplate") || !templateName)
      continue

    let armorEid = find_suitable_item(stashEid.get(), get_controlled_hero(), backpackEid.get(), safepackEid.get(), templateName, banned)
    if (armorEid != ecs.INVALID_ENTITY_ID) {
      v.__update({ noSuitableItemForPresetFoundCount = 0 })
      banned.append(armorEid)
    }
    else
      v.__update({ noSuitableItemForPresetFoundCount = 1 })
  }

  
  foreach (weap in preset?.weapons ?? []) {
    let templateName = weap?.itemTemplate
    let attachments = weap?.attachments ?? {}

    if (!templateName)
      continue

    let attachmentsObj = ecs.CompObject()
    foreach (attachKey, attachVal in attachmentsObj) {
      let attObj = ecs.CompObject()
      foreach (k, v in attachVal) {
        attObj[k] <- v
      }
      attachmentsObj[attachKey] <- attObj
    }
    let weapEid = find_suitable_weapon(templateName, attachmentsObj, stashEid.get(), get_controlled_hero(), backpackEid.get(), safepackEid.get(), banned)
    let alredyInstalledAndOkMods = []
    weaponInstalledModsQuery.perform(weapEid, function (_eid, comp) {
      let mods = comp["gun_mods__curModInSlots"]?.getAll() ?? {}
      foreach(foundWeaponSlotName, foundWeaponEquippedModEid in mods) {
        if (foundWeaponEquippedModEid == ecs.INVALID_ENTITY_ID)
          continue

        if (attachments?[foundWeaponSlotName]?.itemTemplate == getItemTemplateName(foundWeaponEquippedModEid))
          alredyInstalledAndOkMods.append(foundWeaponSlotName)
      }
    })

    foreach (name, val in attachments) {
      if (val?.itemTemplate) {
        let attachFound =
          alredyInstalledAndOkMods.contains(name) ||
          find_suitable_item(stashEid.get(), get_controlled_hero(), backpackEid.get(), safepackEid.get(), val.itemTemplate, banned) != ecs.INVALID_ENTITY_ID
        if (attachFound) {
          val.__update({ noSuitableItemForPresetFoundCount = 0 })
        }
        else {
          val.__update({ noSuitableItemForPresetFoundCount = 1 })
        }
      }
    }

    if (weapEid != ecs.INVALID_ENTITY_ID) {
      weap.__update({ noSuitableItemForPresetFoundCount = 0 })
      banned.append(weapEid)
    }
    else
      weap.__update({ noSuitableItemForPresetFoundCount = 1 })
  }

  
  foreach (key, equip in preset) {
    let templateName = equip?.itemTemplate

    if (!templateName || startswith(key, "chronogene"))
      continue

    let equipEid = find_suitable_item(stashEid.get(), get_controlled_hero(), backpackEid.get(), safepackEid.get(), templateName, banned)

    if (equipEid != ecs.INVALID_ENTITY_ID) {
      equip.__update({ noSuitableItemForPresetFoundCount = 0 })
      banned.append(equipEid)
    }
    else
      equip.__update({ noSuitableItemForPresetFoundCount = 1 })

    let alredyInstalledAndOkMods = []

    let attachments = equip?.attachments ?? {}

    equipmentInstalledModsQuery.perform(equipEid, function (_eid, comp) {
      let mods = comp["equipment_mods__curModInSlots"]?.getAll() ?? {}
      foreach(foundEquipmentSlotName, foundEquipmentEquippedModEid in mods) {
        if (foundEquipmentEquippedModEid == ecs.INVALID_ENTITY_ID)
          continue

        if (attachments[foundEquipmentSlotName]?.itemTemplate == getItemTemplateName(foundEquipmentEquippedModEid))
          alredyInstalledAndOkMods.append(foundEquipmentSlotName)
      }
    })

    foreach (equipKey, equipsEquip in attachments) {
      let equipsEquipTemplateName = equipsEquip?.itemTemplate
      if (!equipsEquipTemplateName)
        continue

      if (alredyInstalledAndOkMods.contains(equipKey)) {
        equipsEquip.__update({ noSuitableItemForPresetFoundCount = 0 })
        continue
      }

      let equipsEquipEid = find_suitable_item(stashEid.get(), get_controlled_hero(), backpackEid.get(), safepackEid.get(), equipsEquipTemplateName, banned)
      if (equipsEquipEid != ecs.INVALID_ENTITY_ID) {
        equipsEquip.__update({ noSuitableItemForPresetFoundCount = 0 })
        banned.append(equipsEquipEid)
      }
      else
        equipsEquip.__update({ noSuitableItemForPresetFoundCount = 1 })
    }
  }

  
  foreach (item in preset?.inventories.myItems.items ?? []) {
    let templateName = item?.itemTemplate

    if (!templateName)
      continue

    let isBoxedItem = isBoxed(templateName)
    if (!isBoxedItem) {
      writeMissedItemCount(item)
    }
    else {
      writeMissedBoxedCount(item)
    }
  }

  
  foreach (item in preset?.inventories.backpack.items ?? []) {
    let templateName = item?.itemTemplate

    if (!templateName)
      continue

    let isBoxedItem = isBoxed(templateName)
    if (!isBoxedItem) {
      writeMissedItemCount(item)
    }
    else {
      writeMissedBoxedCount(item)
    }
  }

  
  foreach (k, v in primaryChronogene) {
    if (!startswith(k, "equipment_mod_pocket") || v?.itemTemplate == null)
      continue

    let isBoxedItem = isBoxed(v.itemTemplate)

    if (!isBoxedItem) {
      writeMissedItemCount(v)
    }
    else {
      writeMissedBoxedCount(v)
    }
  }

  
  foreach (k, v in preset?["pouch"] ?? {}) {
    if (!startswith(k, "equipment_mod_pocket") || v?.itemTemplate == null)
      continue

    let isBoxedItem = isBoxed(v?.itemTemplate)
    if (!isBoxedItem) {
      writeMissedItemCount(v)
    }
    else
      writeMissedBoxedCount(v)
  }

  let boxedItemMissed = availableBoxedItems.filter(@(v) v < 0)
  preset["boxedItemMissed"] <- boxedItemMissed
}


function patchShopPresetItems(preset) {
  if (!preset)
    return
  
  let primaryChronogene = preset?["chronogene_primary_1"] ?? {}

  foreach (_, v in primaryChronogene) {
    let slotName = v?.slotTemplateName ?? ""
    let templateName = v?.itemTemplate
    
    if (!startswith(slotName, "armorplate") || !templateName)
      continue
    else
      v.__update({ isItemToPurchase = true })
  }

  
  foreach (weap in preset?.weapons ?? []) {
    let templateName = weap?.itemTemplate

    if (!templateName)
      continue

    weap.__update({ isItemToPurchase = true })
  }

  
  foreach (key, equip in preset) {
    let templateName = equip?.itemTemplate
    if (!templateName || startswith(key, "chronogene"))
      continue

    equip.__update({ isItemToPurchase = true })
  }

  
  foreach (item in preset?.inventories.myItems.items ?? []) {
    let templateName = item?.itemTemplate

    if (!templateName)
      continue
    item.__update({ isItemToPurchase = true })
  }

  
  foreach (item in preset?.inventories.backpack.items ?? []) {
    let templateName = item?.itemTemplate

    if (!templateName)
      continue
    item.__update({ isItemToPurchase = true })
  }

  
  foreach (k, v in primaryChronogene) {
    if (!startswith(k, "equipment_mod_pocket") || v?.itemTemplate == null)
      continue
    v.__update({ isItemToPurchase = true })
  }

  
  foreach (k, v in preset?["pouch"] ?? {}) {
    if (!startswith(k, "equipment_mod_pocket") || v?.itemTemplate == null)
      continue

    v.__update({ isItemToPurchase = true })
  }
}


function mkLoadPresetButton(presetData) {
  
  let isDelayedMoveModPresents = Computed(function() {
    foreach(v in stashItems.get()) {
      if (v.isDelayedMoveMod)
        return true
    }
    return false
  })
  return @() {
    watch = isDelayedMoveModPresents
    size = [presetRowSize[1], presetRowSize[1]]
    children = button(
      faComp("upload", {
        fontSize = hdpx(12)
        padding = hdpx(10)
      }),
      function() {
        equipPreset(presetData)
        selectedPreset.set(CURRENT_PRESET_UID)
      },
      btnParams.__merge({
        isEnabled = !isDelayedMoveModPresents.get()
        onHover = function(on) {
          if (on) {
            
            let clonedPreset = deep_clone(presetData)

            patchPresetItems(clonedPreset)
            setTooltip(loc("playerPreset/loadButtonTooltip"))
            previewPreset.set(clonedPreset)
            previewPreset.trigger()
          }
          else {
            previewPreset.set(null)
            setTooltip(null)
          }
        }
      })
    )
  }
}

let mkSavePresetButton = @(presetIdx) button(faComp("save", {
    fontSize = hdpx(12)
    padding = hdpx(10)
  }),
  function() {
    if (playerPresetWatch.get()?[$"{PRESET_PREFIX}_{presetIdx}"] != null)
      showMsgbox({
        text = loc("playerPreset/needToRewrite")
        buttons = [
          {
            text = loc("Yes")
            action = @() setPlayerPreset(presetIdx, makeDataToSave())
            isCurrent = true
          },
          {
            text = loc("No")
            isCancel = true
          }
        ]
      })
    else
      setPlayerPreset(presetIdx, makeDataToSave())
  },
  btnParams.__merge({
    onHover = @(on) setTooltip(on ? loc("playerPreset/saveButtonTooltip") : null)
  })
)

let mkEditPresetNameButton = @(idx) button(
  faComp("edit", {
    fontSize = hdpx(12)
    padding = hdpx(10)
  }), @() editingPresetNameIdx.set(idx), {
    onHover = @(on) setTooltip(on ? loc("playerPreset/editName") : null)
  }.__merge(btnParams)
)

let mkApplyPresetNameButton = @(action) button(
  faComp("check", {
    fontSize = hdpx(12)
    padding = hdpx(10)
  }), action, {
    onHover = @(on) setTooltip(on ? loc("playerPreset/applyName") : null)
  }.__merge(btnParams)
)

function stopRenameAction() {
  renameTextWatch.set("")
  editingPresetNameIdx.set(null)
}

let function mkRenamePresetRow(presetIdx, presetData) {
  let applyRename = function() {
    renamePreset(presetData?.presetName, renameTextWatch.get(), presetIdx, presetData)
    stopRenameAction()
  }
  return {
    rendObj = ROBJ_BOX
    size = presetRowSize
    flow = FLOW_HORIZONTAL
    valign = ALIGN_BOTTOM
    borderWidth = hdpx(1)
    borderColor = BtnBgSelected
    fillColor = BtnBgNormal
    children = [
      textInputUnderlined(renameTextWatch, {
        size = presetRowSize
        margin = 0
        textmargin = [0,0,0, hdpx(4)]
        placeholderTextMargin = 0
        valignText = ALIGN_CENTER
        placeholder = loc("playerPreset/namePlaceholder")
        maxChars = MAX_NAME_CHARS_COUNT
        onEscape = stopRenameAction
        onReturn = applyRename
        onChange = @(val) renameTextWatch(val)
        onAttach = @(elem) set_kb_focus(elem)
        onImeFinish = function(applied) {
          if (!applied)
            return
          applyRename()
        }
      })
      mkApplyPresetNameButton(applyRename)
    ]
  }
}

function mkDefPresetRow(presetIdx, presetData) {
  local buttonsBlock = [mkSavePresetButton(presetIdx)]
  if (presetData != null)
    buttonsBlock = [mkEditPresetNameButton(presetIdx), mkLoadPresetButton(presetData), mkSavePresetButton(presetIdx)]
  local presetNameToShow = presetData?.presetName
  if (presetNameToShow == null)
    presetNameToShow = presetData == null
      ? loc("playerPreset/emptyPreset", { presetIdx = presetIdx + 1 })
      : loc("playerPreset/defName", { presetIdx =  presetIdx + 1 })
  return watchElemState(@(sf) {
    rendObj = ROBJ_SOLID
    size = presetRowSize
    behavior = Behaviors.Button
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    color = sf & S_HOVER ? BtnBgHover : BtnBgNormal
    children = [
      mkText(presetNameToShow, {
        size = [flex(), SIZE_TO_CONTENT]
        padding = [0,0,0, hdpx(4)]
      })
    ].extend(presetIdx == LAST_USED_EQUIPMENT ? [mkLoadPresetButton(presetData)] : buttonsBlock)
  })
}

function mkPresetRow(presetIdx) {
  let isEditingPresetName = Computed(@() editingPresetNameIdx.get() == presetIdx)
  let presetData = Computed(@() playerPresetWatch.get()?[$"{PRESET_PREFIX}_{presetIdx}"])

  return @() {
    watch = [isEditingPresetName, playerPresetWatch, presetData]
    flow = FLOW_HORIZONTAL
    gap = hdpx(4)
    children = [
      presetData.get() == null && presetIdx == LAST_USED_EQUIPMENT ? null
        : isEditingPresetName.get() ? mkRenamePresetRow(presetIdx, presetData.get())
        : mkDefPresetRow(presetIdx, presetData.get())
    ]
  }
}

function mkPresetsList() {
  let presetsToShow = [LAST_USED_EQUIPMENT]
  for (local i = 0; i < MAX_PRESETS_COUNT; i++)
    presetsToShow.append(i)
  return {
    rendObj = ROBJ_SOLID
    uid = PRESET_WND_UID
    padding = 0
    popupFlow = FLOW_VERTICAL
    popupHalign = ALIGN_RIGHT
    flow = FLOW_VERTICAL
    gap = hdpx(2)
    color = BtnBdTransparent
    onDetach = function() {
      stopRenameAction()
      isPlayerPresetOpened.set(false)
    }
    children = presetsToShow.map(@(v) mkPresetRow(v))
  }
}

function togglePresetEquipBlock(event) {
  isPlayerPresetOpened.modify(@(v) !v)
  let { r = 0, b = 0 } = event?.targetRect
  addModalPopup([r, b], mkPresetsList())
}

let presetBlockButton = @() {
  watch = isPlayerPresetOpened
  flow = FLOW_HORIZONTAL
  gap = hdpx(4)
  hplace = ALIGN_RIGHT
  halign = ALIGN_RIGHT
  valign = ALIGN_CENTER
  children = [
    button(faComp(isPlayerPresetOpened.get() ? "angle-double-down" : "angle-double-up", {
      fontSize = hdpx(18)
    }), @(event) togglePresetEquipBlock(event), {
      style = { BtnBgNormal = isPlayerPresetOpened.get() ? BtnBgSelected : BtnBgNormal }
      onHover = @(on) setTooltip(on ? loc("playerPreset/show") : null)
    }.__merge(btnParams))
    mkText(loc("playerPreset/presetsTitle"))
  ]
}

let preparationPresetParams = {
  size = [flex(), hdpx(40)]
  valign = ALIGN_CENTER
}

let agencyPresetParams = {
  size = [flex(), hdpx(80)]
  padding = [0, 0, 0, hdpx(15)]
  valign = ALIGN_CENTER
}

function mkPreparationPresetRow(presetIdx) {
  let presetData = Computed(@() playerPresetWatch.get()?[$"{PRESET_PREFIX}_{presetIdx}"])

  let onSelect = function(idx) {
    shopPresetToPurchase.set(null)
    selectedPreset.set(idx)
    useAgencyPreset.set(false)
    let clonedPreset = deep_clone(presetData.get())
    patchPresetItems(clonedPreset)
    previewPreset.set(clonedPreset)
  }

  return function () {
    let watch = presetData
    if (presetData.get() == null)
      return { watch }
    return {
      watch
      size = [flex(), SIZE_TO_CONTENT]
      onAttach = @() selectedPreset.get() == presetIdx ? onSelect(presetIdx) : null
      children = mkSelectPanelItem({
        idx = presetIdx
        state = selectedPreset
        border_align = BD_LEFT
        tooltip_text = loc("playerPreset/loadButtonTooltip")
        onSelect
        visual_params = preparationPresetParams
        children = function() {
          local presetNameToShow = presetData.get()?.presetName
          if (presetNameToShow == null)
            presetNameToShow = presetData.get() == null
              ? loc("playerPreset/emptyPreset", { presetIdx = presetIdx + 1 })
              : loc("playerPreset/defName", { presetIdx =  presetIdx + 1 })
          return {
            size = [flex(), SIZE_TO_CONTENT]
            children = mkText(presetNameToShow, {
              size = [flex(), SIZE_TO_CONTENT]
              padding = [0,0,0, hdpx(4)]
            })
          }
        }
      })
    }
  }
}

function mkAgencyPresetRow() {
  let seed = Computed(function() {
    return mindtransferSeed.get().tointeger() + ecs.calc_hash(selectedRaid.get()?.extraParams?.raidName ?? "")
  })

  let presetData = Computed(function() {
    let compArray = ecs.CompArray()
    let generatorName = "ordinary_equipment_generator"
    generate_loadout_by_seed(generatorName, seed.get(), compArray)
    return loadoutToPreset({ items = compArray.getAll() }).__merge({ overrideMainChronogeneDoll = true })
  })
  let contractTimerUpdateTime = mkCountdownTimerPerSec(currentContractsUpdateTimeleft)
  let presetUpdateTimer = {
    flow = FLOW_HORIZONTAL
    gap = hdpx(4)
    padding = [0,0,0, hdpx(4)]
    children = [
      mkText(loc("playerPreset/agencyPreset/update"), {color = TextDisabled}.__update(tiny_txt)),
      @() {
        watch = contractTimerUpdateTime
        children = mkMonospaceTimeComp(contractTimerUpdateTime.get(), tiny_txt)
      }
    ]
  }
  return @() {
    watch = [presetData, seed]
    size = [flex(), SIZE_TO_CONTENT]
    children = mkSelectPanelItem({
      idx = AGENCY_PRESET_UID
      state = selectedPreset
      border_align = BD_LEFT
      tooltip_text = loc("playerPreset/loadButtonTooltip")
      onSelect = function(_id) {
        shopPresetToPurchase.set(null)
        previewPreset.set(presetData.get())
        selectedPreset.set(AGENCY_PRESET_UID)
        useAgencyPreset.set(true)
      }
      visual_params = agencyPresetParams
      children = [
        @() {
          watch = selectedPreset
          clipChildren = true
          rendObj = ROBJ_IMAGE
          hplace = ALIGN_RIGHT
          image = Picture("ui/mode_thumbnails/mode_raid_mindcontrol.avif")
          size = [pw(25), flex()]
          keepAspect = KEEP_ASPECT_FILL
          picSaturate = selectedPreset.get() == AGENCY_PRESET_UID ? 1 : 0.5
          imageValign = ALIGN_TOP
        }
        {
          size = [flex(), SIZE_TO_CONTENT]
          flow = FLOW_VERTICAL
          gap = hdpx(4)
          children = [
            mkText(loc("playerPreset/agencyPreset/promo"), {
              size = [flex(), SIZE_TO_CONTENT]
              padding = [0,0,0, hdpx(4)]
              color = InfoTextValueColor
            }.__update( body_txt ))
            mkText(loc("playerPreset/agencyPreset/desc"), {
              size = [flex(), SIZE_TO_CONTENT]
              padding = [0,0,0, hdpx(4)]
            })
            presetUpdateTimer
          ]
        }
      ]
    })
  }
}

function mkCurrentPresetRow() {
  return mkSelectPanelItem({
    idx = CURRENT_PRESET_UID
    state = selectedPreset
    border_align = BD_LEFT
    tooltip_text = loc("playerPreset/loadButtonTooltip")
    onSelect = function(_id) {
      shopPresetToPurchase.set(null)
      previewPreset.set(null)
      selectedPreset.set(CURRENT_PRESET_UID)
      useAgencyPreset.set(false)
    }
    visual_params = preparationPresetParams
    children = {
      size = [flex(), SIZE_TO_CONTENT]
      children = mkText(loc("playerPreset/current"), {
        size = [flex(), SIZE_TO_CONTENT]
        padding = [0,0,0, hdpx(4)]
      })
    }
  })
}

function raidPresetsBlock() {
  return {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = hdpx(4)
    halign = ALIGN_CENTER
    margin = [0,0,hdpx(10),0]
    children = [
      {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        gap = hdpx(4)
        halign = ALIGN_CENTER
        children = [
          mkAgencyPresetRow()
          mkCurrentPresetRow()
        ]
      }
    ]
  }
}

function mkMarketPresetRow(preset) {
  let { children = [], offerName = "", buyable = false } = preset
  if (!buyable)
    return null
  let items = children?.items ?? []
  let isSelected = Computed(@() selectedPreset.get())
  return mkSelectPanelItem({
    idx = offerName
    state = isSelected
    border_align = BD_LEFT
    tooltip_text = loc("playerPreset/loadButtonTooltip")
    onSelect = function(idx) {
      shopPresetToPurchase.set(preset)
      selectedPreset.set(idx)
      let presetToShow = mkPresetDataFromMarket(items)
      patchShopPresetItems(presetToShow)
      previewPreset.set(presetToShow)
      useAgencyPreset.set(false)
    }
    visual_params = preparationPresetParams
    children = mkText(loc($"marketOffer/{offerName}"), {
      size = [flex(), SIZE_TO_CONTENT]
      padding = [0,0,0, hdpx(4)]
    })
  })
}

function mkPreviewPresetsBlock() {
  let presetsToShow = [LAST_USED_EQUIPMENT]
  for (local i = 0; i < MAX_PRESETS_COUNT; i++)
    presetsToShow.append(i)

  let marketPresets = Computed(@() marketItems.get().filter(@(v) v?.itemType == "presets") ?? {})
  return {
    size = flex()
    flow = FLOW_VERTICAL
    gap = hdpx(4)
    halign = ALIGN_CENTER
    margin = [0,0, hdpx(10),0]
    children = [
      mkText(loc("playerPreset/previewPreset"))
      makeVertScroll(@() {
        watch = marketPresets
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        gap = hdpx(4)
        halign = ALIGN_CENTER
        children = [].extend(
          presetsToShow.map(mkPreparationPresetRow),
          marketPresets.get().topairs()
            .sort(@(a, b) a[1].reqMoney <=> b[1].reqMoney)
            .map(@(v) mkMarketPresetRow(v[1].__update({ id = v[0] })))
        )
      })
    ]
  }
}

return {
  presetBlockButton
  raidPresetsBlock
  patchPresetItems
  PRESET_WND_UID
  CURRENT_PRESET_UID
  selectedPreset
  mkPreviewPresetsBlock
  shopPresetToPurchase
  currentPreset
}
