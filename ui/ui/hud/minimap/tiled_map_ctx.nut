import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

from "app" import get_current_scene
from "tiledMap.inputEvents" import EventTiledMapZoomed
from "tiledMap" import TiledMapContext

let { Point2 } = require("dagor.math")
let { mapSize,
      mapDefaultVisibleRadius,
      currentMapVisibleRadius } = require("%ui/hud/minimap/map_state.nut")
let { settings } = require("%ui/options/onlineSettings.nut")
let { throttle } = require("%sqstd/timers.nut")
let { vectorToTable, ensurePoint2 } = require("%ui/helpers/parseSceneBlk.nut")
let { EventEndgamePlayerResult } = require("dasevents")


let tiled_map_comps = {
  comps_ro = [
    ["tiled_map__leftTop", ecs.TYPE_POINT2],
    ["tiled_map__rightBottom", ecs.TYPE_POINT2],
    ["tiled_map__leftTopBorder", ecs.TYPE_POINT2],
    ["tiled_map__rightBottomBorder", ecs.TYPE_POINT2],
    ["tiled_map__visibleRange", ecs.TYPE_POINT2],
    ["tiled_map__tileWidth", ecs.TYPE_INT],
    ["tiled_map__zlevels", ecs.TYPE_INT],
    ["tiled_map__northAngle", ecs.TYPE_FLOAT, 0.0],
    ["tiled_map__tilesPath", ecs.TYPE_STRING],
    ["tiled_map__backgroundColor", ecs.TYPE_COLOR],
    ["fog_of_war__enabled", ecs.TYPE_BOOL, false],
    ["fog_of_war__resolution", ecs.TYPE_FLOAT],
  ],
  comps_rw = [
    ["fog_of_war__leftTop", ecs.TYPE_POINT2],
    ["fog_of_war__rightBottom", ecs.TYPE_POINT2],
  ]
}


let zone_comps = {
  comps_ro = [
    ["sphere_zone__radius", ecs.TYPE_FLOAT],
    ["moving_zone__sourceRadius", ecs.TYPE_FLOAT],
    ["moving_zone__sourcePos", ecs.TYPE_POINT3]
  ]
}


let defaultConfig = {
  leftTop = Point2(0, 0)
  rightBottom = Point2(0, 0)
  visibleRange = Point2(10, 1000)
  tileWidth = 1024
  zlevels = 5
  northAngle = 0.0
  tilesPath = ""
  backgroundColor = Color(0, 0, 0, 140)
  viewportWidth = mapSize[0]
  viewportHeight = mapSize[1]
}

let tiledMapOwner = Watched("")
let tiledMapContextData = Watched(defaultConfig)
let tiledMapExist = Watched(false)

let tiledMapContext = persist("tiledMapCtx", function() {
  let ctx = TiledMapContext()
  ctx.setup(defaultConfig)
  return ctx
})

function tiledMapSetupInner(owner, config, exist){
  tiledMapOwner.set(owner)
  tiledMapContextData.set(config)
  tiledMapContext.setup(config)
  tiledMapExist.set(exist)
}

function tiledMapSetup(owner, config){
  if (owner == ""){
    print($"[TILED MAP] Can't setup new config without owner")
    return
  }

  print($"[TILED MAP] Owner '{owner}' setuped new config")
  tiledMapSetupInner(owner, config, true)
}

function tiledMapReset(owner){
  if (owner != tiledMapOwner.value){
    print($"[TILED MAP] Only current owner '{tiledMapOwner.value}' can reset config ('{owner}' was provided).")
    return
  }

  print($"[TILED MAP] Owner '{owner}' reseted config")
  tiledMapSetupInner(owner, defaultConfig, false)
}

function normalizeSceneName(scene) {
  let name = scene.split("/").top().split(".")[0]
    .replace("_adv", "")
    .replace("_distortion", "")
    .replace("_overgrowth", "")
    .replace("_dark", "")
    .replace("_statues", "")
    .replace("_hive", "")
  return name
}

function getSceneName(){
  let scene_blk = get_current_scene()
  return normalizeSceneName(scene_blk)
}

let zoneQuery = ecs.SqQuery("moving_zone_data", zone_comps)

function onTiledMap(_eid, comp){
  let conf = defaultConfig.__merge({
    leftTop = comp["tiled_map__leftTop"]
    rightBottom = comp["tiled_map__rightBottom"]
    leftTopBorder = comp["tiled_map__leftTopBorder"]
    rightBottomBorder = comp["tiled_map__rightBottomBorder"]
    visibleRange = comp["tiled_map__visibleRange"]
    tileWidth = comp["tiled_map__tileWidth"]
    zlevels = comp["tiled_map__zlevels"]
    northAngle = comp["tiled_map__northAngle"]
    tilesPath = comp["tiled_map__tilesPath"]
    backgroundColor = comp["tiled_map__backgroundColor"]
    viewportWidth = mapSize[0]
    viewportHeight = mapSize[1]
    fogOfWarEnabled = comp["fog_of_war__enabled"]
    isClampToBorder = true
    zoomToFitMapEdges = false
    zoomToFitBorderEdges = false
  })

  let zoneParams = zoneQuery.perform(function(_eid, zoneComp){
    let res = {
      pos = zoneComp["moving_zone__sourcePos"],
      radius = max(zoneComp["sphere_zone__radius"], zoneComp["moving_zone__sourceRadius"]) 
    }
    return res
  })

  if (conf.fogOfWarEnabled) {
    
    if (zoneParams == null) {
      return
    }

    let sceneName = getSceneName()

    let data = settings.get()?["fog_of_war"][sceneName]
    conf.fogOfWarOldDataBase64 <- data?.b64
    conf.fogOfWarOldLeftTop <- ensurePoint2(data?.leftTop)
    conf.fogOfWarOldRightBottom <- ensurePoint2(data?.rightBottom)
    conf.fogOfWarOldResolution <- data?.resolution
    conf.fogOfWarLeftTop <- Point2(zoneParams.pos.x, zoneParams.pos.z) - Point2(zoneParams.radius, zoneParams.radius)
    conf.fogOfWarRightBottom <- Point2(zoneParams.pos.x, zoneParams.pos.z) + Point2(zoneParams.radius, zoneParams.radius)
    conf.fogOfWarResolution <- comp["fog_of_war__resolution"]

    comp["fog_of_war__leftTop"] = conf.fogOfWarLeftTop
    comp["fog_of_war__rightBottom"] = conf.fogOfWarRightBottom
  }
  tiledMapSetup("Main", conf)
}

function resetToDefaults(...){
  tiledMapReset("Main")
}

let tiledMapQuery = ecs.SqQuery("tiled_map_ui_init_query", tiled_map_comps)

function onZone(){
  tiledMapQuery.perform(onTiledMap)
}

ecs.register_es("tiled_map_ui_es", { onInit = onTiledMap, onDestroy = resetToDefaults }, tiled_map_comps)
ecs.register_es("storm_zone_with_forcefield_init_es", { onInit = onZone }, zone_comps)

ecs.register_es("tiled_map_zoomed_es", {
    [EventTiledMapZoomed] = function(...) {
      currentMapVisibleRadius.set(tiledMapContext.getVisibleRadius())
    }
  },
  {},
  {tags = "gameClient"}
)

console_register_command(@() settings.mutate(@(v) v.$rawdelete("fog_of_war")), "fog_of_war.clear_data")
console_register_command(@() tiledMapContext.toggleFogOfWar(), "fog_of_war.toggle")

function fog_of_war_save_data(sceneName, data){
  if (settings.get()?.fog_of_war == null)
    settings.mutate(@(v) v["fog_of_war"] <- {})

  settings.mutate(@(v) v["fog_of_war"][sceneName] <- data)
}
let fog_of_war_save_data_throttle = throttle(fog_of_war_save_data, 30, {leading=true, trailing=true})

function fog_of_war_save(_eid, comp){
  let enabled = comp["fog_of_war__enabled"]
  if (!enabled)
    return

  let sceneName = getSceneName()
  let data = {
    b64 = tiledMapContext.getFogOfWarBase64()
    leftTop = vectorToTable(comp["fog_of_war__leftTop"])
    rightBottom = vectorToTable(comp["fog_of_war__rightBottom"])
    resolution = comp["fog_of_war__resolution"]
  }

  fog_of_war_save_data_throttle(sceneName, data)
}


ecs.register_es("fog_of_war_save_es", {
    onChange = fog_of_war_save
  },
  {
    comps_ro = [
      ["fog_of_war__enabled", ecs.TYPE_BOOL],
      ["fog_of_war__leftTop", ecs.TYPE_POINT2],
      ["fog_of_war__rightBottom", ecs.TYPE_POINT2],
      ["fog_of_war__resolution", ecs.TYPE_FLOAT],
    ],
    comps_track = [
      ["fog_of_war__dataGen", ecs.TYPE_INT]
    ]
  }
)

let save_fog_of_war_query = ecs.SqQuery("save_fog_of_war_query", {
  comps_ro = [
    ["fog_of_war__enabled", ecs.TYPE_BOOL],
    ["fog_of_war__leftTop", ecs.TYPE_POINT2],
    ["fog_of_war__rightBottom", ecs.TYPE_POINT2],
    ["fog_of_war__resolution", ecs.TYPE_FLOAT],
  ],
})

ecs.register_es("fog_of_war_save_on_endgame",{
    [EventEndgamePlayerResult] = function(_eid, comp){
      if (comp.is_local)
        save_fog_of_war_query.perform(fog_of_war_save)
    }
  },
  { comps_ro = [["is_local", ecs.TYPE_BOOL]] }
)

mapDefaultVisibleRadius.subscribe(@(r) tiledMapContext.setVisibleRadius(r))


return {
  tiledMapContext
  tiledMapContextData
  tiledMapDefaultConfig = defaultConfig
  tiledMapExist
  tiledMapSetup
  tiledMapReset
  normalizeSceneName
}
