from "%ui/ui_library.nut" import *


let { eventbus_send } = require("eventbus")
let {stashItems} = require("%ui/hud/state/inventory_items_es.nut")
let { itemsPanelList, setupPanelsData, filterItems, inventoryItemSorting, considerTrashBinItems
} = require("%ui/hud/menus/components/inventoryItemsList.nut")
let { mergeNonUniqueItems } = require("%ui/hud/menus/components/inventoryItemUtils.nut")
let { STASH } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { mkInventoryHeader } = require("%ui/hud/menus/components/inventoryCommon.nut")
let { stashVolume, stashMaxVolume } = require("%ui/state/allItems.nut")
let { mkVolumeHdr } = require("%ui/hud/menus/components/inventoryVolumeWidget.nut")
let { trashBinItems } = require("%ui/hud/menus/components/trashBin.nut")
let { activeFilters } = require("%ui/hud/menus/components/inventoryStashFiltersWidget.nut")
let { isItemCanBeDroppedInStash } = require("%ui/hud/menus/components/inventoryItemsListChecks.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let faComp = require("%ui/components/faComp.nut")
let { showMsgbox } = require("%ui/components/msgbox.nut")
let { button } = require("%ui/components/button.nut")
let { BtnTextNormal } = require("%ui/components/colors.nut")
let { mkText } = require("%ui/components/commonComponents.nut")
let { MonolithMenuId, monolithSelectedLevel, monolithSectionToReturn, selectedMonolithUnlock
} = require("%ui/mainMenu/monolith/monolith_common.nut")
let { marketItems, playerStats } = require("%ui/profile/profileState.nut")
let { openMenu } = require("%ui/hud/hud_menus_state.nut")
let { MoveForbidReason } = require("%ui/hud/menus/components/inventoryItemsListChecksCommon.nut")

let extendIconHeigh = hdpxi(30)

function patchItem(item) {
  return item == null ? null : item.__merge({canDrop = false, canTake = true})
}

const itemsInRow = 3
let processItems = function(items) {
  items = items.filter(filterItems)
  items = mergeNonUniqueItems(items)
  items = items.map(patchItem)
  items = considerTrashBinItems(items)
  items.sort(inventoryItemSorting)
  return items
}

let panelsData = setupPanelsData(stashItems,
                                 itemsInRow,
                                 [stashItems, activeFilters, trashBinItems],
                                 processItems)

let extendStashBtn = @() {
  watch = [marketItems, playerStats]
  size = [flex(), SIZE_TO_CONTENT]
  children = button(
    {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      gap = hdpx(8)
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = [
        mkText(loc("inventory/extendStash"))
        {
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          children = [
            {
              rendObj = ROBJ_IMAGE
              size = [extendIconHeigh, extendIconHeigh]
              color = BtnTextNormal
              vplace = ALIGN_CENTER
              image = Picture($"ui/skin#storage_slot_icon.svg:{extendIconHeigh}:{extendIconHeigh}:K")
            }
            faComp("plus", {
              fontSize = hdpxi(20)
              color = BtnTextNormal
              pos = [extendIconHeigh - hdpx(4), 0]
            })
          ]
        }
      ]
    },
    function() {
      let levelsToFocus = []
      foreach (id, item in marketItems.get()) {
        if (item?.offerName.contains("StashUpgrade")
          && !playerStats.get().purchasedUniqueMarketOffers.contains(id.tointeger())
        )
          levelsToFocus.append(item)
      }
      if (levelsToFocus.len() > 0) {
        let res = levelsToFocus.sort(@(a, b) a.requirements.monolithAccessLevel
          <=> b.requirements.monolithAccessLevel)
        monolithSelectedLevel.set(res[0].requirements.monolithAccessLevel - 1)
        selectedMonolithUnlock.set(res[0].children.baseUpgrades[0])
        monolithSectionToReturn.set("Inventory")
        openMenu(MonolithMenuId)
      }
      else
        showMsgbox({ text = loc("stash/extendUnavailable")})
    },
    {
      size = [flex(), hdpx(40)]
      onHover = @(on) setTooltip(on ? loc("inventory/extendStash") : null)
    })
}

function stash_item_dropped_forbid(reason){
  if (reason == MoveForbidReason.VOLUME)
    showMsgbox({
      text = loc("hint/stashOverload")
      buttons = [
        { text = loc("Ok"), isCurrent = true, action = @() null }
        { text = loc("console/press_to_recycler"), isCurrent = false, action = @() eventbus_send("hud_menus.open", const { id = "Am_clean" }) }
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
      size = const [ SIZE_TO_CONTENT, flex() ]
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
  extendStashBtn
}