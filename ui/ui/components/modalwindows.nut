from "%darg/ui_imports.nut" import *
let JB = require("%ui/control/gui_buttons.nut")

#allow-auto-freeze

let WND_PARAMS = {
  key = null 
  children= null
  onClick = null 

  size = flex()
  behavior = Behaviors.Button
  stopMouse = true
  stopHotkeys = true
  hotkeys = [[$"Esc | {JB.B}"]]
  animations = static [
    { prop=AnimProp.opacity, from=0.0, to=1.0, duration=0.15, play=true, easing=OutCubic }
    { prop=AnimProp.opacity, from=1.0, to=0.0, duration=0.125, playFadeOut=true, easing=OutCubic }
  ]
}
#forbid-auto-freeze
let modalWindows = []
#allow-auto-freeze
let modalWindowsGeneration = Watched(0)
let hasModalWindows = Computed(@() modalWindowsGeneration.get() >= 0 && modalWindows.len() > 0)

function removeModalWindow(key) {
  let idx = modalWindows.findindex(@(w) w.key == key)
  if (idx == null)
    return false
  modalWindows.remove(idx)
  modalWindowsGeneration.modify(@(v) v+1)
  return true
}

local lastWndIdx = 0
function addModalWindow(wnd = null) {
  wnd = WND_PARAMS.__merge(wnd ?? {})
  if (wnd.key != null)
    removeModalWindow(wnd.key)
  else {
    lastWndIdx++
    wnd.key = $"modal_wnd_{lastWndIdx}"
  }
  wnd.onClick = wnd.onClick ?? @() removeModalWindow(wnd.key)
  modalWindows.append(wnd)
  modalWindowsGeneration.modify(@(v) v+1)
}

function hideAllModalWindows() {
  if (modalWindows.len() == 0)
    return
  modalWindows.clear()
  modalWindowsGeneration.modify(@(v) v+1)
}

let modalWindowsComponent = @() {
  watch = modalWindowsGeneration
  size = flex()
  children = modalWindows
}

return {
  addModalWindow
  removeModalWindow
  hideAllModalWindows
  modalWindowsComponent
  hasModalWindows
}

