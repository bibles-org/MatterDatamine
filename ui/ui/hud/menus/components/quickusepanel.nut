import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { controlHudHint } = require("%ui/components/controlHudHint.nut")
let { itemHeight } = require("%ui/hud/menus/components/inventoryStyle.nut")
let { quickUseObjective, objectives } = require("%ui/hud/state/objectives_vars.nut")
let { inventoryImageParams, inventoryItemImage } = require("%ui/hud/menus/components/inventoryItemImages.nut")
let { mkEquipmentSlot } = require("%ui/hud/menus/components/inventorySuit.nut")
let { chargesIndicator } = require("%ui/hud/menus/components/inventoryItem.nut")
let { mkFakeItem } = require("%ui/hud/menus/components/fakeItem.nut")
let { equipmentModSlots } = require("%ui/hud/state/equipment.nut")
let { startswith } = require("string")
let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")
let { questItemInUse } = require("%ui/hud//state/quick_use_state.nut")
let dropMarker = require("%ui/hud/menus/components/dropMarker.nut")
let { mkText } = require("%ui/components/commonComponents.nut")
let { currentMenuId } = require("%ui/hud/hud_menus_state.nut")
let { Market_id } = require("%ui/mainMenu/marketMenu.nut")
let { ClonesMenuId } = require("%ui/mainMenu/clonesMenu/clonesMenu.nut")
let { POCKETS } = require("%ui/hud/menus/components/slotTypes.nut")
let { BaseDebriefingMenuId } = require("%ui/mainMenu/baseDebriefing.nut")
let { inventoryItemClickActions } = require("%ui/hud/menus/inventoryActions.nut")
let { mkUnloadAmmoButton, mkLoadAmmoButton, mkStopLoadUnloadAmmoButton } = require("%ui/hud/menus/components/inventoryItemUtils.nut")
let { itemCompExtraInfoQuery } = require("%ui/hud/state/item_info.nut")
let { HERO_ITEM_CONTAINER } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { previewPreset, previewPresetCallbackOverride } = require("%ui/equipPresets/presetsState.nut")
let { getSlotFromTemplate } = require("%ui/hud/menus/components/itemFromTemplate.nut")
let { isNexusDebriefingState } = require("%ui/hud/state/nexus_round_mode_state.nut")
let { droneEnableToUse, isDroneMode, quickUseDroneConsole } = require("%ui/hud/state/drone_state.nut")
let { selectedObjectEid } = require("%ui/hud/state/actions_state.nut")

let quickUseIsOpenedForEdit = Watched(false)

let pockets = Computed(function() {
  return equipmentModSlots.get()?.map(@(mods) mods.filter(@(_v, k) startswith(k, "equipment_mod_pocket"))) ?? {}
})

function mkPocketSlot(slot, idx, callbacks, actionsForbidden) {
  let comps = itemCompExtraInfoQuery.perform(slot?.eid ?? ecs.INVALID_ENTITY_ID, @(_eid, comp) comp)
  return {
    size = [ itemHeight, itemHeight ]
    children = [
      mkEquipmentSlot(slot, callbacks, inventoryImageParams, POCKETS, actionsForbidden)
      controlHudHint({ id = $"Human.QuickUse{idx+1}" })
      mkUnloadAmmoButton(slot.__merge({owner=controlledHeroEid.get()}), HERO_ITEM_CONTAINER,
        comps?.item_holder__customUiProps?.unloadAmmoTooltip ?? "Inventory/unload_ammo",
        comps?.item_holder__customUiProps?.unloadAmmoIcon ?? "unload_magazine.svg")
      mkLoadAmmoButton(slot.__merge({owner=controlledHeroEid.get()}), HERO_ITEM_CONTAINER,
        comps?.item_holder__customUiProps?.loadAmmoTooltip ?? "Inventory/load_ammo",
        comps?.item_holder__customUiProps?.loadAmmoIcon ?? "load_magazine.svg")
      mkStopLoadUnloadAmmoButton(slot.__merge({owner=controlledHeroEid.get()}), HERO_ITEM_CONTAINER)
    ]
  }
}

function getEquipmentPockets(item) {
  if (item?.itemTemplate == null)
    return {}

  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(item.itemTemplate)
  return template.getCompValNullable("equipment_mods__slots")?.getAll().filter(@(_v, k) k.startswith("equipment_mod_pocket")) ?? {}
}

function quickUsePanelEdit() {
  local suitSlots = []
  local pouchesSlots = []
  if (previewPreset.get()) {
    let suitPreview = previewPreset.get()?["chronogene_primary_1"] ?? {}
    let suitPockets = getEquipmentPockets(suitPreview).topairs().sort(@(a, b) a[0] <=> b[0])
    foreach (pair in suitPockets) {
      let k = pair[0]
      let v = pair[1]

      let slotTemplate = getSlotFromTemplate(v)
      let previewItem = suitPreview?[k]
      let fakeItem = previewItem?.itemTemplate ? mkFakeItem(previewItem.itemTemplate) : {}
      suitSlots.append(slotTemplate.__update(fakeItem, {
        noSuitableItemForPresetFoundCount = previewItem?.noSuitableItemForPresetFoundCount
        isItemToPurchase = previewItem?.isItemToPurchase
        slotName = POCKETS.name
      }))
    }

    let pouchPreview = previewPreset.get()?.pouch ?? {}
    let pouchPockets = getEquipmentPockets(pouchPreview).topairs().sort(@(a, b) a[0] <=> b[0])
    foreach (pair in pouchPockets) {
      let k = pair[0]
      let v = pair[1]

      let slotTemplate = getSlotFromTemplate(v)
      let previewItem = pouchPreview?.attachments[k]

      let fakeItem = previewItem?.itemTemplate ? mkFakeItem(previewItem.itemTemplate, {
        noSuitableItemForPresetFoundCount = previewItem?.noSuitableItemForPresetFoundCount
        isItemToPurchase = previewItem?.isItemToPurchase
        slotName = POCKETS.name
      }) : { slotName = POCKETS.name }
      pouchesSlots.append(slotTemplate.__update(fakeItem))
    }

    for (local i = pouchesSlots.len() + suitSlots.len(); i < 5; i++) {
      pouchesSlots.append({
        defaultIcon = "skin#lock.svg",
        iconImageColor = Color(101, 101, 101, 51)
        slotTooltip = "pockets/unavailablePocketTooltip"
        isLocked = true
      })
    }

  }
  else {
    let slots = pockets.get()
      .topairs()
      .sort(@(a, b) (a[0] != "chronogene_primary_1") <=> (b[0] != "chronogene_primary_1") || a[0] <=> b[0])
      .map(@(pair) pair[1].topairs().sort(@(a, b) a[0] <=> b[0]).map(@(mod_pair) mod_pair[1]))
      .reduce(@(res, mod) res.extend(mod), [])
    if (slots.len() == 0)
      return { watch = [ pockets ] }
    for (local i = slots.len(); i < 5; i++)
      slots.append({
        defaultIcon = "skin#lock.svg",
        iconImageColor = Color(101, 101, 101, 51)
        slotTooltip = "pockets/unavailablePocketTooltip"
        isLocked = true
    })
    suitSlots = slots.filter(@(v) (v?.parentSlotName ?? "") == "chronogene_primary_1")
    pouchesSlots = slots.filter(@(v) (v?.parentSlotName ?? "") != "chronogene_primary_1")
  }

  let suitPockets = []
  let pouchPockets = []
  for(local i = 0; i < suitSlots.len(); i++) {
    let slot = suitSlots[i]
    let previewCallbackOverride = previewPreset.get() ? previewPresetCallbackOverride.get()?.chronogene_primary_1[$"equipment_mod_pocket_{i}"] : null
    let actionsForbidden = previewPreset.get() != null && previewCallbackOverride == null

    let callbacks = previewCallbackOverride ? previewCallbackOverride : inventoryItemClickActions[POCKETS.name]
    suitPockets.append(mkPocketSlot(slot, i, callbacks, actionsForbidden))
  }
  for(local i = 0; i < pouchesSlots.len(); i++) {
    let slot = pouchesSlots[i]
    let previewCallbackOverride = previewPreset.get() ? previewPresetCallbackOverride.get()?.pouch.attachments[$"equipment_mod_pocket_{i}"] : null
    let actionsForbidden = previewPreset.get() != null && previewCallbackOverride == null

    let callbacks = previewCallbackOverride ? previewCallbackOverride : inventoryItemClickActions[POCKETS.name]
    pouchPockets.append(mkPocketSlot(slot, suitSlots.len() + i, callbacks, actionsForbidden))
  }

  return {
    watch = [ pockets, previewPreset, previewPresetCallbackOverride ]
    size = [ flex(), SIZE_TO_CONTENT ]
    vplace = ALIGN_BOTTOM
    hplace = ALIGN_CENTER
    children = [
      {
        hplace = ALIGN_LEFT
        flow = FLOW_VERTICAL
        gap = hdpx(6)
        children = [
          mkText(loc("pockets/suit"))
          {
            flow = FLOW_HORIZONTAL
            gap = hdpx(6)
            children = suitPockets
          }
        ]
      }
      {
        hplace = ALIGN_RIGHT
        flow = FLOW_VERTICAL
        gap = hdpx(6)
        children = [
          mkText(loc("pockets/pouches"))
          {
            flow = FLOW_HORIZONTAL
            gap = hdpx(6)
            children = pouchPockets
          }
        ]
      }
    ]
  }
}
let mkControlHudHint = memoize(@(i) controlHudHint({ id = $"Human.QuickUse{i+1}" }))

function quickUsePanelNoEdit(){
  let children = pockets.get().topairs().sort(@(a, b) (a[0] != "chronogene_primary_1") <=> (b[0] != "chronogene_primary_1") || a[0] <=> b[0])
    .map(@(pair) pair[1].topairs().sort(@(a, b) a[0] <=> b[0]).map(@(mod_pair) mod_pair[1]))
    .reduce(@(res, mod) res.extend(mod), [])
    .map(function(slot, i) {
      if (slot?.itemTemplate == null)
        throw null
      let { charges = null, maxCharges = null, countKnown = true } = slot
      return {
        size = const [ itemHeight, itemHeight ]
        rendObj = ROBJ_WORLD_BLUR_PANEL
        children = [
          inventoryItemImage(slot, inventoryImageParams)
          mkControlHudHint(i)
          chargesIndicator(charges, maxCharges, countKnown)
        ]
      }
    })

  return {
    watch = pockets
    size = SIZE_TO_CONTENT
    gap = hdpx(6)
    vplace = ALIGN_BOTTOM
    hplace = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    children
    animations = [
      { prop = AnimProp.opacity, from = 1.0, to = 0.6, duration = 4, trigger = "quick_use_panel_fade"}
    ]
  }
}

function mkQuickUsePanel() {
  let show = Computed(@() !quickUseIsOpenedForEdit.get()
    && currentMenuId.get() != Market_id
    && currentMenuId.get() != ClonesMenuId
    && currentMenuId.get() != BaseDebriefingMenuId
    && !isNexusDebriefingState.get()
  )
  return @() {
    watch = show
    children = show.get() ? quickUsePanelNoEdit : null
  }
}

questItemInUse.subscribe(function(v) {
  if(v)
    anim_request_stop("quickUseObjectiveItemSlot")
  else
    anim_start("quickUseObjectiveItemSlot")
})



function quickUseObjectiveItemSlot() {
  let questItemSize = hdpx(100)
  let empty = {
    size = [ questItemSize, questItemSize ]
    watch = [ quickUseObjective, objectives ]
  }
  if (quickUseObjective.get() == "")
    return empty

  let questItemTemplate = quickUseObjective.get()
  if (questItemTemplate == null || questItemTemplate == "")
    return empty

  let fakeItem = mkFakeItem(questItemTemplate, { notInteractive=true })

  return {
    watch = [ quickUseObjective, objectives ]
    halign = ALIGN_RIGHT
    valign = ALIGN_TOP
    size = [ questItemSize, questItemSize ]
    children = @(){
      transform = {}
      animations = [
        { prop=AnimProp.scale, from=[1.0, 1.0], to=[1.1, 1.1], duration=1.0, loop=true, play=true, easing=CosineFull, trigger="quickUseObjectiveItemSlot" }
      ]
      clipChildren = true
      children = [
        @(){
          size = flex()
          watch = questItemInUse
          children = questItemInUse.get() ? null : dropMarker(0)
        }
        mkEquipmentSlot(fakeItem, {}, inventoryImageParams.__merge({
          width=hdpxi(80)
          height=hdpxi(80)
          slotSize = [ questItemSize, questItemSize ]
        }))
        {
          size = [ questItemSize, questItemSize ]
          behavior = [Behaviors.Marquee]
          children = controlHudHint({ id = $"Human.QuickUseObjectiveItem" })
        }
      ]
    }
  }
}

function quickUseDroneConsoleItem() {
  let consoleItemSize = hdpx(100)
  let empty = {
    size = [ consoleItemSize, consoleItemSize ]
    watch = [ droneEnableToUse, isDroneMode, quickUseDroneConsole, selectedObjectEid ]
  }
  if (!droneEnableToUse.get() || isDroneMode.get() || selectedObjectEid.get() != ecs.INVALID_ENTITY_ID)
    return empty

  let droneConsoleItemTemplate = quickUseDroneConsole.get()
  if (droneConsoleItemTemplate == null || droneConsoleItemTemplate == "")
    return empty

  let fakeItem = mkFakeItem(droneConsoleItemTemplate, { notInteractive=true })
  return {
    watch = [ droneEnableToUse, isDroneMode, quickUseDroneConsole, selectedObjectEid ]
    halign = ALIGN_RIGHT
    valign = ALIGN_TOP
    size = [ consoleItemSize, consoleItemSize ]
    children = @(){
      transform = {}
      animations = [
        { prop=AnimProp.scale, from=[1.0, 1.0], to=[1.1, 1.1], duration=1.0, loop=true, play=true, easing=CosineFull, trigger="quickUseObjectiveItemSlot" }
      ]
      clipChildren = true
      children = [
        @(){
          size = flex()
          watch = isDroneMode
          children = isDroneMode.get() ? null : dropMarker(0)
        }
        mkEquipmentSlot(fakeItem, {}, inventoryImageParams.__merge({
          width=hdpxi(80)
          height=hdpxi(80)
          slotSize = [ consoleItemSize, consoleItemSize ]
        }))
        {
          size = [ consoleItemSize, consoleItemSize ]
          behavior = [Behaviors.Marquee]
          children = controlHudHint({ id = $"Human.QuickUseObjectiveItem" })
        }
      ]
    }
  }
}

return {
  pockets
  mkQuickUsePanel
  quickUsePanelEdit
  quickUseIsOpenedForEdit
  quickUseObjectiveItemSlot
  quickUseDroneConsoleItem
}