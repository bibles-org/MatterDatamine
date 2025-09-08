from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { ConsoleFillColor, ConsoleBorderColor,
      BtnBgHover, BtnBgTransparent, BtnBdHover, ItemBdColor } = require("%ui/components/colors.nut")
let { itemFillColorHovered, itemFillColorDef } = require("%ui/hud/menus/components/inventoryItem.nut")
let { equipment } = require("%ui/hud/state/equipment.nut")
let { startswith } = require("string")
let { inventoryImageParams } = require("%ui/hud/menus/components/inventoryItemImages.nut")
let { humanEquipmentSlots } = require("%ui/hud/state/equipment_slots_stubs.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")
let { isInMonsterState } = require("%ui/hud/state/hero_monster_state.nut")
let { playerBaseState } = require("%ui/profile/profileState.nut")
let { isNexus } = require("%ui/hud/state/nexus_mode_state.nut")
let { chronogeneListPanel } = require("%ui/mainMenu/clonesMenu/itemGenesSlots.nut")
let { addModalPopup } = require("%ui/components/modalPopupWnd.nut")
let { mkChronogeneSlot, getChronogenePreviewPresentation, mkChronogeneDoll, backTrackingMenu
} = require("%ui/mainMenu/clonesMenu/clonesMenuCommon.nut")
let { mkFakeItem } = require("%ui/hud/menus/components/fakeItem.nut")
let { buildInventoryItemTooltip } = require("%ui/hud/menus/components/inventoryItemTooltip.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let { openMenu, currentMenuId } = require("%ui/hud/hud_menus_state.nut")
let { isPreparationOpened, PREPARATION_NEXUS_SUBMENU_ID, PREPARATION_SUBMENU_ID, isNexusPreparationOpened, Raid_id
} = require("%ui/mainMenu/raid_preparation_window_state.nut")
let { previewPreset, previewPresetCallbackOverride } = require("%ui/equipPresets/presetsState.nut")
let { openMainChronogeneSelection } = require("%ui/mainMenu/clonesMenu/mainChronogeneSelection.nut")
let { stashItems } = require("%ui/hud/state/inventory_items_es.nut")
let { mergeNonUniqueItems } = require("%ui/hud/menus/components/inventoryItemUtils.nut")

function secondaryChronogenesWidget() {
  
  
  
  let needToShow = Computed(@() !isOnboarding.get()
    && (playerBaseState.get()?.openedAlterContainers ?? 2) > 1
    && !isInMonsterState.get()
    && !isNexus.get())

  if (!needToShow.get())
    return {watch = needToShow}

  let secondaryGeneEquipped = Computed(function() {
    let preset = previewPreset.get()
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

  let mainChronogene = Computed(function() {
    let preset = previewPreset.get()
    if (preset) {
      
      return clone(preset?.chronogene_primary_1)
    }
    return equipment.get()?.chronogene_primary_1
  })

  let mkChronogeneOnClick = @(idx) function(event) {
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

    let { r, t } = event.targetRect
    addModalPopup( [ r, t ], {
      rendObj = ROBJ_WORLD_BLUR_PANEL
      size = [SIZE_TO_CONTENT, sh(96)]
      uid = "secondaryChronogeneSelectionPopup"
      popupValign = ALIGN_CENTER
      popupHalign = ALIGN_LEFT
      flow = FLOW_VERTICAL
      gap = hdpx(10)
      fillColor = ConsoleFillColor
      borderWidth = hdpx(2)
      borderColor =  mul_color(ConsoleBorderColor, 0.3)
      borderRadius = 0
      children = chronogeneListPanel(idx, chronogeneList, equippedChronogenes, previewPresetOverrideFunc)
    })
  }

  let alterSelectionButton = function() {
    let stateFlags = Watched(0)
    let getFillColor = @(sf) (sf & S_HOVER) ? BtnBgHover : BtnBgTransparent
    return @(){
      watch = [ isOnPlayerBase, stateFlags ]
      children = isOnPlayerBase.get() ? {
        behavior = Behaviors.Button
        size = inventoryImageParams.slotSize
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
          
          
          
          let overrudedFunc = previewPresetCallbackOverride.get()?["chronogene_primary_1"].onDrop
          if (overrudedFunc) {
            openMainChronogeneSelection(overrudedFunc)
          }
          else if (previewPreset.get() != null) {
            return 
          }
          else {
            let subMenu = isPreparationOpened.get() ? $"{Raid_id}/{PREPARATION_SUBMENU_ID}"
              : isNexusPreparationOpened.get() ? $"{Raid_id}/{PREPARATION_NEXUS_SUBMENU_ID}"
              : currentMenuId.get() == "Inventory" ? "Inventory"
              : null
            backTrackingMenu.set(subMenu)
            openMenu(const "CloneBody")
          }
        }
        children = [
          @() {
            watch = stateFlags
            rendObj = ROBJ_BOX
            size = flex()
            color = stateFlags.get() & S_HOVER ? itemFillColorHovered : itemFillColorDef

            fillColor = getFillColor(stateFlags.get())
            borderColor = (stateFlags.get() & S_HOVER) ? BtnBdHover : ItemBdColor
            borderWidth = hdpx(1)
          }
          function() {
            local iconName = mainChronogene.get()?.iconName
            let templateName = mainChronogene.get()?.itemTemplate
            if (iconName == null && templateName) {
              let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
              iconName = template.getCompValNullable("animchar__res") ?? ""
            }
            return {
              watch = mainChronogene
              children = mkChronogeneDoll(iconName, inventoryImageParams.slotSize,
                getChronogenePreviewPresentation(templateName))
            }
          }
        ]
      } : null
    }
  }
  return {
    watch = [ equipment, needToShow ]
    flow = FLOW_HORIZONTAL
    vplace = ALIGN_BOTTOM
    gap = hdpx(4)
    children = [
      alterSelectionButton()
      @() {
        watch = secondaryGeneEquipped
        flow = FLOW_HORIZONTAL
        gap = hdpx(4)
        children = secondaryGeneEquipped.get().map(function(chronogeneItem, idx) {
          let slotAndItem = chronogeneItem.__merge(humanEquipmentSlots.chronogene_secondary, {
            isDragAndDropAvailable = false
          })
          return mkChronogeneSlot(slotAndItem, inventoryImageParams, mkChronogeneOnClick(idx))
        })
      }
    ]
  }
}

return {
  secondaryChronogenesWidget
}