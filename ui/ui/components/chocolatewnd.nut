from "math" import ceil, floor
from "%ui/components/colors.nut" import ItemBgColor, ItemBdColor, BtnBdNormal
from "%ui/hud/menus/components/inventoryItemTooltip.nut" import buildInventoryItemTooltip
from "%ui/components/cursors.nut" import setTooltip
from "%ui/components/button.nut" import button
from "%ui/components/mkDotPaginatorList.nut" import mkHorizPaginatorList
from "%ui/components/mkLightBox.nut" import mkLightBox
from "%ui/hud/menus/components/inventoryItemUtils.nut" import fastUnequipItem
from "%ui/hud/menus/components/inventoryItem.nut" import itemRecognizingComp, chocolateInventoryItem, RecognitionStages
from "eventbus" import eventbus_subscribe
from "%ui/components/modalWindows.nut" import addModalWindow, removeModalWindow
import "%ui/components/faComp.nut" as faComp
import "%ui/components/gamepadImgByKey.nut" as gamepadImgByKey
import "%ui/components/getGamepadHotkeys.nut" as getGamepadHotkeys

from "%ui/ui_library.nut" import *

let { focusedData, isAltPressed, inventoryCurrentVolume, isAltPressedMonitor
} = require("%ui/hud/state/inventory_state.nut")
let { inventoryImageParams } = require("%ui/hud/menus/components/inventoryItemImages.nut")
let { safeAreaVerPadding, safeAreaHorPadding } = require("%ui/options/safeArea.nut")
let { ITEM_PICKER } = require("%ui/hud/menus/components/slotTypes.nut")
let { hoverHotkeysWatchedList } = require("%ui/components/pcHoverHotkeyHitns.nut")
let { hoverPcHotkeysPresentation } = require("%ui/hud/menus/components/inventoryActionsHints.nut")
let { playerProfileCreditsCount, playerBaseState, playerProfilePremiumCredits } = require("%ui/profile/profileState.nut")
let { chocolateRowSafeWatch, chocolateColSafeWatch
} = require("%ui/mainMenu/menus/options/chocolate_matrix_option.nut")
let { creditsTextIcon, monolithTokensTextIcon, premiumCreditsTextIcon } = require("%ui/mainMenu/currencyIcons.nut")
let { mintEditState } = require("%ui/mainMenu/raid_preparation_window_state.nut")
let { previewPresetCallbackOverride } = require("%ui/equipPresets/presetsState.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")

#allow-auto-freeze

const ANIM_DURATION = 0.1
const WND_UID = "chocolateWnd"

let defGap = hdpx(5)
local isFlipped = false
let defSize = hdpxi(76)

let isPurchaseInProgress = Watched(false)
let isShopState = Watched(false)
let commonData = Watched(null)
let isRbPressed = Watched(false)

let isRbPressedMonitor = {
  behavior = Behaviors.Button
  hotkeys = [["^J:RS", {
    description = loc("chocolate/comparisonMode")
    action = @() isRbPressed.modify(@(v) !v)
  }]]
}

eventbus_subscribe("profile_server.buyLots.result", function(_) {
  isPurchaseInProgress.set(false)
})

let slotHeight = inventoryImageParams.slotSize[0]
let hideItemPicker = function() {
  isFlipped = false
  isShopState.set(false)
  isRbPressed.set(false)
  removeModalWindow(WND_UID)
}

let mkCompareTooltip = @(item) function() {
  let watch = [isAltPressed, isRbPressed]
  if (!isAltPressed.get() && !isRbPressed.get())
    return { watch }
  if (item?.itemTemplate == null)
    return { watch }
  return {
    watch
    children = buildInventoryItemTooltip(item)
  }
}

let isSlotEmpty = @(item, itemInSlot) item?.itemTemplate == null
  && itemInSlot?.itemTemplate == null
  && itemInSlot?.template == null

let isUnequipAction = @(item, itemInSlot, defItemTemplate)
  (itemInSlot?.itemTemplate != defItemTemplate && item?.itemTemplate == defItemTemplate)
    || (item?.itemTemplate == null && (itemInSlot?.itemTemplate != null || itemInSlot?.template != null))

function handleClick(chocoData, item, defItemTemplate, isShopActive) {
  let { itemInSlot = null, onClick = null } = chocoData
  if (isSlotEmpty(item, itemInSlot)) {
    if (mintEditState.get()) {
      onClick?(null, previewPresetCallbackOverride.get())
      hideItemPicker()
    }
    else if (isShopState.get())
      isShopState.set(false)
    else
      hideItemPicker()
    return
  }

  if (isUnequipAction(item, itemInSlot, defItemTemplate)) {
    if (mintEditState.get())
      onClick?(null, previewPresetCallbackOverride.get())
    else
      fastUnequipItem(itemInSlot)
  }
  else {
    if (defItemTemplate != null && item?.templateName == defItemTemplate) {
      hideItemPicker()
      return
    }
    let action = !isShopActive
      ? onClick?(item, previewPresetCallbackOverride.get())
      : onClick?(item, playerProfileCreditsCount.get(), playerProfilePremiumCredits.get(), isPurchaseInProgress,
          playerBaseState.get()?.humanInventoryVolume, inventoryCurrentVolume.get())
    action?()
  }
  hideItemPicker()
}

function handleHover(on, item, itemInSlot) {
  if (on) {
    if (item?.itemTemplate == null)
      setTooltip(isShopState.get() ? loc("amClean/back")
        : item?.isNoActionBtn ? loc("action/noAction")
        : loc("item/unequipSlot"))
    else {
      setTooltip([ buildInventoryItemTooltip(item), itemInSlot ? mkCompareTooltip(itemInSlot) : null])
      focusedData.set(item)
    }
    hoverHotkeysWatchedList.set(hoverPcHotkeysPresentation[ITEM_PICKER.name](item))
  }
  else {
    setTooltip(null)
    focusedData.set(null)
    hoverHotkeysWatchedList.set(null)
  }
}

let mkItemPickerSlotActions = @(chocoData, item, defItemTemplate, isShopActive) {
  onClick = item?.isNoActionBtn ? hideItemPicker
    : chocoData?.forceOnClick ? function() {
        chocoData.onClick(item, null)
        hideItemPicker()
      }
    : @() handleClick(chocoData, item, defItemTemplate, isShopActive)
  onHover = @(on) handleHover(on, item, chocoData?.itemInSlot)
}

function getPickerPositioning(size, chocolateData) {
  let rect = chocolateData?.event.targetRect
  if (!rect)
    return [0, 0]

  let width = rect.r - rect.l
  let centerX = rect.l + width * 0.5
  local posX = (centerX - size[0] * 0.5).tointeger()

  if (centerX - size[0] * 0.5 < safeAreaHorPadding.get() + fsh(1))
    posX = (posX + width + defGap).tointeger()

  local posY = (rect.t - size[1] - defGap).tointeger()
  if (isFlipped || rect.t - size[1] <= safeAreaVerPadding.get() + fsh(1)) {
    isFlipped = true
    posY = rect.b + defGap
  }

  return [posX, posY]
}

let mkSlotWrapper = @(content) {
  rendObj = ROBJ_VECTOR_CANVAS
  size = hdpx(50)
  color = ItemBdColor
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  commands = static [
    [VECTOR_COLOR, BtnBdNormal],
    [VECTOR_LINE, 0, 25, 0,  0],
    [VECTOR_LINE, 25, 0, 0,  0],
    [VECTOR_LINE, 75, 0, 100, 0],
    [VECTOR_LINE, 100, 0, 100, 25],
    [VECTOR_LINE, 100, 75, 100, 100],
    [VECTOR_LINE, 100, 100, 75, 100],
    [VECTOR_LINE, 25, 100, 0, 100],
    [VECTOR_LINE, 0, 100, 0, 75],
  ]
  children = content
}

let arrowIcon = faComp("angle-left", { fontSize = hdpxi(33), color = BtnBdNormal })
let minusIcon = faComp("minus", { fontSize = hdpxi(24), color = BtnBdNormal })
let cartIcon = faComp("shopping-basket", { fontSize = hdpxi(23), color = BtnBdNormal })
let crossIcon = faComp("close", { fontSize = hdpxi(23), color = BtnBdNormal })

let mkGamepadHotkeysBlock = @(hotkeys) function() {
  if (!isGamepad.get())
    return { watch = isGamepad }

  let gamepadHotkey = getGamepadHotkeys(hotkeys, false)
  let hotkeyImg = (gamepadHotkey == "") ? null : gamepadImgByKey.mkImageCompByDargKey(gamepadHotkey)
  let gamepadImg = isGamepad.get() && hotkeyImg != null
  return {
    watch = isGamepad
    children = gamepadImg == null ? null : {
      pos = [0, -defSize / 3]
      children = hotkeyImg
    }
  }
}

let noItemSlot = {
  rendObj = ROBJ_BOX
  size = [defSize, defSize]
  fillColor = ItemBgColor
  borderColor = ItemBdColor
  borderWidth = hdpx(1)
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = mkSlotWrapper(@() {
    watch = isShopState
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    children = [
      isShopState.get() ? arrowIcon : minusIcon
      mkGamepadHotkeysBlock(isShopState.get() ? [[$"{JB.B}"]] : [["J:X"]])
    ]
  })
}

let noItemActionsSlot = {
  rendObj = ROBJ_BOX
  size = [defSize, defSize]
  fillColor = ItemBgColor
  borderColor = ItemBdColor
  borderWidth = hdpx(1)
  isNoActionBtn = true
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = mkSlotWrapper(@() {
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    children = [
      crossIcon
      mkGamepadHotkeysBlock([[$"{JB.B}"]])
    ]
  })
}

let shopButton = {
  rendObj = ROBJ_BOX
  size = [defSize, defSize]
  fillColor = ItemBgColor
  borderColor = ItemBdColor
  borderWidth = hdpx(1)
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  behavior = Behaviors.Button
  onClick = @() isShopState.modify(@(v) !v)
  hotkeys = [["J:Y"]]
  isShopBtn = true
  onHover = @(on) setTooltip(on ? loc("slot/action/quickPurchase") : null)
  children = mkSlotWrapper({
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      cartIcon
      mkGamepadHotkeysBlock([["J:Y"]])
    ]
  })
}

function calcItemPos(idx, rowsPerPage, total, slotsPerPage, rowSlots, maxRowsPerPage) {
  if (total <= 1)
    return [0, 0]

  let col = floor((idx % slotsPerPage) / rowSlots)
  let row = isFlipped ? col : min(rowsPerPage, maxRowsPerPage) - 1 - col
  let x = idx % rowSlots
  if (total == 2)
    return [x * slotHeight + (idx == 0 ? 0 : defGap), 0]

  return [x * (slotHeight + defGap), row * (slotHeight + defGap)]
}

function prepareData(chocolateData, shopData) {
  #forbid-auto-freeze
  let { itemsDataArr = [], defaultItem = null, itemInSlot = null } = chocolateData
  let hasNoItemsToChooseOrBuy = shopData == null && itemsDataArr.len() <= 0 && itemInSlot?.itemTemplate == null
  let data = defaultItem == null ? hasNoItemsToChooseOrBuy ? [] : [noItemSlot] : [defaultItem]
  let baseItems = data.extend(itemsDataArr)
    .filter(function(item) {
      if (defaultItem?.itemTemplate == null)
        return true
      return item.itemTemplate != defaultItem.itemTemplate || itemInSlot?.itemTemplate != defaultItem.itemTemplate
    })
  if ((defaultItem != null && baseItems.len() <= 0) || hasNoItemsToChooseOrBuy)
    baseItems.append(noItemActionsSlot)
  return shopData != null ? baseItems.insert(0, shopButton) : baseItems
}

function renderItems(data, rowsPerPage, chocolateData, isShopActive, itemInSlot, defaultItemTemplate) {
  let idxToHover = !isGamepad.get() ? null
    : data.findindex(@(v) (v?.recognizeTimeLeft ?? -1) < 0 && v?.itemTemplate != null)

  return data.map(function(item, idx) {
    let actions = mkItemPickerSlotActions(chocolateData, item, defaultItemTemplate, isShopActive)
    let itemPos = calcItemPos(idx, rowsPerPage, data.len(),
      chocolateRowSafeWatch.get() * chocolateColSafeWatch.get(),
      chocolateRowSafeWatch.get(), chocolateColSafeWatch.get())

    let { itemTemplate = null, recognizeTimeLeft = -1, isShopBtn = false, isNoActionBtn = false } = item
    let isRecognizing = recognizeTimeLeft > 0.0
    if (isRecognizing) {
      let recognitionStage = Watched(RecognitionStages.Queue)
      return function() {
        let showItem = itemInSlot?.itemTemplate != null ? item : item.__merge({ needCompareHint = false })
        let btnItem = recognitionStage.get() != RecognitionStages.Finished
          ? itemRecognizingComp(showItem, @(stage) recognitionStage.set(stage))
          : chocolateInventoryItem(showItem)
        return {
          watch = recognitionStage
          children = button(btnItem, actions.onClick,
            {
              size = [slotHeight, slotHeight]
              pos = itemPos
              onHover = actions.onHover
              behavior = null
            })
        }
      }
    }
    let showItem = itemInSlot?.itemTemplate != null ? item : item.__merge({ needCompareHint = false })
    let gamepadHotkey = itemTemplate == defaultItemTemplate ? mkGamepadHotkeysBlock([["J:X"]]) : null
    let btnItem = isShopBtn ? shopButton
      : isNoActionBtn ? noItemActionsSlot
      : itemTemplate == null ? noItemSlot
      : {
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          children = [
            chocolateInventoryItem(showItem)
            gamepadHotkey
          ]
        }
    return button(btnItem, actions.onClick,
      {
        size = [slotHeight, slotHeight]
        pos = itemPos
        onHover = actions.onHover
        onAttach = @(elem) idxToHover == null ? null
          : idx == idxToHover ? move_mouse_cursor(elem)
          : null
        hotkeys = itemTemplate == defaultItemTemplate || itemTemplate == null ? [["J:X"]] : null
      })
  })
}

let calcDimension = @(count) count * slotHeight + (count - 1) * defGap

function mkItemPicker(chocolateData, isShopActive) {
  let rowSlots = chocolateRowSafeWatch.get()
  let colSlots = chocolateColSafeWatch.get()
  let slotsPerPage = rowSlots * colSlots
  let maxRowsPerPage = colSlots
  let curPage = Watched(0)

  let { shopData = null, itemInSlot = null, defaultItem = null } = chocolateData
  let data = prepareData(chocolateData, shopData)

  let total = data.len()
  let totalRows = ceil(total.tofloat() / rowSlots)
  let totalPages = ceil(total.tofloat() / slotsPerPage)
  let rowsLastPage = ceil((total - ((totalPages - 1) * slotsPerPage)).tofloat() / rowSlots)

  let maxSlotsRow = min(total, rowSlots)
  let usedRows = min(totalRows, maxRowsPerPage)

  let hasPaginator = total > slotsPerPage
  let pagHeight = hasPaginator ? hdpx(29) : 0

  let maxHeight = calcDimension(usedRows) + pagHeight
  let maxWidth = calcDimension(maxSlotsRow)

  let pickerPos = getPickerPositioning([maxWidth, maxHeight], chocolateData)

  let comps = @(rowsPerPage) renderItems(data, rowsPerPage, chocolateData, isShopActive, itemInSlot, defaultItem?.itemTemplate)

  local size = [slotHeight, slotHeight]
  if (total > 1) {
    let w = calcDimension(min(total, rowSlots))
    let h = calcDimension(min(totalRows, maxRowsPerPage))
    size = [w, h]
  }
  let pickerAnimation = [
    { prop=AnimProp.scale, from=[0, 0], duration=ANIM_DURATION, play=true }
    { prop=AnimProp.scale, to=[0, 0], duration=0.1, playFadeOut=true }
  ]
  let isLastPage = Computed(@() totalPages == (curPage.get() + 1))
  return function() {
    let rowsPerPage = isLastPage.get() ? rowsLastPage : maxRowsPerPage
    let items = total == 0 ? noItemSlot : comps(rowsPerPage)
    let adjustedHeight = calcDimension(rowsLastPage)
    let children = mkHorizPaginatorList(items, slotsPerPage, curPage,
      { size = !isLastPage.get() ? size : [size[0], adjustedHeight] },
      { style = {
          size = [size[0], SIZE_TO_CONTENT]
          gap = hdpx(2)
        }
      })
    return {
      watch = isLastPage
      size = [size[0], SIZE_TO_CONTENT]
      stopMouse = true
      pos = isLastPage.get()
        ? getPickerPositioning(calc_comp_size(children), chocolateData)
        : pickerPos
      transform = {}
      animations = pickerAnimation
      behavior = Behaviors.Button
      onClick = hideItemPicker
      children
    }
  }
}

function itemPicker(chocolateData) {
  let {l, r, b, t} = chocolateData.event.targetRect
  commonData.set(chocolateData)
  let { shopData = null } = chocolateData
  return @() {
    watch = [commonData, isShopState]
    size = flex()
    behavior = Behaviors.Button
    onClick = hideItemPicker
    hotkeys = [[$"^Esc | {JB.B}",
      {
        action = function() {
          if (isShopState.get())
            isShopState.set(false)
          else
            hideItemPicker()
        }
        description = loc("mainmenu/btnClose")
      }
    ]]
    onDetach = hideItemPicker
    stopMouse = true
    children = [
      mkLightBox([{l, r, b, t}, isShopState.get() ? [creditsTextIcon, monolithTokensTextIcon, premiumCreditsTextIcon] : null])
      mkItemPicker(isShopState.get() && shopData != null ? shopData : commonData.get(), isShopState.get())
      isAltPressedMonitor
      isRbPressedMonitor
    ]
  }
}

function openChocolateWnd(chocolateData) {
  if (chocolateData == null)
    return
  addModalWindow({
    key = WND_UID
    children = itemPicker(chocolateData)
  })
}

return {
  openChocolateWnd
}
