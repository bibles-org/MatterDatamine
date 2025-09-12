from "%dngscripts/globalState.nut" import nestWatched
from "dagor.debug" import logerr
from "%ui/ui_library.nut" import *

enum GameMode {
  Raid = "Raid"
  Nexus = "Nexus"
}

let PlayerGameModeOptions = freeze([GameMode.Raid, GameMode.Nexus])
let selectedPlayerGameModeOption = nestWatched("selectedPlayerGameModeOption", PlayerGameModeOptions[0])

let selectedRaid = mkWatched(persist, "selectedRaid", null) 
let raidToFocus = Watched({})
let queueRaid = nestWatched("queueRaid", null) 
let selectedSpawn = Watched(null)
let leaderSelectedRaid = nestWatched("squadLeaderSelectedRaid", {})
let selectedNexusFaction = nestWatched("selectedNexusFaction", null)
let selectedNexusNode = nestWatched("selectedNexusNode", null)
let showNexusFactions = nestWatched("showNexusFactions", true)
let allowRaidsSelectInNexus = false

function setShowNexusFactions(v){
  if (allowRaidsSelectInNexus)
    showNexusFactions.set(v)
  else
    logerr("showNexusFactions is not allowed")
}
showNexusFactions.whiteListMutatorClosure(setShowNexusFactions)
let isGroupAvailable = function() {
  return (selectedRaid.get()?.maxGroupSize ?? 1) > 1
}

return {
  GameMode
  selectedPlayerGameModeOption
  isGroupAvailable
  selectedRaid
  queueRaid
  selectedSpawn
  leaderSelectedRaid
  selectedNexusFaction
  selectedNexusNode
  showNexusFactions
  raidToFocus
  setShowNexusFactions
  allowRaidsSelectInNexus
}
