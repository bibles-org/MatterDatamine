from "%ui/ui_library.nut" import *

let { nexusSpawnPoints } = require("%ui/hud/state/nexus_mode_state.nut")
let minimapHoverableMarker = require("minimap_hover_hint.nut")
let { localPlayerTeam } = require("%ui/hud/state/local_player.nut")
let { OrangeHighlightColor } = require("%ui/components/colors.nut")
let { mkText } = require("%ui/components/commonComponents.nut")
let { tiny_txt } = require("%ui/fonts_style.nut")

let markerSize = hdpxi(26)

let mkNexusSpawnPointsMarkers = function(spawnPointsValue, transform) {
  return spawnPointsValue.map(function(spawnPoint) {
    return minimapHoverableMarker({worldPos = spawnPoint.pos, clampToBorder = true},
                                  transform,
                                  loc("marker_tooltip/nexusSpawnPoint"),
                                  @(stateWatched) function(){
      if (spawnPoint.team != localPlayerTeam.get())
        return const { watch = localPlayerTeam }

      let isHover = stateWatched.get() & S_HOVER
      let color = isHover ? OrangeHighlightColor : Color(255, 255, 255, 255)

      return {
        watch = [stateWatched, localPlayerTeam]
        key = $"{color}"
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
