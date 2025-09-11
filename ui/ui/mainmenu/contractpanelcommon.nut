from "%sqGlob/dasenums.nut" import ContractType
from "%ui/mainMenu/contractWidget.nut" import  isRightRaidName
from "%ui/ui_library.nut" import *

let { playerProfileCurrentContracts } = require("%ui/profile/profileState.nut")
let { isOnboarding, playerProfileOnboardingContracts,
      onboardingStateMachineBaseFirstTimeStateEid, onboardingStateMachineCurrentStateEid } = require("%ui/hud/state/onboarding_state.nut")
let { matchingQueues } = require("%ui/matchingQueues.nut")

let mkContractsCompleted = @(raidName=null) Computed(function() {
  let is_onboarding = isOnboarding.get()
  local ret = 0
  if (is_onboarding) {
    if (onboardingStateMachineBaseFirstTimeStateEid.get() == onboardingStateMachineCurrentStateEid.get()){
      return 1
    }
    foreach (contract in playerProfileOnboardingContracts.get())
      if (!contract?.isReported && ((contract?.currentValue ?? 0) >= (contract?.requireValue ?? 0)))
        ret++
    return ret
  }

  foreach (cont in playerProfileCurrentContracts.get()) {
    
    if (null == matchingQueues.get().findindex(@(v) cont.raidName != null && isRightRaidName(v?.extraParams.raidName, cont.raidName)))
      continue

    let sameRaidName = raidName == null || isRightRaidName(raidName, cont.raidName)
    if (sameRaidName && cont.currentValue >= cont.requireValue && !cont.isReported)
      ret++
  }
  return ret
})

function hasPremiumContracts(contracts, onboardingContracts, is_onboarding, raidName = null) {
  if (is_onboarding)
    return onboardingContracts.findindex(@(c) c?.raidName == raidName
      && c?.contractType != ContractType.STORY
      && !c?.isReported
      && c.rewards.reduce(@(res, val) res || (val?.premiumCurrency.x ?? 0) > 0, false)) != null
  return contracts.findindex(@(c) c?.raidName == raidName
    && c?.contractType != ContractType.STORY
    && !c?.isReported
    && c.rewards.reduce(@(res, val) res || (val?.premiumCurrency.x ?? 0) > 0, false)) != null
}

return{
  mkContractsCompleted
  hasPremiumContracts
}
