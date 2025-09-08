from "%ui/ui_library.nut" import *

let { sub_txt, body_txt } = require("%ui/fonts_style.nut")
let { BtnBgFocused } = require("%ui/components/colors.nut")
let { addModalPopup, removeModalPopup } = require("%ui/components/modalPopupWnd.nut")
let { screenSize } = require("%ui/mainMenu/stdPanel.nut")
let { inventoryItemImage, inventoryImageParams} = require("inventoryItemImages.nut")
let { itemHeight } = require("%ui/hud/menus/components/inventoryStyle.nut")
let { mkText, bluredPanel } = require("%ui/components/commonComponents.nut")
let { Horiz } = require("%ui/components/slider.nut")
let { ceil } = require("math")
let { textButton } = require("%ui/components/button.nut")
let { canModifyInventory } = require("%ui/hud/state/inventory_common_es.nut")

let splitCount = Watched(0)

let contentSize = [hdpx(500), hdpx(310)]
let offset = hdpx(50)
let countWidth = hdpx(30)

function canSplitStack(item) {
  let { itemTemplate = null, isBoxedItem = false, ammoCount = 0, count = 0 } = item
  let itemCount = isBoxedItem ? ammoCount : count
  if (itemTemplate == null || itemCount <= 1 || !canModifyInventory.get())
    return false
  return true
}

function mkCountBlock(item) {
  let { isBoxedItem = false, ammoCount = 0, count = 0 } = item
  let itemCount = isBoxedItem ? ammoCount : count
  return {
    rendObj = ROBJ_BOX
    fillColor = Color(67, 67, 67)
    borderRadius = [0, 0, hdpx(5), 0]
    children = {
      rendObj = ROBJ_TEXT
      text = $"{loc("ui/multiply")}{itemCount}"
      padding = hdpx(3)
    }.__update(sub_txt)
  }
}

let mkItemToShow = @(item) {
  rendObj = ROBJ_SOLID
  size = [itemHeight, itemHeight]
  color = Color(40,40,40,210)
  children = [
    inventoryItemImage(item, inventoryImageParams)
    mkCountBlock(item)
  ]
}

let wndTitle = mkText(loc("splitStacks/header"), body_txt)

let mkSlider = @(maxCount) {
  size = [flex(), hdpx(20)]
  children = Horiz(splitCount, {
    min = 1
    max = maxCount
    step = 1
    setValue = @(v) splitCount.set(v.tointeger())
    bgColor = BtnBgFocused
  })
}

let function mkSldierBlock(item) {
  let { isBoxedItem, ammoCount, count } = item
  let itemCount = isBoxedItem ? ammoCount : count
  let maxCount = itemCount
  splitCount.set(ceil(itemCount / 2.0))
  return {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      @() {
        watch = splitCount
        hplace = ALIGN_CENTER
        children = mkText(loc("splitStack/move", { count = splitCount.get() }), body_txt)
      }
      {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        gap = hdpx(20)
        valign = ALIGN_CENTER
        children = [
          mkText("1", {
            size = [countWidth, SIZE_TO_CONTENT]
            halign = ALIGN_RIGHT
          }.__update(body_txt))
          mkSlider(maxCount)
          mkText(maxCount, {
            size = [countWidth, SIZE_TO_CONTENT]
            halign = ALIGN_LEFT
          }.__update(body_txt) )
        ]
      }
    ]
  }
}

let mkItemBlock = @(item) {
  flow = FLOW_VERTICAL
  gap = hdpx(2)
  halign = ALIGN_CENTER
  children = [
    mkItemToShow(item)
    mkText(loc(item?.itemName ?? ""))
  ]
}

let mkButtonsBlock = @(item, cb) {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  gap = { size = flex() }
  padding = [0, hdpx(50)]
  children = [
    textButton(loc("item/action/move"), function () {
      removeModalPopup(item.itemTemplate)
      cb(splitCount.get().tointeger())
    })
    textButton(loc("Cancel"), function () {
      removeModalPopup(item.itemTemplate)
    })
  ]
}

let mkSplitStackWindow = @(item, cb) {
  behavior = Behaviors.Button
  onClick = @() null
  stopMouse = true
  stopHover = true
  size = contentSize
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  flow = FLOW_VERTICAL
  gap = hdpx(10)
  padding = [hdpx(10), hdpx(20)]
  children = [
    wndTitle
    mkItemBlock(item)
    mkSldierBlock(item)
    mkButtonsBlock(item, cb)
  ]
}.__update(bluredPanel)

function openSplitStacksWindow(item, cb) {
  if (item?.itemTemplate == null)
    return
  let uid = item?.itemTemplate
  let { x, y } = get_mouse_cursor_pos()
  let posToAppear = [x - contentSize[0] / 2, y - contentSize[1] / 2]
  for (local i = 0; i < posToAppear.len(); i++) {
    let wndBorder = posToAppear[i] + contentSize[i] / 2 + offset
    if (wndBorder > screenSize[i])
      posToAppear[i] = screenSize[i] - (contentSize[i] / 2 + offset)
  }
  addModalPopup(posToAppear, {
    uid
    size = flex()
    popupHalign = ALIGN_CENTER
    popupOffset = 0
    children = mkSplitStackWindow(item, cb)
  })
}

return {
  openSplitStacksWindow
  canSplitStack
}
