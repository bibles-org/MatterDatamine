from "dasevents" import EventStateMachineStateChanged, EventOnboardingPhaseResult, CmdRequestOnboardingReportContract, CmdShowOnboardingBaseDebriefing
from "%ui/profile/profileState.nut" import playerProfileCreditsCountUpdate, playerProfileMonolithTokensCountUpdate, playerBaseStateUpdate

from "dagor.math" import Point2
from "das.onboarding" import is_onboarding
from "%ui/devInfo.nut" import addTabToDevInfo
from "net" import get_sync_time
from "json" import parse_json
from "base64" import decodeString

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { playerProfileMonolithTokensCount, playerProfileAMConvertionRate, lastBattleResult } = require("%ui/profile/profileState.nut")
let userInfo = require("%sqGlob/userInfo.nut")


let onboardingStateMachineCurrentStateEid = Watched(ecs.INVALID_ENTITY_ID)

let onboardingStateMachineMonolithStateEid = Watched(ecs.INVALID_ENTITY_ID)
let onboardingStateMachineBaseFirstTimeStateEid = Watched(ecs.INVALID_ENTITY_ID)
let onboardingStateMachineMiniraidStateEid = Watched(ecs.INVALID_ENTITY_ID)
let onboardingStateMachineBaseKeyInsertionStateEid = Watched(ecs.INVALID_ENTITY_ID)
let onboardingStateMachineFinishedStateEid = Watched(ecs.INVALID_ENTITY_ID)

let isOnboarding = Watched(false)
let isOnboardingMemory = Watched(false)
let isOnboardingRaid = Watched(false)

let isKeyInserted = Watched(false)


let clearBaseStateForOnboarding = function() {
  playerBaseStateUpdate({
    stashVolumeSize = 0
    stashesCount = {x=0, y=0}
  })
}

isOnboarding.subscribe_with_nasty_disregard_of_frp_update(function(value) {
  if (value) {
    clearBaseStateForOnboarding()
  }
})


function setOnboardingStateByStateMachineEid(state_eid){
  isOnboarding.set(is_onboarding())
  isOnboardingRaid.set(
    state_eid == onboardingStateMachineMonolithStateEid.get() ||
    state_eid == onboardingStateMachineMiniraidStateEid.get())

  if (state_eid != ecs.INVALID_ENTITY_ID && state_eid == onboardingStateMachineMonolithStateEid.get()) {
    playerProfileMonolithTokensCountUpdate(0)
  }
}
onboardingStateMachineCurrentStateEid.subscribe_with_nasty_disregard_of_frp_update(setOnboardingStateByStateMachineEid)
setOnboardingStateByStateMachineEid(onboardingStateMachineCurrentStateEid.get())

onboardingStateMachineMonolithStateEid.subscribe_with_nasty_disregard_of_frp_update(
  function(state_eid) {
    if (state_eid != ecs.INVALID_ENTITY_ID && state_eid == onboardingStateMachineCurrentStateEid.get()) {
      playerProfileMonolithTokensCountUpdate(0)
    }
  })

ecs.register_es("onboarding_show_base_debriefing",
{
  [CmdShowOnboardingBaseDebriefing] = function(evt, _eid, comp) {
    if (!comp.is_local) {
      return
    }
    let data = parse_json(evt.data)

    let encodedTrackPoints = data?.trackPointsV2 ?? ""
    let trackPoints = encodedTrackPoints.len() > 0 ? parse_json(decodeString(encodedTrackPoints)) : []
    data.trackPoints <- trackPoints

    let encodedTeamInfo = data?.teamInfo ?? ""
    data.teamInfo = encodedTeamInfo.len() > 0 ? parse_json(decodeString(data.teamInfo)) : []
    if (data.teamInfo.len() > 0) {
      data.teamInfo[0].id <- userInfo.get().userId
    }
    data.debriefingStatsV2 <- data.debriefingStats
    data.id <- $"onboarding_miniraid_{get_sync_time()}"
    data.chronotracesProgression <- []
    data.battleStat <- {
      isSuccessRaid = data.isSuccessRaid
    }
    data.needRewards <- false

    lastBattleResult.set(data)
  }
},
{
  comps_rq = ["player"],
  comps_ro = [["is_local", ecs.TYPE_BOOL]]
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

ecs.register_es("track_is_key_inserted",
  {
    [["onInit", "onChange"]] = function(_evt, _eid, comp) {
      isKeyInserted.set(comp.animchar__visible)
    }
  },
  {
    comps_track = [[ "animchar__visible", ecs.TYPE_BOOL ]]
    comps_rq = [["player_base_keycard"]]
  }
)

ecs.register_es("onboarding_state_machine_ui_es",
  {
    [["onInit", EventStateMachineStateChanged]] = function(_evt, _eid, comp){
      isOnboarding.set(is_onboarding())
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

ecs.register_es("onboarding_contract_reported",
  {
    onInit = @(...) onboardingContractReported.set(true)
    onDestroy = @(...) onboardingContractReported.set(false)
  },
  {
    comps_rq = [["onboarding_contract_reported"]]
  }
)

ecs.register_es("onboarding_fake_money_on_miniraid_completion",
  {
    [EventOnboardingPhaseResult] = function(evt, _eid, _comp) {
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

ecs.register_es("onboarding_contract_report",
  {
    [CmdRequestOnboardingReportContract] = function(_evt, _eid, _comp) {
      playerProfileMonolithTokensCountUpdate(contractRewardMonolithTokens)
      log($"Onboarding contract reported. New monolith tokens count: {playerProfileMonolithTokensCount.get()}")
    }
  },
  { comps_rq = ["player"] }
)

let playerProfileOnboardingContracts = Computed(@() {
  [0] = {
    contractType = 0,
    raidName = "onboarding+onboarding",
    isReported = onboardingContractReported.get(),
    name = "contract_onboarding_raid",
    requireValue = 1,
    currentValue = onboardingStateMachineCurrentStateEid.get() == onboardingStateMachineBaseKeyInsertionStateEid.get() ? 1 : 0,
    rewards = [{
      monolithTokens = Point2(contractRewardMonolithTokens, contractRewardMonolithTokens)
    }]
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
  contractRewardCurrency
  isKeyInserted
}