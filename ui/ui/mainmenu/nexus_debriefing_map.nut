from "%ui/helpers/parseSceneBlk.nut" import get_zone_info, get_tiled_map_info, get_spawns, get_raid_description,
  get_nexus_beacons, ensurePoint2, ensurePoint3

from "%ui/hud/map/tiled_map_ctx.nut" import tiledMapSetup
from "dagor.math" import Point3
from "%ui/hud/map/map_nexus_beacons.nut" import mkNexusBeaconMarkers
from "%ui/components/colors.nut" import BtnBgDisabled
from "%ui/hud/map/map_spawn_points.nut" import mkSpawns
from "dagor.localize" import doesLocTextExist

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
from "tiledMap.behaviors" import TiledMap

let { currentMapVisibleRadius } = require("%ui/hud/map/map_state.nut")
let { tiledMapContext, tiledMapDefaultConfig } = require("%ui/hud/map/tiled_map_ctx.nut")
let { raidZoneInfo, raidZone } = require("%ui/hud/map/map_restr_zones_raid_menu.nut")

let debriefingScene = Watched(null)
let debriefingRaidName = Watched(null)

function mkTiledMapLayer(ctorWatch, mapSizeToUse) {
  let watches = type(ctorWatch.watch) == "array" ? ctorWatch.watch : [ctorWatch.watch]
  return @() {
    watch = watches
    size = mapSizeToUse
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    clipChildren = true
    eventPassThrough = true
    tiledMapContext = tiledMapContext
    transform = {}
    behavior = TiledMap
    children = ctorWatch.ctor({size=mapSizeToUse, transform={}})
  }
}

function updateMapPos(scene) {
  let mapDesc = get_tiled_map_info(scene)
  if (mapDesc == null)
    return

  let restrZone = get_zone_info(scene)

  let lt = ensurePoint2(mapDesc.leftTop)
  let rb = ensurePoint2(mapDesc.rightBottom)

  let defaultCenter = Point3((lt.x + rb.x) / 2.0, 0, (lt.y + rb.y) / 2.0)
  let defaultRadius = (rb.x - lt.x) / 2.0

  let pos = ensurePoint3(restrZone?.sourcePos ?? defaultCenter)
  let visibleRadius = (restrZone?.radius ?? defaultRadius) * 1.05

  if (restrZone){
    raidZoneInfo.set({
      worldPos = pos
      radius = restrZone.radius
    })
  }
  else
    raidZoneInfo.set(null)

  currentMapVisibleRadius.set(visibleRadius)
  tiledMapContext.setVisibleRadius(visibleRadius)
  tiledMapContext.setWorldPos(pos)
}

let nexus_beacons = Computed(function() {
  let scene = debriefingScene.get()
  let beacons = get_nexus_beacons(scene) ?? []

  let res = beacons.map(@(v, idx) [$"{idx}", v]).totable()
  return res
})

let beaconMarkers = {
  watch = nexus_beacons
  ctor = @(_) mkNexusBeaconMarkers(nexus_beacons.get()?.keys(), nexus_beacons)
}

let spawns = Computed(function() {
  let scene = debriefingScene.get()
  let raidName = debriefingRaidName.get()
  let allSpawns = get_spawns(scene) ?? []
  let offset = 1
  let spawnGroups = [-1]
  let result = {}
  foreach (group in spawnGroups) {
    let locRaid = $"{raidName}/spawn_name/{group - offset}"
    let locZone = $"{raidName?.split("+")?[1]}/spawn_name/{group - offset}"
    result[group] <- {
      spawns = allSpawns.filter(@(v) v.spawnGroupId == group)
      locId = doesLocTextExist(locRaid) ? locRaid : locZone
    }
  }
  return result
})

let mkSpawnPoints = @(mapSizeToUse) @(){
  watch = [spawns, debriefingScene]
  ctor = @(p) mkSpawns(
    spawns.get(),
    get_zone_info(debriefingScene.get()),
    get_raid_description(debriefingScene.get()),
    mapSizeToUse,
    p?.transform ?? {}
  )
}

let mkMapSector = @(mapSizeToUse) {
  rendObj = ROBJ_TILED_MAP
  behavior = TiledMap
  size = mapSizeToUse
  tiledMapContext = tiledMapContext
  children = [raidZone, beaconMarkers, mkSpawnPoints(mapSizeToUse)(),].map(@(c) mkTiledMapLayer(c, mapSizeToUse))
}

function setupMapContext(scene, mapSizeToUse) {
  let mapInfo = get_tiled_map_info(scene)

  if (mapInfo == null){
    tiledMapSetup("Missions Menu", tiledMapDefaultConfig)
    return
  }

  let config = {
    leftTop = ensurePoint2(mapInfo.leftTop)
    rightBottom = ensurePoint2(mapInfo.rightBottom)
    visibleRange = ensurePoint2(mapInfo.visibleRange)
    tileWidth = mapInfo.tileWidth
    zlevels = mapInfo.zlevels
    northAngle = mapInfo.northAngle
    tilesPath = mapInfo.tilesPath
    viewportWidth = mapSizeToUse[0]
    viewportHeight = mapSizeToUse[1]
    backgroundColor = mapInfo.backgroundColor
  }
  tiledMapSetup("Missions Menu", config)
  updateMapPos(scene)
}

let mkMapContainer = @(mapSizeToUse) function() {
  setupMapContext(debriefingScene.get(), mapSizeToUse)
  let mapInfo = get_tiled_map_info(debriefingScene.get())
  return {
    watch = debriefingScene
    size = mapSizeToUse
    rendObj = ROBJ_SOLID
    color = mapInfo?.tilesPath != null && mapInfo?.tilesPath != ""
      ? mapInfo.backgroundColor
      : BtnBgDisabled
    clipChildren = true
    children = mkMapSector(mapSizeToUse)
  }
}

return {
  mkMapContainer
  debriefingScene
  debriefingRaidName
}
