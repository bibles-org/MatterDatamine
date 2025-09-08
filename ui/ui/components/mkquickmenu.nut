from "math" import PI, sin, cos, min, tan, abs, sqrt
from "%sqstd/underscore.nut" import partition
from "%ui/ui_library.nut" import *

let { h2_txt, body_txt } = require("%ui/fonts_style.nut")
let { ConsoleFillColor } = require("%ui/components/colors.nut")
let { mkText } = require("%ui/components/commonComponents.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { button } = require("%ui/components/button.nut")
let { removeInteractiveElement, hudIsInteractive,
  switchInteractiveElement } = require("%ui/hud/state/interactive_state.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let { mkHintRow } = require("%ui/components/uiHotkeysHint.nut")









let hotkeyKbdMap = ["1","2","3","4","5","6","7","8","9","0","-","=",
  "L.Shift 1","L.Shift 2", "L.Shift 3", "L.Shift 4", "L.Shift 5", "L.Shift 6", "L.Shift 7", "L.Shift 8", "L.Shift 9", "L.Shift 0", "L.Shift -", "L.Shift =",
  "L.Ctrl 1", "L.Ctrl 2", "L.Ctrl 3", "L.Ctrl 4", "L.Ctrl 5", "L.Ctrl 6", "L.Ctrl 7", "L.Ctrl 8", "L.Ctrl 9", "L.Ctrl 0", "L.Ctrl -", "L.Ctrl =",
]
let cfgByAmount = {
  [1] = ["J:D.Up"],
  [2] = ["J:D.Up", "J:D.Down"],
  [3] = ["J:D.Up", "J:D.Left", "J:D.Right" ],
  [4] = ["J:D.Up", "J:D.Left", "J:D.Right", "J:D.Down"],
  [5] = ["J:D.Up", "J:D.Left", "J:D.Right", "J:X", "J:D.Down" ],
  [6] = ["J:D.Up", "J:D.Left", "J:D.Right", "J:X", "J:Y", "J:D.Down" ],
  [7] = ["J:D.Up", "J:D.Left", "J:D.Right", "J:X", "J:Y", "J:LB", "J:D.Down" ],
  [8] = ["J:D.Up", "J:D.Left", "J:D.Right", "J:X", "J:Y", "J:LB", "J:RB", "J:D.Down" ],
}

const QuickMenuId = "QuickMenu"
let vGap = hdpx(4)


let itemTxtHgt = calc_str_box(mkText("A", body_txt))[1]
let usedPieMenus = {}

function mkFramedHotkey(hotkey, handler=null) {
  return {
    padding = [hdpx(1), hdpx(5)]
    hotkeys = handler!=null ? [[hotkey, {action=handler, description={skip=true}}]] : null
    pos = [0, hdpx(2)]
    children = mkHintRow(hotkey)
  }
}

function mkHotkeyWithText(hotkey, text, handler=null) {
  let hotkeyComp = mkFramedHotkey(hotkey, handler)
  return {
    flow = FLOW_HORIZONTAL
    gap = hdpx(5)
    valign = ALIGN_CENTER
    children = [
      hotkeyComp
      mkText(text, body_txt)
    ]
  }
}


function mkQMenu(getPieMenuItems, close, id, header=null) {
  assert(id not in usedPieMenus, $"{id} already registered!")
  usedPieMenus[id] <- true

  let eventHandlers = {
    ["HUD.Interactive"] = @(_event) switchInteractiveElement(QuickMenuId),
    ["HUD.Interactive:end"] = function(event) {
      if ((event?.dur ?? 0) > 500 || event?.appActive == false)
        removeInteractiveElement(QuickMenuId)
    }
  }

  let hotkeysComp = {
    flow = FLOW_VERTICAL
    gap = hdpx(2)
    halign = ALIGN_CENTER
    children = [
      mkHotkeyWithText("Esc", loc("mainmenu/btnClose")),
      id == "EmotesUI" ? null : mkHotkeyWithText("@HUD.Interactive", loc("controls/HUD.Interactive"))
    ]
  }

  let mkMkItem = @(params=null) function(item, idx) {
    let {action, text, hotkey_idx=null, icon=null, iconAspectRatio = null} = item
    let total = getPieMenuItems().len()
    let hotkey = isGamepad.get() ? cfgByAmount?[total][hotkey_idx] ?? cfgByAmount[8]?[hotkey_idx]
      : hotkeyKbdMap?[hotkey_idx]
    let btnText = mkText(text, body_txt)
    function onClick() {
      action()
      close()
    }
    let hotkeyComp = hotkey!= null ? mkFramedHotkey(hotkey, onClick) : null
    let iconComp = icon==null ? null : {
      rendObj = ROBJ_IMAGE
      size = [iconAspectRatio==null ? itemTxtHgt : iconAspectRatio*itemTxtHgt, itemTxtHgt]
      image = Picture(icon)
    }
    return @() {
      watch = hudIsInteractive
      children = button(
        {
          minWidth = sw(15)
          flow = FLOW_HORIZONTAL
          gap = hdpx(10)
          valign = ALIGN_CENTER
          padding = [hdpx(1), hdpx(4)]
          children = [iconComp, btnText, hotkeyComp]
        }.__update(params ?? {})
        onClick,
        {
          padding = hdpx(4)
          isInteractive = hudIsInteractive.get()
          key = idx
        }
      )
    }
  }
  let mkLeftItem = mkMkItem({hplace = ALIGN_RIGHT, halign = ALIGN_RIGHT})
  let mkRightItem = mkMkItem({})
  let mkTopItem = mkMkItem({halign = ALIGN_CENTER})
  let mkBottomItem = mkMkItem({halign = ALIGN_CENTER})

  function mkColumn(items, left = false) {
    return {
      flow = FLOW_VERTICAL
      gap = vGap
      children = items.map(left ? mkLeftItem : mkRightItem)
    }.__update(left ? {halign = ALIGN_RIGHT} : {})
  }

  let gapElem = {size = [0, hdpx(10)]}

  return function() {
    let pieMenuItems = getPieMenuItems().map(@(v, idx) v.__merge({hotkey_idx = idx}))
    let n = pieMenuItems.len()
    if (n==0)
      return null
    let bottomElem = n==4 || n==6 ? pieMenuItems[pieMenuItems.len()-1] : null
    let topElem = (n%2==1 && n<14) || n==4 || n==6 ? pieMenuItems[0] : null
    let itemsForCols = topElem || bottomElem ? pieMenuItems.slice(topElem ? 1 : 0, bottomElem ? n-1 : n) : pieMenuItems
    let [leftItems, rightItems] = partition(itemsForCols, @(_, idx) idx%2==0)
    return {
      size = flex()
      onDetach = @() removeInteractiveElement(QuickMenuId)
      behavior = DngBhv.ActivateActionSet
      actionSet = "BigMap"
      padding = sh(10)
      halign = ALIGN_RIGHT
      valign = ALIGN_BOTTOM
      watch = isGamepad
      children = [
        {
          rendObj = ROBJ_WORLD_BLUR_PANEL
          fillColor = ConsoleFillColor
          padding = hdpx(10)
          halign = ALIGN_CENTER
          flow = FLOW_VERTICAL
          gap = vGap
          children = [
            header !=null ? mkText(header, h2_txt) : null
            gapElem
            topElem ? { children = mkTopItem(topElem, 0) hplace = ALIGN_CENTER} : null
            {
              flow = FLOW_HORIZONTAL
              gap = hdpx(20)
              children = [mkColumn(leftItems, true), mkColumn(rightItems)]
            }
            bottomElem ? { children = mkBottomItem(bottomElem, n-1) hplace = ALIGN_CENTER} : null
            gapElem
            hotkeysComp
          ]
        },
        {hotkeys = [[$"Esc | {JB.B}", {action = close, description=loc("mainmenu/btnClose")}]], eventHandlers}
      ]
    }
  }
}

return {mkQMenu}