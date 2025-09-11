from "%sqstd/timers.nut" import throttle

from "%ui/hud/state/item_info.nut" import get_nearby_item_info
from "%ui/hud/menus/components/inventoryItemsList.nut" import itemsPanelList, setupPanelsData, inventoryItemSorting
from "%ui/hud/menus/components/inventoryCommon.nut" import mkInventoryHeader
from "%ui/hud/menus/components/inventoryItemsListChecks.nut" import isItemCanBeDroppedOnGround
from "%ui/hud/menus/components/inventoryVolumeWidget.nut" import volumeHdrHeight

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")
let { GROUND } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { moveModAroundInfo } = require("%ui/hud/state/move_mod_state.nut")

let itemsAround = Watched([])
const rebuildItemsAroundTime = 0.15
local doCheckItemsAround = false

function mkTrackItemsAround() {
  local _itemsAround = []
  let _get_items_around = throttle(@() itemsAround.set(_itemsAround.map(function(v) {
    let res = get_nearby_item_info(v)
    if (res == null || !res.isPickable)
      throw null
    return res
  })), rebuildItemsAroundTime, static {leading=false, trailing=true})
  return function(_eid, comp){
    if (!doCheckItemsAround) {
      itemsAround.set(static [])
      return
    }
    _itemsAround = comp["itemsAround"].getAll()
    _get_items_around()
  }
}

ecs.register_es("hud_state_track_items_around_ui_es", {
  [["onInit","onChange"]] = mkTrackItemsAround()
  onDestroy = function(_eid, _comp) {
    itemsAround.set(static [])
  }
}, { comps_track = [["itemsAround", ecs.TYPE_EID_LIST]], comps_rq = ["watchedByPlr"]})

let updateItemsAroundQuery = ecs.SqQuery("update_items_around_Query", {
  comps_rq=["watchedByPlr"]
  comps_ro=[
    ["itemsAround", ecs.TYPE_EID_LIST]
  ]
})

let updateItemsAround = @() updateItemsAroundQuery.perform(watchedHeroEid.get(), mkTrackItemsAround())

ecs.register_es("update_items_around_item_change_es",
  {
    onChange = function(eid, comp) {
      if (itemsAround.get().findindex(@(v) v.eid == eid) != null) {
        if (comp?.itemContainer == null || comp.itemContainer.len() <= 1)
          updateItemsAround()
      }
    }
  },
  {
    comps_rq = ["traceVisibility", "item_in_world"] 
    comps_track = [["itemContainer", ecs.TYPE_EID_LIST, null],
                   ["item__currentBoxedItemCount", ecs.TYPE_INT, null],
                   ["ammo_holder__ammoCountKnown", ecs.TYPE_EID_LIST, null]]
  }
)

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

let {onAttach, onDetach, itemsPanelData, scrollHandlerData, numberOfPanels, resetScrollHandlerData} = setupPanelsData(itemsAround,
                                 itemsInRow,
                                 [itemsAround, moveModAroundInfo],
                                 processItems)

function mkGroundItemsList(on_item_dropped_to_list_cb, on_click_actions, params = {}) {
  let { xSize = 3 } = params
  return function() {
    resetScrollHandlerData()
    let children = itemsPanelList({
      outScrollHandlerInfo = scrollHandlerData,
      list_type = GROUND,
      itemsPanelData,
      headers = static mkInventoryHeader(loc("inventory/itemsNearby"), { size = [0, volumeHdrHeight] }),
      can_drop_dragged_cb = isItemCanBeDroppedOnGround,
      on_item_dropped_to_list_cb,
      item_actions = on_click_actions
      xSize
    })

    return {
      size = FLEX_V
      watch = numberOfPanels
      children
      onAttach = function(){
        doCheckItemsAround = true
        updateItemsAround()
        onAttach()
      }
      onDetach = function() {
        doCheckItemsAround = false
        onDetach()
      }
    }
  }
}

return {
  isItemCanBeDroppedOnGround
  mkGroundItemsList
}