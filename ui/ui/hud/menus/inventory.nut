from "%sqstd/math.nut" import truncateToMultiple

from "%ui/hud/menus/components/inventoryItemsHeroExtraInventories.nut" import mkHeroBackpackItemContainerItemsList, mkHeroSafepackItemContainerItemsList

from "%ui/components/colors.nut" import RedWarningColor, ConsoleFillColor
from "%ui/fonts_style.nut" import body_txt
from "%ui/hud/state/interactive_state.nut" import addInteractiveElement, removeInteractiveElement
from "%ui/hud/menus/components/amStorage.nut" import mkActiveMatterStorageWidget
from "%ui/hud/menus/components/suitTypeMark.nut" import suitTypeMark
from "%ui/hud/menus/components/inventoryStashFiltersWidget.nut" import inventoryFiltersWidget
from "%ui/hud/menus/components/inventoryItemsHeroItemContainer.nut" import mkHeroItemContainerItemsList
from "%ui/hud/menus/components/inventoryItemsPresetPreview.nut" import mkSafepackInventoryPresetPreview, mkHeroInventoryPresetPreview, mkBackpackInventoryPresetPreview
from "%ui/hud/menus/components/inventoryItemsHeroWeapons.nut" import mkEquipmentWeapons
from "%ui/hud/menus/components/inventoryItemsGround.nut" import mkGroundItemsList
from "%ui/hud/menus/components/inventoryItemsExternalItemContainer.nut" import mkExternalItemContainerItemsList
from "%ui/hud/menus/components/inventoryItemsTrashBin.nut" import trashBinItemContainerItemsList
from "dasevents" import CmdShowUiMenu, CmdHideUiMenu, RequestFillAllItems, EventHeroInventoryOpened, EventHeroInventoryClosed
from "%ui/hud/menus/components/damageModel.nut" import bodypartsPanel
from "das.inventory" import is_item_inventory_move_blocked
from "%ui/hud/menus/components/inventoryItemsStash.nut" import mkStashItemsList, extendStashBlock
from "%ui/hud/menus/components/quickUsePanel.nut" import quickUsePanelEdit
from "%ui/hud/menus/components/inventoryCommon.nut" import mkInventoryHeaderText
from "%ui/components/controlHudHint.nut" import controlHudHint
from "%ui/hud/menus/inventoryActions.nut" import moveItemWithKeyboardMode
from "%ui/equipPresets/presetsButton.nut" import presetBlockButton
from "%ui/mainMenu/ribbons_colors_picker.nut" import colorPickerButton
from "%ui/components/commonComponents.nut" import bluredPanelWindow, mkText, mkTextArea, fontIconButton
from "%ui/hud/menus/components/inventoryItemsListChecks.nut" import isItemCanBeDroppedInStash, isItemCanBeDroppedOnGround
from "%ui/hud/menus/components/inventoryItemsListChecksCommon.nut" import MoveForbidReason
from "%ui/hud/player_info/affects_widget.nut" import inventoryAffectsWidget
import "%ui/components/faComp.nut" as faComp
from "%ui/components/button.nut" import button
from "%ui/components/cursors.nut" import setTooltip
from "%ui/hud/menus/components/chronogenesWidget.nut" import chronogenesWidget
from "%ui/components/modalPopupWnd.nut" import removeModalPopup
from "%ui/mainMenu/stdPanel.nut" import wrapInStdPanel
from "%ui/components/msgbox.nut" import showMsgbox
from "%ui/context_hotkeys.nut" import contextHotkeys, rmbGamepadHotkey

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { disabledEquipmentWeapons } = require("%ui/hud/menus/components/inventoryItemsHeroWeapons.nut")
let { trashBinItemContainerCursorAttractor } = require("%ui/hud/menus/components/inventoryItemsTrashBin.nut")
let { GROUND, HERO_ITEM_CONTAINER, EXTERNAL_ITEM_CONTAINER, BACKPACK0, STASH, SAFEPACK } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { shiftPressedMonitor, isAltPressedMonitor, inventoryCurrentWeight, playerMovePenalty,
  mutationForbidenDueToInQueueState } = require("%ui/hud/state/inventory_state.nut")
let { externalInventoryEid, prevExternalInventoryEid } = require("%ui/hud/state/hero_external_inventory_state.nut")
let { backpackEid, safepackEid, backpackItemRecognitionEnabled } = require("%ui/hud/state/hero_extra_inventories_state.nut")
require("%ui/hud/state/item_use_message.nut")
let { isInPlayerSession, isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")
let { quickUseIsOpenedForEdit } = require("%ui/hud/menus/components/quickUsePanel.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { isSpectator } = require("%ui/hud/state/spectator_state.nut")
let { inventoryItemClickActions, CONTEXT_MENU_WND_UID } = require("%ui/hud/menus/inventoryActions.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { PRESET_WND_UID } = require("%ui/equipPresets/presetsButton.nut")
let { previewPreset } = require("%ui/equipPresets/presetsState.nut")
let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")
let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")
let { isNexus } = require("%ui/hud/state/nexus_mode_state.nut")
let { isInMonsterState, isMonsterInventoryEnabled, isMonsterWeaponsEnabled } = require("%ui/hud/state/hero_monster_state.nut")
let { safeAreaVerPadding, safeAreaHorPadding, safeAreaAmount } = require("%ui/options/safeArea.nut")
let { isInBattleState } = require("%ui/state/appState.nut")
let { tagChronogeneSlot } = require("%ui/mainMenu/clonesMenu/clonesMenuCommon.nut")

const InventoryMenuId = "Inventory"

let bluredPanel = bluredPanelWindow

let inventoryPanelSize = calc_comp_size(mkHeroBackpackItemContainerItemsList(@(...) null, {}))

function open() {
  ecs.g_entity_mgr.broadcastEvent(CmdShowUiMenu({menuName = InventoryMenuId}))
}

function close() {
  ecs.g_entity_mgr.broadcastEvent(CmdHideUiMenu({menuName = InventoryMenuId}))
}

externalInventoryEid.subscribe(function(v) {
  if ((v == ecs.INVALID_ENTITY_ID && prevExternalInventoryEid.get() == backpackEid.get()) || isSpectator.get())
    
    return

  if (v != ecs.INVALID_ENTITY_ID)
    open()
})



let contentPadding = [ hdpx(1), hdpx(10), hdpx(10), hdpx(10) ]

let containerAnims = [
  { prop=AnimProp.opacity, from=0, to=1, duration=0.25, play=true, easing=OutCubic }
  { prop=AnimProp.scale, from=[1,1], to=[1,0.01], duration=0.25, playFadeOut=true, easing=OutCubic }
  { prop=AnimProp.opacity, from=1, to=0, duration=0.25, playFadeOut=true, easing=OutCubic }
]

let emptyHotkey = {action = @() null, description = {skip=true}}
let hotkeysEater = {
  hotkeys = [rmbGamepadHotkey].map(@(v) [v, emptyHotkey])
}

let weaponSlotAnims = freeze([
  { prop=AnimProp.opacity,from=0, to=1, duration=0.3, play=true, easing=OutCubic }
  { prop=AnimProp.opacity,from=1, to=0, duration=0.3, playFadeOut=true, easing=OutCubic }
])

let dropItemsArea = {
  behavior = [Behaviors.DragAndDrop]
  onDrop = @(data) isInPlayerSession.get() ? moveItemWithKeyboardMode(data, GROUND) :
                   moveItemWithKeyboardMode(data, STASH)
  canDrop = @(data) data && data?.canDrop
                    && !is_item_inventory_move_blocked(data?.eid ?? ecs.INVALID_ENTITY_ID)
                    && (isInPlayerSession.get() ? isItemCanBeDroppedOnGround(data) : isItemCanBeDroppedInStash(data)) == MoveForbidReason.NONE
  size = flex()
  skipDirPadNav = true
}

let leftpadding = @() {
  watch = isInPlayerSession
  size=flex()
  children = [
    dropItemsArea
  ]
}
let filters = @() {
  size= FLEX_V
  watch = [isInPlayerSession, isOnboarding]
  children = [
    dropItemsArea,
    isOnPlayerBase.get() && !isOnboarding.get() ? inventoryFiltersWidget : null
  ]
}
let rightpadding = {size = flex(), children = dropItemsArea}

let closebutton = fontIconButton("icon_buttons/x_btn.svg", close, { skipDirPadNav = true })

let itemsAround = mkGroundItemsList(moveItemWithKeyboardMode,
  inventoryItemClickActions[GROUND.name], { xSize = 4 })

let trashBin = {
  size = FLEX_H
  padding = static [0, 0, hdpx(5), 0]
  children = [
    trashBinItemContainerCursorAttractor
    trashBinItemContainerItemsList
  ]
}

let externalInventories = {
  size = static [ SIZE_TO_CONTENT, flex(1.5) ]
  children = mkExternalItemContainerItemsList(moveItemWithKeyboardMode,
    inventoryItemClickActions[EXTERNAL_ITEM_CONTAINER.name], { xSize = 4 })
}.__update(bluredPanel)


let aroundOrStash = @() {
  watch = static [isInPlayerSession, isOnboarding]
  size = FLEX_V
  flow = FLOW_VERTICAL
  gap = hdpx(5)
  children = [
    isInPlayerSession.get() ? itemsAround : !isOnboarding.get()
      ? mkStashItemsList(moveItemWithKeyboardMode, inventoryItemClickActions[STASH.name], { xSize = 4 })
      : { size = [ inventoryPanelSize[0], 0] },
    isInPlayerSession.get() || isOnboarding.get() ? null : extendStashBlock,
    isInPlayerSession.get() || isOnboarding.get() ? null : trashBin
  ]
}.__update(bluredPanel)

function sideInventories() {
  return {
    watch = static [ externalInventoryEid, isOnboarding, isNexus]
    size = FLEX_V
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      externalInventoryEid.get() == ecs.INVALID_ENTITY_ID ? null : externalInventories
      isInPlayerSession.get() || !isOnboarding.get()  ? aroundOrStash : null
    ]
  }
}

function heroInventories() {
  local pouches = mkHeroItemContainerItemsList(moveItemWithKeyboardMode, inventoryItemClickActions[HERO_ITEM_CONTAINER.name])
  local backpack = backpackEid.get() == ecs.INVALID_ENTITY_ID ? null
    : mkHeroBackpackItemContainerItemsList(moveItemWithKeyboardMode, inventoryItemClickActions[BACKPACK0.name])
  local safePack = safepackEid.get() == ecs.INVALID_ENTITY_ID ? null
    : mkHeroSafepackItemContainerItemsList(moveItemWithKeyboardMode, inventoryItemClickActions[SAFEPACK.name])
  if (previewPreset.get()) {
    pouches = mkHeroInventoryPresetPreview()
    safePack = previewPreset.get()?.safePack.itemTemplate == null ? null
      : mkSafepackInventoryPresetPreview()
    backpack = previewPreset.get()?.backpack.itemTemplate == null ? null
      : mkBackpackInventoryPresetPreview()
  }

  return {
    watch = [ safepackEid, backpackEid, previewPreset ]
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
      safePack == null ? null : {
        children = safePack
      }.__update(bluredPanel)
    ]
  }
}

function mkBodyPartsPanel() {
  return {
    watch = [isInPlayerSession]
    size = FLEX_V
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      bodypartsPanel
      inventoryAffectsWidget
      @() {
        watch = [isInMonsterState, isMonsterInventoryEnabled, isOnPlayerBase]
        size = FLEX_H
        vplace = ALIGN_BOTTOM
        halign = ALIGN_RIGHT
        valign = ALIGN_BOTTOM
        flow = FLOW_HORIZONTAL
        gap = hdpx(10)
        children = [
          chronogenesWidget,
          { size = FLEX_H },
          (isInMonsterState.get() && !isMonsterInventoryEnabled.get()) || isOnPlayerBase.get() ? null : mkActiveMatterStorageWidget(),
          (isInMonsterState.get() && !isMonsterInventoryEnabled.get()) ? suitTypeMark : @() {
            watch = isInBattleState
            flow = FLOW_HORIZONTAL
            gap = hdpx(4)
            children = [
              isInBattleState.get() ? null : tagChronogeneSlot
              colorPickerButton
            ]
          }
        ]
      }
    ]
  }
}

let refillButton = button(
  faComp("repeat", {
    fontSize = hdpx(12)
    padding = hdpx(10)
  }),
  function() {
    if (mutationForbidenDueToInQueueState.get()) {
      showMsgbox({ text = loc("playerPreset/cantChangePresetRightNow") })
      return
    }
    ecs.g_entity_mgr.sendEvent(controlledHeroEid.get(), RequestFillAllItems())
  },
  {
    onHover = @(on) setTooltip(on ? loc("inventory/refillTooltip") : null)
  }
)

let hotkeys = [["^{0} | Esc".subst(JB.B), {action = close, description = loc("mainmenu/btnClose")}]]

let weightBlock = @() {
  watch = [inventoryCurrentWeight, playerMovePenalty, isInBattleState]
  behavior = Behaviors.Button
  skipDirPadNav = isInBattleState.get()
  onHover = @(on) setTooltip(on ? loc("inventory/playerMovePenalty", { value = (playerMovePenalty.get() * 100.0).tointeger() }) : null)
  children = mkText(loc("inventory/weight", { value = truncateToMultiple(inventoryCurrentWeight.get(), 0.1) }))
}

let dollPanels = @() {
  watch = [ isInPlayerSession, isOnboarding ]
  size = FLEX_V
  padding = contentPadding
  children = [
    {
      size = FLEX_H
      flow = FLOW_VERTICAL
      cursorNavAnchor = [elemw(50), elemh(50)]
      children = [
        { size = static [ 0, hdpx(34)]  }
        weightBlock
      ]
    }
    mkBodyPartsPanel
    isInPlayerSession.get() || isOnboarding.get() || isNexus.get() ? null
      : presetBlockButton
  ]
}.__update(bluredPanel)

let weaponPanels = {
  size = FLEX_V
  padding = contentPadding
  flow = FLOW_VERTICAL
  gap = hdpx(6)
  transform = {}
  animations = weaponSlotAnims
  children = [
    mkInventoryHeaderText(loc("inventory/weapons"), { size = static [ flex(), hdpx(53) ] })
    mkEquipmentWeapons()
    quickUsePanelEdit
  ]
}.__update(bluredPanel)

function refillItemsButton() {
  let watch = static [isInPlayerSession, isOnboarding, isNexus]
  if (isInPlayerSession.get() || isOnboarding.get() || isNexus.get())
    return static { watch }
  return {
    watch
    padding = static [ 0, hdpx(10) ]
    hplace = ALIGN_RIGHT
    children = refillButton
  }
}

let playerInventoryPanels = {
  size = FLEX_V
  flow = FLOW_HORIZONTAL
  gap = hdpx(10)
  children = [
    dollPanels
    {
      size = FLEX_V
      children = [
        weaponPanels
        {pos = static [0, hdpx(1)] children = refillItemsButton}
      ]
    }
    heroInventories
  ]
}

let monsterWeaponPanels = static {
  size = FLEX_V
  flow = FLOW_VERTICAL
  gap = hdpx(6)
  children = [
    mkInventoryHeaderText(loc("inventory/weapons"), { size = static [ flex(), hdpx(53) ] })
    disabledEquipmentWeapons
  ]
}.__update(bluredPanel, { padding = contentPadding })

function monsterInventories() {
  let pouches = mkHeroItemContainerItemsList(null, inventoryItemClickActions[HERO_ITEM_CONTAINER.name])
  return {
    size = FLEX_V
    children = [
      pouches
      {
        size = flex()
        behavior = Behaviors.Button
        onHover = @(on) setTooltip(on ? loc("inventory/monsterDisabledTip") : null)
      }
      mkTextArea(loc("poaches/disabled"), {
        vplace = ALIGN_CENTER
        halign = ALIGN_CENTER
        color = RedWarningColor
      }.__update(body_txt))
    ]
  }.__update(bluredPanel, static { padding = 0 })
}

let monsterInventoryPanels = @() {
  watch = [isMonsterInventoryEnabled, isMonsterWeaponsEnabled]
  size = FLEX_V
  flow = FLOW_HORIZONTAL
  gap = hdpx(10)
  children = [
    dollPanels
    isMonsterWeaponsEnabled.get() ? {
      size = FLEX_V
      children = [
        weaponPanels
        {pos = [0, hdpx(1)] children = refillItemsButton}
      ]
    } : monsterWeaponPanels
    isMonsterInventoryEnabled.get() ? heroInventories : monsterInventories
  ]
}

let inventoryPanels = @() {
  watch = isInMonsterState
  rendObj = ROBJ_WORLD_BLUR_PANEL
  fillColor = ConsoleFillColor
  size = FLEX_V
  flow = FLOW_HORIZONTAL
  gap = hdpx(38)
  children = (isInMonsterState.get())
    ? [
        monsterInventoryPanels
        sideInventories
      ]
    : [
        playerInventoryPanels
        sideInventories
      ]
}

let inventoryBlock = {
  size = flex()
  flow = FLOW_HORIZONTAL
  halign = ALIGN_CENTER
  children = [
    leftpadding
    inventoryPanels
    {
      size = static [0, flex()]
      flow = FLOW_VERTICAL
      gap = hdpx(10)
      children = [
        closebutton
        filters
      ]
    }
    rightpadding
  ]
  animations = containerAnims
}

let inventoryContent = {
  key = InventoryMenuId
  size = flex()
  children = [
    shiftPressedMonitor
    isAltPressedMonitor
    hotkeysEater
    {
      size = flex()
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      flow = FLOW_VERTICAL
      hotkeys
      children = [
        inventoryBlock
        contextHotkeys
      ]
    }
  ]
}

let inventoryUi = @() @() {
  watch = static [safeAreaVerPadding, safeAreaHorPadding, safeAreaAmount, isNexus]
  size = flex()
  onAttach = function() {
    addInteractiveElement(InventoryMenuId)
    quickUseIsOpenedForEdit.set(true)
    backpackItemRecognitionEnabled.set(true)
    ecs.g_entity_mgr.broadcastEvent(EventHeroInventoryOpened())
  }
  onDetach = function(){
    removeInteractiveElement(InventoryMenuId)
    quickUseIsOpenedForEdit.set(false)
    backpackItemRecognitionEnabled.set(false)
    removeModalPopup(PRESET_WND_UID)
    removeModalPopup(CONTEXT_MENU_WND_UID)
    ecs.g_entity_mgr.broadcastEvent(EventHeroInventoryClosed())
  }
  children = wrapInStdPanel(InventoryMenuId, inventoryContent, loc("Inventory"), null,
  static { size = 0 }, {
    showback = false
    pos = safeAreaAmount.get() == 1 ? static [0, 0] : [-fsh(2.5), safeAreaVerPadding.get() / 2]
  })
}

let inventoryMenuDesc = {
  getContent = inventoryUi
  event = "HUD.Inventory"
  openSound = "ui_sounds/inventory_on"
  closeSound = "ui_sounds/inventory_off"
  isAvailable = Computed(@() watchedHeroEid.get() != ecs.INVALID_ENTITY_ID)
  onOpenTriggerHash = ecs.calc_hash("show_shelter_note_storage")
}

return {
  inventoryMenuDesc
  InventoryMenuId
  filters
  refillButton
}
