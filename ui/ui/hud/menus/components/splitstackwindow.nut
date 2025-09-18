from "%ui/mainMenu/stdPanel.nut" import screenSize

from "%ui/fonts_style.nut" import sub_txt, body_txt
from "%ui/components/colors.nut" import BtnBgFocused
from "%ui/components/modalPopupWnd.nut" import addModalPopup, removeModalPopup
from "%ui/hud/menus/components/inventoryItemImages.nut" import inventoryItemImage
from "%ui/hud/menus/components/inventoryStyle.nut" import itemHeight
from "%ui/components/commonComponents.nut" import mkText, bluredPanel
from "%ui/components/slider.nut" import Horiz
from "math" import ceil
from "%ui/components/button.nut" import textButton
from "%ui/hud/state/inventory_items_es.nut" import stashItems
from "%ui/hud/state/gametype_state.nut" import isOnPlayerBase
from "das.inventory" import is_inventory_have_free_volume
from "%ui/hud/menus/components/inventoryItemUtils.nut" import findInventoryWithFreeVolume

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { inventoryImageParams } = require("%ui/hud/menus/components/inventoryItemImages.nut")
let { canModifyInventory } = require("%ui/hud/state/inventory_common_es.nut")
let { mutationForbidenDueToInQueueState } = require("%ui/hud/state/inventory_state.nut")
let { backpackEid, safepackEid } = require("%ui/hud/state/hero_extra_inventories_state.nut")
let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")

#allow-auto-freeze

let splitCount = Watched(0)

let contentSize = [hdpx(500), hdpx(310)]
let offset = hdpx(50)
let countWidth = hdpx(40)

function canSplitStack(item) {
  let { itemTemplate = null, isBoxedItem = false, ammoCount = 0, count = 0, inventoryEid = 0 } = item

  if (mutationForbidenDueToInQueueState.get() && (
    inventoryEid == safepackEid.get() ||
    inventoryEid == backpackEid.get() ||
    inventoryEid == controlledHeroEid.get()
  )) {
    return false
  }

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
  size = static [flex(), hdpx(20)]
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
    size = FLEX_H
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      @() {
        watch = splitCount
        hplace = ALIGN_CENTER
        children = mkText(loc("splitStack/move", { count = splitCount.get() }), body_txt)
      }
      {
        size = FLEX_H
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
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  gap = { size = flex() }
  padding = static [0, hdpx(50)]
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
  padding = static [hdpx(10), hdpx(20)]
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
  #forbid-auto-freeze
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

function canAddSplitStackToInventory(item, showSuitableAmmo = false, inventories = null) {
  if (!isOnPlayerBase.get() || mutationForbidenDueToInQueueState.get() || !canModifyInventory.get())
    return false
  let { itemTemplate = null, inventoryEid = 0, boxedItemTemplate = null, ammo = null } = item
  let tempToSearch = showSuitableAmmo
    ? ammo != null ? ammo?.template : boxedItemTemplate
    : itemTemplate
  let itemInStash = stashItems.get().findvalue(@(v) v?.itemTemplate != null && v.itemTemplate == tempToSearch)
  let { isBoxedItem = false, ammoCount = -1, count = -1 } = itemInStash
  if (itemInStash == null || itemInStash?.itemTemplate == null)
    return false
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(itemInStash.itemTemplate)
  let volume = template?.getCompValNullable("item__volume") ?? 0
  let hasVolume = inventories != null
    ? findInventoryWithFreeVolume(volume) != null
    : is_inventory_have_free_volume(inventoryEid, volume)
  if (!hasVolume)
    return false
  let countToUse = isBoxedItem ? ammoCount : count
  if (countToUse < 0)
    return false
  return true
}

return {
  openSplitStacksWindow
  canSplitStack
  canAddSplitStackToInventory
}
