from "%ui/fonts_style.nut" import h1_txt, body_txt
from "%sqGlob/userInfoState.nut" import userInfo
from "%ui/components/per_character_animation.nut" import mkAnimText
from "dasevents" import CmdForceLoadProfile

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *



let showConnectionInProgressScreen = Watched(false)

userInfo.subscribe(@(v) v == null ? showConnectionInProgressScreen.set(false) : null)

let connectionInProgressMsg = @() showConnectionInProgressScreen.set(true)

ecs.register_es("load_profile_server_data_es", {
    onInit = function(_eid, comp) {
      if (!comp.player_profile__isLoaded) {
        ecs.g_entity_mgr.broadcastEvent(CmdForceLoadProfile())
      }
    }
  },
  { comps_ro=[["player_profile__isLoaded", ecs.TYPE_BOOL]] },
  { tags="gameClient" }
)

ecs.register_es("check_profile_is_loaded_profile_es", {
    [["onInit", "onChange"]] = function(_eid, comp){
      if (!comp.player_profile__isLoaded) {
        gui_scene.setTimeout(3, connectionInProgressMsg)
      }
      else {
        showConnectionInProgressScreen.set(false)
        gui_scene.clearTimer(connectionInProgressMsg)
      }
    }
    onDestroy = @(...) gui_scene.clearTimer(connectionInProgressMsg)
  },
  { comps_track=[["player_profile__isLoaded", ecs.TYPE_BOOL]] },
  { tags="gameClient", after="load_profile_server_data_es" }
)

let mkAnimationBig = function(delay) {
  return [
    { prop=AnimProp.opacity, from=1, to=0.5, duration=5, easing=CosineFull, play=true, loop=true, delay=delay }
  ]
}

function connectionInProgressScreen() {
  return {
    watch = [showConnectionInProgressScreen]
    size = flex()
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    valign = ALIGN_CENTER
    children = showConnectionInProgressScreen.get() ? [
      mkAnimText(loc("login/profileConnectionProgress"), mkAnimationBig, h1_txt)
      mkAnimText(loc("login/profileConnectionProgress2"), mkAnimationBig, body_txt)
    ] : null
  }
}

return connectionInProgressScreen