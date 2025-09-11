from "%ui/components/commonComponents.nut" import mkText, underlineComp
from "%ui/components/colors.nut" import InfoTextValueColor, InfoTextDescColor
from "%ui/fonts_style.nut" import body_txt
from "%ui/components/scrollbar.nut" import makeVertScroll
from "%ui/components/mkSelection.nut" import mkSelection
import "%ui/components/checkbox.nut" as checkBox

from "%ui/ui_library.nut" import *

#allow-auto-freeze

let { playerStats,
      playerProfileAllResearchNodes,
      playerProfileOpenedNodes,
      playerBaseState,
      playerProfileUnlocksData } = require("%ui/profile/profileState.nut")
let { matchingQueuesMap } = require("%ui/matchingQueues.nut")

let gameModeOptions = [
  { locId = "stats/game_mode/operative" }
  { locId = "stats/game_mode/monster"}
]

let selectedGameMode = Watched({ locId = "stats/game_mode/operative" })
let selectedZone = Watched({ locId = "stats/zone/all" })
let isGlobalStats = Watched(false)

let killsStats = [
  "kills"
  "deaths"
  "kills_operative"
  "kills_monster"
  "kills_monster_flowerman"
  "kills_monster_flowerman_boss"
  "kills_monster_invisible"
  "kills_monster_changed"
  "kills_monster_changed_boss"
  "kills_monster_worms"
  "kills_monster_corrupted_soldiers"
  "kills_monster_mimic"
  "kills_monster_xenohound"
  "kills_monster_dendroid"
  "kills_monster_statue"
]

let raidStats = [
  "raid_count"
  "raid_success"
  "primary_objectives_complete"
  "secondary_objectives_complete"
  "story_objectives_complete"
  "item_objectives_complete"
]

let explorationStats = [
  "collected_am"
  "collected_loot"
]

function mkStatString(statName, statValue) {
  return {
    padding = hdpx(5)
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    children = [
      mkText(statName, { color = InfoTextDescColor })
      { size = static [flex(), 0] }
      mkText(statValue, { color = InfoTextValueColor })
    ]
  }
}

function mkSectionStrings(data, sectionStats) {
  return sectionStats.map(@(v) underlineComp(mkStatString(loc($"stats/{v}"), data?[v] ?? -1)))
}


let mkStatSection = @(stats, sectionName=null) stats?.len() ? {
  flow = FLOW_VERTICAL
  size = FLEX_H
  padding = hdpx(10)
  gap = hdpx(10)
  children = [
    sectionName ? mkText(sectionName, body_txt) : null
    {
      padding = static [0, 0, 0, hdpx(10)]
      flow = FLOW_VERTICAL
      size = FLEX_H
      gap = hdpx(5)
      children = stats
    }
  ]
} : null

function mkUnlocks() {
  let unlocks = playerStats.get()?.unlocks
    .filter(@(v) playerProfileUnlocksData.get()?[v]?.isJournalVisible ?? false)
    .sort()
  if(!unlocks?.len())
    return null

  let rows = unlocks.map(@(v) underlineComp( {
    padding = hdpx(5)
    children = mkText(loc($"stats/{v}"), {color = InfoTextValueColor})
  }))

  return mkStatSection(rows, loc("stats/section/unlock"))
}

function getResearchStats() {
  #forbid-auto-freeze
  let researchStats = {}
  let researchStat = {
    maxPoints = 0
    currentPoints = 0
    researches = 0
    researchesOpened = 0
  }
  #allow-auto-freeze
  foreach (id, research in playerProfileAllResearchNodes.get()) {
      researchStat.maxPoints += research.requireResearchPointsToComplete
      researchStat.researches++
      researchStats[id] <- researchStat
    }

  foreach (openedRes in playerProfileOpenedNodes.get()) {
    let node = playerProfileAllResearchNodes.get()?[openedRes.prototypeId]
    let stat = researchStats?[openedRes.prototypeId]
    if (node && stat != null) {
      if ((node?.requireResearchPointsToComplete ?? 0) <= (openedRes?.currentResearchPoints ?? 0))
        stat.researchesOpened++
      stat.currentPoints += openedRes.currentResearchPoints
    }
  }
  #forbid-auto-freeze
  let content = []
  #allow-auto-freeze
  let summary = researchStats.reduce(@(res, v) res.__update({
    currentPoints = res.currentPoints + v.currentPoints
    maxPoints = res.maxPoints + v.maxPoints
    researchesOpened = res.researchesOpened + v.researchesOpened
    researches = res.researches + v.researches
  }), researchStat)
  let points = (playerBaseState.get()?.openedReplicatorDevices ?? 0) > 0 ? $"{summary.currentPoints}/{summary.maxPoints}" : "---"
  let researches = (playerBaseState.get()?.openedReplicatorDevices ?? 0) > 0 ?  $"{summary.researchesOpened}/{summary.researches}" : "---"
  content.append(
    underlineComp(mkStatString(loc("chronotraces"), points))
    underlineComp(mkStatString($"{loc("stats/research/researches")}", researches))
  )

  return mkStatSection( {
    size = FLEX_H
    flow = FLOW_VERTICAL
    gap = hdpx(5)
    children = content
  }, loc("stats/section/research"))
}

function leftSide() {
  let stats = playerStats.get()?.statsCurrentSeason ?? {}
  #forbid-auto-freeze
  let zoneOptions = stats.reduce(function(acc, _val, key) {
    let zone = key.replace("_operative", "").replace("_monster", "")
    let isAlreadyAdded = acc.findvalue(@(v) v.locId == zone) != null
    if (!isAlreadyAdded && zone != "operative" && zone != "monster")
      acc.append({locId = zone})
    return acc
  }, [])
  #allow-auto-freeze
  let sortedZones = zoneOptions.sort(function(a, b) {
    let extraparamsA = matchingQueuesMap.get().findvalue(@(v) v?.extraParams.zone == a.locId)
    let extraparamsB = matchingQueuesMap.get().findvalue(@(v) v?.extraParams.zone == b.locId)
    return (extraparamsA?.extraParams.uiOrder ?? 999) <=> (extraparamsB?.extraParams.uiOrder ?? 999)
  }).insert(0, static { locId = "stats/zone/all" })
  let gameModeSelection = mkSelection(gameModeOptions, selectedGameMode)
  let zoneSelection = mkSelection(sortedZones, selectedZone)
  let isGlobalStatsSelection = checkBox(isGlobalStats, loc("career/showGlobalStatCheckbox"), static { textOnTheLeft = true override = { padding = hdpx(4) } })

  let data = Computed(function(){
    let mode = gameModeOptions.findvalue(@(v) v.locId == selectedGameMode.get().locId)?.locId ?? ""
    let gameMode = mode.replace("stats/game_mode/", "")
    let zone = sortedZones.findvalue(@(v) v.locId == selectedZone.get().locId)?.locId ?? ""
    let allData = isGlobalStats.get() ? (playerStats.get()?.stats ?? {}) : (playerStats.get()?.statsCurrentSeason ?? {})

    if (zone == "stats/zone/all")
      return allData?[gameMode] ?? {}

    return allData?[$"{zone}_{gameMode}"] ?? allData?[$"{zone}"]  ?? {}
  })

  let statsComp = makeVertScroll(@(){
    watch = data
    size = FLEX_H
    gap = hdpx(15)
    flow = FLOW_VERTICAL
    children = [].append(
      mkStatSection(mkSectionStrings(data.get(), killsStats), loc("stats/section/kills"))
      mkStatSection(mkSectionStrings(data.get(), raidStats), loc("stats/section/raids"))
      mkStatSection(mkSectionStrings(data.get(), explorationStats), loc("stats/section/exploration"))
      selectedGameMode.get().locId == "stats/game_mode/operative" ? mkUnlocks() : null
    )
  })
  #allow-auto-freeze
  return {
    watch = playerStats
    size = flex()
    flow = FLOW_VERTICAL
    gap = hdpx(4)
    children = [
      {
        size = FLEX_H
        flow = FLOW_HORIZONTAL
        gap = hdpx(10)
        children = [
          {
            flow = FLOW_VERTICAL
            size = FLEX_H
            gap = hdpx(4)
            children = [
              zoneSelection
              isGlobalStatsSelection
            ]
          }
          {
            flow = FLOW_VERTICAL
            size = FLEX_H
            gap = hdpx(4)
            children = [
              gameModeSelection
            ]
          }
        ]
      }
      statsComp
    ]
  }
}

let rightSide = {
  size = flex()
  children = makeVertScroll(@(){
    watch = playerStats
    size = FLEX_H
    gap = hdpx(15)
    flow = FLOW_VERTICAL
    children = [].append(
      getResearchStats()
    )
  })
}

let playerStatPanel = @() {
  flow = FLOW_HORIZONTAL
  size = flex()
  gap = hdpx(20)
  children = [ leftSide, rightSide ]
}

return playerStatPanel