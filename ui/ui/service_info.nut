from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let {DBGLEVEL} = require("dagor.system")
let {tiny_txt} = require("%ui/fonts_style.nut")
let {fpsBar, latencyBar} = require("fpsBar.nut")
let platform = require("%dngscripts/platform.nut")

let {has_network} = require("net")
let {EventLevelLoaded} = require("gameevents")
let { get_session_id } = require("app")
let { nestWatched } = require("%dngscripts/globalState.nut")


let sessionId = nestWatched("sessionId", null)
ecs.register_es( "session_id_ui_es",
  {
    [EventLevelLoaded] = @(_evt, _eid, _comp) sessionId.update(has_network() ? get_session_id() : null)
  }
)

function sessionIdComp(){
  return {
    text = sessionId.value
    rendObj = ROBJ_TEXT
    opacity = 0.5
    color = Color(120,120,120, 100)
    watch = sessionId
  }.__update(tiny_txt)
}


let showFps = mkWatched(persist, "showFps", false)

let showService = Computed(@() platform.is_pc || DBGLEVEL>0 || showFps.value)
function serviceInfo() {
  let children = showService.value ? [fpsBar, latencyBar] : []
  if (platform.is_pc || platform.is_xbox)
    children.append(sessionIdComp)
  return {
    watch = showService
    flow = FLOW_HORIZONTAL
    vplace = ALIGN_BOTTOM
    gap = hdpx(5)
    padding = [hdpx(2), hdpx(10)]
    children
  }
}
return {serviceInfo, fpsBar, latencyBar, showFps, sessionId}