import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { h1_txt, body_txt } = require("%ui/fonts_style.nut")
let { textButton } = require("%ui/components/button.nut")
let { logOut } = require("%ui/login/login_state.nut")
let { addInteractiveElement, removeInteractiveElement } = require("%ui/hud/state/interactive_state.nut")
let { mkAnimText } = require("%ui/components/per_character_animation.nut")


let showConnectionInProgressScreen = Watched(false)
let connectionInProgressMsgDelayed = Watched(false)

function back() {
  showConnectionInProgressScreen.set(false)
  connectionInProgressMsgDelayed.set(false)
  logOut()
}

let connectionDelayedMsg = @() connectionInProgressMsgDelayed.set(true)
let connectionInProgressMsg = @() showConnectionInProgressScreen.set(true)

ecs.register_es("check_profile_is_loaded_profile_es", {
    [["onInit", "onChange"]] = function(_eid, comp){
      if (!comp.player_profile__isLoaded) {
        gui_scene.setTimeout(3, connectionInProgressMsg)
        gui_scene.setTimeout(15, connectionDelayedMsg)
      }
      else {
        showConnectionInProgressScreen.set(false)
        connectionInProgressMsgDelayed.set(false)
        gui_scene.clearTimer(connectionInProgressMsg)
        gui_scene.clearTimer(connectionDelayedMsg)
      }
    }
    onDestroy = function(...) {
      gui_scene.clearTimer(connectionDelayedMsg)
      gui_scene.clearTimer(connectionInProgressMsg)
    }
  },
  { comps_track=[["player_profile__isLoaded", ecs.TYPE_BOOL]] },
  { tags="gameClient" }
)

let mkAnimationBig = function(delay) {
  return [
    { prop=AnimProp.opacity, from=1, to=0.5, duration=5, easing=CosineFull, play=true, loop=true, delay=delay }
  ]
}

let initialTime = 1
let mkAnimationSmall = function(delay) {
  return [
    { prop=AnimProp.opacity, from=0, to=1, duration=initialTime, easing=InCubic, play=true}
    { prop=AnimProp.opacity, from=1, to=0.5, duration=5, easing=CosineFull, play=true, loop=true, delay=delay + initialTime }
  ]
}

function connectionInProgressScreen() {
  return {
    watch = [showConnectionInProgressScreen, connectionInProgressMsgDelayed]
    size = flex()
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    valign = ALIGN_CENTER
    children = showConnectionInProgressScreen.get() ? [
      mkAnimText(loc("login/profileConnectionProgress"), mkAnimationBig, h1_txt),
      connectionInProgressMsgDelayed.get()
        ? mkAnimText(loc("login/profileConnectionDelayed"), mkAnimationSmall, body_txt)
        : {rendObj = ROBJ_TEXT, fontSize = body_txt.fontSize},
      connectionInProgressMsgDelayed.get()
        ? textButton(loc("login/return"), back, {
            hplace = ALIGN_CENTER
            vplace = ALIGN_TOP
            size = [SIZE_TO_CONTENT, sh(5)]
            onAttach = @() addInteractiveElement("connectionInProgressScreen")
            onDetach = @() removeInteractiveElement("connectionInProgressScreen")
            margin = sh(5)
            animations = [{ prop=AnimProp.opacity, from=0, to=1, duration=initialTime, easing=InCubic, play=true }]
            padding = [0, sh(5), 0, sh(5)]
            sound = { click = "ui_sounds/interface_back" }
        })
        : { size = [SIZE_TO_CONTENT, sh(5)], margin = sh(5) }
    ] : null
  }
}

return connectionInProgressScreen