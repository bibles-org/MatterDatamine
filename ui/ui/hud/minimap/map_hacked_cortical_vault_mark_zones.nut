import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let minimapHoverableMarker = require("minimap_hover_hint.nut")
let { mkObjectiveIdxMark } = require("%ui/hud/objectives/objective_components.nut")
let { currentMapVisibleRadius } = require("%ui/hud/minimap/map_state.nut")

let hackedCorticalVaultMapMarks = Watched({})

ecs.register_es("hacked_cortical_vault_map_mark_zones_ui_es",
  {
    onInit = function(eid, comp){
      hackedCorticalVaultMapMarks.mutate(@(v) v[eid] <- {
        pos = comp.transform[3],
        radius = comp.map_object_zone__radius
      })
    },
    onDestroy = function(eid, _comp){
      if (eid in hackedCorticalVaultMapMarks.get())
        hackedCorticalVaultMapMarks.mutate(@(v) v.$rawdelete(eid))
    }
  },
  {
    comps_rq = [
      ["hacked_cortical_vault_map_mark", ecs.TYPE_TAG]
    ],
    comps_ro = [
      ["transform", ecs.TYPE_MATRIX],
      ["map_object_zone__radius", ecs.TYPE_FLOAT]
    ]
  }
)



let HACKED_CORTICAL_VAULT_MARK_COLOR = Color(255, 128, 128)

function mkHackedCorticalVaultMapMarkZone(zone, map_size){
  function objectiveIdxMark() {
    let realVisRadius = currentMapVisibleRadius.get()
    let canvasRadius = zone.radius * min(map_size[0], map_size[1]) / (2 * realVisRadius)

    return {
      watch = currentMapVisibleRadius
      children = mkObjectiveIdxMark("", [2 * canvasRadius, 2 * canvasRadius], HACKED_CORTICAL_VAULT_MARK_COLOR)
    }
  }

  let transform = {
    pivot = [0.5, 0.5]
  }

  return minimapHoverableMarker(
    {
      worldPos = zone.pos,
      clampToBorder = false
      dirRotate = false
    },
    transform,
    loc("hint/hacked_cortical_vault_map_mark"),
    @(_) objectiveIdxMark
  )
}

function mkHackedCorticalVaultMapMarkZones(marks, map_size) {
  return marks.map(@(data) mkHackedCorticalVaultMapMarkZone(data, map_size))
}

return {
  watch = hackedCorticalVaultMapMarks
  ctor = @(p) mkHackedCorticalVaultMapMarkZones(hackedCorticalVaultMapMarks.get().values(), p?.size)
}