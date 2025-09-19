from "%ui/hud/menus/components/inventoryItemsList.nut" import setupPanelsData, itemsPanelList, inventoryItemSorting
from "%ui/hud/menus/components/inventoryItemUtils.nut" import mergeNonUniqueItems
from "%ui/components/button.nut" import buttonWithGamepadHotkey
from "%ui/fonts_style.nut" import h2_txt, body_txt
from "math" import ceil
from "eventbus" import eventbus_send
import "%ui/components/faComp.nut" as faComp
from "%ui/hud/menus/components/inventoryItemsListChecksCommon.nut" import MoveForbidReason
from "%ui/components/cursors.nut" import setTooltip
from "%ui/components/colors.nut" import BtnBdHover, BtnTextNormal
from "%ui/hud/state/item_info.nut" import get_item_info
from "%ui/components/commonComponents.nut" import mkTextArea, mkText
from "%ui/components/accentButton.style.nut" import accentButtonStyle
from "%ui/hud/menus/components/inventoryItemTypes.nut" import REFINER, EXTERNAL_ITEM_CONTAINER
from "%ui/hud/menus/inventoryActions.nut" import inventoryItemClickActions, moveItemWithKeyboardMode
from "%ui/mainMenu/amProcessingDeviceMenu.nut" import amProcessingIsAvailable
from "%ui/mainMenu/amProcessingSelectItem.nut" import startQuickRefine, mkExpectedRewardInfo
from "%ui/hud/menus/inventories/refinerInventoryCommon.nut" import itemsInRefiner
from "%ui/profile/profileState.nut" import amProcessingTask

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let trashBinHeaderTxt = @() {
  watch = amProcessingIsAvailable
  rendObj = ROBJ_TEXT
  text = amProcessingIsAvailable.get() ? loc("inventory/refineItemsTitle") : loc("inventory/destroyItems")
  color = BtnTextNormal
}

let trashIcon = faComp("trash")

let trashBinHeader = @() {
  watch = itemsInRefiner
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  gap = hdpx(10)
  padding = hdpx(8)

  children = [
    itemsInRefiner.get().len() > 0 ? trashIcon : null
    trashBinHeaderTxt
  ]
}

let trashBinItemContainerCursorAttractor = freeze({
  size = static [flex(), hdpx(40)]
  cursorNavAnchor = [elemw(50), elemh(50)]
  children = {
    rendObj = ROBJ_SOLID
  }
})

function isItemCanBePuttedInTrashBinItemContainer(item) {
  if (item == null)
    return MoveForbidReason.OTHER

  if (item?.fromList == null)
    return MoveForbidReason.FORBIDDEN

  if (amProcessingIsAvailable.get() && amProcessingTask.get()?.taskId != "")
    return MoveForbidReason.FORBIDDEN_REFINER_IN_PROGRESS

  if (   item?.fromList.name == REFINER.name
      || item?.fromList.name == EXTERNAL_ITEM_CONTAINER.name
      || item?.slotName
      || item?.currentWeaponSlotName)
    return MoveForbidReason.OTHER

  return MoveForbidReason.NONE
}

let destroyButton = buttonWithGamepadHotkey(mkText(loc("inventory/destroyItems"), { hplace = ALIGN_CENTER }.__merge(body_txt)),
  function() {
    let eids2destroy = []
    foreach(item in itemsInRefiner.get()) {
      let isAmmo = (item?.ammoCount ?? 0) > 0 && (item?.countPerStack ?? 0) > 0
      if (isAmmo) {
        let stackCount = ceil(item.ammoCount.tofloat() / item.countPerStack.tofloat())
        let eids = [].resize(stackCount, item.uniqueId)
        eids2destroy.extend(eids)
      }
      else
        eids2destroy.extend(item.uniqueIds)
    }
    eventbus_send("profile_server.destroyItems", eids2destroy)
    itemsInRefiner.set([])
  },
  {
    size = static [flex(), hdpx(50)]
    halign = ALIGN_CENTER
    margin = 0
    style = {
      BtnBgNormal = Color(180, 40, 40)
    }
    hotkeys = [["J:Y", { description = { skip = true } }]]
    sound = {
      click = "ui_sounds/inventory_item_destroy"
      hover = "ui_sounds/button_highlight"
    }
  }
)

let refineButton = buttonWithGamepadHotkey(mkText(loc("inventory/refineItems"), { hplace = ALIGN_CENTER }.__merge(body_txt)),
  function() {
    startQuickRefine()
    itemsInRefiner.set([])
  },
  {
    size = static [flex(), hdpx(50)]
    halign = ALIGN_CENTER
    margin = 0
    style = {
      BtnBgNormal = Color(40, 40, 180)
    }
    hotkeys = [["J:Y", { description = { skip = true } }]]
    sound = {
      click = "ui_sounds/inventory_item_destroy"
      hover = "ui_sounds/button_highlight"
    }
  }.__update(accentButtonStyle)
)

const itemsInRow = 3
let processItems = function(items) {
  items = mergeNonUniqueItems(items)
  items.sort(inventoryItemSorting)
  return items
}

let panelsData = setupPanelsData(itemsInRefiner,
                                 itemsInRow,
                                 [itemsInRefiner],
                                 processItems)

function trashBinItemContainerItemsList() {
  let items = itemsInRefiner.get()
  let isEmpty = items.len() == 0
  panelsData.resetScrollHandlerData()
  let stateFlags = Watched(0)
  return {
    watch = [itemsInRefiner, panelsData.numberOfPanels, amProcessingIsAvailable]
    size = isEmpty ? [ flex(), hdpx(40)] : [ flex(), hdpx(300) ]
    onAttach = panelsData.onAttach
    onDetach = function() {
      itemsInRefiner.set([])
      panelsData.onDetach()
    }
    children = [
      {
        size = flex()
        flow = FLOW_VERTICAL
        children = [
          itemsPanelList({
            outScrollHandlerInfo=panelsData.scrollHandlerData,
            list_type=REFINER,
            itemsPanelData=panelsData.itemsPanelData,
            headers=[
              trashBinHeader,
              function() {
                let { overallMoneyIncome = null } = mkExpectedRewardInfo(itemsInRefiner.get(), null, null, null)
                let watch = [ itemsInRefiner, amProcessingIsAvailable ]

                if (!amProcessingIsAvailable.get())
                  return { watch }

                return {
                  watch
                  size = FLEX_H
                  children = overallMoneyIncome ? mkTextArea(
                    loc("amClean/expectedMoneyFromNonCorruptedItems", { minVal = overallMoneyIncome}),
                    {
                      halign = ALIGN_CENTER
                    }) : null
                }
              }
            ],
            can_drop_dragged_cb=isItemCanBePuttedInTrashBinItemContainer,
            on_item_dropped_to_list_cb=moveItemWithKeyboardMode,
            item_actions = inventoryItemClickActions[REFINER.name]
            visualParams={
              rendObj = ROBJ_SOLID
              color = amProcessingIsAvailable.get() ? Color(5, 55, 60) : Color(20,0,0,150)
            },
            xSize = 4
          })
          isEmpty ? null : amProcessingIsAvailable.get() ? refineButton : destroyButton
        ]
      }
      !isEmpty ? null : function() {
        let sf = stateFlags.get()
        return {
          watch = stateFlags
          onElemState = @(s) stateFlags.set(s)
          rendObj = ROBJ_BOX
          size = flex()
          borderWidth = sf & S_HOVER ? hdpx(2) : 0
          borderColor = BtnBdHover
          behavior = Behaviors.Button
          onHover= @(on) setTooltip(on ?
            (
              amProcessingIsAvailable.get() ? loc("trashBin/dropToRefine") : loc("trashBin/dropToDelete")
            ) : null)
        }
      }
    ]
  }
}


return freeze({
  trashBinItemContainerCursorAttractor
  trashBinItemContainerItemsList
})