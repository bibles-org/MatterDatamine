from "%dngscripts/sound_system.nut" import sound_play
from "%sqstd/math.nut" import truncateToMultiple
from "%ui/hud/menus/components/inventoryItemsHeroExtraInventories.nut" import mkHeroBackpackItemContainerItemsList, mkHeroSafepackItemContainerItemsList
from "%ui/equipPresets/presetsButton.nut" import patchPresetItems, mkPreviewPresetsBlock, raidPresetsBlock
from "%ui/mainMenu/raid_preparation_window_state.nut" import getPresetMissedItemsMarketIds, getPresetMissedBoxedItemsMarketIds, checkImportantSlotEmptiness, checkRaidAvailability
from "%ui/fonts_style.nut" import body_txt, sub_txt
from "%ui/hud/menus/components/damageModel.nut" import nonInteractiveBodypartsPanel, bodypartsPanel
from "%ui/hud/player_info/affects_widget.nut" import inventoryAffectsWidget
from "%ui/hud/menus/components/chronogenesWidget.nut" import chronogenesWidget
from "%ui/components/commonComponents.nut" import bluredPanel, mkText, mkTextArea, mkTabs
from "%ui/hud/menus/components/inventoryCommon.nut" import mkInventoryHeaderText
from "%ui/components/cursors.nut" import setTooltip
from "%ui/hud/menus/components/inventoryItemsHeroWeapons.nut" import mkEquipmentWeapons
from "%ui/hud/menus/components/quickUsePanel.nut" import quickUsePanelEdit
from "%ui/equipPresets/presetsState.nut" import equipPreset
from "%ui/hud/menus/components/inventoryItemsPresetPreview.nut" import mkSafepackInventoryPresetPreview, mkHeroInventoryPresetPreview, mkBackpackInventoryPresetPreview
from "%ui/hud/menus/components/inventoryItemsHeroItemContainer.nut" import mkHeroItemContainerItemsList
from "%ui/mainMenu/startButton.nut" import startButton
from "%ui/components/button.nut" import button, textButton, buttonWithGamepadHotkey
from "eventbus" import eventbus_send, eventbus_subscribe_onehit
from "%ui/mainMenu/contractWidget.nut" import mkDifficultyBlock
from "%ui/components/msgbox.nut" import showMsgbox
from "%ui/components/colors.nut" import RedWarningColor, TextHover, ContactLeader, BtnBdNormal, BtnBgDisabled
from "%ui/components/accentButton.style.nut" import accentButtonStyle
from "%ui/hud/menus/components/inventoryItemsStash.nut" import mkStashItemsList
from "%ui/hud/menus/inventoryActions.nut" import moveItemWithKeyboardMode
from "%ui/hud/menus/components/inventoryStashFiltersWidget.nut" import resetFilters
from "%ui/hud/hud_menus_state.nut" import openMenu, currentMenuId, convertMenuId
from "%ui/hud/menus/inventory.nut" import refillButton, repairAllButton
from "%ui/hud/menus/components/inventoryItemUtils.nut" import checkInventoryVolume
from "%ui/mainMenu/stashSpaceMsgbox.nut" import showNoEnoughStashSpaceMsgbox
from "%ui/mainMenu/ribbons_colors_picker.nut" import colorPickerButton
from "%ui/equipPresets/convert_loadout_to_preset.nut" import loadoutToPreset
from "das.equipment" import generate_loadout_by_seed
from "%ui/hud/menus/components/inventoryStashFiltersWidget.nut" import inventoryFiltersWidget
from "%ui/context_hotkeys.nut" import contextHotkeys
from "%ui/mainMenu/offline_raid_widget.nut" import mkOfflineRaidIcon, wantOfflineRaid

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { marketItems, playerProfileCreditsCount, playerStats, mindtransferSeed } = require("%ui/profile/profileState.nut")
let { inventoryCurrentWeight, playerMovePenalty, shiftPressedMonitor, isAltPressedMonitor, mutationForbidenDueToInQueueState } = require("%ui/hud/state/inventory_state.nut")
let { backpackEid, safepackEid, safepackYVisualSize } = require("%ui/hud/state/hero_extra_inventories_state.nut")
let { previewPreset, useAgencyPreset, AGENCY_PRESET_UID } = require("%ui/equipPresets/presetsState.nut")
let { selectedPreset, shopPresetToPurchase, currentPreset, CURRENT_PRESET_UID } = require("%ui/equipPresets/presetsButton.nut")
let { creditsTextIcon } = require("%ui/mainMenu/currencyIcons.nut")
let { slotsWithWarning } = require("%ui/mainMenu/raid_preparation_window_state.nut")
let { inventoryItemClickActions } = require("%ui/hud/menus/inventoryActions.nut")
let { STASH, HERO_ITEM_CONTAINER, BACKPACK0, SAFEPACK } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { loadoutItems } = require("%ui/state/allItems.nut")
let JB = require("%ui/control/gui_buttons.nut")
let currentTab = Watched("consoleRaid/presetTab")
let { safeAreaAmount } = require("%ui/options/safeArea.nut")
let { selectedRaid } = require("%ui/gameModeState.nut")
let { tagChronogeneSlot } = require("%ui/mainMenu/clonesMenu/clonesMenuCommon.nut")
let { PREPARATION_NEXUS_SUBMENU_ID } = require("%ui/hud/menus/mintMenu/mintState.nut")

let weightBlock = @() {
  watch = [inventoryCurrentWeight, playerMovePenalty]
  behavior = Behaviors.Button
  onHover = @(on) setTooltip(on ? loc("inventory/playerMovePenalty", { value = (playerMovePenalty.get() * 100.0).tointeger() }) : null)
  children = mkText(loc("inventory/weight", { value = truncateToMultiple(inventoryCurrentWeight.get(), 0.1) }))
}

let statusBlock = {
  size = FLEX_H
  vplace = ALIGN_TOP
  flow = FLOW_HORIZONTAL
  gap = {
    rendObj = ROBJ_SOLID
    size = [hdpx(1), flex()]
    margin = [0, hdpx(10)]
    color = BtnBgDisabled
  }
  valign = ALIGN_CENTER
  children = [
    repairAllButton
    {
      size = FLEX_H
      flow = FLOW_HORIZONTAL
      gap = hdpx(10)
      cursorNavAnchor = [elemw(50), elemh(50)]
      valign = ALIGN_CENTER
      children = [
        weightBlock
        inventoryAffectsWidget({ pos = [0, 0] })
      ]
    }
  ]

}

let bodyPartsPanel = @(){
  watch = useAgencyPreset
  size = FLEX_V
  valign = ALIGN_CENTER
  padding = hdpx(10)
  children = [
    useAgencyPreset.get() ? nonInteractiveBodypartsPanel : bodypartsPanel
    chronogenesWidget
    {
      hplace = ALIGN_RIGHT
      vplace = ALIGN_BOTTOM
      flow = FLOW_HORIZONTAL
      gap = hdpx(4)
      children = [
        tagChronogeneSlot
        colorPickerButton
      ]
    }
    {
      size = FLEX_H
      vplace = ALIGN_TOP
      children = statusBlock
    }
  ]
}.__update(bluredPanel)

let weaponPanels = @() {
  watch = safeAreaAmount
  size = FLEX_V
  padding = safeAreaAmount.get() == 1 ? hdpx(10) : 0
  children = [
    refillButton
    {
      size = FLEX_V
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

let backButton = buttonWithGamepadHotkey(mkText(loc("mainmenu/btnBack"), { hplace = ALIGN_CENTER }.__merge(body_txt)),
  @() openMenu("Missions") {
    size = FLEX_H
    halign = ALIGN_CENTER
    hotkeys = [[$"Esc | {JB.B}", { description = { skip = true } }]]
  })

let mkEquipPresetButton = @(preset) preset == null ? { size = static [flex(), hdpx(50)] }
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
      size = FLEX_H
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
    size = FLEX_H
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
          if (missingVolume > 0) {
            showNoEnoughStashSpaceMsgbox(missingVolume)
            return
          }
          eventbus_send("profile_server.buyLots", [shopPresetToPurchase.get().__merge({ count = 1, usePremium = false })])
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
        size = static [flex(), hdpx(56)]
        minHeight = hdpx(56)
      }.__update(canPurchase ? accentButtonStyle : {}))
  }
}

function purchaseButton() {
  if (shopPresetToPurchase.get() || selectedPreset.get() == AGENCY_PRESET_UID)
    return { watch = [shopPresetToPurchase, selectedPreset] }
  return {
    watch = [previewPreset, shopPresetToPurchase, selectedPreset]
    size = FLEX_H
    children = mkEquipPresetButton(previewPreset.get())
  }
}

let presetsBlock = @() {
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

let stashContent = @() {
  size = flex()
  halign = ALIGN_CENTER
  flow = FLOW_HORIZONTAL
  children = [
    mkStashItemsList(moveItemWithKeyboardMode, inventoryItemClickActions[STASH.name], { xSize = 4 })
    inventoryFiltersWidget
  ]
}.__update(bluredPanel)

let tabConstr = @(locId, params) {
  size = [(hdpx(364) / 2) - fsh(4), SIZE_TO_CONTENT]
  padding = 0
  margin = 0
  children = mkTextArea(loc(locId), params.__merge({
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
    isAvailable = Computed(@() previewPreset.get() == null && !mutationForbidenDueToInQueueState.get())
    unavailableHoverHint = loc("consoleRaid/unavailableStashTab")
  }
]
#allow-auto-freeze

let getCurTabContent = @(tabId) tabsList.findvalue(@(v) v.id == tabId)?.content

let mkPresetStashTabs = @(rotationTimer) function() {
  let tabsUi = mkTabs({
    tabs = tabsList
    currentTab = currentTab.get()
    onChange = @(tab) currentTab.set(tab.id)
  })
  let tabContent = getCurTabContent(currentTab.get())

  mutationForbidenDueToInQueueState.subscribe_with_nasty_disregard_of_frp_update(function(state) {
    if (!state)
      return

    let [_id, submenus] = convertMenuId(currentMenuId.get())
    let submenu = submenus?[0]
    let isNexusPreparation = submenu == PREPARATION_NEXUS_SUBMENU_ID

    if (isNexusPreparation)
      return

    currentTab.set("consoleRaid/presetTab")

    if (useAgencyPreset.get()) {
      selectedPreset.set(AGENCY_PRESET_UID)

      let seed = mindtransferSeed.get().tointeger() + ecs.calc_hash(selectedRaid.get()?.extraParams?.raidName ?? "")
      let compArray = ecs.CompArray()
      let generatorName = "ordinary_equipment_generator"
      generate_loadout_by_seed(generatorName, seed, compArray)
      previewPreset.set (loadoutToPreset({ items = compArray.getAll() }).__merge({ overrideMainChronogeneDoll = true }))
    }
    else {
      selectedPreset.set(CURRENT_PRESET_UID)
      previewPreset.set(null)
    }
  })
  return {
    watch = currentTab
    size = static [hdpx(364), flex()]
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      tabsUi
      tabContent
      @() {
        watch = selectedPreset
        size = FLEX_H
        vplace = ALIGN_BOTTOM
        flow = FLOW_VERTICAL
        gap = hdpx(4)
        children = [
          rotationTimer,
          backButton,
          [CURRENT_PRESET_UID, AGENCY_PRESET_UID].contains(selectedPreset.get()) ? null : buyOrEquipButton,
          [CURRENT_PRESET_UID, AGENCY_PRESET_UID].contains(selectedPreset.get()) ? null : purchaseButton,
          [CURRENT_PRESET_UID, AGENCY_PRESET_UID].contains(selectedPreset.get())
            ? startButton(@() {
              watch = wantOfflineRaid
              flow = FLOW_HORIZONTAL
              valign = ALIGN_CENTER
              gap = {
                rendObj = ROBJ_SOLID
                size = [hdpx(1), flex()]
                margin = static [0, hdpx(4)]
                color = ContactLeader
              }
              children = [
                wantOfflineRaid.get() ? mkOfflineRaidIcon({ fontSize = hdpx(20), color = ContactLeader }) : null
                mkDifficultyBlock(false)
              ]
            }) : null
        ]
      }
    ]
  }
}

let mkPreparationWindow = @(rotationTimer) {
  size = flex()
  flow = FLOW_HORIZONTAL
  gap = hdpx(10)
  padding = hdpx(10)
  onAttach = function() {
    gui_scene.setInterval(10, checkRaidAvailability)
    checkImportantSlotEmptiness(loadoutItems.get())
    loadoutItems.subscribe_with_nasty_disregard_of_frp_update(checkImportantSlotEmptiness)
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
    gui_scene.clearTimer(checkRaidAvailability)
  }
  children = [
    shiftPressedMonitor
    isAltPressedMonitor
    bodyPartsPanel
    weaponPanels
    heroInventories
    mkPresetStashTabs(rotationTimer)
    contextHotkeys
  ]
}.__update(bluredPanel)

return {
  mkPreparationWindow
}
