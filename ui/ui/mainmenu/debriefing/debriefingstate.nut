from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { nestWatched } = require("%dngscripts/globalState.nut")
let { loadJson, saveJson } = require("%sqstd/json.nut")
let {get_sync_time} = require("net")
let userInfo = require("%sqGlob/userInfo.nut")
let { remap_nick } = require("%ui/helpers/remap_nick.nut")
let { switch_to_menu_scene } = require("%sqGlob/app_control.nut")
let { get_session_id } = require("app")
let { GameEndReasons, EndgameControllerState } = require("%sqGlob/dasenums.nut")
let { eventbus_send } = require("eventbus")
let { endgameControllerState, endgameControllerDebriefingReason,
  endgameControllerDebriefingTeam, endgameControllerDebriefingAllowSpectate,
  endgameControllerAutoExit } = require("%ui/hud/state/endgame_controller_state.nut")
let { deathCause } = require("death_cause.nut")
let { heroAmValue } = require("%ui/hud/state/am_storage_state.nut")
let { addTabToDevInfo } = require("%ui/devInfo.nut")
let { isInBattleState } = require("%ui/state/appState.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { EventOnboardingRaidExit, CmdStartAssistantSpeak } = require("dasevents")
let { isAlive } = require("%ui/hud/state/health_state.nut")
let { localPlayerEid } = require("%ui/hud/state/local_player.nut")

let showDebriefing = nestWatched("showDebriefing", false)
let fakeDebriefing = Watched(null)

let localPlayerTeamQuery = ecs.SqQuery("localPlayerTeamQuery", {comps_rq=["player"], comps_ro=[["is_local", ecs.TYPE_BOOL],["team", ecs.TYPE_INT],]})
function getPlayerTeam(){
  return localPlayerTeamQuery.perform(function(_eid, comp){
    if (!comp.is_local)
      return null
    return comp.team
  })
}

let isReplayQuery = ecs.SqQuery("isReplayQuery", {comps_rq=["replayIsPlaying"]})
let isReplay = @() isReplayQuery.perform(@(...) true) ?? false

let reasonsMap = {
  [GameEndReasons.YOU_DIED] = {
    result = loc("debriefing/died")
  },
  [GameEndReasons.YOU_EXTRACTED] = {
    result = loc("debriefing/extraction")
    success = true
  },
  [GameEndReasons.BASE_PROTECTED] = {
    result = loc("debriefing/baseProtected", "Base protected! Great job!")
    success = true
  },
  [GameEndReasons.TIME_OUT] = {
    result = loc("debriefing/timeOut", "Time is over.")
    success = true
  },
  [GameEndReasons.LEFT_WITH_NOTHING] = {
    result = loc("debriefing/baseCaptured", "We left without any loot. Siege raid is failed.")
  },
  [GameEndReasons.LEFT_WITH_LOOT] = {
    result = loc("debriefing/baseCaptured", "We took some loot! Great job!")
    success = true
  },
  [GameEndReasons.BASE_ROBBED] = {
    result = loc("debriefing/baseCaptured", "The base has been robbed! We failed.")
  },
  [GameEndReasons.NEXUS_BATTLE_WON] = {
    result = loc("debriefing/nexusBattleWon", "Nexus battle won")
    success = true
  },
  [GameEndReasons.NEXUS_BATTLE_LOST] = {
    result = loc("debriefing/nexusBattleLost", "Nexus battle lost")
  },
  [GameEndReasons.NEXUS_BATTLE_DIED] = {
    result = loc("debriefing/nexusBattleDied", "You died in nexus battle")
  },
  [GameEndReasons.NEXUS_ROUND_LOST] = {
    result = loc("debriefing/nexusRoundLost", "Round lost")
  },
  [GameEndReasons.NEXUS_ROUND_WON] = {
    result = loc("debriefing/nexusRoundWon", "Round won")
    success = true
  },
  [GameEndReasons.ONBOARDING_FAILED_CONTRACT] = {
    result = loc("debriefing/onboardingContractFailed")
  }
}

let computedDebriefingData = Computed(function() {
  if (fakeDebriefing.get() != null) {
    return fakeDebriefing.get()
  }

  let reason = endgameControllerDebriefingReason.get()
  let {result = "", success = false} = reasonsMap?[reason]

  let allowSpectate = endgameControllerDebriefingAllowSpectate.get()
  let state = endgameControllerState.get()
  let isLocalTeam = endgameControllerDebriefingTeam.get() == getPlayerTeam()
  if (endgameControllerAutoExit.get()
      && (state == EndgameControllerState.SPECTATING || state == EndgameControllerState.DEBRIEFING)
      && isLocalTeam
      && !isReplay()) {
    return {
      autoExit = true
      allowSpectate = false
      result = {
        fail = !success
        result
        success = success
        time = get_sync_time()
      }
      showButtons = false
    }
  }

  if ((state == EndgameControllerState.FADEIN || state == EndgameControllerState.DEBRIEFING)
      && isLocalTeam && !isReplay()) {
    return {
      playerName = remap_nick(userInfo.value?.name)
      allowSpectate
      result = {
        fail = !success
        result
        success = success
        time = get_sync_time()
      }
      sessionId = get_session_id()
      showButtons = state == EndgameControllerState.DEBRIEFING
    }
  }
  return null
})

function exitBattle(){
  showDebriefing(false)
  if (isOnboarding.get()){
    let success = computedDebriefingData.get()?.result.success ?? true
    ecs.g_entity_mgr.broadcastEvent(EventOnboardingRaidExit({success}))
    return
  }
  if (isInBattleState.get())
    switch_to_menu_scene()
}

addTabToDevInfo("debriefing", computedDebriefingData, @"
console commands:
  baseDebriefing.showSample -- show debriefing sample
")

let missSecondPlayedThisDeath = nestWatched("missSecondPlayedThisDeath", false)


computedDebriefingData.subscribe(function(v) {
  log($"[debriefing data]: autoExit={v?.autoExit} ; realDebriefing={v?.result != null} ; success={v?.result?.success}")
  if (v?.autoExit ?? false) {
    exitBattle()
    return
  }

  let isRealDebriefing = v?.result != null
  if (isRealDebriefing) {
    eventbus_send("closeAllMenus", null)
  }

  showDebriefing(isRealDebriefing)
  if (isRealDebriefing && !(v?.result?.success ?? false) && !missSecondPlayedThisDeath.get()) {
    ecs.g_entity_mgr.sendEvent(localPlayerEid.get(), CmdStartAssistantSpeak({scriptName = "raid_die_message", skipBeepSound = true}))
    missSecondPlayedThisDeath.set(true)
  }
})

isAlive.subscribe(@(v) v ? missSecondPlayedThisDeath.set(false) : null)

function loadDebriefing(path = null) {
  path = path ?? "%ui/mainMenu/debriefing/debriefing_sample.json"
  let data = loadJson(path, { logger = log_for_user })

  deathCause.set(data?.deathCause)
  heroAmValue.set(data?.earned_am ?? 0)

  fakeDebriefing.set(data)
}

function saveDebriefing(path="") {
  let dData = computedDebriefingData.get()
  let { sessionId = "0" } = dData
  path = path!="" ? $"{path}/" : ""
  path = $"{path}debriefing_{sessionId}.json"
  saveJson(path, dData, {logger = log_for_user})
  log($"Debriefing for session {sessionId} saved as {path}")
}

console_register_command(@(path="") saveDebriefing(path), "ui.debriefing_save")

console_register_command(function() {
  loadDebriefing()
  showDebriefing(true)
}, "ui.show_sample_debriefing")

console_register_command(function(path) {
  loadDebriefing(path)
  showDebriefing(true)
}, "ui.load_debriefing")

return {
  showDebriefing
  computedDebriefingData
  exitBattle
}