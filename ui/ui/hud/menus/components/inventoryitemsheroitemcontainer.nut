from "%ui/fonts_style.nut" import tiny_txt, sub_txt
from "%ui/hud/menus/components/inventoryItemsList.nut" import itemsPanelList, setupPanelsData, inventoryItemSorting

from "%ui/hud/menus/components/inventoryItemUtils.nut" import mergeNonUniqueItems
from "%ui/hud/menus/components/inventoryCommon.nut" import mkInventoryHeader
from "%ui/hud/menus/components/inventoryVolumeWidget.nut" import mkVolumeHdr
from "%ui/hud/menus/components/inventoryItemsListChecks.nut" import isHeroInventoryDropForbidden
from "%ui/hud/menus/inventories/refinerInventory.nut" import considerRefineItems
from "%ui/components/button.nut" import button
from "dasevents" import sendNetEvent, CmdDropAllItemsFromInventory
from "%ui/components/commonComponents.nut" import mkText, mkMonospaceTimeComp
from "%ui/components/colors.nut" import TextNormal, BtnBgDisabled, BtnBgNormal, BtnBgActive
from "%ui/state/appState.nut" import isInBattleState
from "%ui/state/allItems.nut" import stashEid
from "%ui/hud/state/gametype_state.nut" import isOnPlayerBase
from "%ui/hud/state/inventory_state.nut" import mutationForbidenDueToInQueueState
from "%ui/squad/squadState.nut" import selfMemberState
from "%ui/popup/player_event_log.nut" import addPlayerLog, mkPlayerLog, playerLogsColors
from "%ui/hud/state/entity_use_state.nut" import entityUseEnd, entityToUse, calcItemUseProgress
from "%ui/hud/state/time_state.nut" import curTime

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


let { inventoryItems, inventoryItemsSortingEnabled } = require("%ui/hud/state/inventory_items_es.nut")
let { HERO_ITEM_CONTAINER } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { carriedVolume, maxVolume } = require("%ui/hud/state/inventory_common_es.nut")
let { itemsInRefiner } = require("%ui/hud/menus/inventories/refinerInventoryCommon.nut")
let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")

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

let mkDropIcon = @(iconSize) {
  size = [iconSize, iconSize]
  rendObj = ROBJ_IMAGE
  color = TextNormal
  hplace = ALIGN_CENTER
  image = Picture("ui/skin#context_icons/drop_out_1.svg:{0}:{0}:P".subst(iconSize))
}

function mkDropAllButton() {
  let hasItems = Computed(@() inventoryItems.get().len() > 0)
  let hasProgression = Computed(@() !isOnPlayerBase.get() && entityToUse.get() == controlledHeroEid.get())
  function mkProgressLine(isInProgress) {
    if (!isInProgress)
      return null
    let timeLeft = Computed(@() entityUseEnd.get() - curTime.get())
    let progressProportion = Computed(@() calcItemUseProgress(curTime.get()))
    return function() {
      if (entityToUse.get() != controlledHeroEid.get())
        return { watch = [entityToUse, controlledHeroEid] }
      if (timeLeft.get() <= 0)
        return { watch = [entityToUse, controlledHeroEid, timeLeft] }
      return {
        watch = [entityToUse, controlledHeroEid, timeLeft]
        size = flex()
        padding = hdpx(1)
        children = [
          @() {
            watch = progressProportion
            rendObj = ROBJ_SOLID
            size = [pw(progressProportion.get()), flex()]
            color = BtnBgActive
          }
          {
            size = FLEX_H
            padding = [0, hdpx(4)]
            vplace = ALIGN_CENTER
            halign = ALIGN_RIGHT
            valign = ALIGN_CENTER
            children = [
              {
                flow = FLOW_HORIZONTAL
                gap = hdpx(4)
                hplace = ALIGN_CENTER
                valign = ALIGN_CENTER
                children = [
                  mkDropIcon(hdpxi(14))
                  mkText(loc("action/interrupt"), tiny_txt)
                ]
              }
              mkMonospaceTimeComp(timeLeft.get(), tiny_txt)
            ]
          }
        ]
      }
    }
  }

  return function() {
    let iconSize = isInBattleState.get() ? hdpxi(14) : hdpxi(16)
    let textStyle = isInBattleState.get() ? tiny_txt : sub_txt
    let vertPadding = isInBattleState.get() ? hdpx(4) : hdpx(10)
    let hintText = hasProgression.get() ? loc("action/interrupt")
      : selfMemberState.get()?.ready ? loc("inventory/cannotPutToContainerDuringReady")
      : mutationForbidenDueToInQueueState.get() ? loc("inventory/cannotPutToContainerDuringSearch")
      : hasItems.get() ? loc("item/action/dropFromPouch")
      : loc("item/action/nothingDropFromPouch")
    return {
      watch = [hasItems, isInBattleState, mutationForbidenDueToInQueueState, selfMemberState, hasProgression]
      size = FLEX_H
      children = button(
        {
          size = flex()
          valign = ALIGN_CENTER
          children = [
            hasProgression.get() ? null : {
              size = FLEX_H
              flow = FLOW_HORIZONTAL
              gap = hdpx(4)
              valign = ALIGN_CENTER
              halign = ALIGN_CENTER
              padding = [vertPadding, hdpx(4)]
              children = [
                mkDropIcon(iconSize)
                mkText(loc("item/action/dropFromContainer"), { color = TextNormal }.__merge(textStyle))
              ]
            }
            mkProgressLine(hasProgression.get())
          ]
        },
        function dropAllFromContainer() {
          if (!hasItems.get() || mutationForbidenDueToInQueueState.get()) {
            addPlayerLog({
              id = "dropAllFromPouch"
              idToIgnore = "dropAllFromPouch"
              content = mkPlayerLog({
                titleText = loc("pieMenu/actionUnavailable")
                titleFaIcon = "close"
                bodyText = hintText
                logColor = playerLogsColors.warningLog
              })
            })
            return
          }
          sendNetEvent(controlledHeroEid.get(), CmdDropAllItemsFromInventory({fromInventoryEid = controlledHeroEid.get(), toInventoryEid = stashEid.get()}))
        },
        {
          size = [flex(), iconSize + vertPadding * 2]
          margin = static [0, 0, hdpx(5), 0]
          tooltipText = hintText
          style = { BtnBgNormal = hasItems.get() && !mutationForbidenDueToInQueueState.get() && !selfMemberState.get()?.ready
            ? BtnBgNormal : BtnBgDisabled }
        })
    }
  }
}


function mkHeroItemContainerItemsList(on_item_dropped_to_list_cb = null, on_click_actions = {}) {
  return function() {
    panelsData.resetScrollHandlerData()
    let content = itemsPanelList({
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
      flow = FLOW_VERTICAL
      gap = hdpx(4)
      children = [
        content
        mkDropAllButton()
      ]
      key = $"pouch{panelsData.numberOfPanels.get()};{panelsData.isElementShown.get()}"
      onAttach = panelsData.onAttach
      onDetach = panelsData.onDetach
    }
  }
}

return {
  mkHeroItemContainerItemsList
  isHeroInventoryDropForbidden
}