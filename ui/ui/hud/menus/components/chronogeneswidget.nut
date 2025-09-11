from "%ui/components/colors.nut" import ConsoleFillColor, ConsoleBorderColor, BtnBgHover, BtnBgTransparent,
  BtnBdHover, ItemBdColor
from "%ui/mainMenu/clonesMenu/clonesMenuCommon.nut" import mkChronogeneSlot, mkAlterIconParams
from "%ui/hud/menus/components/inventoryItem.nut" import itemFillColorHovered, itemFillColorDef
from "string" import startswith
from "%ui/mainMenu/clonesMenu/itemGenesSlots.nut" import chronogeneListPanel
from "%ui/components/modalPopupWnd.nut" import addModalPopup, removeModalPopup
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem
from "%ui/hud/menus/components/inventoryItemTooltip.nut" import buildInventoryItemTooltip
from "%ui/components/cursors.nut" import setTooltip
from "%ui/hud/hud_menus_state.nut" import openMenu
from "%ui/mainMenu/clonesMenu/mainChronogeneSelection.nut" import openMainChronogeneSelection, mkAlterBackgroundTexture
from "%ui/hud/menus/components/inventoryItemUtils.nut" import mergeNonUniqueItems
from "%ui/components/msgbox.nut" import showMsgbox
from "%ui/hud/menus/components/inventoryItemImages.nut" import inventoryItemImage, inventoryImageParams
from "%ui/hud/menus/components/inventoryStyle.nut" import itemHeight

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { equipment } = require("%ui/hud/state/equipment.nut")
let { humanEquipmentSlots } = require("%ui/hud/state/equipment_slots_stubs.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")
let { isInMonsterState } = require("%ui/hud/state/hero_monster_state.nut")
let { backTrackingMenu } = require("%ui/mainMenu/clonesMenu/clonesMenuCommon.nut")
let { currentMenuId } = require("%ui/hud/hud_menus_state.nut")
let { isPreparationOpened, PREPARATION_SUBMENU_ID, isNexusPreparationOpened, Missions_id } = require("%ui/mainMenu/raid_preparation_window_state.nut")
let { previewPreset, useAgencyPreset, previewPresetCallbackOverride } = require("%ui/equipPresets/presetsState.nut")
let { stashItems } = require("%ui/hud/state/inventory_items_es.nut")
let { mutationForbidenDueToInQueueState } = require("%ui/hud/state/inventory_state.nut")
let { isInBattleState } = require("%ui/state/appState.nut")
let { PREPARATION_NEXUS_SUBMENU_ID } = require("%ui/hud/menus/mintMenu/mintState.nut")
let { inShootingRange } = require("%ui/hud/state/shooting_range_state.nut")


#allow-auto-freeze

function youCantEditAgencyPreset() {
  showMsgbox({ text = loc("playerPreset/youCantEditAgencyPreset") })
}

function chronogenesWidget() {
  
  
  
  let needToShow = Computed(@() !isOnboarding.get()
    && !isInMonsterState.get() )
  let isInBattleLikeState = Computed(@() isOnPlayerBase.get() && !inShootingRange.get())

  if (!needToShow.get())
    return {watch = needToShow}

  let secondaryGeneEquipped = Computed(function() {
    let preset = previewPreset.get()
    #forbid-auto-freeze
    local slots = []
    if (preset) {
      foreach (slotName in [ "chronogene_secondary_1", "chronogene_secondary_2", "chronogene_secondary_3", "chronogene_secondary_4" ]) {
        let templateName = preset?[slotName].itemTemplate
        slots.append({
          slotName
          itemTemplate = templateName
          uniqueId = templateName
        })
      }
    }
    else {
      slots = equipment.get().filter(@(_v, k) startswith(k, "chronogene_secondary")).values().sort(@(a, b) a.slotName <=> b.slotName)
    }
    return slots
  })

  let isCurrentPresetAgency = Computed(@() previewPreset.get()?.agencyPreset)

  let mainChronogene = Computed(function() {
    let preset = previewPreset.get()
    if (preset) {
      
      return clone(preset?.chronogene_primary_1)
    }
    return equipment.get()?.chronogene_primary_1
  })

  mutationForbidenDueToInQueueState.subscribe(function(state) {
    if (!state)
      return
    removeModalPopup("secondaryChronogeneSelectionPopup")
  })

  let mkChronogeneOnClick = @(idx) function(event) {
    if (mutationForbidenDueToInQueueState.get()) {
      showMsgbox({ text = loc("playerPreset/cantChangePresetRightNow") })
      return
    }

    let previewPresetOverrideFunc = previewPresetCallbackOverride.get()?[$"chronogene_secondary_{idx+1}"].onDrop
    if (!isOnPlayerBase.get() || (previewPresetOverrideFunc == null && previewPreset.get()))
      return

    let isFakedChronogenes = previewPresetOverrideFunc != null && previewPreset.get() != null

    let equippedChronogenes = secondaryGeneEquipped.get().map(@(v) v?.uniqueId)
    local chronogeneList = []
      .extend(
        stashItems.get() ?? [],
        equipment.get().values() ?? []
      ).filter(@(item) item?.filterType == "chronogene")
    if (isFakedChronogenes) {
      
      chronogeneList = mergeNonUniqueItems(chronogeneList).map(@(v) v.__merge({ count = 1 }))
    }
    chronogeneList = chronogeneList
      .filter(@(item) (equippedChronogenes.findindex(@(v) v == item?.uniqueId) == null
        || equippedChronogenes[idx] == item?.uniqueId))
      .sort(@(a, b) loc(a.itemName) <=> loc(b.itemName))
    #forbid-auto-freeze
    let { r, t } = event.targetRect
    addModalPopup( [ r, t ], {
      rendObj = ROBJ_WORLD_BLUR_PANEL
      size = static [SIZE_TO_CONTENT, sh(96)]
      uid = "secondaryChronogeneSelectionPopup"
      popupValign = ALIGN_CENTER
      popupHalign = ALIGN_LEFT
      flow = FLOW_VERTICAL
      gap = static hdpx(10)
      fillColor = ConsoleFillColor
      borderWidth = static hdpx(2)
      borderColor =  mul_color(ConsoleBorderColor, 0.3)
      borderRadius = 0
      children = chronogeneListPanel(idx, chronogeneList, equippedChronogenes, previewPresetOverrideFunc)
    })
  }
  #allow-auto-freeze
  let alterSelectionButton = function() {
    let stateFlags = Watched(0)
    return @() {
      watch = [isInBattleLikeState, inShootingRange, stateFlags, isInBattleState]
      size = static [itemHeight, hdpx(110)]
      skipDirPadNav = isInBattleState.get()
      behavior = Behaviors.Button
      onElemState = @(sf) stateFlags.set(sf)
      onHover = function(on) {
        if (on) {
          local tooltip = null
          let itemTemplate = mainChronogene.get()?.itemTemplate
          if (itemTemplate) {
            let fake = mkFakeItem(itemTemplate)
            tooltip = buildInventoryItemTooltip(fake)
          }
          else {
            tooltip = loc(humanEquipmentSlots.chronogene_primary_1.slotTooltip)
          }
          setTooltip(tooltip)
        }
        else
          setTooltip(null)
      }
      onClick = function() {
        if (isCurrentPresetAgency.get()) {
          youCantEditAgencyPreset()
          return
        }

        if (!isInBattleLikeState.get())
          return
        if (mutationForbidenDueToInQueueState.get()) {
          showMsgbox({ text = loc("playerPreset/cantChangePresetRightNow") })
          return
        }
        
        
        
        let overridedFunc = previewPresetCallbackOverride.get()?["chronogene_primary_1"].onDrop
        if (overridedFunc)
          openMainChronogeneSelection(overridedFunc)
        else if (previewPreset.get() != null) {
          return 
        }
        else {
          let subMenu = isPreparationOpened.get() ? $"{Missions_id}/{PREPARATION_SUBMENU_ID}"
            : isNexusPreparationOpened.get() ? $"{Missions_id}/{PREPARATION_NEXUS_SUBMENU_ID}"
            : currentMenuId.get() == "Inventory" ? "Inventory"
            : null
          backTrackingMenu.set(subMenu)
          openMenu("CloneBody")
        }
      }
      clipChildren = true
      children = [
        function() {
          let templateName = mainChronogene.get()?.itemTemplate
          if (templateName == null)
            return { watch = mainChronogene }
          let { attachments, alterIconParams } = mkAlterIconParams(templateName)
          let item = mkFakeItem(templateName, alterIconParams, attachments)
          return {
            watch = [mainChronogene, stateFlags]
            transform = { scale = stateFlags.get() & S_HOVER ? [1.04, 1.04] : [1, 1] }
            transitions = [{ prop = AnimProp.scale, duration = 0.4, easing = OutQuintic }]
            children = [
              mkAlterBackgroundTexture(item?.itemRarity)
              inventoryItemImage(item, static {
                width = itemHeight - hdpx(2)
                height = hdpx(108)
                slotSize = [itemHeight, hdpx(110)]
                hplace = ALIGN_CENTER
                vplace = ALIGN_BOTTOM
              }, static { padding = [0,0, hdpx(1), 0] })
            ]
          }
        }
        function() {
          let isHoverred = Computed(@() isInBattleLikeState.get() && (stateFlags.get() & S_HOVER))
          return {
            watch = isHoverred
            rendObj = ROBJ_BOX
            size = flex()
            color = isHoverred.get() ? itemFillColorHovered : itemFillColorDef
            borderColor = isHoverred.get() ? BtnBdHover : ItemBdColor
            borderWidth = hdpx(1)
          }
        }
      ]
    }
  }
  return {
    watch = [equipment, needToShow]
    flow = FLOW_HORIZONTAL
    gap = hdpx(4)
    vplace = ALIGN_BOTTOM
    valign = ALIGN_BOTTOM
    children = [
      alterSelectionButton()
      @() {
        watch = [ secondaryGeneEquipped, isInBattleLikeState, useAgencyPreset ]
        flow = FLOW_HORIZONTAL
        gap = hdpx(4)
        children = secondaryGeneEquipped.get().map(function(chronogeneItem, idx) {
          let slotAndItem = chronogeneItem.__merge(humanEquipmentSlots.chronogene_secondary, {
            isDragAndDropAvailable = false
          })
          return mkChronogeneSlot(
            slotAndItem,
            inventoryImageParams,
            isCurrentPresetAgency.get() ? youCantEditAgencyPreset :
              isInBattleLikeState.get() ? mkChronogeneOnClick(idx) :
                null
          )
        })
      }
    ]
  }
}

return {
  chronogenesWidget
}