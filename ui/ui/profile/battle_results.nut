from "%ui/ui_library.nut" import *

let { settings, onlineSettingUpdated } = require("%ui/options/onlineSettings.nut")
let { nestWatched } = require("%dngscripts/globalState.nut")
let { vectorToTable } = require("%ui/helpers/parseSceneBlk.nut")

let battleResultsSaveQueue = nestWatched("battleResultsSaveQueue", [])
let journalBattleResult = Watched(null)

let maxSavedBattleResults = 10
const CURRENT_VERSION = 6

function updateOnlineStorageBattleResults() {
  if (battleResultsSaveQueue.get().len() == 0 || !onlineSettingUpdated.get()) {
    return
  }

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
  })

  battleResultsSaveQueue.set([])
}

battleResultsSaveQueue.subscribe(@(...) updateOnlineStorageBattleResults())
onlineSettingUpdated.subscribe(@(...) updateOnlineStorageBattleResults())


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

  battleResultsSaveQueue.mutate(function(v) {
    
    
    
    let knownBattles = v.extend(settings.get()?.battleResults ?? [])
    foreach(knownBattle in knownBattles) {
      if (knownBattle?.id == result?.id) {
        return
      }
    }

    v.append(battleResultVectorsToTable(result).__update({ version = CURRENT_VERSION }))
  })
}

function saveNexusBattleResultToHistory(result) {
  if (result == null) {
    return
  }

  battleResultsSaveQueue.mutate(function(v) {
    
    
    
    let knownBattles = v.extend(settings.get()?.battleResults ?? [])
    foreach(knownBattle in knownBattles) {
      if (knownBattle?.id == result?.id) {
        return
      }
    }
    v.append(result.__update({ version = CURRENT_VERSION }))
  })
}

function isBattleResultInHistory(id) {
  return (settings.get()?.battleResults ?? []).findindex(@(v) v?.id == id) != null
}

return {
  maxSavedBattleResults
  createBattleResultsComputed = @() Computed(@() settings.get()?.battleResults ?? [])
  saveBattleResultToHistory
  saveNexusBattleResultToHistory
  isBattleResultInHistory
  journalBattleResult
  CURRENT_VERSION
}
