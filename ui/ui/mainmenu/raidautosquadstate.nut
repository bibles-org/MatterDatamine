from "%dngscripts/globalState.nut" import nestWatched

from "%ui/ui_library.nut" import *


let autoSquadGatheringState = nestWatched("autoSquadCheckboxState", false)
let autosquadPlayers = nestWatched("autosquadPlayers", [])
let reservedSquad = Watched([])
let waitingInvite = Watched(false)
let waitingInviteFromLeaderNumber = Watched(0)

function getFormalLeaderUid(squad) {
  if (squad.len() == 0)
    return null
  local leaderUid = squad[0].userId
  local leaderMemberId = squad[0].memberId
  foreach (player in squad) {
    if (leaderMemberId > player.memberId) {
      leaderUid = player.userId
      leaderMemberId = player.memberId
    }
  }
  return leaderUid
}

return {
  autoSquadGatheringState
  autosquadPlayers
  getFormalLeaderUid
  reservedSquad
  waitingInvite
  waitingInviteFromLeaderNumber
}