from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
from "math" import cos, sin, PI
from "das.inventory" import get_showroom_item_slot_node_wtm, install_weapon_mod_to_slot, move_equipped_weapon_mod_to_inventory

from "dagor.debug" import logerr
from "dasevents" import EventShowItemInShowroom, EventActivateShowroom, EventCloseShowroom, EventUIMouseMoved,
  EventUIMouseWheelUsed, CmdShowUiMenu, EventShowroomCameraChangedPosition, EventShowroomFadeEnds
from "dagor.math" import Point2
from "%dngscripts/globalState.nut" import nestWatched
from "%ui/mainMenu/stdPanel.nut" import mkCloseBtn
from "%ui/components/commonComponents.nut" import mkText, bluredPanelWindow, mkTextArea
from "%ui/hud/menus/components/inventorySuit.nut" import mkEquipmentSlot, findItemsForSlot
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem
from "%ui/hud/menus/components/itemFromTemplate.nut" import getSlotFromTemplate
from "%ui/components/chocolateWnd.nut" import openChocolateWnd
from "%ui/hud/state/item_info.nut" import get_item_info
from "%ui/hud/menus/components/inventoryItemUtils.nut" import purchaseItemsToSlot, needShowQuickSlotPurchase
from "%ui/options/safeArea.nut" import safeAreaVerPadding, safeAreaHorPadding
from "%ui/hud/menus/components/inventoryItemTooltip.nut" import getInventoryItemTooltipLines
from "eventbus" import eventbus_subscribe
from "%ui/fonts_style.nut" import body_txt, sub_txt
from "%ui/components/scrollbar.nut" import makeVertScroll
import "%ui/components/checkbox.nut" as checkBox

let { stashEid } = require("%ui/state/allItems.nut")

let WEAPON_SHOWROOM_MENU_ID = "WeaponShowroomMenuId"

let inventoryShowroomItem = nestWatched("inventoryShowroomItem", null)
let showroomPreviewSize = { posX = 0, posY = 0, sizeX = 0, sizeY = 0 }

let hideShowroomUi = Watched(null)
let onWeaponPoints = Watched(null)
let pointsInUi = Watched(null)

let hideShowroomUiCheckBox = checkBox(hideShowroomUi, loc("weaponShowroom/hideUi"))

function updateonWeaponPoints() {
  let object = ecs.CompObject()

  let slots = (inventoryShowroomItem.get()?.mods ?? {}).keys()

  get_showroom_item_slot_node_wtm(slots, object)

  onWeaponPoints.set(object?.getAll())
}

ecs.register_es("unpdate_weapon_points_on_camera_position_changed",
  {
    [[EventShowroomCameraChangedPosition]] = @(_evt, _eid, _comp) updateonWeaponPoints(),
    [[EventShowroomFadeEnds]] = function(...) {
      updateonWeaponPoints()
    }
  },
  {
    comps_rq = ["camera__active"]
  },
)

console_register_command(updateonWeaponPoints, "get_showroom_item_slot_node_wtm")

function updateShowroomItem() {
  let data = ecs.CompObject()

  let template = inventoryShowroomItem.get()?.itemTemplate
  if (template == null)
    return

  data["__weapon"] <- template
  data["autorotation"] <- false

  foreach (k, v in inventoryShowroomItem.get()?.modInSlots ?? {}) {
    data[k] <- v.itemTemplate
  }

  ecs.g_entity_mgr.broadcastEvent(EventShowItemInShowroom({ showroomKey="itemShowroom", data }))
  ecs.g_entity_mgr.broadcastEvent(EventActivateShowroom({
    showroomKey="itemShowroom",
    placeScreenPosition=Point2(showroomPreviewSize.posX, showroomPreviewSize.posY),
    placeScreenSize=Point2(showroomPreviewSize.sizeX, showroomPreviewSize.sizeY)
  }))

  gui_scene.resetTimeout(0.1, function() {
    updateonWeaponPoints()
  }, "updateShowroomItemDelay")
}

function updateInventoryShowroomItem() {
  let oldEid = inventoryShowroomItem.get()?.eid
  inventoryShowroomItem.set(get_item_info(oldEid))
}

function getDefaultPointsInUi(posCount, center, slotWidth) {
  let points = []
  let startAt = -posCount / 2 * slotWidth
  for (local i = 0; i < posCount; i++) {
    points.append([center[0] + startAt + i * slotWidth, center[1]])
  }
  return points
}


eventbus_subscribe("profile_server.buyLots.result", function(...) {
  if (inventoryShowroomItem.get() == null)
    return

  gui_scene.resetTimeout(0.1, function() {
    updateInventoryShowroomItem()
    updateShowroomItem()
  }, "updateShowroomItemDelay")
})





let hadrDefinedSlotPositions = {
  magazine = { pos = [sw(50), sh(80)], align = [ALIGN_CENTER, ALIGN_TOP] }
  stock = { pos = [sw(65), sh(70)], align = [ALIGN_CENTER, ALIGN_TOP] }
  silencer = { pos = [sw(10), sh(50)], align = [ALIGN_RIGHT, ALIGN_CENTER] }
  underbarrel = { pos = [sw(25), sh(70)], align = [ALIGN_CENTER, ALIGN_TOP] }
  scope = { pos = [sw(50), sh(20)], align = [ALIGN_CENTER, ALIGN_BOTTOM] }
}


function weaponSlots() {
  if (hideShowroomUi.get()) {
    return { watch = hideShowroomUi }
  }

  local mods = {}
  local modsInSlot = {}

  
  
  
  if (inventoryShowroomItem.get()?.isWeapon) {
    mods = (inventoryShowroomItem.get()?.mods ?? {}).topairs().sort(@(a, _b) a[0] == "magazine" ? 1 : 0)
    modsInSlot = inventoryShowroomItem.get()?.modInSlots ?? {}
  }

  let screenCenter = [ sw(50), sh(90) ]
  let defaultUiPoints = getDefaultPointsInUi(mods.filter(@(_v, k) !hadrDefinedSlotPositions?[k]).len(), screenCenter, hdpx(120))

  let children = []
  let toSave = {}

  local defaultPositionIterator = 0
  for (local i = 0; i < mods.len(); i++) {
    let slotName = mods[i][0]
    if (hadrDefinedSlotPositions?[slotName]) {
      toSave[slotName] <- hadrDefinedSlotPositions[slotName]
    }
    else {
      toSave[slotName] <- defaultUiPoints[defaultPositionIterator]
      defaultPositionIterator++
    }
    let curMod = modsInSlot?[slotName]

    let slotObj = getSlotFromTemplate(mods[i][1]?.slotTemplateName).__update({
      weapUniqueId = inventoryShowroomItem.get()?.uniqueId
      weapModSlotName = slotName
    })
    let itemObj = mkFakeItem(curMod?.itemTemplate, slotObj)

    let onDropFunc = function(item) {
      if (item?.eid == null) {
        move_equipped_weapon_mod_to_inventory(inventoryShowroomItem.get()?.eid, slotName, stashEid.get())
        gui_scene.resetTimeout(0.1, function() {
          updateInventoryShowroomItem()
          updateShowroomItem()
        }, "updateShowroomItemDelay")
        return
      }
      install_weapon_mod_to_slot(item.eid, item?.inventoryEid ?? ecs.INVALID_ENTITY_ID, slotName, inventoryShowroomItem.get()?.eid ?? ecs.INVALID_ENTITY_ID)

      gui_scene.resetTimeout(0.1, function() {
        updateInventoryShowroomItem()
        updateShowroomItem()
      }, "weaponShowroomDelay")
    }

    let onClickFunc = function(event) {
      local fittingItems = null
      fittingItems = findItemsForSlot(itemObj)

      openChocolateWnd({
        event,
        itemsDataArr = fittingItems,
        onClick = @(item, _actions) onDropFunc(item),
        itemInSlot = null
        forceOnClick = true
        shopData = needShowQuickSlotPurchase(itemObj) ? purchaseItemsToSlot(itemObj, event) : null
      })
    }

    children.append({
      pos = toSave[slotName].pos
      size = [1, 1] 
      children = {
        hplace = toSave[slotName].align[0]
        vplace = toSave[slotName].align[1]
        children = mkEquipmentSlot(itemObj, { onClick = onClickFunc })
      }
    })
  }

  pointsInUi.set(toSave)

  return {
    watch = [ inventoryShowroomItem, hideShowroomUi ]
    children
  }
}

function pointsOnWeapon() {
  if (hideShowroomUi.get())
    return { watch = [ hideShowroomUi ] }

  let commands = [ [VECTOR_WIDTH, 1.0] ]

  let circleSize = 2.0
  let circleSizeNorm = [ circleSize / sw(100) * 100, circleSize / sh(100) * 100 ]

  let screenWidth = sw(100)
  let screenHeight = sh(100)

  foreach (slot, onWeaponTable in (onWeaponPoints.get() ?? {})) {
    let pointOnCircle = pointsInUi.get()?[slot].pos
    if (pointOnCircle == null)
      continue

    let pointOnWeapon = onWeaponTable.screenPoint
    let { x, y } = pointOnWeapon
    if (x < 0 || y < 0 || x >= screenWidth || y >= screenHeight)
      continue

    let pointOnCircleNorm = [ pointOnCircle[0].tofloat() / sw(100).tofloat() * 100, pointOnCircle[1].tofloat() / sh(100).tofloat() * 100 ]
    let pointOnWeaponNorm = [ pointOnWeapon.x.tofloat() / sw(100).tofloat() * 100, pointOnWeapon.y.tofloat() / sh(100).tofloat() * 100 ]
    commands.append([
      VECTOR_LINE,
      pointOnCircleNorm[0], pointOnCircleNorm[1],
      pointOnWeaponNorm[0], pointOnWeaponNorm[1]
    ],
      [VECTOR_ELLIPSE, pointOnWeaponNorm[0], pointOnWeaponNorm[1], circleSizeNorm[0], circleSizeNorm[1]],
    )
  }

  return {
    watch = [ onWeaponPoints, pointsInUi, hideShowroomUi ]
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    commands
    opacity = 0.7
  }
}

function mkWeaponDesc() {
  if (hideShowroomUi.get())
    return { watch = hideShowroomUi }
  let weaponStrings = getInventoryItemTooltipLines(inventoryShowroomItem.get())
  let mods = []

  
  
  
  if (inventoryShowroomItem.get()?.isWeapon) {
    foreach (item in inventoryShowroomItem.get()?.modInSlots ?? {}) {
      if (item?.itemTemplate == null)
        continue

      let faked = mkFakeItem(item.itemTemplate)
      mods.append(getInventoryItemTooltipLines(faked))
    }
  }

  let mkDesc = @(strings) {
    size = FLEX_H
    padding = hdpx(10)
    children = [
      mkTextArea(strings, {
          size = FLEX_H
          tagsTable = {
            header = {
              fontSize = body_txt.fontSize
            }
          }
        }
      )
    ]
  }.__update(bluredPanelWindow)

  return {
    watch = [ inventoryShowroomItem, hideShowroomUi ]
    hplace = ALIGN_RIGHT
    vplace = ALIGN_CENTER
    size = [ sw(20), sh(70) ]
    children = makeVertScroll ({
      gap = hdpx(4)
      flow = FLOW_VERTICAL
      size = FLEX_H
      children = [
        mkDesc(weaponStrings)
      ].extend(mods.map(@(v) mkDesc(v)))
    })
  }
}

function mkWeaponShowroomMenu() {
  let mouseCatchPanel = {
    size = flex()
    behavior = [Behaviors.MoveResize, Behaviors.WheelScroll, Behaviors.Button]
    stopMouse = false
    onMoveResize = function(dx, dy, _dw, _dh) {
      ecs.g_entity_mgr.broadcastEvent(EventUIMouseMoved({screenX = dx, screenY = dy}))
      updateonWeaponPoints()
    }
    onWheelScroll = function(value) {
      ecs.g_entity_mgr.broadcastEvent(EventUIMouseWheelUsed({value}))
    }
  }

  let closeBtn = {
    hplace = ALIGN_RIGHT
    pos = static [-fsh(3), fsh(9)]
    children = mkCloseBtn(WEAPON_SHOWROOM_MENU_ID)
  }

  return {
    size = flex()
    children = [
      @() {
        size = flex()
        hplace = ALIGN_CENTER
        vplace = ALIGN_CENTER

        onAttach = function(elem) {
          showroomPreviewSize.posX = elem.getWidth() / 2
          showroomPreviewSize.posY = elem.getHeight() / 2
          showroomPreviewSize.sizeX = elem.getWidth() * 0.55
          showroomPreviewSize.sizeY = elem.getHeight() * 0.55
          updateShowroomItem()
        }
        onDetach = function() {
          ecs.g_entity_mgr.broadcastEvent(EventCloseShowroom())
          inventoryShowroomItem.set(null)
        }

        children = [
          mouseCatchPanel
          closeBtn
        ]
      }
      @() {
        watch = safeAreaVerPadding, safeAreaHorPadding
        pos = [ -safeAreaHorPadding.get(), -safeAreaVerPadding.get() ]
        size = [ sw(100), sh(100) ]
        children = [
          pointsOnWeapon
          weaponSlots
        ]
      }
      mkWeaponDesc
      {
        hplace = ALIGN_RIGHT
        vplace = ALIGN_BOTTOM
        padding = hdpx(30)
        children = hideShowroomUiCheckBox
      }
    ]
  }
}


return {
  WEAPON_SHOWROOM_MENU_ID
  mkWeaponShowroomMenu
  inventoryShowroomItem
}
