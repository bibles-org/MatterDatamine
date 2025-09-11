from "%ui/hud/map/map_debriefing_ctors.nut" import mapDebriefingCtors
from "%ui/hud/map/tiled_map_ctx.nut" import tiledMapSetup, getFogOfWarData
from "%ui/helpers/parseSceneBlk.nut" import ensurePoint2, ensurePoint3, get_tiled_map_info, get_zone_info
from "dagor.math" import Point2

from "%ui/ui_library.nut" import *

import "%dngscripts/ecs.nut" as ecs
import "%ui/control/mouse_buttons.nut" as mouseButtons
from "tiledMap.behaviors" import TiledMap, TiledMapInput

let { lastBattleResult } = require("%ui/profile/profileState.nut")
let { journalBattleResult } = require("%ui/profile/battle_results.nut")
let { currentMapVisibleRadius } = require("%ui/hud/map/map_state.nut")
let { tiledMapContext, tiledMapContextData } = require("%ui/hud/map/tiled_map_ctx.nut")

let mapHgt = min(fsh(71), sw(45))
let mapSize = static [mapHgt, mapHgt]
let mapTransform = { }
let markersTransform = { }



function setupMapContext(config) {
  tiledMapSetup("Debriefing", config)
}

function updateMapContext(scene, size) {
  let mapInfo = get_tiled_map_info(scene)
  let zoneInfo = get_zone_info(scene)
  if (mapInfo == null || zoneInfo == null || zoneInfo?.sourcePos == null)
    return
  let center = ensurePoint3(zoneInfo.sourcePos)
  let radius = zoneInfo.radius
  let leftTop = ensurePoint2(mapInfo.leftTop)
  let rightBottom = ensurePoint2(mapInfo.rightBottom)
  let leftTopBorder = ensurePoint2(mapInfo?.leftTopBorder ?? leftTop)
  let rightBottomBorder = ensurePoint2(mapInfo?.rightBottomBorder ?? rightBottom)
  let visibleRange = ensurePoint2(mapInfo.visibleRange)
  let backgroundColor = mapInfo?.backgroundColor ?? Color(0, 0, 0, 140)

  let config = {
    mapColor = Color(255, 255, 255, 255)
    tilesPath = mapInfo.tilesPath
    leftTop
    rightBottom
    leftTopBorder
    rightBottomBorder
    visibleRange
    backgroundColor
    northAngle = mapInfo.northAngle
    viewportWidth = size[0]
    viewportHeight = size[1]
    tileWidth = mapInfo.tileWidth
    zlevels = mapInfo.zlevels
    fogOfWarEnabled = mapInfo.fogOfWarEnabled
    fogOfWarSavePath = mapInfo.fogOfWarSavePath
    isClampToBorder = true
    zoomToFitMapEdges = false
    zoomToFitBorderEdges = false
  }

  if (config.fogOfWarEnabled) {
    let data = getFogOfWarData(config.fogOfWarSavePath)
    config.fogOfWarOldDataBase64 <- data?.b64
    config.fogOfWarOldLeftTop <- ensurePoint2(data?.leftTop)
    config.fogOfWarOldRightBottom <- ensurePoint2(data?.rightBottom)
    config.fogOfWarOldResolution <- data?.resolution
    config.fogOfWarLeftTop <- Point2(zoneInfo.sourcePos.x, zoneInfo.sourcePos.z) - Point2(zoneInfo.radius, zoneInfo.radius)
    config.fogOfWarRightBottom <- Point2(zoneInfo.sourcePos.x, zoneInfo.sourcePos.z) + Point2(zoneInfo.radius, zoneInfo.radius)
    config.fogOfWarResolution <- mapInfo.fogOfWarResolution
  }

  setupMapContext(config)

  
  currentMapVisibleRadius.set(tiledMapContext.setVisibleRadius(radius * 1.05))
  tiledMapContext.setWorldPos(center)
}

function mkDebriefingMap(battleResult, size) {
  let scene = battleResult?.battleAreaInfo?.scene
  if (scene == null || scene == "")
    return null

  let layerParams = {
    state = tiledMapContext
    size
    transform = markersTransform
  }

  function mkMapLayer(ctorWatch, params, map_size) {
    let watches = type(ctorWatch.watch) == "array" ? ctorWatch.watch : [ctorWatch.watch]
    return @() {
      watch = watches
      size = map_size
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      clipChildren = true
      eventPassThrough = true
      tiledMapContext = tiledMapContext
      transform = {}
      behavior = TiledMap
      children = ctorWatch.ctor(params)
    }
  }

  return @() {
    watch = currentMapVisibleRadius
    onAttach = @() updateMapContext(scene, size)
    size
    tiledMapContext
    rendObj = ROBJ_TILED_MAP
    transform = mapTransform
    panMouseButton = mouseButtons.LMB
    color = Color(255, 255, 255, 255)
    behavior = [TiledMap, TiledMapInput]
    skipDirPadNav = true
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER

    clipChildren = true
    eventPassThrough = true
    children = mapDebriefingCtors.map(@(c) mkMapLayer(c, layerParams, size))
  }
}

let framedMap = @(size = mapSize) function() {
  let mapData = lastBattleResult.get() ?? journalBattleResult.get()
  return {
    watch = [journalBattleResult, lastBattleResult, tiledMapContextData]
    size
    rendObj = ROBJ_SOLID
    color = tiledMapContextData.get()?.backgroundColor ?? Color(0, 0, 0, 140)
    clipChildren = true
    children = mapData != null ? mkDebriefingMap(mapData, size) : null
  }
}

return freeze({
  mkDebriefingMap = framedMap
  mapSize
  updateMapContext
})
