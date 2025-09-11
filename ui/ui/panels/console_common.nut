from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
from "dasevents" import CmdStartConsoleBlinking, CmdStopConsoleBlinking
from "%ui/mainMenu/notificationMark.nut" import mkNotificationCircle


let panelsFlashingTimings = {}
let numTimings = Watched(0)

ecs.register_es("panels_flashing_timings",
  {
    [["onInit", "onChange"]] = function(_evt, _eid, comp) {
      let name = comp.screen_light__panelName
      if (name in panelsFlashingTimings) {
        panelsFlashingTimings[name].set(comp.light__brightness)
      }
      else {
        panelsFlashingTimings[name] <- Watched(comp.light__brightness)
        numTimings.modify(@(n) n + 1)
      }
    }
  },
  {
    comps_track = [["light__brightness", ecs.TYPE_FLOAT]]
    comps_ro = [["screen_light__panelName", ecs.TYPE_STRING]]
  }
)

#allow-auto-freeze
let textColor = Color(227, 109, 0, 255)
const consoleFontSize = 12
const consoleTitleFontSize = 22

let waitingCursor = static {
  rendObj = ROBJ_TEXT text = ">", color=textColor,
  animations=[{ prop=AnimProp.opacity,  from=0.0, to=1.0, duration=1,  play=true, loop=true, easing=OutStep }]
  fontSize = consoleFontSize
}


let inviteText = static {
  rendObj = ROBJ_TEXTAREA behavior = Behaviors.TextArea text = loc("missions/console/invite", "Waiting for commands. Tap with your smartwatch to start"), size = FLEX_H color=textColor
  fontSize = consoleFontSize
}

function mkStdPanel(canvasSize, data=static {}, override=null) {
  return {
    
    worldAnchor   = PANEL_ANCHOR_ENTITY
    worldGeometry = PANEL_GEOMETRY_RECTANGLE
    canvasSize
    
    color = Color(0,0,0,255)
    size = [canvasSize[0], canvasSize[1]]
  }.__update(data, override ?? static {})
}

let flashingScreen = @(panelName) @() (panelName in panelsFlashingTimings) ? {
  rendObj = ROBJ_SOLID, size = flex()
  color = textColor
  watch = panelsFlashingTimings[panelName]
  opacity = panelsFlashingTimings[panelName].get()
} : { watch=numTimings }

let mkInviteText = @(text) {
  rendObj = ROBJ_TEXTAREA behavior=Behaviors.TextArea color=textColor fontSize = consoleTitleFontSize, size = flex()
  halign = ALIGN_CENTER
  text
  margin = static [5, 10]
  animations = static [{prop=AnimProp.opacity from = 0, to = 1 duration = 0.5 play = true loop = true easing=CosineFull}]
  fontFx = FFT_BLUR
  fontFxColor = Color(0,0,0,120)
}

let mkFlashingInviteTextScreen = @(text, panel_name) freeze({
  size = flex(),
  children = [ flashingScreen(panel_name), mkInviteText(text) ],
  onAttach = @() ecs.g_entity_mgr.broadcastEvent(CmdStartConsoleBlinking({panelName=panel_name})),
  onDetach = @() ecs.g_entity_mgr.broadcastEvent(CmdStopConsoleBlinking({panelName=panel_name}))
})

function mkNotificationIndicator(notificationWatch=null) {
  return function() {
    let val = notificationWatch?.get()?.notificationsCount != null ? notificationWatch?.get().notificationsCount : notificationWatch?.get()
    let notificationsType = notificationWatch?.get()?.notificationsType ?? "reward"
    let isReward = notificationsType == "reward"
    let show = (val ?? 0) > 0
    return {
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      watch = notificationWatch
      size = show ? 16 : 0
      key = show
      children = show ? [
        static mkNotificationCircle([47, 52])
        static { size = 12 children=mkNotificationCircle([47, 52], Color(130,130,130,10)) animations = [{prop=AnimProp.opacity from = 0.3, to = 0.9 duration = 1.0 play = true loop = true easing=CosineFull}]}

        isReward ? {
          vplace = ALIGN_CENTER
          hplace = ALIGN_CENTER
          rendObj = ROBJ_TEXT
          text = val
          color = Color(0,0,0)
          fontSize = consoleFontSize
        } : null
      ] : null
    }
  }
}

return static {
  textColor
  consoleFontSize
  consoleTitleFontSize
  waitingCursor
  inviteText
  mkStdPanel
  mkFlashingInviteTextScreen
  mkInviteText
  flashingScreen
  mkNotificationIndicator
}