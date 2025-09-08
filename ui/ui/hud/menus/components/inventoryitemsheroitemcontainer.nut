import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


let {inventoryItems, inventoryItemsSortingEnabled} = require("%ui/hud/state/inventory_items_es.nut")
let { itemsPanelList, setupPanelsData, inventoryItemSorting, considerTrashBinItems
} = require("%ui/hud/menus/components/inventoryItemsList.nut")
let { mergeNonUniqueItems } = require("%ui/hud/menus/components/inventoryItemUtils.nut")
let {mkInventoryHeader} = require("%ui/hud/menus/components/inventoryCommon.nut")
let {HERO_ITEM_CONTAINER} = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let {carriedVolume, maxVolume} = require("%ui/hud/state/inventory_common_es.nut")
let {mkVolumeHdr} = require("%ui/hud/menus/components/inventoryVolumeWidget.nut")
let { trashBinItems } = require("%ui/hud/menus/components/trashBin.nut")
let { isHeroInventoryDropForbidden } = require("%ui/hud/menus/components/inventoryItemsListChecks.nut")

const itemsInRow = 3
let processItems = function(items) {
  items = mergeNonUniqueItems(items)
  items = considerTrashBinItems(items)
  if (inventoryItemsSortingEnabled.get())
    items.sort(inventoryItemSorting)
  return items
}

let panelsData = setupPanelsData(inventoryItems,
                                 itemsInRow,
                                 [inventoryItems, trashBinItems, inventoryItemsSortingEnabled],
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
      size = [ SIZE_TO_CONTENT, flex() ]
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