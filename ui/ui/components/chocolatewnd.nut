from "%ui/ui_library.nut" import *

let { ceil, floor } = require("math")
let { ItemBgColor, ItemBdColor, BtnBdNormal } = require("%ui/components/colors.nut")
let { buildInventoryItemTooltip } = require("%ui/hud/menus/components/inventoryItemTooltip.nut")
let { focusedData, isAltPressed, inventoryCurrentVolume, isAltPressedMonitor
} = require("%ui/hud/state/inventory_state.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let { button } =  require("button.nut")
let { inventoryImageParams } = require("%ui/hud/menus/components/inventoryItemImages.nut")
let { mkHorizPaginatorList } = require("%ui/components/mkDotPaginatorList.nut")
let { safeAreaVerPadding, safeAreaHorPadding } = require("%ui/options/safeArea.nut")
let { mkLightBox } = require("%ui/components/mkLightBox.nut")
let { fastUnequipItem } = require("%ui/hud/menus/components/inventoryItemUtils.nut")
let { itemRecognizingComp, chocolateInventoryItem } = require("%ui/hud/menus/components/inventoryItem.nut")
let { ITEM_PICKER } = require("%ui/hud/menus/components/slotTypes.nut")
let { hoverHotkeysWatchedList } = require("%ui/components/pcHoverHotkeyHitns.nut")
let { hoverPcHotkeysPresentation } = require("%ui/hud/menus/components/inventoryActionsHints.nut")
let { playerProfileCreditsCount, playerBaseState } = require("%ui/profile/profileState.nut")
let { eventbus_subscribe } = require("eventbus")
let { chocolateRowSafeWatch, chocolateColSafeWatch
} = require("%ui/mainMenu/menus/options/chocolate_matrix_option.nut")
let { creditsTextIcon, monolithTokensTextIcon } = require("%ui/mainMenu/currencyIcons.nut")
let { addModalWindow, removeModalWindow } = require("%ui/components/modalWindows.nut")
let { mintEditState } = require("%ui/mainMenu/raid_preparation_window_state.nut")
let { previewPreset, previewPresetCallbackOverride } = require("%ui/equipPresets/presetsState.nut")
let faComp = require("%ui/components/faComp.nut")

const ANIM_DURATION = 0.1
const WND_UID = "chocolateWnd"

let defGap = hdpx(5)
local isFlipped = false
let defSize = hdpxi(76)

let isPurchaseInProgress = Watched(false)
let isShopState = Watched(false)
let commonData = Watched(null)

eventbus_subscribe("profile_server.buyLots.result", function(_) {
  isPurchaseInProgress.set(false)
})

let slotHeight = inventoryImageParams.slotSize[0]
let hideItemPicker = function() {
  isFlipped = false
  isShopState.set(false)
  removeModalWindow(WND_UID)
}

let mkCompareTooltip = @(item) function() {
  let watch = isAltPressed
  if (!isAltPressed.get())
    return { watch }
  if (item?.itemTemplate == null)
    return { watch }
  return {
    watch
    children = buildInventoryItemTooltip(item)
  }
}

function mkItemPickerSlotActions(chocolateData, item, defItemTemplate, isShopActive) {
  let { itemInSlot = null, onClick = null } = chocolateData
  return {
    onClick = function() {
      if (item?.itemTemplate == null && itemInSlot?.itemTemplate == null) {
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
      if ((itemInSlot?.itemTemplate != defItemTemplate && item?.itemTemplate == defItemTemplate)
        || (item?.itemTemplate == null && itemInSlot?.itemTemplate != null)
      ) {
        if (mintEditState.get())
          onClick?(null, previewPresetCallbackOverride.get())
        else
          fastUnequipItem(itemInSlot)
      }
      else {
        let action = !isShopActive ? onClick?(item, previewPresetCallbackOverride.get())
          : onClick?(item, playerProfileCreditsCount.get(), isPurchaseInProgress,
            playerBaseState.get()?.humanInventoryVolume, inventoryCurrentVolume.get())
        action?()
      }
      hideItemPicker()
    }
    onHover = function(on) {
      let tooltip = buildInventoryItemTooltip(item)
      if (on) {
        if (item?.itemTemplate == null)
          setTooltip(isShopState.get() ? loc("amClean/back") : loc("item/unequipSlot"))
        else {
          setTooltip([
            tooltip
            itemInSlot ? mkCompareTooltip(itemInSlot) : null
          ])
          focusedData.set(item)
        }
        let pcHotkeysHints = hoverPcHotkeysPresentation[ITEM_PICKER.name](item)
        hoverHotkeysWatchedList.set(pcHotkeysHints)
      }
      else {
        setTooltip(null)
        focusedData.set(null)
        hoverHotkeysWatchedList.set(null)
      }
    }
  }
}

function getPickerPositioning(size, chocolateData) {
  let elemPos = chocolateData.event.targetRect
  if (!elemPos)
    return [0, 0]

  let rootSizeWidth = elemPos.r - elemPos.l
  let centerX = elemPos.l + rootSizeWidth / 2
  local posX = (centerX - size[0] * 0.5).tointeger()
  let critPosX = centerX - size[0] / 2
  if (critPosX < (safeAreaHorPadding.get() + fsh(1)))
    posX = (posX + rootSizeWidth + defGap).tointeger()
  local posY = (elemPos.t - size[1]).tointeger() - defGap
  let critPosY = elemPos.t - size[1]
  if (isFlipped || critPosY <= (safeAreaVerPadding.get() + fsh(1))) {
    isFlipped = true
    posY = elemPos.b + defGap
  }
  return [posX, posY]
}

let mkSlotWrapper = @(content) {
  rendObj = ROBJ_VECTOR_CANVAS
  size = [hdpx(50), hdpx(50)]
  color = ItemBdColor
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  commands = [
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
    children = isShopState.get() ? arrowIcon : minusIcon
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
  isShopBtn = true
  onHover = @(on) setTooltip(on ? loc("slot/action/quickPurchase") : null)
  children = mkSlotWrapper(cartIcon)
}

function mkItemPicker(chocolateData, isShopActive) {
  let maxChocolateRowSlots = chocolateRowSafeWatch.get()
  let maxChocolatePageSlots = chocolateRowSafeWatch.get() * chocolateColSafeWatch.get()
  let maxRowsPerPage = maxChocolatePageSlots / maxChocolateRowSlots
  let curPage = Watched(0)
  let { itemsDataArr = [], defaultItem = null, shopData = null, itemInSlot = null } = chocolateData
  let data = []
    .append(defaultItem ?? noItemSlot)
    .extend(itemsDataArr)
  if (shopData != null)
    data.insert(1, shopButton)
  let totalElements = data.len()
  let totalRows = ceil(totalElements.tofloat() / maxChocolateRowSlots)
  let totalPages = ceil(totalElements.tofloat() / maxChocolatePageSlots)
  let maxSlotsPerRow = min(totalElements, maxChocolateRowSlots)
  let maxRowsPerData = min(totalRows, maxRowsPerPage)

  let paginatorsHeight = totalElements <= maxChocolatePageSlots ? 0 : hdpx(29)
  let maxHeight = maxRowsPerData * slotHeight + maxRowsPerData * defGap + paginatorsHeight
  let maxWidth = maxSlotsPerRow * slotHeight + maxSlotsPerRow * defGap - defGap

  let pickerPos = getPickerPositioning([maxWidth, maxHeight], chocolateData)

  let rowsOnLastPage = ceil((totalElements - ((totalPages - 1) * maxChocolatePageSlots)).tofloat() / maxChocolateRowSlots)

  function calcItemPos(idx, rowsPerPage) {
    if (totalElements <= 1)
      return [0, 0]

    let curSlotX = idx % maxChocolateRowSlots
    if (totalElements == 2) {
      let additional = idx == 0 ? 0 : defGap
      return [curSlotX * slotHeight + additional, 0]
    }
    else {
      let col = floor((idx % maxChocolatePageSlots) / maxChocolateRowSlots)
      let rowsCount = isFlipped ? col : (min(rowsPerPage, maxRowsPerPage) - 1 - col)
      return [curSlotX * slotHeight + curSlotX * defGap, rowsCount * slotHeight + rowsCount * defGap]
    }
  }

  let comps = @(rowsPerPage) data.map(function(item, idx) {
    let actions = mkItemPickerSlotActions(chocolateData, item, defaultItem?.itemTemplate, isShopActive)
    let itemPos = calcItemPos(idx, rowsPerPage)

    let { itemTemplate = null, recognizeTimeLeft = -1, isShopBtn = false } = item
    let isRecognizingRequired = recognizeTimeLeft > 0.0
    let itemToUse = itemInSlot?.itemTemplate != null ? item : item.__merge({ needCompareHint = false })
    return button(
      isShopBtn ? shopButton
        : itemTemplate == null ? noItemSlot
        : isRecognizingRequired ? itemRecognizingComp(itemToUse)
        : chocolateInventoryItem(itemToUse),
      actions.onClick,
      {
        key = $"{itemTemplate}_{isRecognizingRequired}_{isShopState.get()}"
        size = [slotHeight, slotHeight]
        pos = itemPos
        onHover = actions.onHover
        behavior = isRecognizingRequired ? null : Behaviors.Button
      }
    )
  })


  local size = [slotHeight, slotHeight]
  if (totalElements > 1) {
    let rows = min(totalRows, maxRowsPerPage)
    let totalHeight = rows * slotHeight + rows * defGap - defGap
    let cols = min(totalElements, maxChocolateRowSlots)
    let totalWidth = cols * slotHeight + cols * defGap - defGap
    size = [totalWidth, totalHeight]
  }

  let pickerAnimation = [
    { prop=AnimProp.scale, from=[0, 0], duration=ANIM_DURATION, play=true }
    { prop=AnimProp.scale, to=[0, 0], duration=0.1, playFadeOut=true }
  ]

  let isLastPage = Computed(@() totalPages == (curPage.get() + 1))
  return function() {
    let rowsPerPage = isLastPage.get() ? rowsOnLastPage : maxRowsPerPage
    let itemsToShow = data.len() == 0 ? noItemSlot : comps(rowsPerPage)
    let children = mkHorizPaginatorList(itemsToShow, maxChocolatePageSlots, curPage,
      { size = !isLastPage.get() ? size : [size[0], rowsOnLastPage * slotHeight + (rowsOnLastPage * defGap ) - defGap] },
      { style = {
          size = [size[0], SIZE_TO_CONTENT]
          gap = hdpx(2)
        }
      })
    return {
      watch = isLastPage
      size = [size[0], SIZE_TO_CONTENT]
      stopMouse = true
      pos = isLastPage.get() ? getPickerPositioning(calc_comp_size(children), chocolateData) : pickerPos
      transform = {}
      animations = pickerAnimation
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
    hotkeys = [[ "^Esc", { action = hideItemPicker } ]]
    onDetach = hideItemPicker
    stopMouse = true
    children = [
      mkLightBox([{l, r, b, t}, isShopState.get() ? [creditsTextIcon, monolithTokensTextIcon] : null])
      mkItemPicker(isShopState.get() && shopData != null ? shopData : commonData.get(), isShopState.get())
      isAltPressedMonitor
    ]
  }
}

function openChocolateWnd(chocolateData) {
  if (previewPreset.get() && !mintEditState.get())
    return
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
