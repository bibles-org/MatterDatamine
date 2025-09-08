import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { EventOnItemStartUse, CmdHideUiMenu } = require("dasevents")
let { truncateToMultiple } = require("%sqstd/math.nut")

let inventoryMaxVolume = Watched(0.0)
let inventoryCurrentVolume = Watched(0.0)
let inventoryCurrentWeight = Watched(0.0)
let playerMovePenalty = Watched(0.0)
let showSuitSlot = Watched(false)
let showCorticalVaultSlot = Watched(false)

let focusedData = Watched(null, FRP_DONT_CHECK_NESTED)
let contextHoveredData = Watched(null)
let isShiftPressed = Watched(false)
let isCtrlPressed = Watched(false)
let isAltPressed = Watched(false)
let unremovableSlots = Watched(["grenade", "suit"])

let scPressedMonitor = @(sc, watch) {
  behavior = Behaviors.Button
  onElemState = @(sf) watch((sf & S_ACTIVE) != 0)
  hotkeys = [[sc]]
  onDetach = @() watch(false)
}
let shiftPressedMonitor = scPressedMonitor("^L.Shift | R.Shift", isShiftPressed)
let isCtrlPressedMonitor = scPressedMonitor("^L.Ctrl | R.Ctrl", isCtrlPressed)
let isAltPressedMonitor = scPressedMonitor("^L.Alt | R.Alt", isAltPressed)

function doForAllEidsWhenShift(item, action) {
  if (isShiftPressed.value && ("eids" in item))
    item.eids.each(action)
  else
    action(item.eid)
}

function doForAllUniqueIdsWhenShift(item, action) {
  if (isShiftPressed.value && ("uniqueIds" in item))
    item.uniqueIds.each(action)
  else
    action(item.uniqueId)
}

function isWeaponModsForItem(item, weaponMods){
  return (weaponMods ?? {})
    .filter(@(modSlot, modSlotName) item?.weapModSlotName == modSlotName && (modSlot?.allowed_items ?? []).contains(item?.itemTemplate))
    .len()>0
}

function trackInventory(_eid, comp){
  inventoryMaxVolume.set(comp.human_inventory__maxVolumeInt / 10.0)
  inventoryCurrentVolume.set(comp.human_inventory__currentVolume / 10.0)
  inventoryCurrentWeight.set(truncateToMultiple(comp.human_inventory__currentWeight, 0.01))
  playerMovePenalty.set(comp.human_net_phys__moveSpeedMult)
}

ecs.register_es("inventory_ui_es",
  {
    [["onInit", "onChange"]] = trackInventory
  },
  {
    comps_rq = [
      ["watchedByPlr"]
    ]
    comps_track = [
      ["human_inventory__maxVolumeInt", ecs.TYPE_INT],
      ["human_inventory__currentVolume", ecs.TYPE_INT],
      ["human_inventory__currentWeight", ecs.TYPE_FLOAT],
      ["human_net_phys__moveSpeedMult", ecs.TYPE_FLOAT]
    ]
  }
)

ecs.register_es("show_suit_slot_ui_es",
  {
    [["onInit", "onChange",]] = function(_eid, comp){ showSuitSlot.set(comp.human_inventory__showSuitSlot) }
    onDestroy = function(_eid, _comp) { showSuitSlot.set(false) }
  },
  {
    comps_rq = [["hero"]]
    comps_track = [["human_inventory__showSuitSlot", ecs.TYPE_BOOL]]
  }
)

ecs.register_es("show_cortical_vault_slot_ui_es",
  {
    [["onInit", "onChange"]] = function(_eid, comp){ showCorticalVaultSlot.set(comp.human_inventory__showCorticalVaultSlot) }
    onDestroy = function(_eid, _comp) { showCorticalVaultSlot.set(false) }
  },
  {
    comps_rq = [["hero"]]
    comps_track = [["human_inventory__showCorticalVaultSlot", ecs.TYPE_BOOL]]
  }
)

ecs.register_es("close_inventory_on_item_start_use_es",
  {
    [EventOnItemStartUse] = function(_evt, _eid, _comps) {
      ecs.g_entity_mgr.broadcastEvent(CmdHideUiMenu({menuName="Inventory"}))
    }
  },
  {
    comps_rq = [
      ["item__closeInventoryOnUsage"]
    ]
  }
)

let slotWithItemOpacity = 1.0
let slotEmptyOpacity = 0.7

function getSlotOpacity(slot){
  let isSlotWithItem = ((slot?.eid ?? ecs.INVALID_ENTITY_ID) != ecs.INVALID_ENTITY_ID) || (slot?.inactiveItem ?? false)
  return isSlotWithItem ? slotWithItemOpacity : slotEmptyOpacity
}

return {
  draggedData = Watched(null, FRP_DONT_CHECK_NESTED)
  focusedData = focusedData
  contextHoveredData
  isShiftPressed
  isCtrlPressed
  isAltPressed
  shiftPressedMonitor
  isCtrlPressedMonitor
  isAltPressedMonitor
  requestData = Watched(null)
  requestItemData = Watched(null)
  doForAllEidsWhenShift
  doForAllUniqueIdsWhenShift
  unremovableSlots
  isWeaponModsForItem
  inventoryMaxVolume
  inventoryCurrentVolume
  inventoryCurrentWeight
  playerMovePenalty
  showSuitSlot
  showCorticalVaultSlot
  getSlotOpacity
  slotWithItemOpacity
  slotEmptyOpacity
}
