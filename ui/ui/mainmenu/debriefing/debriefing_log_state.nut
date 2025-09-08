let { Computed, Watched } = require("%ui/ui_library.nut")
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")
let { lastBattleResult } = require("%ui/profile/profileState.nut")
let { journalBattleResult } = require("%ui/profile/battle_results.nut")


let chosenLogElement = Watched(null) 
let hoveredLogElement = Watched(null)
let highlightedLogElement = Computed(@() hoveredLogElement.get() ?? chosenLogElement.get())

let logEntries = Computed(function() {
  if (!isOnPlayerBase.get()) {
    return []
  }

  let battleResult = lastBattleResult.get() ?? journalBattleResult.get()
  if (battleResult == null) {
    return []
  }

  return (battleResult?.trackPoints ?? [])
    .filter(@(point) point.eventType != "positionPoint")
    .map(@(v, i) v.__merge({index = i}))
})

return {
  logEntries
  chosenLogElement
  hoveredLogElement
  highlightedLogElement
}
