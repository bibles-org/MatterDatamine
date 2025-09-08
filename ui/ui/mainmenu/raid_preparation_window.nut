from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { body_txt, sub_txt } = require("%ui/fonts_style.nut")
let { nonInteractiveBodypartsPanel, bodypartsPanel } = require("%ui/hud/menus/components/damageModel.nut")
let { inventoryAffectsWidget } = require("%ui/hud/player_info/affects_widget.nut")
let { secondaryChronogenesWidget } = require("%ui/hud/menus/components/secondaryChronogenesWidget.nut")
let { bluredPanel, mkText, mkTextArea, mkTabs } = require("%ui/components/commonComponents.nut")
let { marketItems, playerProfileCreditsCount, playerStats, mindtransferSeed } = require("%ui/profile/profileState.nut")
let { mkInventoryHeaderText } = require("%ui/hud/menus/components/inventoryCommon.nut")
let { inventoryCurrentWeight, playerMovePenalty, shiftPressedMonitor, isAltPressedMonitor
} = require("%ui/hud/state/inventory_state.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let { truncateToMultiple } = require("%sqstd/math.nut")
let { mkEquipmentWeapons } = require("%ui/hud/menus/components/inventoryItemsHeroWeapons.nut")
let { quickUsePanelEdit } = require("%ui/hud/menus/components/quickUsePanel.nut")
let { backpackEid, safepackEid, safepackYVisualSize } = require("%ui/hud/state/hero_extra_inventories_state.nut")
let { previewPreset, equipPreset, useAgencyPreset, AGENCY_PRESET_UID } = require("%ui/equipPresets/presetsState.nut")
let { mkSafepackInventoryPresetPreview, mkHeroInventoryPresetPreview, mkBackpackInventoryPresetPreview } = require("%ui/hud/menus/components/inventoryItemsPresetPreview.nut")
let { mkHeroItemContainerItemsList } = require("%ui/hud/menus/components/inventoryItemsHeroItemContainer.nut")
let { mkHeroBackpackItemContainerItemsList,
  mkHeroSafepackItemContainerItemsList } = require("%ui/hud/menus/components/inventoryItemsHeroExtraInventories.nut")
let { startButton } = require("startButton.nut")
let { button, textButton } = require("%ui/components/button.nut")
let { patchPresetItems, selectedPreset, mkPreviewPresetsBlock,
  shopPresetToPurchase, currentPreset, CURRENT_PRESET_UID, raidPresetsBlock,
  presetBlockButton
} = require("%ui/equipPresets/presetsButton.nut")
let { eventbus_send, eventbus_subscribe_onehit } = require("eventbus")
let { sound_play } = require("%dngscripts/sound_system.nut")
let { creditsTextIcon } = require("%ui/mainMenu/currencyIcons.nut")
let { showMsgbox } = require("%ui/components/msgbox.nut")
let { RedWarningColor, TextHover } = require("%ui/components/colors.nut")
let { accentButtonStyle } = require("%ui/components/accentButton.style.nut")
let { getPresetMissedItemsMarketIds, getPresetMissedBoxedItemsMarketIds, checkImportantSlotEmptiness,
  slotsWithWarning } = require("%ui/mainMenu/raid_preparation_window_state.nut")
let { mkStashItemsList } = require("%ui/hud/menus/components/inventoryItemsStash.nut")
let { moveItemWithKeyboardMode, inventoryItemClickActions } = require("%ui/hud/menus/inventoryActions.nut")
let { STASH, HERO_ITEM_CONTAINER, BACKPACK0, SAFEPACK } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { loadoutItems } = require("%ui/state/allItems.nut")
let { resetFilters } = require("%ui/hud/menus/components/inventoryStashFiltersWidget.nut")
let JB = require("%ui/control/gui_buttons.nut")
let currentTab = Watched("consoleRaid/presetTab")
let { safeAreaAmount } = require("%ui/options/safeArea.nut")
let { openMenu } = require("%ui/hud/hud_menus_state.nut")
let { refillButton } = require("%ui/hud/menus/inventory.nut")
let { checkInventoryVolume } = require("%ui/hud/menus/components/inventoryItemUtils.nut")
let { showNoEnoughStashSpaceMsgbox } = require("%ui/mainMenu/stashSpaceMsgbox.nut")
let { colorPickerButton } = require("%ui/mainMenu/ribbons_colors_picker.nut")
let { loadoutToPreset } = require("%ui/equipPresets/convert_loadout_to_preset.nut")
let { generate_loadout_by_seed } = require("%ui/profile/server_game_profile.nut")
let { selectedRaid } = require("%ui/gameModeState.nut")

let weightBlock = @() {
  watch = [inventoryCurrentWeight, playerMovePenalty]
  size = [flex(), SIZE_TO_CONTENT]
  behavior = Behaviors.Button
  onHover = @(on) setTooltip(on ? loc("inventory/playerMovePenalty", { value = (playerMovePenalty.get() * 100.0).tointeger() }) : null)
  children = mkText(loc("inventory/weight", { value = truncateToMultiple(inventoryCurrentWeight.get(), 0.1) }))
}

let statusBlock = {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  vplace = ALIGN_TOP
  cursorNavAnchor = [elemw(50), elemh(50)]
  children = [
    weightBlock
    inventoryAffectsWidget
  ]
}

let bodyPartsPanel = @(){
  watch = useAgencyPreset
  size = [SIZE_TO_CONTENT, flex()]
  valign = ALIGN_CENTER
  padding = hdpx(10)
  children = [
    useAgencyPreset.get() ? nonInteractiveBodypartsPanel : bodypartsPanel
    secondaryChronogenesWidget
    {
      hplace = ALIGN_RIGHT
      vplace = ALIGN_BOTTOM
      children = colorPickerButton
    }
    {
      vplace = ALIGN_TOP
      hplace = ALIGN_RIGHT
      children = presetBlockButton
    }
    statusBlock
  ]
}.__update(bluredPanel)

let weaponPanels = @() {
  watch = safeAreaAmount
  size = [SIZE_TO_CONTENT, flex()]
  padding = safeAreaAmount.get() == 1 ? hdpx(10) : 0
  children = [
    refillButton
    {
      size = [SIZE_TO_CONTENT, flex()]
      flow = FLOW_VERTICAL
      gap = safeAreaAmount.get() == 1 ? hdpx(6) : 0
      children = [
        mkInventoryHeaderText(loc("inventory/weapons"), {
          size = [ flex(), safeAreaAmount.get() == 1 ? hdpx(40) : hdpx(20)]
        }.__update(safeAreaAmount.get() == 1 ? body_txt : sub_txt))
        mkEquipmentWeapons()
        quickUsePanelEdit
      ]
    }
  ]
}.__update(bluredPanel)

function heroInventories() {
  local pouches = mkHeroItemContainerItemsList(moveItemWithKeyboardMode, inventoryItemClickActions[HERO_ITEM_CONTAINER.name])
  local backpack = backpackEid.get() == ecs.INVALID_ENTITY_ID ? null
    : mkHeroBackpackItemContainerItemsList(moveItemWithKeyboardMode, inventoryItemClickActions[BACKPACK0.name])
  if (previewPreset.get()) {
    pouches = mkHeroInventoryPresetPreview(inventoryItemClickActions[HERO_ITEM_CONTAINER.name])
    backpack = previewPreset.get()?.backpack.itemTemplate == null ? null
      : mkBackpackInventoryPresetPreview(inventoryItemClickActions[BACKPACK0.name])
  }

  return {
    watch = [backpackEid, previewPreset]
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
            : mkSafepackInventoryPresetPreview(inventoryItemClickActions[SAFEPACK.name])
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

let backButton = textButton(loc("mainmenu/btnBack"), @() openMenu("Raid") {
  size = [flex(), SIZE_TO_CONTENT]
  halign = ALIGN_CENTER
  hotkeys = [[$"Esc | {JB.B}", { description = loc("mainmenu/btnBack") }]]
})

let mkEquipPresetButton = @(preset) preset == null ? { size = [flex(), hdpx(50)] }
  : textButton(loc("playerPreset/equip"),
      function() {
        if (preset == null) {
          showMsgbox({ text = loc("playerPreset/chooseToEquip")})
          return
        }
        equipPreset(preset)
        previewPreset.set(null)
        selectedPreset.set(CURRENT_PRESET_UID)
      }, {
      size = [flex(), SIZE_TO_CONTENT]
      halign = ALIGN_CENTER
    }.__update(preset == null ? {} : accentButtonStyle))


function buyOrEquipButton() {
  let playerStat = playerStats.get()

  let marketIdsToBuy = getPresetMissedItemsMarketIds(previewPreset.get(), playerStat)
    .extend(getPresetMissedBoxedItemsMarketIds(previewPreset.get(), playerStats.get()))
  let needMoney = shopPresetToPurchase.get() != null ? shopPresetToPurchase.get().reqMoney
    : marketIdsToBuy.reduce(@(acc, val) acc + (marketItems.get()?[val.id].reqMoney ?? 0) * val.count, 0)
  if ((marketIdsToBuy.len() <= 0 && shopPresetToPurchase.get() == null) || needMoney == 0 || selectedPreset.get() == AGENCY_PRESET_UID)
    return { watch = [previewPreset, shopPresetToPurchase, selectedPreset] }

  let text = shopPresetToPurchase.get() != null ? $"{loc("shop/purchaseEquip")} \n" : loc("shop/purchaseAll")
  let canPurchase = needMoney <= playerProfileCreditsCount.get()
  let textColor = canPurchase ? TextHover : RedWarningColor
  return {
    watch = [previewPreset, playerProfileCreditsCount, shopPresetToPurchase, playerStats, selectedPreset]
    size = [flex(), SIZE_TO_CONTENT]
    children = button(
      mkTextArea($" {text} {creditsTextIcon}{needMoney}", {
        color = textColor
        halign = ALIGN_CENTER
        fontFx = null
      }.__update(body_txt)),
      function() {
        if (needMoney == 0) {
          showMsgbox({ text = loc("shop/playerPreset/nothingToBuy")})
          return
        }
        else if (needMoney > playerProfileCreditsCount.get()) {
          showMsgbox({ text = loc("responseStatus/Not enough money")})
          return
        }
        if (shopPresetToPurchase.get() != null) {
          let missingVolume = checkInventoryVolume(shopPresetToPurchase.get().children.items)
          showNoEnoughStashSpaceMsgbox(missingVolume)
          eventbus_send("profile_server.buyLots", [shopPresetToPurchase.get().__merge({ count = 1 })])
        }
        else
          eventbus_send("profile_server.buyLots", marketIdsToBuy )
        sound_play("ui_sounds/button_buy")

        eventbus_subscribe_onehit("profile_server.buyLots.result", function(_) {
          patchPresetItems(previewPreset.get())
          previewPreset.trigger()
          if (shopPresetToPurchase.get() != null) {
            selectedPreset.set(null)
            shopPresetToPurchase.set(null)
            equipPreset(previewPreset.get())
            previewPreset.set(null)
          }
        })
      },
      {
        size = [flex(), hdpx(56)]
        minHeight = hdpx(56)
      }.__update(canPurchase ? accentButtonStyle : {}))
  }
}

function purchaseButton() {
  if (shopPresetToPurchase.get() || selectedPreset.get() == AGENCY_PRESET_UID)
    return { watch = [shopPresetToPurchase, selectedPreset] }
  return {
    watch = [previewPreset, shopPresetToPurchase, selectedPreset]
    size = [flex(), SIZE_TO_CONTENT]
    children = mkEquipPresetButton(previewPreset.get())
  }
}

let presetsBlock = {
  size = flex()
  flow = FLOW_VERTICAL
  gap = hdpx(8)
  children = [
    {
      size = flex()
      flow = FLOW_VERTICAL
      gap = hdpx(8)
      children = [
        raidPresetsBlock
        mkPreviewPresetsBlock()
      ]
    }
  ]
}.__update(bluredPanel)

let stashContent = {
  size = flex()
  halign = ALIGN_CENTER
  children = mkStashItemsList(moveItemWithKeyboardMode, inventoryItemClickActions[STASH.name], { xSize = 4 })
}.__update(bluredPanel)

let tabConstr = @(locId, params) {
  size = [(hdpx(364) / 2) - fsh(4), SIZE_TO_CONTENT]
  padding = 0
  margin = 0
  children = mkTextArea(loc(locId), params.__update({
    halign = ALIGN_CENTER
    fontFx = null
  }, body_txt))
}

let tabsList = [
  { id = "consoleRaid/presetTab"
    childrenConstr = @(params) tabConstr("consoleRaid/presetTab", params)
    content = presetsBlock
  }
  {
    id = "consoleRaid/stashTab"
    childrenConstr = @(params) tabConstr("consoleRaid/stashTab", params)
    content = stashContent
    isAvailable = Computed(@() previewPreset.get() == null)
    unavailableHoverHint = loc("consoleRaid/unavailableStashTab")
  }
]

let getCurTabContent = @(tabId) tabsList.findvalue(@(v) v.id == tabId)?.content

function presetStashTabs() {
  let tabsUi = mkTabs({
    tabs = tabsList
    currentTab = currentTab.get()
    onChange = @(tab) currentTab.set(tab.id)
  })
  let tabContent = getCurTabContent(currentTab.get())
  return {
    watch = currentTab
    size = [hdpx(364), flex()]
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      tabsUi
      tabContent
      @() {
        watch = selectedPreset
        size = [flex(), SIZE_TO_CONTENT]
        vplace = ALIGN_BOTTOM
        flow = FLOW_VERTICAL
        gap = hdpx(4)
        children = [
          backButton,
          [CURRENT_PRESET_UID, AGENCY_PRESET_UID].contains(selectedPreset.get()) ? null : buyOrEquipButton,
          [CURRENT_PRESET_UID, AGENCY_PRESET_UID].contains(selectedPreset.get()) ? null : purchaseButton,
          [CURRENT_PRESET_UID, AGENCY_PRESET_UID].contains(selectedPreset.get()) ? startButton : null
        ]
      }
    ]
  }
}

let preparationWindow = @() {
  size = flex()
  flow = FLOW_HORIZONTAL
  gap = hdpx(10)
  padding = hdpx(10)
  onAttach = function() {
    checkImportantSlotEmptiness(loadoutItems.get())
    loadoutItems.subscribe(checkImportantSlotEmptiness)
    resetFilters()
    if (useAgencyPreset.get()){
      selectedPreset.set(AGENCY_PRESET_UID)

      let seed = mindtransferSeed.get().tointeger() + ecs.calc_hash(selectedRaid.get()?.extraParams?.raidName ?? "")

      let compArray = ecs.CompArray()
      let generatorName = "ordinary_equipment_generator"
      generate_loadout_by_seed(generatorName, seed, compArray)
      let loadout = loadoutToPreset({ items = compArray.getAll() }).__merge({ overrideMainChronogeneDoll = true })
      previewPreset.set(loadout)
    }
    else
      selectedPreset.set(CURRENT_PRESET_UID)
  }
  onDetach = function() {
    previewPreset.set(null)
    selectedPreset.set(null)
    shopPresetToPurchase.set(null)
    currentPreset.set(null)
    loadoutItems.unsubscribe(checkImportantSlotEmptiness)
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
}.__update(bluredPanel)

return {
  preparationWindow
}
