from "%sqstd/json.nut" import parse_json, loadJson

from "base64" import decodeString
from "%ui/mainMenu/debriefing/debriefing_quests_state.nut" import updateDebriefingContractsData

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { lastBattleResult, lastNexusResult } = require("%ui/profile/profileState.nut")
let { userInfo } = require("%sqGlob/userInfoState.nut")
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")

function loadBaseDebriefingSample() {
  let data = loadJson("%ui/mainMenu/debriefing/battle_result_sample.json", { logger = log_for_user })

  let scene = data?.battleAreaInfo?.scene

  let encodedTrackPoints = data?.trackPointsV2 ?? ""
  let trackPoints = encodedTrackPoints.len() > 0 ? parse_json(decodeString(encodedTrackPoints)) : []
  data.trackPoints <- trackPoints

  let encodedTeamInfo = data?.teamInfo ?? ""
  data.teamInfo = encodedTeamInfo.len() > 0 ? parse_json(decodeString(data.teamInfo)) : {}
  let localUserId = userInfo.get().userId
  let hasLocalPlayer = localUserId in data.teamInfo

  
  
  
  if (!hasLocalPlayer) {
    let anyTeammateId = data.teamInfo.keys()[0]
    let info = data.teamInfo[anyTeammateId]
    data.teamInfo[localUserId] <- info
    data.teamInfo.$rawdelete(anyTeammateId)
  }

  if (scene == null || scene == ""){
    lastBattleResult.set(data)
    updateDebriefingContractsData(isOnPlayerBase.get(), data)
    return
  }
  
  
  lastBattleResult.set(data)
  updateDebriefingContractsData(isOnPlayerBase.get(), lastBattleResult.get())
}

function getBaseDebriefingData() {
  let data = loadJson("%ui/mainMenu/debriefing/battle_result_sample.json", { logger = log_for_user })
  let encodedTrackPoints = data?.trackPointsV2 ?? ""
  let trackPoints = encodedTrackPoints.len() > 0 ? parse_json(decodeString(encodedTrackPoints)) : []
  data.trackPoints <- trackPoints

  let encodedTeamInfo = data?.teamInfo ?? ""
  data.teamInfo = encodedTeamInfo.len() > 0 ? parse_json(decodeString(data.teamInfo)) : {}
  let localUserId = userInfo.get().userId
  let hasLocalPlayer = localUserId in data.teamInfo

  
  
  
  if (!hasLocalPlayer) {
    let anyTeammateId = data.teamInfo.keys()[0]
    let info = data.teamInfo[anyTeammateId]
    data.teamInfo[localUserId] <- info
    data.teamInfo.$rawdelete(anyTeammateId)
  }
  return data
}

function loadNexusDebriefingSample() {
  let last_nexus_result = loadJson("%ui/mainMenu/debriefing/nexus_result_sample.json", { logger = log_for_user })
  let encodedModeData = last_nexus_result?.modeSpecificData ?? ""
  let encodedPlayers = last_nexus_result?.players ?? ""
  let encodedMvps = last_nexus_result?.mvps ?? ""

  let modeData = encodedModeData.len() > 0 ? parse_json(decodeString(encodedModeData)) : []
  let players = encodedPlayers.len() > 0 ? parse_json(decodeString(encodedPlayers)) : []
  let mvps = encodedMvps.len() > 0 ? parse_json(decodeString(encodedMvps)) : []

  last_nexus_result.modeSpecificData <- modeData
  last_nexus_result.players <- players
  last_nexus_result.mvps <- mvps
  lastNexusResult.set(last_nexus_result)
}

return {
  loadBaseDebriefingSample
  loadNexusDebriefingSample
  getBaseDebriefingData
}
