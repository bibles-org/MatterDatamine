from "%dngscripts/globalState.nut" import nestWatched
from "%ui/mainMenu/baseDebriefingSample.nut" import getBaseDebriefingData, loadBaseDebriefingSample
from "%ui/helpers/parseSceneBlk.nut" import vectorToTable
from "string" import startswith

from "%ui/ui_library.nut" import *

let { settings, onlineSettingUpdated } = require("%ui/options/onlineSettings.nut")

let battleResultsSaveQueue = nestWatched("battleResultsSaveQueue", [])
let lastBattleResultByModeQueue = nestWatched("lastBattleResultByModeQueue", {})
let journalBattleResult = Watched(null)

enum ResultModes {
  OPERATIVE_RAID = "raid"
  NEXUS_RAID = "nexus"
}

let maxSavedBattleResults = 10
const CURRENT_VERSION = 7

function updateOnlineStorageBattleResults() {
  if ((lastBattleResultByModeQueue.get().len() == 0 && battleResultsSaveQueue.get().len() == 0)
    || !onlineSettingUpdated.get()
  )
    return

  settings.mutate(function(v){
    if (!("battleResults" in v)) {
      v.battleResults <- []
    }

    foreach (result in battleResultsSaveQueue.get()) {
      
      
      local isAlreadyAddeed = false
      foreach(archivedBattle in v.battleResults) {
        if (archivedBattle?.id == result?.id) {
          isAlreadyAddeed = true
          break
        }
      }
      if (isAlreadyAddeed) {
        continue
      }

      if (v.battleResults.len() >= maxSavedBattleResults) {
        v.battleResults = v.battleResults.slice(v.battleResults.len() - maxSavedBattleResults + 1)
      }

      v.battleResults.append(result)
    }
    if ("lastBattleResultsByMode" not in v)
      v.lastBattleResultsByMode <- {}
    foreach (mode, id in lastBattleResultByModeQueue.get())
      if (!startswith(id, "base") && !startswith(id, "nexus"))
        v.lastBattleResultsByMode[mode] <- id
  })

  battleResultsSaveQueue.set([])
  lastBattleResultByModeQueue.set({})
}

foreach (watch in [battleResultsSaveQueue, lastBattleResultByModeQueue, onlineSettingUpdated] )
  watch.subscribe_with_nasty_disregard_of_frp_update(@(...) updateOnlineStorageBattleResults())


function battleResultVectorsToTable(result) {
  result.trackPoints = result.trackPoints.map(function(v) {
    return v.__merge({
      position = vectorToTable(v.position)
    })
  })
  result.teamInfo = result.teamInfo.map(function(v) {
    return v.__merge( { ribbonColors = vectorToTable(v.ribbonColors) } )
  })

  if ("mapInfo" in result){
    foreach (field in ["visibleRange", "leftTop", "rightBottom", "leftTopBorder", "rightBottomBorder"]) {
      if (field in result.mapInfo) {
        result.mapInfo[field] = vectorToTable(result.mapInfo[field])
      }
    }
  }

  if ("zoneInfo" in result && "sourcePos" in result.zoneInfo)
    result.zoneInfo.sourcePos = vectorToTable(result.zoneInfo.sourcePos)

  return result
}

function saveBattleResultToHistory(result) {
  if (result == null) {
    return
  }
  let isInHiddenHistory = settings.get()?.lastBattleResultsByMode[ResultModes.OPERATIVE_RAID] == result.id
  if (isInHiddenHistory)
    return
  battleResultsSaveQueue.mutate(function(v) {
    
    
    
    let knownBattles = v.extend(settings.get()?.battleResults ?? [])
    foreach(knownBattle in knownBattles) {
      if (knownBattle?.id == result?.id) {
        return
      }
    }

    v.append(battleResultVectorsToTable(result).__update({ version = CURRENT_VERSION }))
  })

  lastBattleResultByModeQueue.mutate(function(modeData) {
    foreach (vMode in settings.get()?.lastBattleResultsByMode ?? {}) {
      if (vMode == result?.id)
        return
    }
    modeData[ResultModes.OPERATIVE_RAID] <- result.id
  })
}

function saveNexusBattleResultToHistory(result) {
  if (result == null) {
    return
  }
  let isInHiddenHistory = settings.get()?.lastBattleResultsByMode[ResultModes.NEXUS_RAID] == result.id
  if (isInHiddenHistory)
    return
  battleResultsSaveQueue.mutate(function(v) {
    
    
    
    let knownBattles = v.extend(settings.get()?.battleResults ?? [])
    foreach(knownBattle in knownBattles) {
      if (knownBattle?.id == result?.id) {
        return
      }
    }
    v.append(result.__update({ version = CURRENT_VERSION }))
  })
  lastBattleResultByModeQueue.mutate(function(modeData) {
    foreach (vMode in settings.get()?.lastBattleResultsByMode ?? {}) {
      if (vMode == result?.id)
        return
    }
    modeData[ResultModes.NEXUS_RAID] <- result.id
  })
}

function isBattleResultInHistory(id) {
  return (settings.get()?.battleResults ?? []).findindex(@(v) v?.id == id) != null
    || (settings.get()?.lastBattleResultsByMode ?? {}).findvalue(@(v) v == id) != null
}

console_register_command(@() settings.mutate(@(v) v.battleResults <- []), "battleResult.clear")
console_register_command(@() settings.mutate(@(v) v.lastBattleResultsByMode <- {}), "battleResultByMode.clear")
console_register_command(@() settings.mutate(function(v) {
  let results = []
  let curLen = v.battleResults.len()
  let neededCount = maxSavedBattleResults - curLen
  for (local i = 0; i < neededCount; i++) {
    let res = getBaseDebriefingData()
    res.id = $"{res.id}_{i}"
    res.version <- CURRENT_VERSION
    results.append(res)
  }
  v.battleResults <- results
}), "battleResult.fillFull")

return {
  maxSavedBattleResults
  createBattleResultsComputed = @() Computed(@() settings.get()?.battleResults ?? [])
  saveBattleResultToHistory
  saveNexusBattleResultToHistory
  isBattleResultInHistory
  journalBattleResult
  CURRENT_VERSION
}
