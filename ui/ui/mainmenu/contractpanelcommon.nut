from "%ui/ui_library.nut" import *

let { playerProfileCurrentContracts } = require("%ui/profile/profileState.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { matchingQueues } = require("%ui/matchingQueues.nut")
let { ContractType } = require("%sqGlob/dasenums.nut")

let mkContractsCompleted = @(raidName=null) Computed(function() {
  let contracts = playerProfileCurrentContracts.get()
  local ret = 0
  if (isOnboarding.get())
    return 0
  foreach(cont in contracts) {
    
    if (matchingQueues.get().findindex(@(v) cont.raidName != null && v.extraParams.raidName != null
      && (cont.raidName == v.extraParams.raidName
        || (cont.contractType == ContractType.STORY && v.extraParams.raidName.split("+")?[0] == cont.raidName))
    ) == null)
      continue

    let sameRaidName = raidName == null ? true
      : cont?.raidName == raidName || (cont.contractType == ContractType.STORY && cont.raidName == raidName.split("+")?[0])

    if (sameRaidName && cont.currentValue >= cont.requireValue && !cont.isReported)
      ret++
  }
  return ret
})

return{
  mkContractsCompleted
}
