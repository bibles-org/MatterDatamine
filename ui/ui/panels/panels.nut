from "%dngscripts/globalState.nut" import nestWatched
from "dagor.math" import Point2, Point3
from "%ui/panels/smartwatch_panel.nut" import mkSmartwatchOnboardingInitializationPanel
from "%ui/panels/craft_panel.nut" import mkCraftPanel, mkCraftNotifications
from "%ui/panels/refine_panel.nut" import mkRefinePanel, mkRefinerNotifications
from "%ui/panels/contacts_panel.nut" import mkContactsPanel
from "%ui/panels/market_panel.nut" import mkMarketPanel
from "%ui/panels/raid_panel.nut" import mkMissionsPanel, mkMissionsNotifications
from "%ui/panels/monolith_panel.nut" import mkMonolithPanel, mkMonolithNotification
from "%ui/panels/console_common.nut" import mkStdPanel, waitingCursor, inviteText, mkNotificationIndicator
import "%dngscripts/ecs.nut" as ecs
from "dasevents" import CmdStartConsoleNotificationLight, CmdStopConsoleNotificationLight
from "%ui/ui_library.nut" import *

let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")

let mkNotificationLed = @(notifications) { hplace = ALIGN_RIGHT pos = [-10, 10] children = mkNotificationIndicator(notifications) }


let panels = nestWatched("ui_panels", [])
let mkDefaultPanel = @(canvasSize, data, notifier=null) mkStdPanel(canvasSize, data.__merge({
    worldAnchorEntity = data.eid, color = Color(0,0,0,0), rendObj = ROBJ_SOLID
    children = [
      @() {
        size = flex()
        watch = isOnboarding
        flow = FLOW_VERTICAL
        children = isOnboarding.get() ? [notifier] : [
          static {size = flex()}
          inviteText
          waitingCursor
        ]
      }
      notifier
    ]
  }))

let panelByName = {
  "default" : [mkDefaultPanel]
  "smartwatch_onboarding_initialization" : [mkSmartwatchOnboardingInitializationPanel]
  "craft_panel" : [mkCraftPanel, mkCraftNotifications]
  "refine_panel" : [mkRefinePanel, mkRefinerNotifications]
  "missions_panel" : [mkMissionsPanel, mkMissionsNotifications]
  "leaderboard_panel" : [mkMonolithPanel, mkMonolithNotification]
  "intercom": [mkContactsPanel]
  "market": [mkMarketPanel]
}

let reactToNotificationStateChange = function(value, panel_eid) {
  let numNotifs = value?.notificationsCount ?? value ?? 0
  if (type(numNotifs) == "integer" && numNotifs > 0)
    ecs.g_entity_mgr.sendEvent(panel_eid, CmdStartConsoleNotificationLight())
  else
    ecs.g_entity_mgr.sendEvent(panel_eid, CmdStopConsoleNotificationLight())
}

let registeredNotifierWatches = {}

ecs.register_es("notification_lights_init",
{
  onInit = function(eid, comp) {
    let panelName = comp.notification_lamp__panelName
    if (panelName not in panelByName) {
      return
    }
    let [_, notifierWatch=null] = panelByName[panelName] ?? []
    if (notifierWatch == null) {
      return
    }
    let actualWatch = type(notifierWatch)=="function" ? notifierWatch() : notifierWatch
    let callback = @(v) reactToNotificationStateChange(v, eid)

    actualWatch.subscribe_with_nasty_disregard_of_frp_update(callback)
    callback(actualWatch.get())

    registeredNotifierWatches[panelName] <- {watch=actualWatch, callback}
  }

  onDestroy = function(_evt, _eid, comp) {
    if (comp.notification_lamp__panelName not in registeredNotifierWatches)
      return
    let {watch, callback} = registeredNotifierWatches[comp.notification_lamp__panelName]
    watch.unsubscribe(callback)
    registeredNotifierWatches.$rawdelete(comp.notification_lamp__panelName)
  }
},{
  comps_ro = [["notification_lamp__panelName", ecs.TYPE_STRING]]
})

let panelIndexQuery = ecs.SqQuery("panelIndexQuery", {
  comps_rw = [
    ["dynamic_screen_ui_panel__index", ecs.TYPE_INT]
  ]
})

let panel_rw_comps = [
  ["dynamic_screen_ui_panel__index", ecs.TYPE_INT],
  ["dynamic_screen__texture_size", ecs.TYPE_IPOINT2]
]

let panel_comps = [
  ["panel_name", ecs.TYPE_STRING],
  ["worldAngles", ecs.TYPE_POINT3],
  ["worldOffset", ecs.TYPE_POINT3],

  ["worldRenderFeatures", ecs.TYPE_INT],
  ["worldBrightness", ecs.TYPE_FLOAT],
  ["worldSmoothness", ecs.TYPE_FLOAT],
  ["worldReflectance", ecs.TYPE_FLOAT],
  ["worldMetalness", ecs.TYPE_FLOAT],
  ["worldAnchorEntityNode", ecs.TYPE_STRING, null],
  ["worldAnchorEntity", ecs.TYPE_EID, null],
]

function mkPanel(panelData){
  let [panel, notifierWatch=null] = panelByName?[panelData.panel_name] ?? [mkDefaultPanel]

  let data = panelData.__merge({
    worldSize = Point2(panelData.textureSize[0], panelData.textureSize[1])
    worldAngles = Point3(panelData.worldAngles[0], panelData.worldAngles[1], panelData.worldAngles[2])
    worldOffset = Point3(panelData.worldOffset[0], panelData.worldOffset[1], panelData.worldOffset[2])
  })
  let notifierLed = notifierWatch ? mkNotificationLed(type(notifierWatch)=="function" ? notifierWatch() : notifierWatch) : null
  let res = panel(panelData.textureSize, data, notifierLed)
  return res
}

function removePanel(eid){
  let arr = panels.get()
  let n = arr.len()
  let i = arr.findindex(@(e) e.eid == eid)

  if (i == null || n == 0)
    return

  if (i == n - 1){
    gui_scene.removePanel(i)
    arr.pop()
    panels.set(arr)
    return
  }

  arr[i] = arr[n-1]
  arr.pop()
  panels.set(arr)
  panels.trigger()

  gui_scene.removePanel(i)
  gui_scene.removePanel(n-1)

  let panel = mkPanel(arr[i])
  panelIndexQuery.perform(arr[i].eid, function(_eid, comps) {
    comps.dynamic_screen_ui_panel__index = i
  })
  gui_scene.addPanel(i, panel)
}

function addPanel(eid, comp){
  
  local i = panels.get().len()-1
  while(i>=0){
    if (panels.get()[i].eid == eid || !ecs.g_entity_mgr.doesEntityExist(panels.get()[i].eid)){
      removePanel(eid)
      i = min(i, panels.get().len()-1)
    } else {
      i--
    }
  }

  
  
  
  let res = {
    eid,
    panel_name = comp.panel_name
    textureSize = [comp.dynamic_screen__texture_size.x, comp.dynamic_screen__texture_size.y]
    worldAngles = [comp.worldAngles.x, comp.worldAngles.y, comp.worldAngles.z]
    worldOffset = [comp.worldOffset.x, comp.worldOffset.y, comp.worldOffset.z]
    worldRenderFeatures = comp.worldRenderFeatures
    worldBrightness = comp.worldBrightness
    worldSmoothness = comp.worldSmoothness
    worldReflectance = comp.worldReflectance
    worldMetalness = comp.worldMetalness
  }
  if (comp.worldAnchorEntity != null)
    res["worldAnchorEntity"] <- comp.worldAnchorEntity
  if (comp.worldAnchorEntityNode != null)
    res["worldAnchorEntityNode"] <- comp.worldAnchorEntityNode

  local arr = panels.get()
  arr.append(res)
  panels.set(arr)
  panels.trigger()

  let panel = mkPanel(res)
  let newPanelIndex = panels.get().len()-1
  gui_scene.addPanel(newPanelIndex, panel)

  if (comp?.dynamic_screen_ui_panel__index != null)
    comp.dynamic_screen_ui_panel__index = newPanelIndex
}

ecs.register_es("track_ui_panel_es",
  {
    onInit = function(eid, comp) {
      addPanel(eid, comp)
    }
    onDestroy = function(eid, _comp) {
      removePanel(eid)
    }
  },
  { comps_ro = panel_comps, comps_rw = panel_rw_comps }
)
