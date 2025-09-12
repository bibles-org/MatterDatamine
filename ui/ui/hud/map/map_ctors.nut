from "dagor.debug" import logerr
import "%ui/hud/map/map_monstrify_victim_zone.nut" as mkVictimZones
import "%ui/hud/map/map_airdrop_zone.nut" as mkAirdropZones
import "%ui/hud/map/map_object_markers.nut" as mkMapObjectMarkers
import "%ui/hud/map/map_object_zone.nut" as mkMapObjectZones
from "%ui/hud/map/map_assistant_points.nut" import assistantPoints
from "%ui/hud/map/map_nexus_portals.nut" import nexusPortals
from "%ui/hud/map/map_robodog.nut" import robodogMarks
from "%ui/ui_library.nut" import *

from "tiledMap.behaviors" import TiledMap
let { tiledMapExist, tiledMapContext } = require("%ui/hud/map/tiled_map_ctx.nut")

let mapRegionsPolygons = require("%ui/hud/map/map_regions_polygons.nut")
let mapRegionsTitles = require("%ui/hud/map/map_regions_titles.nut")
let restrictionZones = require("%ui/hud/map/map_restr_zones.nut")
let { userPoints } = require("%ui/hud/map/map_user_points.nut")
let { teammatesMarkers } = require("%ui/hud/map/unit_ctor.nut")
let secretLootables = require("%ui/hud/map/map_secret_lootables.nut")
let { nexusBeacons } = require("%ui/hud/map/map_nexus_beacons.nut")
let { nexusSpawnPoints } = require("%ui/hud/map/map_nexus_spawn_points.nut")
let { monstrifyTrapPos } = require("%ui/hud/map/map_monstrify_traps.nut")
let { monstrifyVictimCircles } = require("%ui/hud/state/monstrify_state.nut")
let { airdropPredictedPositions } = require("%ui/hud/state/airdrop_state.nut")
let hackedCorticalVaultMapMarkZones = require("%ui/hud/map/map_hacked_cortical_vault_mark_zones.nut")
let { scannedPoints, radarCircle } = require("%ui/hud/map/map_scan_points_of_interest_mark_zones.nut")
let corticalVaults = require("%ui/hud/map/map_cortical_vaults.nut")
let { objectives } = require("%ui/hud/state/objectives_vars.nut")
let { mapObjectZones, mapObjectMarkers } = require("%ui/hud/state/markers.nut")
let { scalebar } = require("%ui/hud/map/map_scalebar.nut")
let { extractionPoints } = require("%ui/hud/map/map_extraction_points.nut")
let { isNexus } = require("%ui/hud/state/nexus_mode_state.nut")
let { deathPos } = require("%ui/hud/map/map_death_points.nut")


let tiledVisCone = freeze({
  watch = null
  ctor = @(_) {
    size = flex()
    tiledMapContext = tiledMapContext
    rendObj = ROBJ_TILED_MAP_VIS_CONE
    behavior = TiledMap
  }
})

let tiledFogOfWar = {
  watch = null
  ctor = @(_) {
    size = flex()
    tiledMapContext = tiledMapContext
    rendObj = ROBJ_TILED_MAP_FOG_OF_WAR
    behavior = TiledMap
  }
}

function checkCtor(obj){
  let isArrayOfWatched = type(obj?.watch) == "array"
    && obj?.watch.findindex(@(w) w != null && !(w instanceof Watched)) == null
  if (!(obj?.watch == null || obj?.watch instanceof Watched || isArrayOfWatched) || (type(obj?.ctor)!="function")) {
    let src = obj?.ctor.getfuncinfos().src
    logerr($"incorrect mmap obj : ctor = {src}, watch = {obj?.watch.tostring()}")
    return false
  }
  return true
}


function getMapLayers(){
  let layers = [
    mapRegionsPolygons,
    mapRegionsTitles,
    tiledFogOfWar,
    tiledMapExist.get() ? tiledVisCone : null,
    restrictionZones,
    mkMapObjectZones(mapObjectZones, objectives),
    hackedCorticalVaultMapMarkZones,
    scannedPoints,
    radarCircle,
    assistantPoints,
    secretLootables,
    nexusBeacons,
    isNexus.get() ? nexusPortals : null,
    isNexus.get() ? nexusSpawnPoints : null,
    monstrifyTrapPos,
    mkVictimZones(monstrifyVictimCircles),
    mkAirdropZones(airdropPredictedPositions),
    deathPos,
    mkMapObjectMarkers(mapObjectMarkers, objectives),
    robodogMarks,
    extractionPoints,
    corticalVaults,
    userPoints,
    teammatesMarkers,
    scalebar
  ].filter(@(v) v != null)
  layers.each(checkCtor)
  return layers
}


return {
  getMapLayers
}
