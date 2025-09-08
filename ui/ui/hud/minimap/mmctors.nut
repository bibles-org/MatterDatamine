from "%ui/ui_library.nut" import *

from "minimap.behaviors" import Minimap
from "tiledMap.behaviors" import TiledMap
let {logerr} = require("dagor.debug")
let {minimapState} = require("%ui/hud/minimap/minimap_state.nut")
let {tiledMapExist, tiledMapContext} = require("%ui/hud/minimap/tiled_map_ctx.nut")

let minimapRegionsPolygons = require("%ui/hud/minimap/minimap_regions_polygons.nut")
let minimapRegionsTitles = require("%ui/hud/minimap/minimap_regions_titles.nut")
let restrictionZones = require("%ui/hud/minimap/minimap_restr_zones.nut")
let {userPoints} = require("%ui/hud/minimap/minimap_user_points.nut")
let {teammatesMarkers} = require("%ui/hud/minimap/unit_ctor.nut")
let secretLootables = require("%ui/hud/minimap/minimap_secret_lootables.nut")
let { nexusBeacons } = require("%ui/hud/minimap/minimap_nexus_beacons.nut")
let { nexusSpawnPoints } = require("%ui/hud/minimap/minimap_nexus_spawn_points.nut")
let { monstrifyTrapPos } = require("%ui/hud/minimap/minimap_monstrify_traps.nut")
let { monstrifyVictimCircles } = require("%ui/hud/state/monstrify_state.nut")
let { airdropPredictedPositions } = require("%ui/hud/state/airdrop_state.nut")
let mkVictimZones = require("%ui/hud/minimap/minimap_monstrify_victim_zone.nut")
let mkAirdropZones = require("%ui/hud/minimap/minimap_airdrop_zone.nut")
let mkMapObjectMarkers = require("%ui/hud/minimap/map_object_markers.nut")
let mkMapObjectZones = require("%ui/hud/minimap/map_object_zone.nut")
let hackedCorticalVaultMapMarkZones = require("%ui/hud/minimap/map_hacked_cortical_vault_mark_zones.nut")
let corticalVaults = require("%ui/hud/minimap/minimap_cortical_vaults.nut")
let { objectives } = require("%ui/hud/state/objectives_vars.nut")
let { mapObjectZones, mapObjectMarkers } = require("%ui/hud/state/markers.nut")
let { scalebar } = require("%ui/hud/minimap/map_scalebar.nut")
let { extractionPoints } = require("%ui/hud/minimap/map_extraction_points.nut")
let { isNexus } = require("%ui/hud/state/nexus_mode_state.nut")
let { deathPos } = require("%ui/hud/minimap/minimap_death_points.nut")


let visCone = freeze({
  watch = null
  ctor = @(_) {
    size = flex()
    minimapState = minimapState
    rendObj = ROBJ_MINIMAP_VIS_CONE
    behavior = Minimap
  }
})

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
    minimapRegionsPolygons,
    minimapRegionsTitles,
    tiledFogOfWar,
    tiledMapExist.get() ? tiledVisCone : visCone,
    restrictionZones,
    mkMapObjectZones(mapObjectZones, objectives),
    hackedCorticalVaultMapMarkZones,
    userPoints,
    secretLootables,
    nexusBeacons,
    isNexus.get() ? nexusSpawnPoints : null,
    monstrifyTrapPos,
    mkVictimZones(monstrifyVictimCircles),
    mkAirdropZones(airdropPredictedPositions),
    deathPos,
    mkMapObjectMarkers(mapObjectMarkers, objectives),
    extractionPoints,
    corticalVaults,
    teammatesMarkers,
    scalebar
  ].filter(@(v) v != null)
  layers.each(checkCtor)
  return layers
}


return {
  getMapLayers
}
