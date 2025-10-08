import "%ui/navState.nut" as navState
import "%ui/control/gui_buttons.nut" as JB
from "%ui/changelog.ui.nut" import currentPatchnote, patchnoteSelector
from "%ui/components/commonComponents.nut" import textButton, fontIconButton, mkText
from "%ui/control/active_controls.nut" import isGamepad
from "%ui/changeLogState.nut" import chosenPatchnote, curPatchnoteIdx, nextPatchNote, prevPatchNote, updateVersion, markLastSeen
import "%ui/components/colors.nut" as colors
from "%ui/ui_library.nut" import *
from "%ui/fonts_style.nut" import h1_txt
from "%sqstd/string.nut" import utf8ToUpper

let isOpened = mkWatched(persist, "isOpened", false)

let btnStyle = {}

let close = function() {
  markLastSeen()
  isOpened.set(false)
}
let open = @() isOpened.set(true)

let gap = hdpx(10)
let btnNext  = textButton(loc("shop/nextItem"), nextPatchNote,
  btnStyle.__merge({hotkeys = [["Enter"]]}))
let btnClose = textButton(loc("mainmenu/btnClose"), close,
  btnStyle.__merge({hotkeys=[[$"^{JB.B} | Esc"]]}))

let closeBtn = fontIconButton("close", close, {
  skipDirPadNav = true
  hplace = ALIGN_RIGHT
  margin = 0
  hotkeys=[[$"^{JB.B} | Esc", {description=loc("Close")}]]
})

let nextButton = @() {
  minWidth = hdpxi(155)
  children = curPatchnoteIdx.get() != 0 ? btnNext : btnClose
  watch = curPatchnoteIdx
  hplace = ALIGN_RIGHT
  function onAttach(elem) {
    if (isGamepad.get()) {
      move_mouse_cursor(elem, false)
    }
  }
}

let attractorForCursorDirPad = {
  behavior = Behaviors.Button
  size = static [hdpx(50), ph(66)]
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  eventPassThrough = true
}

let hkLB = ["^J:LB | Left", prevPatchNote, loc("shop/previousItem")]
let hkRB = ["^J:RB | Right", nextPatchNote, loc("shop/nextItem")]

let clicksHandler = {
  size = flex()
  eventPassThrough = true
  behavior = Behaviors.Button
  hotkeys = [hkLB, hkRB]
  onClick = nextPatchNote
}

let changelogRoot = @() {
  stopHover = true
  stopMouse = true
  rendObj = ROBJ_WORLD_BLUR_PANEL
  size = flex()
  children = [
    clicksHandler
    {
      rendObj = ROBJ_WORLD_BLUR_PANEL
      fillColor = colors.ConsoleFillColor
      borderColor = colors.ConsoleBorderColor
      borderWidth = static [hdpx(1), 0]
      flow = FLOW_VERTICAL
      children = [
        {size = FLEX_H, flow = FLOW_HORIZONTAL, children = [mkText(utf8ToUpper(loc("gamemenu/btnChangelog")), {margin=[hdpx(8),hdpx(20)]}.__update(h1_txt)), {size = FLEX_H}, closeBtn]}
        currentPatchnote
        @() {
          watch = isGamepad
          size = FLEX_H
          flow = FLOW_HORIZONTAL
          gap
          valign = ALIGN_CENTER
          children = [
            patchnoteSelector
            isGamepad.get() ? null : nextButton
          ]
        }
      ]
    }
    attractorForCursorDirPad
  ]
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  hotkeys = [
    ["Esc | Space", {action=close, description = loc("mainmenu/btnClose")}]
  ]
}

let addLogScene = @() navState.addNavScene(changelogRoot)
if (isOpened.get())
  addLogScene()
isOpened.subscribe_with_nasty_disregard_of_frp_update(function(opened) {
  if (opened) {
    addLogScene()
    return
  }
  updateVersion()
  chosenPatchnote.set(null)
  navState.removeNavScene(changelogRoot)
})

return {
  openChangelog = open
  addLogScene
}
