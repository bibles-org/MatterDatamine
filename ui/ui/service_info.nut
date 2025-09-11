from "%dngscripts/globalState.nut" import nestWatched

from "dagor.system" import DBGLEVEL
from "%ui/fonts_style.nut" import tiny_txt
from "%ui/fpsBar.nut" import fpsBar, latencyBar
from "net" import has_network
from "gameevents" import EventLevelLoaded
from "app" import get_session_id

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
let { isInPlayerSession } = require("%ui/hud/state/gametype_state.nut")

let platform = require("%dngscripts/platform.nut")



let sessionIdRaw = nestWatched("sessionId", null)
let sessionId = Computed(@() isInPlayerSession.get() ? sessionIdRaw.get() : null )
ecs.register_es( "session_id_ui_es",
  {
    [EventLevelLoaded] = @(_evt, _eid, _comp) sessionIdRaw.set(get_session_id())
  }
)

function sessionIdComp(){
  return {
    text = sessionId.get() == null
      ? null
      : has_network()
        ? sessionId.get()
        : sessionId.get()!="" ? $"F{sessionId.get()}" : null
    rendObj = ROBJ_TEXT
    opacity = 0.5
    color = Color(120,120,120, 100)
    watch = sessionId
  }.__update(tiny_txt)
}


let showFps = mkWatched(persist, "showFps", false)

let showService = Computed(@() platform.is_pc || DBGLEVEL>0 || showFps.get())
function serviceInfo() {
  let children = showService.get() ? [fpsBar, latencyBar] : []
  if (platform.is_pc || platform.is_xbox)
    children.append(sessionIdComp)
  return {
    watch = showService
    flow = FLOW_HORIZONTAL
    vplace = ALIGN_BOTTOM
    gap = hdpx(5)
    padding = static [hdpx(2), hdpx(10)]
    children
  }
}
return {serviceInfo, fpsBar, latencyBar, showFps, sessionId}