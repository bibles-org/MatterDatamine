from "%sqstd/underscore.nut" import deep_clone

from "%ui/hud/menus/components/inventoryItemsListVisibility.nut" import mkScrollHandlerData, resetScrollHandlerDataCommon, updatePanelsVisibilityDataCommon

from "%ui/hud/menus/components/inventoryItem.nut" import inventoryItemPanel, itemShadedBg
from "%ui/components/scrollbar.nut" import makeVertScrollExt, thinAndReservedPaddingStyle
from "%ui/hud/state/inventory_state.nut" import doForAllEidsWhenShift
from "das.inventory" import get_inventory_for_item_by_volume, move_item_from_inventory_to_inventory
from "%ui/hud/menus/components/dropMarkerConstructor.nut" import mkDropMarkerFunc
from "%dngscripts/sound_system.nut" import sound_play
from "dasevents" import CmdItemPickup, sendNetEvent
from "%ui/hud/menus/components/inventoryStyle.nut" import itemHeight
from "%ui/hud/menus/components/inventoryFilter.nut" import filterItemByInventoryFilter
from "%ui/hud/state/inventory_common_es.nut" import didItemDataChange
from "%ui/hud/menus/components/inventoryItemsListChecksCommon.nut" import MoveForbidReason

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
from "math" import min, max
from "dagor.debug" import logerr

let { draggedData } = require("%ui/hud/state/inventory_state.nut")
let { get_controlled_hero } = require("%dngscripts/common_queries.nut")
let { inventoryImageParams } = require("%ui/hud/menus/components/inventoryItemImages.nut")

let itemsListGap = hdpx(5)
let scrollHandlers = memoize(@(_v) ScrollHandler())
let xmbContainers = memoize(@(_v) XmbContainer({
    canFocus = false
    scrollSpeed = 5.0
    isViewport = true
  })
)

let itemsListAnims = [
  { prop=AnimProp.opacity,from=0, to=1, duration=0.3, play=true, easing=OutCubic }
  { prop=AnimProp.opacity,from=1, to=0, duration=0.3, playFadeOut=true, easing=OutCubic }
]


function tryTakeItem(data) {
  let heroEid = get_controlled_hero()
  if (data?.inventoryEid == null || data.inventoryEid == ecs.INVALID_ENTITY_ID) {
    
    doForAllEidsWhenShift(data, @(eid) sendNetEvent(heroEid, CmdItemPickup({item=eid})))
  }
  else {
    
    doForAllEidsWhenShift(data,
      function (eid){
        let inventoryEid = get_inventory_for_item_by_volume(heroEid, eid)
        move_item_from_inventory_to_inventory(eid, inventoryEid)
      })
  }
}

let itemsPanelList = kwarg(function(outScrollHandlerInfo, itemsPanelData, list_type=null, headers=null, can_drop_dragged_cb=null,
  on_item_dropped_to_list_cb=null, item_actions={}, visualParams={}, listVisualParams={}, xSize = 3, ySize = null,
  itemSize=[itemHeight, itemHeight], itemIconParams=inventoryImageParams, dropMarkerConstructor=null,
  on_item_dropped_forbid_cb = null) {

  let onDropItemFunc = function(data) {
    let moveForbidReason = can_drop_dragged_cb?(data)
    if (moveForbidReason == MoveForbidReason.NONE)
      on_item_dropped_to_list_cb?(data, list_type)
    else {
      sound_play("ui_sounds/button_click_inactive")
      on_item_dropped_forbid_cb?(moveForbidReason)
    }
  }
  let stateFlags = Watched(0)
  let hasItems = itemsPanelData.len() > 0
  let isActionForbided = on_item_dropped_to_list_cb == null && (item_actions ?? {}).len() == 0
  local itemsTilesX = []
  let itemsTilesY = []
  let itemsNum = itemsPanelData.len()
  const blankRowsNum = 6
  let blankRowsNumToShow = max(0, (blankRowsNum-itemsNum/xSize).tointeger())
  let blankItemsToShow = max(0, xSize*blankRowsNumToShow-1)
  let verticalSize = ySize == null ? flex()
    : itemHeight * ySize + ySize * itemsListGap - itemsListGap + calc_comp_size(headers)[1] + hdpx(11)
  let opacityStep = 1.0 / max(blankItemsToShow, 1)
  local curOp = 1.0
  function mkItemShadedBg(){
    if (curOp<=0.0)
      return null
    else {
      curOp -= opacityStep
      return itemShadedBg(curOp+opacityStep)
    }
  }

  foreach (item in itemsPanelData) {
    if (itemsTilesX.len() < xSize) {
      mkItemShadedBg()
      itemsTilesX.append(inventoryItemPanel(item, list_type, { tryTake = tryTakeItem }.__update(item_actions),
        itemSize, itemIconParams, isActionForbided ))
    }
    else {
      itemsTilesY.append({
        flow = FLOW_HORIZONTAL
        gap = itemsListGap
        children = clone(itemsTilesX)
      })
      itemsTilesX = [ inventoryItemPanel(item, list_type, { tryTake = tryTakeItem }.__update(item_actions),
        itemSize, itemIconParams, isActionForbided ) ]
    }
  }
  for (local i = itemsTilesX.len(); i < xSize; i++) {
    itemsTilesX.append({ size = itemSize, children = mkItemShadedBg() })
  }
  itemsTilesY.append({
    flow = FLOW_HORIZONTAL
    gap = itemsListGap
    children = itemsTilesX
  })

  let blankRows = array(blankItemsToShow).map(@(_) {
      flow = FLOW_HORIZONTAL
      gap = itemsListGap
      children = array(xSize).map(@(_) {size = itemSize, children = mkItemShadedBg()})
  })

  let emptySlotsY = blankRowsNumToShow > 0 ? {
    size = static [ flex(), 0 ]
    flow = FLOW_VERTICAL
    gap = itemsListGap
    children = blankRows
  } : null

  itemsTilesY.append(emptySlotsY)

  let content = type(headers) == "array" ? headers : [ headers ]
  outScrollHandlerInfo.handler = scrollHandlers(list_type)

  content.append(
    makeVertScrollExt({
      flow = FLOW_VERTICAL
      gap = itemsListGap
      children = itemsTilesY
    },
    {
      scrollHandler = outScrollHandlerInfo.handler
      styling = thinAndReservedPaddingStyle
      size = FLEX_V
    })
  )


  return {
    size = [ SIZE_TO_CONTENT, verticalSize ]
    transform ={}
    xmbNode = xmbContainers(list_type)
    animations = itemsListAnims
    children = [
      {
        behavior = [Behaviors.DragAndDrop]
        canDrop = @(_) true
        onDrop = onDropItemFunc
        onElemState=function(sf) {stateFlags.set(sf)}
        eventPassThrough=true
        size = flex()
      }
      {
        size = FLEX_V
        flow = FLOW_VERTICAL
        padding = static [0, hdpx(10)]
        gap = itemsListGap
        children = content
      }.__update(listVisualParams)
      function() {
        let getDropMarker = dropMarkerConstructor ?? @(sf) mkDropMarkerFunc(sf, can_drop_dragged_cb, draggedData)
        return {
          children = getDropMarker(stateFlags)
          size = flex()
          watch = stateFlags
          skipDirPadNav = true
          behavior = hasItems ? null : Behaviors.DragAndDrop
        }
      }
    ]
  }.__update(visualParams)
})

let weaponTypeScore = {
  assault_rifle = 1
  rifle = 2
  shotgun = 3
  semiauto = 4
  submachine_gun = 5
  pistol = 6
  flamethrower = 7
  melee = 8
}

let equipmentSlotsScore = {
  flashlight = 1
  helmet = 2
  pouch = 3
  backpack = 4
}

let remains = [
  "changed_ear_item",
  "distorted_remains_item",
  "flowerman_eye_item",
  "devourer_remains_item",
  "invisible_remains_item",
  "turned_soldier_remains_item",
  "altered_wax_item",
  "cortical_vault_inactive",
]

function weaponSort(weapA, weapB) {
  return (
    weapA.isWeapon <=> weapB.isWeapon ||
    weaponTypeScore?[weapB.weapType] <=> weaponTypeScore?[weapA.weapType]
  )
}

function equipmentSlotsSort(itemA, itemB) {
  let defaultSlotScore = equipmentSlotsScore.len() + 1
  let minSlotScoreA = itemA?.equipmentSlots.reduce(@(acc, slot) min(acc, equipmentSlotsScore?[slot] ?? defaultSlotScore), defaultSlotScore)
  let minSlotScoreB = itemB?.equipmentSlots.reduce(@(acc, slot) min(acc, equipmentSlotsScore?[slot] ?? defaultSlotScore), defaultSlotScore)
  return (
    itemA.isEquipment <=> itemB.isEquipment ||
    minSlotScoreB <=> minSlotScoreA
  )
}

function enemyRemainsSort(itemA, itemB) {
  let defaultScore = remains.len() + 1
  let scoreA = remains.findindex(@(v) v == itemA.itemTemplate) ?? defaultScore
  let scoreB = remains.findindex(@(v) v == itemB.itemTemplate) ?? defaultScore
  return scoreB <=> scoreA
}

function inventoryItemSorting(itemB, itemA) {
  return (
    (itemA.itemType == "container") <=> (itemB.itemType == "container") ||
    itemA?.isQuestItem <=> itemB?.isQuestItem ||
    weaponSort(itemA, itemB) ||
    (itemA.filterType == "weapon_mods") <=> (itemB.filterType == "weapon_mods") ||
    (itemA.filterType == "ammunition") <=> (itemB.filterType == "ammunition") ||
    
    ((!itemA.isHealkit && (itemA.isAmmo || itemA.isBoxedItem)) <=> (!itemB.isHealkit && (itemB.isAmmo || itemB.isBoxedItem))) ||
    itemA.isHealkit <=> itemB.isHealkit ||
    itemA?.isReplica <=> itemB?.isReplica ||
    equipmentSlotsSort(itemA, itemB) ||
    itemA?.ui_order <=> itemB?.ui_order || 
    itemA.inventoryExtension <=> itemB.inventoryExtension || 
    itemA.inventoryMaxVolume <=> itemB.inventoryMaxVolume || 
    itemA.protectionMinHpKoef <=> itemB.protectionMinHpKoef || 
    (itemA.itemType == "grenade") <=> (itemB.itemType == "grenade") ||
    (itemA.filterType == "keys") <=> (itemB.filterType == "keys") ||
    enemyRemainsSort(itemA, itemB) ||
    itemA.maxCharges <=> itemB.maxCharges ||
    itemA.charges <=> itemB.charges ||
    (itemB?.countKnown ?? true) <=> (itemA?.countKnown ?? true) ||
    !(itemA.isDelayedMoveMod) <=> !(itemB.isDelayedMoveMod) ||
    itemA.isCorrupted <=> itemB.isCorrupted ||
    itemA.itemTemplate <=> itemB.itemTemplate ||
    itemA?.itemStorage <=> itemB?.itemStorage
  )
}

function inventoryItemOverridePrioritySorting(itemA, itemB) {
  return (
    (itemB?.sortingPriority ?? -1) <=> (itemA?.sortingPriority ?? -1) ||
    itemB.eid <=> itemA.eid
  )
}

function filterItems(item) {
  if (
      item.filterType == "alters" ||
      item.filterType == "chronogene" ||
      item.filterType == "dogtag_chronogene" ||
      item.filterType == "stub_melee_weapon"
    ) {
      return false
    }

  return filterItemByInventoryFilter(item)
}

function updatePanelsDataCommon(itemsPanelData,
                                numberOfPanelsWatched,
                                items,
                                itemsInRow) {
  
  
  let oldSize = itemsPanelData.len()
  let sparePanelsNum = ((items.len() % itemsInRow) == 0) ? 0 : (itemsInRow - (items.len() % itemsInRow))
  let numPanels = items.len() + sparePanelsNum
  itemsPanelData.resize(numPanels)

  
  for (local i = oldSize; i < itemsPanelData.len(); i++) {
    itemsPanelData[i] = {
      itemData = null
      itemDataGeneration = Watched(0)
      isVisible = Watched(false)
    }
  }

  
  for (local i = items.len(); i < itemsPanelData.len(); i++){
    itemsPanelData[i].itemData = null
    itemsPanelData[i].itemDataGeneration.modify(@(v) v + 1)
  }

  
  for (local i = 0; i < items.len(); i++) {
    let panelData = itemsPanelData[i].itemData
    if (didItemDataChange(panelData, items[i])) {
      
      if (items[i]?.dataChanged)
        items[i].dataChanged = false

      
      
      itemsPanelData[i].itemData = clone(items[i])
      if (itemsPanelData[i].isVisible.get())
        itemsPanelData[i].itemDataGeneration.modify(@(v) v + 1)
    }
  }

  
  numberOfPanelsWatched.set(numPanels)
}

let visibilityUpdateFrequency = 1.0/15.0

let setupPanelsData = function(itemsList,
                               itemsInRow,
                               updateDataOn,
                               processItemsCb) {
  let getItemsList = itemsList instanceof Watched ? ( @() itemsList.get() ) : itemsList
  let itemsPanelData = []
  let numberOfPanels = Watched(0)
  let scrollHandlerData = mkScrollHandlerData()
  let isElementShown = Watched(false)
  let res = {
    itemsPanelData
    numberOfPanels
    scrollHandlerData
    isElementShown
    elementAttachCounter = 0
  }

  let resetScrollHandlerData = @() resetScrollHandlerDataCommon(scrollHandlerData)

  let updateItemsPanelData = function() {
    updatePanelsDataCommon(itemsPanelData,
                           numberOfPanels,
                           processItemsCb(getItemsList()),
                           itemsInRow)
  }

  let updatePanelsVisibilityData = function() {
    updatePanelsVisibilityDataCommon(scrollHandlerData,
                                     numberOfPanels,
                                     itemsPanelData,
                                     itemsInRow)
  }

  let updateData = function(_) {
    if (!isElementShown.get()) {
      return
    }

    updateItemsPanelData()
  }

  let onAttach = function() {
    if (res.elementAttachCounter == 0) {
      gui_scene.setInterval(visibilityUpdateFrequency, updatePanelsVisibilityData, res)
      updatePanelsVisibilityData()
      isElementShown.set(true)
    }

    res.elementAttachCounter += 1
    foreach (watched in updateDataOn) {
      watched.subscribe_with_nasty_disregard_of_frp_update(updateData)
    }
    isElementShown.subscribe_with_nasty_disregard_of_frp_update(updateData)
  }

  let onDetach = function() {
    res.elementAttachCounter -= 1
    if (res.elementAttachCounter == 0) {
      isElementShown.set(false)
      gui_scene.clearTimer(res)
      foreach (watched in updateDataOn) {
        watched.unsubscribe(updateData)
      }
      isElementShown.unsubscribe(updateData)
    }
  }

  return res.__update({
    updateItemsPanelData,
    updatePanelsVisibilityData,
    resetScrollHandlerData,
    onAttach,
    onDetach
  })
}

return {
  itemsPanelList
  inventoryItemSorting
  inventoryItemOverridePrioritySorting
  updatePanelsDataCommon
  setupPanelsData
  filterItems
}