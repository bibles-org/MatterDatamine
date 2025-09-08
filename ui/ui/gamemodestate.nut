from "%ui/ui_library.nut" import *

let { nestWatched } = require("%dngscripts/globalState.nut")

let selectedRaid = mkWatched(persist, "selectedRaid", null) 
let queueRaid = nestWatched("queueRaid", null) 
let selectedSpawn = Watched(null)
let spawnOptions = Watched([])

let isGroupAvailable = function() {
  return (selectedRaid.get()?.maxGroupSize ?? 1) > 1
}

return {
  isGroupAvailable
  selectedRaid
  queueRaid
  selectedSpawn
  spawnOptions
}
