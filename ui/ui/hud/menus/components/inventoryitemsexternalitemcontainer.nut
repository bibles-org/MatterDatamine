from "%sqstd/string.nut" import utf8ToLower

from "%ui/hud/menus/components/inventoryItemsList.nut" import itemsPanelList, setupPanelsData, inventoryItemSorting, inventoryItemOverridePrioritySorting

from "%ui/hud/menus/components/inventoryCommon.nut" import mkInventoryHeader
from "%ui/hud/menus/components/inventoryItemUtils.nut" import mergeNonUniqueItems
from "%ui/hud/menus/components/inventoryVolumeWidget.nut" import mkVolumeHdr
from "%ui/hud/menus/components/inventoryItemsListChecks.nut" import isExternalInventoryDropForbidden
from "%ui/components/button.nut" import button
from "%ui/components/commonComponents.nut" import mkText
from "dasevents" import CmdCloseExternalInventoryRequest, sendNetEvent

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { externalInventoryName, externalInventoryQuestName, externalInventoryItems, externalInventoryItemsMergeEnabled,
      externalInventoryItemsSortingEnabled, externalInventoryItemsOverrideSortingPriority, externalInventoryCurrentVolume,
      externalInventoryMaxVolume, externalInventoryEid, externalInventoryContainerOwnerEid } = require("%ui/hud/state/hero_external_inventory_state.nut")
let { EXTERNAL_ITEM_CONTAINER } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")

function patchItem(item) {
  return item == null ? null : item.__merge({inExternalItemContainer = true, canTake = true})
}

const itemsInRow = 3
let processItems = function(items) {
  if (externalInventoryItemsMergeEnabled.get())
    items = mergeNonUniqueItems(items)

  items = items.map(patchItem)
  if (externalInventoryItemsSortingEnabled.get()) {
    if (externalInventoryItemsOverrideSortingPriority.get())
      items.sort(inventoryItemOverridePrioritySorting)
    else
      items.sort(inventoryItemSorting)
  }
  return items
}

function getExternalContainerLoc(inventoryName, questInventoryName){
  let containerOwnName = loc(inventoryName ?? "inventory/externalItemContainer")
  let questName = questInventoryName
  if (questName != "" && questName != null){
    return loc(questName, {containerName = containerOwnName})
  }
  return containerOwnName
}

let panelsData = setupPanelsData(externalInventoryItems,
                                 itemsInRow,
                                 [externalInventoryItems, externalInventoryItemsMergeEnabled, externalInventoryItemsSortingEnabled, externalInventoryItemsOverrideSortingPriority],
                                 processItems)

function mkExternalItemContainerItemsList(on_item_dropped_to_list_cb, on_click_actions, params = {}) {
  let { xSize = 3 } = params
  return function() {
    panelsData.resetScrollHandlerData()
    let children = itemsPanelList({
      outScrollHandlerInfo=panelsData.scrollHandlerData,
      list_type=EXTERNAL_ITEM_CONTAINER,
      itemsPanelData=panelsData.itemsPanelData,
      headers= @() {
        watch = [externalInventoryName, externalInventoryQuestName]
        size = FLEX_H
        children = mkInventoryHeader(
          getExternalContainerLoc(externalInventoryName.get(), externalInventoryQuestName.get()),
          mkVolumeHdr(externalInventoryCurrentVolume, externalInventoryMaxVolume, EXTERNAL_ITEM_CONTAINER.name)
        )
      }
      can_drop_dragged_cb=isExternalInventoryDropForbidden,
      on_item_dropped_to_list_cb=on_item_dropped_to_list_cb,
      item_actions=on_click_actions
      xSize
    })

    return {
      watch = [externalInventoryName, panelsData.numberOfPanels, externalInventoryContainerOwnerEid]
      size = FLEX_V
      flow = FLOW_VERTICAL
      gap = hdpx(4)
      onAttach = panelsData.onAttach
      onDetach = panelsData.onDetach
      children = [
        children
        externalInventoryContainerOwnerEid.get() != ecs.INVALID_ENTITY_ID ? button(
          {
            size = FLEX_H
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            children = mkText($"{loc("mainmenu/btnClose")} { utf8ToLower(loc(externalInventoryName.get() ?? "inventory/externalItemContainer")) }")
          },
          @() sendNetEvent(controlledHeroEid.get(), CmdCloseExternalInventoryRequest({ inventoryEid = externalInventoryEid.get() })),
          {
            size = static [flex(), hdpx(40)]
          }
        ) : null
      ]
    }
  }
}

return {
  mkExternalItemContainerItemsList
}