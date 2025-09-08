from "%ui/ui_library.nut" import *

let { eventbus_send, eventbus_subscribe } = require("eventbus")
let { currentAlter, alterContainers } = require("%ui/profile/profileState.nut")

let currentChronogenes = Computed(function() {
  return alterContainers.get().findvalue(@(v) v.containerId == currentAlter.get()) ?? {}
})

let isWaitingForChronogenesResponse = Watched(false)
eventbus_subscribe("profile_server.make_alter_from_chronogenes.result", @(...) isWaitingForChronogenesResponse.set(false))

function sendRawChronogenes(container) {
  let mainGenes = container.primaryChronogenes
  let secondaryGenes = container.secondaryChronogenes
  let alter_name = container.alterName
  isWaitingForChronogenesResponse.set(true)
  eventbus_send("profile_server.make_alter_from_chronogenes",
    {container_id_int64=container.containerId, mainGenes=mainGenes, secondaryGenes=secondaryGenes, alterName=alter_name})
}

return {
  isWaitingForChronogenesResponse
  sendRawChronogenes
  currentChronogenes
}