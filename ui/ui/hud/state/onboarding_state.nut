import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { Point2 } = require("dagor.math")
let { is_onboarding } = require("das.onboarding")
let { EventStateMachineStateChanged, EventOnboardingPhaseResult,
      CmdRequestOnboardingReportContract } = require("dasevents")
let { playerProfileCreditsCountUpdate, playerProfileMonolithTokensCountUpdate, playerProfileMonolithTokensCount,
      playerProfileAMConvertionRate, playerBaseStateUpdate } = require("%ui/profile/profileState.nut")
let {addTabToDevInfo} = require("%ui/devInfo.nut")


let onboardingStateMachineCurrentStateEid = Watched(ecs.INVALID_ENTITY_ID)

let onboardingStateMachineMonolithStateEid = Watched(ecs.INVALID_ENTITY_ID)
let onboardingStateMachineBaseFirstTimeStateEid = Watched(ecs.INVALID_ENTITY_ID)
let onboardingStateMachineMiniraidStateEid = Watched(ecs.INVALID_ENTITY_ID)
let onboardingStateMachineBaseKeyInsertionStateEid = Watched(ecs.INVALID_ENTITY_ID)
let onboardingStateMachineFinishedStateEid = Watched(ecs.INVALID_ENTITY_ID)

let isOnboarding = Watched(false)
let isOnboardingMemory = Watched(false)
let isOnboardingRaid = Watched(false)


let clearBaseStateForOnboarding = function() {
  playerBaseStateUpdate({
    stashVolumeSize = 0
    stashAdditionalVolume = 0
  })
}

isOnboarding.subscribe(function(value) {
  if (value) {
    clearBaseStateForOnboarding()
  }
})


onboardingStateMachineCurrentStateEid.subscribe(
  function(state_eid) {
    isOnboarding.set(is_onboarding())
    isOnboardingRaid.set(
      state_eid == onboardingStateMachineMonolithStateEid.get() ||
      state_eid == onboardingStateMachineMiniraidStateEid.get())

    if (state_eid != ecs.INVALID_ENTITY_ID && state_eid == onboardingStateMachineMonolithStateEid.get()) {
      playerProfileMonolithTokensCountUpdate(0)
    }
  })

onboardingStateMachineMonolithStateEid.subscribe(
  function(state_eid) {
    if (state_eid != ecs.INVALID_ENTITY_ID && state_eid == onboardingStateMachineCurrentStateEid.get()) {
      playerProfileMonolithTokensCountUpdate(0)
    }
  })

ecs.register_es("track_is_onboarding_memory_state",
  {
    onInit = @(_eid, _comp) isOnboardingMemory.set(true)
    onDestroy = @(_eid, _comp) isOnboardingMemory.set(false)
  },
  {
    comps_rq = [["onboarding_state_machine_memory"]]
  }
)

ecs.register_es("onboarding_state_machine_ui_es",
  {
    [["onInit", EventStateMachineStateChanged]] = function(_evt, _eid, comp){
      onboardingStateMachineCurrentStateEid.set(comp.state_machine__currentState)
    }
    onDestroy = function(_eid, _comp) {
      onboardingStateMachineCurrentStateEid.set(ecs.INVALID_ENTITY_ID)
      isOnboarding.set(false)
    }
  },
  {
    comps_rq = [
      ["onboarding_state_machine"]
    ]
    comps_ro = [
      ["state_machine__currentState", ecs.TYPE_EID]
    ]
  }
)

ecs.register_es("onboarding_phase_monolith_ui_es",
  {
    onInit = @(eid, _comp) onboardingStateMachineMonolithStateEid.set(eid)
    onDestroy = @(_eid, _comp) onboardingStateMachineMonolithStateEid.set(ecs.INVALID_ENTITY_ID)
  },
  {
    comps_rq = [["onboarding_phase_monolith"]]
  }
)

ecs.register_es("onboarding_phase_base_first_time_ui_es",
  {
    onInit = @(eid, _comp) onboardingStateMachineBaseFirstTimeStateEid.set(eid)
    onDestroy = @(_eid, _comp) onboardingStateMachineBaseFirstTimeStateEid.set(ecs.INVALID_ENTITY_ID)
  },
  {
    comps_rq = [["onboarding_phase_base_first_time"]]
  }
)

ecs.register_es("onboarding_phase_miniraid_ui_es",
  {
    onInit = @(eid, _comp) onboardingStateMachineMiniraidStateEid.set(eid)
    onDestroy = @(_eid, _comp) onboardingStateMachineMiniraidStateEid.set(ecs.INVALID_ENTITY_ID)
  },
  {
    comps_rq = [["onboarding_phase_miniraid"]]
  }
)

ecs.register_es("onboarding_phase_base_key_insertion_ui_es",
  {
    onInit = @(eid, _comp) onboardingStateMachineBaseKeyInsertionStateEid.set(eid)
    onDestroy = @(_eid, _comp) onboardingStateMachineBaseKeyInsertionStateEid.set(ecs.INVALID_ENTITY_ID)
  },
  {
    comps_rq = [["onboarding_phase_base_key_insertion"]]
  }
)

ecs.register_es("onboarding_phase_finished_ui_es",
  {
    onInit = @(eid, _comp) onboardingStateMachineFinishedStateEid.set(eid)
    onDestroy = @(_eid, _comp) onboardingStateMachineFinishedStateEid.set(ecs.INVALID_ENTITY_ID)
  },
  {
    comps_rq = [["onboarding_phase_finished"]]
  }
)

let contractRewardMonolithTokens = 100
let contractRewardCurrency = 10000
let onboardingContractReported = Watched(false)
let onboardingMonolithFirstLevelUnlocked = Watched(false)
isOnboarding.subscribe(function(v){
  if(v){
    onboardingMonolithFirstLevelUnlocked.set(false)
    onboardingContractReported.set(false)
  }
})
onboardingMonolithFirstLevelUnlocked.subscribe(@(v) v ? onboardingContractReported.set(false) : null)

ecs.register_es("onboarding_fake_money_on_miniraid_completion",
  {
    [EventOnboardingPhaseResult] = function(evt, _eid, _comp) {
      onboardingMonolithFirstLevelUnlocked.set(false)
      playerProfileCreditsCountUpdate(evt.amCount * playerProfileAMConvertionRate.get())
    }
  },
  { comps_rq = ["player"] }
)

addTabToDevInfo("onboarding", Computed(@(){
  onbaording_in_progress = isOnboarding.get(),
  is_onbaording_in_raid = isOnboardingRaid.get()
  onboarding_phase = isOnboarding.get() ? {
    eid = onboardingStateMachineCurrentStateEid.get(),
    name = ecs.g_entity_mgr.getEntityTemplateName(onboardingStateMachineCurrentStateEid.get())
  } : null
}),
  "console commands:\nonboarding.start -- start onboarding\nonboarding.set_phase [phase] -- set concrete onboarding phase. Hints on what phases are available will appear when onboarding is in progress\nonbaording.finish -- forcefully finish onboarding and return to the bunker\nonboarding.get_state -- print current onboarding phase\nonboarding.open_note [note] -- open a note"
)

let reportContract = @() onboardingContractReported.set(true)

ecs.register_es("onboarding_contract_report",
  {
    [CmdRequestOnboardingReportContract] = function(_evt, _eid, _comp) {
      playerProfileMonolithTokensCountUpdate(contractRewardMonolithTokens)
      reportContract()
      log($"Onboarding contract reported. New monolith tokens count: {playerProfileMonolithTokensCount.get()}")
    }
  },
  { comps_rq = ["player"] }
)

let playerProfileOnboardingContracts = Computed(@() {
  [0] = {
    contractType = 0,
    raidName = "onboarding+onboarding",
    isStoryContract = false,
    isReported = onboardingContractReported.get(),
    name = "contract_onboarding_raid",
    requireValue = 1,
    currentValue = onboardingStateMachineCurrentStateEid.get() == onboardingStateMachineBaseKeyInsertionStateEid.get() ? 1 : 0,
    rewards = {
      monolithTokens = Point2(contractRewardMonolithTokens, contractRewardMonolithTokens)
    }
    handledByGameTemplate = ""
    onReport = function() {
      log("Reporting onboarding contract")
      ecs.g_entity_mgr.broadcastEvent(CmdRequestOnboardingReportContract())
    }
    fakedContract = true
  }
})

let onboardingQuery = freeze({
  onboarding = {
    locId = "onboarding"
    enabled = true
    extraParams = {
      raidDescription = ["dif_easy" "distorted"]
      raidType = "collect"
      missionImages = ["ui/zone_thumbnails/no_info" "ui/zone_thumbnails/no_info" "ui/zone_thumbnails/no_info"]
      raidName = "onboarding+onboarding"
      operatives = true
    }
    teams = [{}]
    envInfo = {
      level_synced_environment__weatherChainSegments = -1
      level_synced_environment__timeOfDayChainSegments = -1
      level_synced_environment__timeOfDayChangeInterval = 60
      level_synced_environment__weatherChangeInterval = 60
    }
    scenes = [
      {
        fileName = "gamedata/scenes/player_onboarding_island.blk"
      }
    ]
    maxGroupSize = 1
    id = "onboarding"
  }
})

return {
  onboardingStateMachineCurrentStateEid
  onboardingStateMachineMonolithStateEid
  onboardingStateMachineBaseFirstTimeStateEid
  onboardingStateMachineMiniraidStateEid
  onboardingStateMachineBaseKeyInsertionStateEid
  onboardingStateMachineFinishedStateEid
  isOnboarding
  onboardingQuery
  isOnboardingRaid
  isOnboardingMemory
  playerProfileOnboardingContracts
  onboardingContractReported
  onboardingMonolithFirstLevelUnlocked
  contractRewardCurrency
}