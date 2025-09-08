import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

from "minimap" import MinimapState
let { mmContext } = require("%ui/hud/minimap/minimap_ctx.nut")
let { EventMinimapZoomed } = require("bhvMinimap")
let { mapDefaultVisibleRadius,
      minimalMapVisibleRadius,
      currentMapVisibleRadius } = require("%ui/hud/minimap/map_state.nut")


let minimapState = MinimapState({
  ctx = mmContext
  visibleRadius = mapDefaultVisibleRadius.get()
  shape = "square"
})

ecs.register_es("minimap_zoomed_es",
  { [EventMinimapZoomed] = function(...) {
      if (minimapState.getVisibleRadius() < minimalMapVisibleRadius.get()){
        minimapState.setVisibleRadius(minimalMapVisibleRadius.get())
        currentMapVisibleRadius.set(minimalMapVisibleRadius.get())
      } else {
        currentMapVisibleRadius.set(minimapState.getVisibleRadius())
      }
    }
  },
  {},
  {tags = "gameClient"}
)

mapDefaultVisibleRadius.subscribe(@(r) minimapState.setVisibleRadius(r))

return {
  mapDefaultVisibleRadius
  minimalMapVisibleRadius
  currentMapVisibleRadius
  minimapState
}
