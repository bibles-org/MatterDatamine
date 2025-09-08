import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


let {itemsAround} = require("%ui/hud/state/inventory_items_es.nut")
let { itemsPanelList, setupPanelsData, inventoryItemSorting } = require("%ui/hud/menus/components/inventoryItemsList.nut")
let {GROUND} = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let {mkInventoryHeader} = require("%ui/hud/menus/components/inventoryCommon.nut")
let {moveModAroundInfo} = require("%ui/hud/state/move_mod_state.nut")
let { isItemCanBeDroppedOnGround } = require("%ui/hud/menus/components/inventoryItemsListChecks.nut")
let { volumeHdrHeight } = require("%ui/hud/menus/components/inventoryVolumeWidget.nut")

function patchItem(item) {
  return item == null ? null : item.__merge({canDrop = false, canTake = true})
}

const itemsInRow = 3
let processItems = function(items) {
  items = items.map(patchItem)
  if (moveModAroundInfo.get()?.eid != null)
    items.append(moveModAroundInfo.get())

  items.sort(inventoryItemSorting)
  return items
}

let panelsData = setupPanelsData(itemsAround,
                                 itemsInRow,
                                 [itemsAround, moveModAroundInfo],
                                 processItems)

function mkGroundItemsList(on_item_dropped_to_list_cb, on_click_actions, params = {}) {
  let { xSize = 3 } = params
  return function() {
    panelsData.resetScrollHandlerData()
    let children = itemsPanelList({
      outScrollHandlerInfo=panelsData.scrollHandlerData,
      list_type=GROUND,
      itemsPanelData=panelsData.itemsPanelData,
      headers=mkInventoryHeader(loc("inventory/itemsNearby"), { size = [0, volumeHdrHeight] }),
      can_drop_dragged_cb=isItemCanBeDroppedOnGround,
      on_item_dropped_to_list_cb=on_item_dropped_to_list_cb,
      item_actions=on_click_actions
      xSize
    })

    return {
      size = [ SIZE_TO_CONTENT, flex() ]
      watch = [panelsData.numberOfPanels]
      children
      onAttach = panelsData.onAttach
      onDetach = panelsData.onDetach
    }
  }
}

return {
  isItemCanBeDroppedOnGround
  mkGroundItemsList
}