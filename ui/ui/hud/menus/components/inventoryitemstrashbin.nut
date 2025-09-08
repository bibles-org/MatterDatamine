from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { setupPanelsData, itemsPanelList, inventoryItemSorting } = require("%ui/hud/menus/components/inventoryItemsList.nut")
let { mergeNonUniqueItems } = require("%ui/hud/menus/components/inventoryItemUtils.nut")
let { TRASH_BIN } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { trashBinItems } = require("%ui/hud/menus/components/trashBin.nut")
let { textButton } = require("%ui/components/button.nut")
let { h2_txt } = require("%ui/fonts_style.nut")
let { ceil } = require("math")
let { eventbus_send } = require("eventbus")
let { isShiftPressed } = require("%ui/hud/state/inventory_state.nut")
let faComp = require("%ui/components/faComp.nut")
let { MoveForbidReason } = require("%ui/hud/menus/components/inventoryItemsListChecksCommon.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let { BtnBdHover } = require("%ui/components/colors.nut")
let { inventoryItemClickActions } = require("%ui/hud/menus/inventoryActions.nut")
let { get_item_info } = require("%ui/hud/state/item_info.nut")

let trashBinHeaderTxt = {
  rendObj = ROBJ_TEXT
  text = loc("inventory/destroyItems")
  color = Color(80,80,80)
}

let trashIcon = faComp("trash")

let trashBinHeader = @() {
  size = [ flex(), SIZE_TO_CONTENT ]
  watch = trashBinItems
  flow = FLOW_HORIZONTAL
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  gap = hdpx(10)
  padding = hdpx(8)

  children = [
    trashBinItems.get().len() > 0 ? trashIcon : null
    trashBinHeaderTxt
  ]
}

let trashBinItemContainerCursorAttractor = {
  size = [flex(), hdpx(40)]
  cursorNavAnchor = [elemw(50), elemh(50)]
  children = {
    rendObj = ROBJ_SOLID
  }
}

function isItemCanBePuttedInTrashBinItemContainer(item) {
  if (item == null)
    return MoveForbidReason.OTHER

  if (item?.fromList?.name == "trashBin"
      || item?.slotName
      || item?.currentWeaponSlotName
      || item?.fromList == null)
    return MoveForbidReason.OTHER

  return MoveForbidReason.NONE
}

function dropItemToTrashBin(item, _list_type) {
  if (item?.fromList?.name == "trashBin"
    || item?.slotName
    || item?.currentWeaponSlotName)
    return false
  let isAmmo = (item?.ammoCount ?? 0) > 0 && (item?.countPerStack ?? 0) > 0

  if (isAmmo) {
    local idx = trashBinItems.get().findindex(@(trash) trash.eids.findindex(@(eid) eid==item.eid) != null)
    let wishAdd = isShiftPressed.get() ? item.ammoCount : item.countPerStack
    let add = min(wishAdd, item.ammoCount)

    trashBinItems.mutate(function(v) {
      if (idx == null) {
        let additionalFields = {
          ammoCount = add
          trashBinItemOrigin = item.fromList
        }
        v.append(item?.itemOverridedWithProto ?
          get_item_info(item.eids[0]).__update(additionalFields) :
          item.__merge(additionalFields)
        )
      }
      else {
        v[idx].ammoCount += add
      }
    })
  }
  else {
    let indexToProceed = isShiftPressed.get() ? item.count : 1
    trashBinItems.mutate(function(tbItems) {
      let uniqueIds = []
      let eids = []
      let trashBinIdx = tbItems.findindex(@(stackedItems) stackedItems.eids.findindex(@(v) v.tointeger()==item.eid.tointeger()) != null )
      for(local i=0; i < indexToProceed; i++){
        uniqueIds.append(item.uniqueIds[i])
        eids.append(item.eids[i])
      }
      let additionalFields = {
        uniqueId = item.uniqueIds[0]
        uniqueIds
        eid = item.eids[0]
        eids
        count = uniqueIds.len()
        trashBinItemOrigin = item.fromList
      }

      if (trashBinIdx == null) {
        tbItems.append(
          item?.itemOverridedWithProto ?
            get_item_info(item.eids[0]).__merge(additionalFields) :
            item.__merge(additionalFields)
        )
      }
      else {
        let toChange = tbItems[trashBinIdx]
        toChange.uniqueIds.extend(additionalFields.uniqueIds)
        toChange.eids.extend(additionalFields.eids)
        toChange.count += additionalFields.count
      }
    })
  }
}

let destroyButton = textButton(loc("inventory/destroyItems"),
  function() {
    let eids2destroy = []
    foreach(item in trashBinItems.get()) {
      let isAmmo = (item?.ammoCount ?? 0) > 0 && (item?.countPerStack ?? 0) > 0
      if (isAmmo) {
        let stackCount = ceil(item.ammoCount.tofloat() / item.countPerStack.tofloat())
        let eids = [].resize(stackCount, item.uniqueIds[0])
        eids2destroy.extend(eids)
      }
      else
        eids2destroy.extend(item.uniqueIds)
    }
    eventbus_send("profile_server.destroyItems", eids2destroy)
    trashBinItems.set([])
  },
  {
    size = [flex(), hdpx(50)]
    halign = ALIGN_CENTER
    margin = 0
    style = {
      BtnBgNormal = Color(180, 40, 40)
    }
    sound = {
      click = "ui_sounds/inventory_item_destroy"
      hover = "ui_sounds/button_highlight"
    }
  }.__update(h2_txt)
)

const itemsInRow = 3
let processItems = function(items) {
  items = mergeNonUniqueItems(items)
  items.sort(inventoryItemSorting)
  return items
}

let panelsData = setupPanelsData(trashBinItems,
                                 itemsInRow,
                                 [trashBinItems],
                                 processItems)

function trashBinItemContainerItemsList() {
  let items = trashBinItems.get()
  let isEmpty = items.len() == 0
  panelsData.resetScrollHandlerData()
  return {
    watch = panelsData.numberOfPanels
    size = isEmpty ? [ flex(), hdpx(40)] : [ flex(), hdpx(300) ]
    onAttach = panelsData.onAttach
    onDetach = function() {
      trashBinItems.set([])
      panelsData.onDetach()
    }
    children = [
      {
        size = flex()
        flow = FLOW_VERTICAL
        children = [
          itemsPanelList({
            outScrollHandlerInfo=panelsData.scrollHandlerData,
            list_type=TRASH_BIN,
            itemsPanelData=panelsData.itemsPanelData,
            headers=[
              trashBinHeader
            ],
            can_drop_dragged_cb=isItemCanBePuttedInTrashBinItemContainer,
            on_item_dropped_to_list_cb=dropItemToTrashBin,
            item_actions = inventoryItemClickActions[TRASH_BIN.name]
            visualParams={
              rendObj = ROBJ_SOLID
              color = Color(20,0,0,150)
            },
            xSize = 4
          })
          isEmpty ? null : destroyButton
        ]
      }
      !isEmpty ? null : watchElemState(@(sf) {
        rendObj = ROBJ_BOX
        size = flex()
        borderWidth = sf & S_HOVER ? hdpx(2) : 0
        borderColor = BtnBdHover
        behavior = Behaviors.Button
        onHover= @(on) setTooltip(on ? loc("trashBin/dropToDelete") : null)
      })
    ]
  }
}


return {
  trashBinItemContainerCursorAttractor
  trashBinItemContainerItemsList
}