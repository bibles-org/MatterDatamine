import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { RedWarningColor, ConsoleFillColor } = require("%ui/components/colors.nut")
let { body_txt } = require("%ui/fonts_style.nut")
let { addInteractiveElement, removeInteractiveElement } = require("%ui/hud/state/interactive_state.nut")
let {mkActiveMatterStorageWidget} = require("%ui/hud/menus/components/amStorage.nut")
let {suitTypeMark} = require("%ui/hud/menus/components/suitTypeMark.nut")
let { inventoryFiltersWidget } = require("%ui/hud/menus/components/inventoryStashFiltersWidget.nut")
let { mkHeroBackpackItemContainerItemsList,
      mkHeroSafepackItemContainerItemsList } = require("%ui/hud/menus/components/inventoryItemsHeroExtraInventories.nut")
let { mkHeroItemContainerItemsList } = require("%ui/hud/menus/components/inventoryItemsHeroItemContainer.nut")
let { mkSafepackInventoryPresetPreview, mkHeroInventoryPresetPreview, mkBackpackInventoryPresetPreview } = require("%ui/hud/menus/components/inventoryItemsPresetPreview.nut")
let { mkEquipmentWeapons, disabledEquipmentWeapons } = require("%ui/hud/menus/components/inventoryItemsHeroWeapons.nut")
let { mkGroundItemsList } = require("%ui/hud/menus/components/inventoryItemsGround.nut")
let { mkExternalItemContainerItemsList } = require("%ui/hud/menus/components/inventoryItemsExternalItemContainer.nut")
let { trashBinItemContainerCursorAttractor, trashBinItemContainerItemsList } = require("%ui/hud/menus/components/inventoryItemsTrashBin.nut")
let { GROUND, HERO_ITEM_CONTAINER, EXTERNAL_ITEM_CONTAINER,
      BACKPACK0, STASH, SAFEPACK} = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { focusedData, shiftPressedMonitor, isAltPressedMonitor, inventoryCurrentWeight, playerMovePenalty } = require("%ui/hud/state/inventory_state.nut")
let {externalInventoryEid, prevExternalInventoryEid} = require("%ui/hud/state/hero_external_inventory_state.nut")
let {backpackEid, safepackEid, backpackItemRecognitionEnabled} = require("%ui/hud/state/hero_extra_inventories_state.nut")
let {CmdShowUiMenu, CmdHideUiMenu, EventInventoryClosed, RequestFillAllItems } = require("dasevents")
let {bodypartsPanel} = require("%ui/hud/menus/components/damageModel.nut")
let { is_item_inventory_move_blocked } = require("das.inventory")
require("%ui/hud/state/item_use_message.nut")
let { isInPlayerSession, isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")
let { mkStashItemsList, extendStashBtn } = require("%ui/hud/menus/components/inventoryItemsStash.nut")
let {quickUsePanelEdit, quickUseIsOpenedForEdit} = require("%ui/hud/menus/components/quickUsePanel.nut")
let {mkInventoryHeaderText} = require("%ui/hud/menus/components/inventoryCommon.nut")
let JB = require("%ui/control/gui_buttons.nut")
let {isGamepad} = require("%ui/control/active_controls.nut")
let {controlHudHint} = require("%ui/components/controlHudHint.nut")
let {addHotkeysComp, removeHotkeysComp} = require("%ui/hotkeysPanelStateComps.nut")
let {isSpectator} = require("%ui/hud/state/spectator_state.nut")
let { moveItemWithKeyboardMode, inventoryItemClickActions, CONTEXT_MENU_WND_UID } = require("%ui/hud/menus/inventoryActions.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { presetBlockButton, PRESET_WND_UID } = require("%ui/equipPresets/presetsButton.nut")
let { previewPreset } = require("%ui/equipPresets/presetsState.nut")
let { colorPickerButton } = require("%ui/mainMenu/ribbons_colors_picker.nut")
let { bluredPanelWindow, mkText, mkTextArea, fontIconButton } = require("%ui/components/commonComponents.nut")
let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")
let { isItemCanBeDroppedInStash, isItemCanBeDroppedOnGround } = require("%ui/hud/menus/components/inventoryItemsListChecks.nut")
let { MoveForbidReason } = require("%ui/hud/menus/components/inventoryItemsListChecksCommon.nut")
let { inventoryAffectsWidget } = require("%ui/hud/player_info/affects_widget.nut")
let faComp = require("%ui/components/faComp.nut")
let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")
let { button } = require("%ui/components/button.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let { isNexus } = require("%ui/hud/state/nexus_mode_state.nut")
let { secondaryChronogenesWidget } = require("%ui/hud/menus/components/secondaryChronogenesWidget.nut")
let { isInMonsterState, isMonsterInventoryEnabled, isMonsterWeaponsEnabled } = require("%ui/hud/state/hero_monster_state.nut")
let { removeModalPopup } = require("%ui/components/modalPopupWnd.nut")
let { truncateToMultiple } = require("%sqstd/math.nut")
let { wrapInStdPanel } = require("%ui/mainMenu/stdPanel.nut")
let { safeAreaVerPadding, safeAreaHorPadding, safeAreaAmount } = require("%ui/options/safeArea.nut")

const HUD_GAMEMENU_HOTKEY  = "HUD.GameMenu"
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

const takeOrDropHotkey = "^J:Y"
const useHotkey = "^J:X"
const secondUseKey  = "^J:LB"

let contentPadding = [ hdpx(1), hdpx(10), hdpx(10), hdpx(10) ]

let containerAnims = [
  { prop=AnimProp.opacity, from=0, to=1, duration=0.25, play=true, easing=OutCubic }
  { prop=AnimProp.scale, from=[1,1], to=[1,0.01], duration=0.25, playFadeOut=true, easing=OutCubic }
  { prop=AnimProp.opacity, from=1, to=0, duration=0.25, playFadeOut=true, easing=OutCubic }
]

let emptyHotkey = {action = @() null, description = {skip=true}}
let hotkeysEater = {
  hotkeys = [takeOrDropHotkey, useHotkey, secondUseKey].map(@(v) [v, emptyHotkey])
}

let actionTextMap = {
  take = loc("hud/onlyPickup")
  use = loc("controls/Inventory.UseItem")
  drop = loc("controls/Inventory.DropItem")
  secondUse = loc("controls/Inventory.EquipToSecondWeapon")
}

function contextHotkeys(){
  if (isSpectator.get() || !isGamepad.get())
    return { watch = [isSpectator, isGamepad] }
  let children = []
  let item = focusedData.get()
  let tryTake = item?.lmbAltAction
  let tryUse = item?.lmbAction
  let tryDrop = item?.rmbAltAction
  if (tryTake!=null)
    children.append({key = tryTake, hotkeys = [[takeOrDropHotkey, {action = tryTake, description=actionTextMap.take}]]})
  else if (tryDrop!=null)
    children.append({key = tryDrop, hotkeys = [[takeOrDropHotkey, {action = tryDrop, description=actionTextMap.drop}]]})
  if (tryUse != null)
    children.append({key = tryUse, hotkeys = [[useHotkey, {action = tryUse, description=actionTextMap.use}]]})
  return {
    watch = [focusedData, isSpectator, isGamepad]
    children = children
  }
}

function makeHintText(locId) {
  return {
    rendObj = ROBJ_TEXT
    color = Color(180,180,180,180)
    text = loc($"controls/{locId}")
  }
}
let gameMenuHint = @(){
  flow = FLOW_HORIZONTAL
  gap = hdpx(5)
  watch = isGamepad
  children = isGamepad.value ? [controlHudHint(HUD_GAMEMENU_HOTKEY), makeHintText(HUD_GAMEMENU_HOTKEY)] : null
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
  size= const [SIZE_TO_CONTENT, flex()]
  watch = [isInPlayerSession, isOnboarding]
  children = [
    dropItemsArea,
    isOnPlayerBase.get() && !isOnboarding.get() ? inventoryFiltersWidget : null
  ]
}
let rightpadding = {size = flex(), children = dropItemsArea}

let closebutton = fontIconButton("icon_buttons/x_btn.svg", close)

let itemsAround = mkGroundItemsList(moveItemWithKeyboardMode,
  inventoryItemClickActions[GROUND.name], { xSize = 4 })

let trashBin = {
  size = [ flex(), SIZE_TO_CONTENT ]
  padding = [0, 0, hdpx(5), 0]
  children = [
    trashBinItemContainerCursorAttractor
    trashBinItemContainerItemsList
  ]
}

let externalInventories = {
  size = [ SIZE_TO_CONTENT, flex(1.5) ]
  children = mkExternalItemContainerItemsList(moveItemWithKeyboardMode,
    inventoryItemClickActions[EXTERNAL_ITEM_CONTAINER.name], { xSize = 4 })
}.__update(bluredPanel)


let aroundOrStash = @() {
  watch = const [isInPlayerSession, isOnboarding]
  size = const [ SIZE_TO_CONTENT, flex() ]
  flow = FLOW_VERTICAL
  gap = hdpx(5)
  children = [
    isInPlayerSession.get() ? itemsAround : !isOnboarding.get()
      ? mkStashItemsList(moveItemWithKeyboardMode, inventoryItemClickActions[STASH.name], { xSize = 4 })
      : { size = [ inventoryPanelSize[0], 0] },
    isInPlayerSession.get() || isOnboarding.get() ? null : extendStashBtn,
    isInPlayerSession.get() || isOnboarding.get() ? null : trashBin
  ]
}.__update(bluredPanel)

function sideInventories() {
  return {
    watch = const [ externalInventoryEid, isOnboarding, isNexus]
    size = const [ SIZE_TO_CONTENT, flex() ]
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
    size = const [ SIZE_TO_CONTENT, flex() ]
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      {
        size = const [ SIZE_TO_CONTENT, flex() ]
        children = pouches
      }.__update(bluredPanel)
      backpack == null ? null : {
        size = const [ SIZE_TO_CONTENT, flex() ]
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
    size = [ SIZE_TO_CONTENT, flex() ]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      bodypartsPanel
      inventoryAffectsWidget
      @() {
        watch = [isInMonsterState, isMonsterInventoryEnabled, isOnPlayerBase]
        size = [ flex(), SIZE_TO_CONTENT ]
        vplace = ALIGN_BOTTOM
        halign = ALIGN_RIGHT
        valign = ALIGN_CENTER
        flow = FLOW_HORIZONTAL
        gap = hdpx(10)
        children = [
          secondaryChronogenesWidget,
          { size = [flex(), SIZE_TO_CONTENT] },
          (isInMonsterState.get() && !isMonsterInventoryEnabled.get()) || isOnPlayerBase.get() ? null : mkActiveMatterStorageWidget(),
          (isInMonsterState.get() && !isMonsterInventoryEnabled.get()) ? suitTypeMark : colorPickerButton
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
  @() ecs.g_entity_mgr.sendEvent(controlledHeroEid.get(), RequestFillAllItems()),
  {
    onHover = @(on) setTooltip(on ? loc("inventory/refillTooltip") : null)
  }
)

let hotkeys = [["^{0} | Esc".subst(JB.B), {action = close, description = loc("mainmenu/btnClose")}]]

let weightBlock = @() {
  watch = [inventoryCurrentWeight, playerMovePenalty]
  behavior = Behaviors.Button
  onHover = @(on) setTooltip(on ? loc("inventory/playerMovePenalty", { value = (playerMovePenalty.get() * 100.0).tointeger() }) : null)
  children = mkText(loc("inventory/weight", { value = truncateToMultiple(inventoryCurrentWeight.get(), 0.1) }))
}

let dollPanels = @() {
  watch = [ isInPlayerSession, isOnboarding ]
  size = [ SIZE_TO_CONTENT, flex() ]
  padding = contentPadding
  children = [
    {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      cursorNavAnchor = [elemw(50), elemh(50)]
      children = [
        { size = [ 0, hdpx(34)]  }
        weightBlock
      ]
    }
    mkBodyPartsPanel
    isInPlayerSession.get() || isOnboarding.get() || isNexus.get() ? null
      : presetBlockButton
  ]
}.__update(bluredPanel)

let weaponPanels = {
  size = [ SIZE_TO_CONTENT, flex() ]
  padding = contentPadding
  flow = FLOW_VERTICAL
  gap = hdpx(6)
  transform = {}
  animations = weaponSlotAnims
  children = [
    mkInventoryHeaderText(loc("inventory/weapons"), { size = [ flex(), hdpx(53) ] })
    mkEquipmentWeapons()
    quickUsePanelEdit
  ]
}.__update(bluredPanel)

function refillItemsButton() {
  let watch = const [isInPlayerSession, isOnboarding, isNexus]
  if (isInPlayerSession.get() || isOnboarding.get() || isNexus.get())
    return const { watch }
  return {
    watch
    padding = const [ 0, hdpx(10) ]
    hplace = ALIGN_RIGHT
    children = refillButton
  }
}

let playerInventoryPanels = {
  size = const [ SIZE_TO_CONTENT, flex() ]
  flow = FLOW_HORIZONTAL
  gap = hdpx(10)
  children = [
    dollPanels
    {
      size = const [ SIZE_TO_CONTENT, flex() ]
      children = [
        weaponPanels
        {pos = const [0, hdpx(1)] children = refillItemsButton}
      ]
    }
    heroInventories
  ]
}

let monsterWeaponPanels = const {
  size = [SIZE_TO_CONTENT, flex()]
  flow = FLOW_VERTICAL
  gap = hdpx(6)
  children = [
    mkInventoryHeaderText(loc("inventory/weapons"), { size = [ flex(), hdpx(53) ] })
    disabledEquipmentWeapons
  ]
}.__update(bluredPanel, { padding = contentPadding })

function monsterInventories() {
  let pouches = mkHeroItemContainerItemsList(null, inventoryItemClickActions[HERO_ITEM_CONTAINER.name])
  return {
    size = const [SIZE_TO_CONTENT, flex()]
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
  }.__update(bluredPanel, const { padding = 0 })
}

let monsterInventoryPanels = @() {
  watch = [isMonsterInventoryEnabled, isMonsterWeaponsEnabled]
  size = [SIZE_TO_CONTENT, flex()]
  flow = FLOW_HORIZONTAL
  gap = hdpx(10)
  children = [
    dollPanels
    isMonsterWeaponsEnabled.get() ? {
      size = [ SIZE_TO_CONTENT, flex() ]
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
  size = const [SIZE_TO_CONTENT, flex()]
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
      size = const [0, flex()]
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
  watch = const [safeAreaVerPadding, safeAreaHorPadding, safeAreaAmount, isNexus]
  size = flex()
  onAttach = function() {
    addHotkeysComp(HUD_GAMEMENU_HOTKEY, gameMenuHint)
    addInteractiveElement(InventoryMenuId)
    quickUseIsOpenedForEdit.set(true)
    backpackItemRecognitionEnabled.set(true)
  }
  onDetach = function(){
    removeHotkeysComp(HUD_GAMEMENU_HOTKEY)
    removeInteractiveElement(InventoryMenuId)
    quickUseIsOpenedForEdit.set(false)
    backpackItemRecognitionEnabled.set(false)
    removeModalPopup(PRESET_WND_UID)
    removeModalPopup(CONTEXT_MENU_WND_UID)
  }
  children = wrapInStdPanel(InventoryMenuId, inventoryContent, loc("Inventory"), null,
  const { size = 0}, {
    showback = false
    pos = safeAreaAmount.get() == 1 ? [0, 0] : [-fsh(2.5), safeAreaVerPadding.get() / 2]
  })
}

let inventoryMenuDesc = {
  getContent = inventoryUi
  event = "HUD.Inventory"
  openSound = "ui_sounds/inventory_on"
  closeSound = "ui_sounds/inventory_off"
  onClose = @() ecs.g_entity_mgr.broadcastEvent(EventInventoryClosed())
  isAvailable = Computed(@() watchedHeroEid.get() != ecs.INVALID_ENTITY_ID)
  onOpenTriggerHash = ecs.calc_hash("show_shelter_note_storage")
}

return {
  inventoryMenuDesc
  InventoryMenuId
  filters
  refillButton
}
