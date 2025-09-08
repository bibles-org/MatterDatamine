import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { Point2, Point3 } = require("dagor.math")
let { nestWatched } = require("%dngscripts/globalState.nut")
let { mkSmartwatchOnboardingInitializationPanel } = require("smartwatch_panel.nut")
let { mkCraftPanel } = require("craft_panel.nut")
let { mkRefinePanel } = require("refine_panel.nut")
let { mkContactsPanel } = require("contacts_panel.nut")
let { mkMarketPanel } = require("market_panel.nut")
let { mkRaidPanel } = require("raid_panel.nut")
let { mkMonolithPanel } = require("monolith_panel.nut")
let { mkStdPanel, waitingCursor, inviteText } = require("%ui/panels/console_common.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")


let panels = nestWatched("ui_panels", [])
let mkDefaultPanel = @(canvasSize, data) mkStdPanel(canvasSize, data.__merge({
  worldAnchorEntity = data.eid, color = Color(0,0,0,0), rendObj = ROBJ_SOLID
  children = @() {
    size = flex()
    watch = isOnboarding
    flow = FLOW_VERTICAL
    children = isOnboarding.get() ? null : [
      const {size = flex()}
      inviteText
      waitingCursor
    ]
  }
}))

let panelByName = {
  "default" : mkDefaultPanel
  "smartwatch_onboarding_initialization" : mkSmartwatchOnboardingInitializationPanel
  "craft_panel" : mkCraftPanel
  "refine_panel" : mkRefinePanel
  "raid_panel" : mkRaidPanel
  "leaderboard_panel" : mkMonolithPanel
  "intercom": mkContactsPanel
  "market": mkMarketPanel
}

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
  let panel = panelByName?[panelData.panel_name] ?? mkDefaultPanel

  let data = panelData.__merge({
    worldSize = Point2(panelData.textureSize[0], panelData.textureSize[1])
    worldAngles = Point3(panelData.worldAngles[0], panelData.worldAngles[1], panelData.worldAngles[2])
    worldOffset = Point3(panelData.worldOffset[0], panelData.worldOffset[1], panelData.worldOffset[2])
  })

  return panel(panelData.textureSize, data)
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
