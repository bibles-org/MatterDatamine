from "%ui/hud/menus/components/inventoryItemsList.nut" import itemsPanelList, setupPanelsData, filterItems, inventoryItemSorting
from "eventbus" import eventbus_send
from "%ui/hud/menus/components/inventoryItemUtils.nut" import mergeNonUniqueItems
from "%ui/hud/menus/components/inventoryCommon.nut" import mkInventoryHeader
from "%ui/hud/menus/components/inventoryVolumeWidget.nut" import mkVolumeHdr
from "%ui/hud/menus/components/inventoryItemsListChecks.nut" import isItemCanBeDroppedInStash
from "%ui/components/cursors.nut" import setTooltip
import "%ui/components/faComp.nut" as faComp
from "%ui/components/msgbox.nut" import showMsgbox
from "%ui/components/button.nut" import button
from "%ui/components/colors.nut" import BtnTextNormal, TextNormal, GreenSuccessColor, BtnBgDisabled, BtnBdDisabled
from "%ui/components/commonComponents.nut" import mkText
from "%ui/hud/hud_menus_state.nut" import openMenu
from "%sqstd/string.nut" import startsWith
from "%ui/hud/menus/components/inventoryItemsListChecksCommon.nut" import MoveForbidReason
from "%ui/hud/menus/inventories/refinerInventory.nut" import considerRefineItems

from "%ui/ui_library.nut" import *


let { stashItems } = require("%ui/hud/state/inventory_items_es.nut")
let { STASH } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { stashVolume, stashMaxVolume } = require("%ui/state/allItems.nut")
let { activeFilters } = require("%ui/hud/menus/components/inventoryStashFiltersWidget.nut")
let { MonolithMenuId, monolithSelectedLevel, monolithSectionToReturn, selectedMonolithUnlock, currentTab
} = require("%ui/mainMenu/monolith/monolith_common.nut")
let { marketItems, playerStats, playerBaseState } = require("%ui/profile/profileState.nut")
let { itemsInRefiner } = require("%ui/hud/menus/inventories/refinerInventoryCommon.nut")

let extendIconHeigh = static hdpxi(24)

function patchItem(item) {
  return item == null ? null : item.__merge({canDrop = false, canTake = true})
}

const itemsInRow = 3
let processItems = function(items) {
  items = considerRefineItems(items)
  items = items.filter(filterItems)
  items = mergeNonUniqueItems(items)
  items = items.map(patchItem)
  items.sort(inventoryItemSorting)
  return items
}

let panelsData = setupPanelsData(stashItems,
                                 itemsInRow,
                                 [stashItems, activeFilters, itemsInRefiner],
                                 processItems)

function mkStashButton(isPurchased, onClick, isFeatured = false) {
  let iconColor = isFeatured ? Color(170, 123, 0) : TextNormal

  let statusIcon = faComp("check", {
    fontSize = static hdpxi(16)
    color = GreenSuccessColor
    hplace = ALIGN_RIGHT
    pos = static [hdpx(5), -hdpx(5)]
  })

  let icon = {
    rendObj = ROBJ_IMAGE
    size = [extendIconHeigh, extendIconHeigh]
    color = isPurchased ? mul_color(iconColor, 0.5) : iconColor
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    image = Picture($"ui/skin#storage_slot_icon.svg:{extendIconHeigh}:{extendIconHeigh}:K")
    children = isPurchased ? statusIcon : null
  }

  return button(icon, onClick, {
    size = static [hdpx(40), hdpxi(40)]
    style = !isPurchased ? {} : { BtnBgNormal = BtnBgDisabled }
    tooltipText = isFeatured ?
      loc("inventory/extendStashFeatured", {size = playerBaseState.get()?.stashVolumeUpgrade.y ?? 0}) :
      loc("inventory/extendStash", {size = playerBaseState.get()?.stashVolumeUpgrade.x ?? 0})
  })
}

function extendStashBlock() {
  let { stashesCount = {}, maxStashesCount = {} } = playerBaseState.get()
  let curCommonStashCount = stashesCount?.x ?? 0
  let curFeaturedStashCount = stashesCount?.y ?? 0
  let maxCommonStashCount = maxStashesCount?.x ?? 0
  let maxFeaturedStashCount = maxStashesCount?.y ?? 0

  if (maxCommonStashCount <= 0 && maxFeaturedStashCount <= 0)
    return { watch = playerBaseState }

  function commonStashAction() {
    let levelsToFocus = []
    foreach (id, item in marketItems.get()) {
      if (item?.offerName.contains("StashUpgrade")
        && !item?.isPermanent
        && !playerStats.get().purchasedUniqueMarketOffers.contains(id.tointeger())
      )
        levelsToFocus.append(item)
    }

    if (levelsToFocus.len() > 0) {
      let res = levelsToFocus.sort(@(a, b) a.requirements.monolithAccessLevel
        <=> b.requirements.monolithAccessLevel)
      monolithSelectedLevel.set(res[0].requirements.monolithAccessLevel)
      selectedMonolithUnlock.set(res[0].children.baseUpgrades[0])
      monolithSectionToReturn.set("Inventory")
      currentTab.set("monolithLevelId")
      openMenu(MonolithMenuId)
    }
    else
      showMsgbox({ text = loc("inventory/extendUnavailable")})
  }

  function featuredStashAction() {
    let levelsToFocus = []
    local hasPurchasedAll = true
    let featuredInventoryMarketOffers = marketItems.get()
      .filter(@(item) item?.offerName.contains("PermanentStashUpgrade"))
    foreach (id, item in featuredInventoryMarketOffers) {
      if (!playerStats.get().purchasedUniqueMarketOffers.contains(id.tointeger())) {
        hasPurchasedAll = false
        levelsToFocus.append(item)
      }
    }
    if (hasPurchasedAll) {
      showMsgbox({ text = loc("inventory/featuredStashPurchased")})
      return
    }
    if (levelsToFocus.len() > 0) {
      let res = levelsToFocus.sort(@(a, b) a.requirements.monolithAccessLevel
        <=> b.requirements.monolithAccessLevel)
      monolithSelectedLevel.set(res[0].requirements.monolithAccessLevel - 1)
      selectedMonolithUnlock.set(res[0].children.baseUpgrades[0])
      monolithSectionToReturn.set("Inventory")
      currentTab.set("monolithLevelId")
      openMenu(MonolithMenuId)
    }
    else
      showMsgbox({ text = loc("inventory/featuredStashUnavailable")})
  }

  return {
    watch = [marketItems, playerStats, playerBaseState]
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    gap = static { size = flex() }
    padding = static [0, hdpx(2)]
    children = array(maxCommonStashCount)
      .map(@(_v, i) mkStashButton(i <= curCommonStashCount - 1, commonStashAction))
      .extend(array(maxFeaturedStashCount)
        .map(@(_v, i) mkStashButton(i <= curFeaturedStashCount - 1, featuredStashAction, true)))
  }
}

function stash_item_dropped_forbid(reason){
  if (reason == MoveForbidReason.VOLUME)
    showMsgbox({
      text = loc("hint/stashOverload")
      buttons = [
        { text = loc("Ok"), isCurrent = true, action = @() null }
        { text = loc("console/press_to_recycler"), isCurrent = false, action = @() eventbus_send("hud_menus.open", static { id = "Am_clean" }) }
      ]
    })
}

function mkStashItemsList(on_item_dropped_to_list_cb, on_click_actions, params = {}) {
  let { xSize = 3 } = params
  return function(){
    panelsData.resetScrollHandlerData()
    let children = itemsPanelList({
      outScrollHandlerInfo=panelsData.scrollHandlerData,
      list_type=STASH,
      itemsPanelData=panelsData.itemsPanelData,
      headers=mkInventoryHeader(
        loc("inventory/itemsInStash"),
        mkVolumeHdr(stashVolume, stashMaxVolume, STASH.name)
      )
      can_drop_dragged_cb=isItemCanBeDroppedInStash,
      on_item_dropped_to_list_cb=on_item_dropped_to_list_cb,
      on_item_dropped_forbid_cb=stash_item_dropped_forbid
      item_actions=on_click_actions
      xSize
    })

    return {
      size = FLEX_V
      watch = [ panelsData.numberOfPanels ]
      children
      onAttach = panelsData.onAttach
      onDetach = panelsData.onDetach
    }
  }
}

return {
  isItemCanBeDroppedInStash,
  mkStashItemsList
  extendStashBlock
}