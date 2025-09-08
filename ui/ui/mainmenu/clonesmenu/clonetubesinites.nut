import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
let { EventAlterHighlight } = require("dasevents")
let { alterContainers, currentAlter, playerBaseState } = require("%ui/profile/profileState.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")

const tubeKeySartsWith = "alter_tube_"
const selectedContainerHighlightIntence = 0.5
const hoveredContainerHighlightIntence = 1.0

function updateLight() {
  for (local i = 0; i < (playerBaseState.get()?.maxAlterContainers ?? 0); i++) {
    let currentContainer = alterContainers.get()?[i].containerId
    if (currentAlter.get()?.tostring() == currentContainer?.tostring() && !isOnboarding.get())
      ecs.g_entity_mgr.broadcastEvent(EventAlterHighlight({ alterTubeKey=$"alter_tube_{i}", highlightIntence=selectedContainerHighlightIntence }))
    else
      ecs.g_entity_mgr.broadcastEvent(EventAlterHighlight({ alterTubeKey=$"alter_tube_{i}", highlightIntence=0 }))
  }
}

currentAlter.subscribe(@(_) updateLight())
alterContainers.subscribe(@(_) updateLight())
isOnboarding.subscribe(@(_) updateLight())

return {
  tubeKeySartsWith
  selectedContainerHighlightIntence
  hoveredContainerHighlightIntence
}