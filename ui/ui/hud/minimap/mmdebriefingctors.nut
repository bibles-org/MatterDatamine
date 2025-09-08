from "%ui/ui_library.nut" import *


from "dagor.debug" import logerr
from "tiledMap.behaviors" import TiledMap
import "%ui/hud/minimap/minimap_restr_zones_debriefing.nut" as restrictionZones
import "%ui/hud/minimap/minimap_debriefing_players_path.nut" as playersPath
import "%ui/hud/minimap/minimap_debriefing_log_points.nut" as logPoints
import "%ui/hud/minimap/map_object_zone.nut" as mkMapObjectZones
import "%ui/hud/minimap/map_object_markers.nut" as mkMapObjectMarkers
let { debriefingObjectives, debriefingObjectiveZones, debriefingObjectiveMarkers } = require("%ui/mainMenu/debriefing/debriefing_quests_state.nut")
let { scalebar } = require("%ui/hud/minimap/map_scalebar.nut")
let { tiledMapContext } = require("%ui/hud/minimap/tiled_map_ctx.nut")


let tiledFogOfWar = {
  watch = null
  ctor = @(_) {
    size = flex()
    tiledMapContext = tiledMapContext
    rendObj = ROBJ_TILED_MAP_FOG_OF_WAR
    behavior = TiledMap
  }
}

let mmDebriefingCtors = freeze([
  tiledFogOfWar,
  restrictionZones,
  playersPath,
  logPoints,
  mkMapObjectZones(debriefingObjectiveZones, debriefingObjectives),
  mkMapObjectMarkers(debriefingObjectiveMarkers, debriefingObjectives),
  scalebar
])

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

mmDebriefingCtors.each(checkCtor)

return {mmDebriefingCtors}