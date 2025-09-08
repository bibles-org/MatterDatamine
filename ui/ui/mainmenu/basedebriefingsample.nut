from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
let { parse_json, loadJson } = require("%sqstd/json.nut")

let { lastBattleResult } = require("%ui/profile/profileState.nut")
let { decodeString } = require("base64")
let { userInfo } = require("%sqGlob/userInfoState.nut")
let { updateDebriefingContractsData } = require("%ui/mainMenu/debriefing/debriefing_quests_state.nut")
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

return loadBaseDebriefingSample
