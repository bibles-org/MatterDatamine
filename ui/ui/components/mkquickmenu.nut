from "%ui/hud/state/interactive_state.nut" import removeInteractiveElement, switchInteractiveElement
from "%ui/fonts_style.nut" import sub_txt, body_txt
from "%ui/components/colors.nut" import ConsoleFillColor, InfoTextDescColor, TextHighlight
from "%ui/components/commonComponents.nut" import mkText, mkTextArea
from "%ui/components/button.nut" import button
from "%ui/components/uiHotkeysHint.nut" import mkHintRow
from "math" import PI, sin, cos, min, tan, abs, sqrt
from "%sqstd/underscore.nut" import partition
from "%ui/ui_library.nut" import *

let { showCursor } = require("%ui/cursorState.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")









#allow-auto-freeze

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
let vGap = hdpx(6)



#forbid-auto-freeze
let usedPieMenus = {}
#allow-auto-freeze

function mkFramedHotkey(hotkey, handler=null) {
  return {
    hotkeys = handler!=null ? [[hotkey, {action=handler, description={skip=true}}]] : null
    children = mkHintRow(hotkey, { fontSize = sub_txt.fontSize })
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
      mkText(text, { color = InfoTextDescColor })
    ]
  }
}

let mkEmptyBlock = @(emptyHint, header, hotkeysComp) emptyHint == null ? null : {
  rendObj = ROBJ_WORLD_BLUR_PANEL
  size = [hdpx(200), SIZE_TO_CONTENT]
  fillColor = ConsoleFillColor
  padding = hdpx(10)
  margin = sh(10)
  halign = ALIGN_CENTER
  flow = FLOW_VERTICAL
  gap = vGap
  hplace = ALIGN_RIGHT
  vplace = ALIGN_BOTTOM
  children = [
    header != null ? mkText(header, { color = TextHighlight }.__merge(body_txt)) : null
    mkTextArea(emptyHint, { halign = ALIGN_CENTER })
    hotkeysComp
  ]
}

function mkQMenu(getPieMenuItems, close, id, header = null, emptyHint = null) {
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
      id == "EmotesUI" || id == "grenadeSelectionWnd" ? null
        : mkHotkeyWithText("@HUD.Interactive", loc("controls/HUD.Interactive"))
    ]
  }

  let mkMkItem = @(params=null) function(item, idx) {
    let {action, text, hotkey_idx = null, icon = null } = item
    let stateFlags = Watched(0)
    let group = ElemGroup()
    let total = getPieMenuItems().len()
    let hotkey = isGamepad.get() ? cfgByAmount?[total][hotkey_idx] ?? cfgByAmount[8]?[hotkey_idx]
      : hotkeyKbdMap?[hotkey_idx]
    let btnText = mkText(text, {
      size = FLEX_H
      behavior = Behaviors.Marquee
      scrollOnHover = true
      speed = hdpx(50)
      group
    })

    function onClick() {
      action()
      close()
    }
    let hotkeyComp = hotkey!= null ? mkFramedHotkey(hotkey, onClick) : null

    return @() {
      watch = showCursor
      size = FLEX_H
      children = button(
        {
          size = FLEX_H
          flow = FLOW_HORIZONTAL
          gap = hdpx(4)
          valign = ALIGN_CENTER
          vplace = ALIGN_CENTER
          children = [icon, btnText, hotkeyComp]
        }.__update(params)
        onClick,
        {
          size = FLEX_H
          padding = static [hdpx(2), hdpx(4)]
          isInteractive = showCursor.get()
          key = idx
          stateFlags
        }, group
      )
    }
  }
  let mkLeftItem = mkMkItem({hplace = ALIGN_RIGHT})
  let mkRightItem = mkMkItem({})

  function mkColumn(items, left = false) {
    return {
      size = static [hdpx(250), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap = vGap
      children = items.map(left ? mkLeftItem : mkRightItem)
    }.__update(left ? {halign = ALIGN_RIGHT} : {})
  }

  return function() {
    let pieMenuItems = getPieMenuItems().map(@(v, idx) v.__merge({hotkey_idx = idx}))
    let n = pieMenuItems.len()
    if (n == 0)
      return mkEmptyBlock(emptyHint, header, hotkeysComp)
    let bottomElem = n==4 || n==6 ? pieMenuItems[pieMenuItems.len()-1] : null
    let itemsForCols = bottomElem ? pieMenuItems.slice(0, bottomElem ? n-1 : n) : pieMenuItems
    let [leftItems, rightItems] = partition(itemsForCols, @(_, idx) idx%2==0)
    return {
      watch = isGamepad
      size = flex()
      onDetach = @() removeInteractiveElement(QuickMenuId)
      behavior = DngBhv.ActivateActionSet
      actionSet = "BigMap"
      padding = sh(10)
      halign = ALIGN_RIGHT
      valign = ALIGN_BOTTOM
      children = [
        {
          rendObj = ROBJ_WORLD_BLUR_PANEL
          fillColor = ConsoleFillColor
          padding = [hdpx(4), hdpx(10)]
          halign = ALIGN_CENTER
          flow = FLOW_VERTICAL
          gap = vGap
          children = [
            header != null ? mkText(header, { color = TextHighlight }.__merge(body_txt)) : null
            {
              flow = FLOW_HORIZONTAL
              gap = hdpx(10)
              children = [mkColumn(leftItems, true), mkColumn(rightItems)]
            }
            hotkeysComp
          ]
        },
        {hotkeys = [[$"^Esc | {JB.B}", {action = close, description=loc("mainmenu/btnClose")}]], eventHandlers}
      ]
    }
  }
}

return {mkQMenu}