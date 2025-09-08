import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let {mkInventoryHeader} = require("%ui/hud/menus/components/inventoryCommon.nut")
let { backpackItemsMergeEnabled, backpackCurrentVolume, backpackMaxVolume,
    backpackItemsSortingEnabled, backpackItemsOverrideSortingPriority, safepackMaxVolume,
    safepackCurrentVolume, safepackYVisualSize } = require("%ui/hud/state/hero_extra_inventories_state.nut")
let {backpackItems, safepackItems} = require("%ui/hud/state/inventory_items_es.nut")
let {itemsPanelList, setupPanelsData, inventoryItemSorting, considerTrashBinItems,
  inventoryItemOverridePrioritySorting} = require("%ui/hud/menus/components/inventoryItemsList.nut")
let { mergeNonUniqueItems } = require("%ui/hud/menus/components/inventoryItemUtils.nut")
let { BACKPACK0, SAFEPACK } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { mkVolumeHdr } = require("%ui/hud/menus/components/inventoryVolumeWidget.nut")
let { trashBinItems } = require("%ui/hud/menus/components/trashBin.nut")
let { isBackpackDropForbidder, isSafepackDropForbidder } = require("%ui/hud/menus/components/inventoryItemsListChecks.nut")


function patchItem(item) {
  return item == null ? null : item.__merge({inBackpack = true, canTake = true})
}

const itemsInRow = 3
let processItems = function(items) {
  if (backpackItemsMergeEnabled.get())
    items = mergeNonUniqueItems(items)

  items = items.map(patchItem)
  items = considerTrashBinItems(items)

  if (backpackItemsSortingEnabled.get()) {
    if (backpackItemsOverrideSortingPriority.get())
      items.sort(inventoryItemOverridePrioritySorting)
    else
      items.sort(inventoryItemSorting)
  }
  return items
}

let backpackPanelsData = setupPanelsData(backpackItems,
                                         itemsInRow,
                                         [backpackItems, trashBinItems, backpackItemsMergeEnabled, backpackItemsSortingEnabled],
                                         processItems)

let safepackPanelsData = setupPanelsData(safepackItems,
                                         itemsInRow,
                                         [safepackItems, trashBinItems, backpackItemsMergeEnabled, backpackItemsSortingEnabled],
                                         processItems)

function mkHeroBackpackItemContainerItemsList(on_item_dropped_to_list_cb = null, on_click_actions = {}) {
  return function() {
    backpackPanelsData.resetScrollHandlerData()
    let children = itemsPanelList({
      outScrollHandlerInfo=backpackPanelsData.scrollHandlerData,
      list_type=BACKPACK0,
      itemsPanelData=backpackPanelsData.itemsPanelData,
      headers=mkInventoryHeader(
        loc("inventory/backpack"),
        mkVolumeHdr(backpackCurrentVolume, backpackMaxVolume, BACKPACK0.name)
      )
      can_drop_dragged_cb=isBackpackDropForbidder,
      on_item_dropped_to_list_cb=on_item_dropped_to_list_cb,
      item_actions=on_click_actions
    })

    return {
      key = $"backpack{backpackPanelsData.numberOfPanels.get()};{backpackPanelsData.isElementShown.get()}"
      size = [ SIZE_TO_CONTENT, flex() ]
      children
      watch = [backpackPanelsData.numberOfPanels]
      onAttach = backpackPanelsData.onAttach
      onDetach = backpackPanelsData.onDetach
    }
  }
}

let mkHeroSafepackItemContainerItemsList = @(on_item_dropped_to_list_cb = null, on_click_actions = {}) function() {
  safepackPanelsData.resetScrollHandlerData()
  let children = itemsPanelList({
    outScrollHandlerInfo=safepackPanelsData.scrollHandlerData,
    list_type=SAFEPACK,
    itemsPanelData=safepackPanelsData.itemsPanelData,
    headers=mkInventoryHeader(
      loc("inventory/safepack"),
      mkVolumeHdr(safepackCurrentVolume, safepackMaxVolume, SAFEPACK.name)
    )
    can_drop_dragged_cb=isSafepackDropForbidder,
    on_item_dropped_to_list_cb=on_item_dropped_to_list_cb,
    item_actions=on_click_actions
    ySize = safepackYVisualSize.get()
  })
  return {
    watch = [safepackPanelsData.numberOfPanels, safepackYVisualSize]
    key = $"safepack{safepackPanelsData.numberOfPanels.get()};{safepackPanelsData.isElementShown.get()}"
    onAttach = safepackPanelsData.onAttach
    onDetach = safepackPanelsData.onDetach
    children
  }
}

return {
  mkHeroBackpackItemContainerItemsList
  mkHeroSafepackItemContainerItemsList
}