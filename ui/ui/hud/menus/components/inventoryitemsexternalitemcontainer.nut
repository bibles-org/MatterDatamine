from "%sqstd/string.nut" import utf8ToLower
from "%ui/fonts_style.nut" import tiny_txt
from "%ui/components/colors.nut" import TextNormal, BtnBgDisabled, BtnBgNormal
from "%ui/hud/menus/components/inventoryItemsList.nut" import itemsPanelList, setupPanelsData, inventoryItemSorting, inventoryItemOverridePrioritySorting

from "%ui/hud/menus/components/inventoryCommon.nut" import mkInventoryHeader
from "%ui/hud/menus/components/inventoryItemUtils.nut" import mergeNonUniqueItems
from "%ui/hud/menus/components/inventoryVolumeWidget.nut" import mkVolumeHdr
from "%ui/hud/menus/components/inventoryItemsListChecks.nut" import isExternalInventoryDropForbidden
from "%ui/components/button.nut" import button
from "%ui/components/commonComponents.nut" import mkText, mkMonospaceTimeComp
from "%ui/components/colors.nut" import TextNormal, BtnBgDisabled, BtnBgNormal, BtnBgActive
from "dasevents" import CmdCloseExternalInventoryRequest, sendNetEvent, CmdDropAllItemsFromInventory
from "%ui/state/allItems.nut" import stashEid
from "%ui/hud/state/entity_use_state.nut" import entityUseEnd, entityToUse, calcItemUseProgress
from "%ui/hud/state/gametype_state.nut" import isOnPlayerBase
from "%ui/hud/state/time_state.nut" import curTime

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { externalInventoryName, externalInventoryQuestName, externalInventoryItems, externalInventoryItemsMergeEnabled,
      externalInventoryItemsSortingEnabled, externalInventoryItemsOverrideSortingPriority, externalInventoryCurrentVolume,
      externalInventoryMaxVolume, externalInventoryEid, externalInventoryContainerOwnerEid, externalInventoryIsEquipment } = require("%ui/hud/state/hero_external_inventory_state.nut")
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

let dropIcon = {
  size = [hdpxi(14), hdpxi(14)]
  rendObj = ROBJ_IMAGE
  color = TextNormal
  hplace = ALIGN_CENTER
  image = Picture("ui/skin#context_icons/drop_out_1.svg:{0}:{0}:P".subst(hdpxi(14)))
}

function mkDropAllButton() {
  let hasItems = Computed(@() externalInventoryItems.get().len() > 0)
  let hasProgression = Computed(@() !isOnPlayerBase.get() && entityToUse.get() == externalInventoryEid.get())
  function mkProgressLine(isInProgress) {
    if (!isInProgress)
      return null
    let timeLeft = Computed(@() entityUseEnd.get() - curTime.get())
    let progressProportion = Computed(@() calcItemUseProgress(curTime.get()))
    return function() {
      if (timeLeft.get() <= 0)
        return { watch = timeLeft }
      return {
        watch = timeLeft
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
                  dropIcon
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
  let vertPadding = hdpx(4)
  return function() {
    let hintText = hasProgression.get() ? loc("action/interrupt")
      : hasItems.get() ? loc("item/action/dropFromBackpack")
      : loc("item/action/nothingDropFromBackpack")

    if (!externalInventoryIsEquipment.get())
      return { watch = externalInventoryIsEquipment }

    return {
      watch = [hasItems, hasProgression, externalInventoryIsEquipment]
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
                dropIcon
                mkText(loc("item/action/dropFromContainer"), { color = TextNormal }.__merge(tiny_txt))
              ]
            }
            mkProgressLine(hasProgression.get())
          ]
        },
        function dropAllFromContainer() {
          if (!hasItems.get())
            return
          sendNetEvent(controlledHeroEid.get(),
            CmdDropAllItemsFromInventory({fromInventoryEid = externalInventoryEid.get(), toInventoryEid = stashEid.get()}))
        },
        {
          size = [flex(), hdpx(14) + vertPadding * 2]
          margin = static [0, 0, hdpx(5), 0]
          tooltipText = hintText
          style = { BtnBgNormal = hasItems.get() ? BtnBgNormal : BtnBgDisabled }
        })
    }
  }
}

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
        externalInventoryContainerOwnerEid.get() != ecs.INVALID_ENTITY_ID && externalInventoryContainerOwnerEid.get() != null
          ? button(
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
            )
          : mkDropAllButton()
      ]
    }
  }
}

return {
  mkExternalItemContainerItemsList
}