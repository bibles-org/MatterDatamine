from "%dngscripts/sound_system.nut" import sound_play

from "%ui/ui_library.nut" import *

let POPUP_PARAMS = {
  id = ""
  text = ""
  styleName = ""
  showTime = 10.0
  onClick = null 
}

const MAX_POPUPS = 3
let popups = []
let popupsGen = Watched(0)
local counter = 0 

let POPUP_DEFAULT_SOUND = "ui_sounds/notification"

let popupSound = {
  error = "ui_sounds/notification"
}

function removePopup(id) {
 
  let idx = popups.findindex(@(p) p.id == id)
  if (idx == null)
    return
  popups.remove(idx)
  popupsGen.set(popupsGen.get()+1)
}

function addPopup(config) {
  let uid = counter++
  if (config?.id != null)
    removePopup(config.id)
  else
    config.id <- $"_{uid}"

  if (popups.len() >= MAX_POPUPS)
    popups.remove(0)

  let popup = POPUP_PARAMS.__merge(config)
  let sound = popupSound?[popup.styleName] ?? POPUP_DEFAULT_SOUND
  sound_play(sound)

  popup.click <- function() {
    popup.onClick?()
    removePopup(popup.id)
  }

  popup.visibleIdx <- Watched(-1)
  popup.visibleIdx.subscribe(function(_newVal) {
    popup.visibleIdx.unsubscribe(callee())
    gui_scene.setInterval(popup.showTime,
      function() {
        gui_scene.clearTimer(callee())
        removePopup(popup.id) 
      }, uid)
    })

  popups.append(popup)
  popupsGen.set(popupsGen.get()+1)
}

console_register_command(@() addPopup({ text = $"Default popup\ndouble line {counter}" }),
  "popup.add")
console_register_command(@() addPopup({ text = $"Default error popup\nnext line {counter}", styleName = "error" }),
  "popup.error")

let getPopups = @() clone popups

return {
  getPopups
  addPopup
  removePopup
  popupsGen
}