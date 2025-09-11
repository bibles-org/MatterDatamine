from "%ui/hud/menus/components/inventoryItemsList.nut" import itemsPanelList, setupPanelsData, inventoryItemSorting

from "%ui/hud/menus/components/inventoryItemUtils.nut" import mergeNonUniqueItems
from "%ui/hud/menus/components/inventoryCommon.nut" import mkInventoryHeader
from "%ui/hud/menus/components/inventoryVolumeWidget.nut" import mkVolumeHdr
from "%ui/hud/menus/components/inventoryItemsListChecks.nut" import isHeroInventoryDropForbidden
from "%ui/hud/menus/inventories/refinerInventory.nut" import considerRefineItems

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


let { inventoryItems, inventoryItemsSortingEnabled } = require("%ui/hud/state/inventory_items_es.nut")
let { HERO_ITEM_CONTAINER } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { carriedVolume, maxVolume } = require("%ui/hud/state/inventory_common_es.nut")
let { itemsInRefiner } = require("%ui/hud/menus/inventories/refinerInventoryCommon.nut")

const itemsInRow = 3
let processItems = function(items) {
  items = considerRefineItems(items)
  items = mergeNonUniqueItems(items)
  if (inventoryItemsSortingEnabled.get())
    items.sort(inventoryItemSorting)
  return items
}

let panelsData = setupPanelsData(inventoryItems,
                                 itemsInRow,
                                 [inventoryItems, itemsInRefiner, inventoryItemsSortingEnabled],
                                 processItems)


function mkHeroItemContainerItemsList(on_item_dropped_to_list_cb = null, on_click_actions = {}) {
  return function() {
    panelsData.resetScrollHandlerData()
    let children = itemsPanelList({
      outScrollHandlerInfo=panelsData.scrollHandlerData,
      list_type=HERO_ITEM_CONTAINER,
      itemsPanelData=panelsData.itemsPanelData,
      headers=mkInventoryHeader(
        loc("inventory/myItems"),
        mkVolumeHdr(carriedVolume, maxVolume, HERO_ITEM_CONTAINER.name)
      )
      can_drop_dragged_cb=isHeroInventoryDropForbidden,
      on_item_dropped_to_list_cb=on_item_dropped_to_list_cb,
      item_actions=on_click_actions
    })
    return {
      size = FLEX_V
      watch = panelsData.numberOfPanels
      children
      onAttach = panelsData.onAttach
      onDetach = panelsData.onDetach
    }
  }
}

return {
  mkHeroItemContainerItemsList
  isHeroInventoryDropForbidden
}