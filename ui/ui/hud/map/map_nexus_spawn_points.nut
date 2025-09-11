import "%ui/hud/map/map_hover_hint.nut" as mapHoverableMarker
from "%ui/components/colors.nut" import OrangeHighlightColor
from "%ui/components/commonComponents.nut" import mkText
from "%ui/fonts_style.nut" import tiny_txt

from "%ui/ui_library.nut" import *

let { nexusSpawnPoints } = require("%ui/hud/state/nexus_mode_state.nut")
let { localPlayerTeam } = require("%ui/hud/state/local_player.nut")

let markerSize = hdpxi(26)

let mkNexusSpawnPointsMarkers = function(spawnPointsValue, transform) {
  return spawnPointsValue.map(function(spawnPoint) {
    return mapHoverableMarker({worldPos = spawnPoint.pos, clampToBorder = true},
                                  transform,
                                  loc("marker_tooltip/nexusSpawnPoint"),
                                  @(stateWatched) function(){
      if (spawnPoint.team != localPlayerTeam.get())
        return static { watch = localPlayerTeam }

      let isHover = stateWatched.get() & S_HOVER
      let color = isHover ? OrangeHighlightColor : Color(255, 255, 255, 255)

      return {
        watch = [stateWatched, localPlayerTeam]
        key = color
        rendObj = ROBJ_IMAGE
        image = Picture("!ui/skin#antenna.svg:{0}:{0}:K".subst(markerSize))
        size = markerSize
        color
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        children = mkText(loc("marker_tooltip/nexusSpawnPoint"), {pos = [0, markerSize]}.__merge(tiny_txt))
      }
    })
  })
}

return {
  nexusSpawnPoints = {
    watch = nexusSpawnPoints
    ctor = @(p) mkNexusSpawnPointsMarkers(nexusSpawnPoints.get().values(), p?.transform ?? {})
  }
}
