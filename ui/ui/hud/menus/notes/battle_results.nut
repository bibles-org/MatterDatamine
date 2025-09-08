from "%ui/ui_library.nut" import *
from "%ui/components/colors.nut" import BtnBgNormal, BtnBgSelected, RedFailColor, BtnBdNormal, ItemBgColor, InfoTextValueColor, ConsoleFillColor, RedWarningColor, TextNormal

let { h2_txt, body_txt, h1_txt, sub_txt } = require("%ui/fonts_style.nut")
let { createBattleResultsComputed, maxSavedBattleResults, journalBattleResult, CURRENT_VERSION
} = require("%ui/profile/battle_results.nut")
let { mkText, mkTextArea, mkSelectPanelItem, BD_LEFT, VertSelectPanelGap, mkTabs
} = require("%ui/components/commonComponents.nut")
let { format_unixtime } = require("dagor.time")
let { secondsToStringLoc } = require("%ui/helpers/time.nut")
let faComp = require("%ui/components/faComp.nut")
let { mkDebriefingMap, updateMapContext } = require("%ui/mainMenu/baseDebriefingMap.nut")
let { debriefingStats, mkTeamBlock, mkDailyRewardsStats } = require("%ui/mainMenu/baseDebriefingTeamStats.nut")
let { debriefingLog } = require("%ui/mainMenu/baseDebriefingLog.nut")
let { mkDebriefingItemsList, mkDebriefingCronotracesList } = require("%ui/mainMenu/horisontalItemList.nut")
let { makeVertScrollExt, thinAndReservedPaddingStyle } = require("%ui/components/scrollbar.nut")
let { mkFakeItem } = require("%ui/hud/menus/components/fakeItem.nut")
let { updateDebriefingContractsData } = require("%ui/mainMenu/debriefing/debriefing_quests_state.nut")
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")
let { inventoryItem } = require("%ui/hud/menus/components/inventoryItem.nut")
let { mkActiveMatterStorageWidget } = require("%ui/hud/menus/components/amStorage.nut")
let { mkMapContainer, debriefingScene } = require("%ui/mainMenu/nexus_debriefing_map.nut")
let { mkPlayerStats, defStats, statsHeader, mkMvpPlayerBlock, getScoresTbl
} = require("%ui/hud/menus/nexus_stats.nut")
let userInfo = require("%sqGlob/userInfo.nut")
let { remap_nick } = require("%ui/helpers/remap_nick.nut")
let { NexusMvpReason } = require("%sqGlob/dasenums.nut")
let colorize = require("%ui/components/colorize.nut")

const MAX_ITEM_TO_SHOW = 10

let battleResultCardSize = [hdpx(300), hdpx(71)]
let iconHeight = hdpxi(24)
let smallIconHeight = hdpxi(14)
let mapHeight = min(sh(50), hdpx(500))
let nexusMapHeight = min(sh(64), hdpx(670))
let allyTeamColor = const 0xFF18e7e6

let currentTab = Watched("battleHistory/history")

let mapSize = [mapHeight, mapHeight]
let nexusMapSize = [nexusMapHeight, nexusMapHeight]

let dateFormatString = "%d %b %H:%M"

let isBattleSuccessiful = @(battle) battle.battleStat?.isSuccessRaid ?? false

let successIcon = {
  rendObj = ROBJ_IMAGE
  size = [iconHeight, iconHeight]
  color = Color(153, 240, 143)
  image = Picture("ui/skin#extraction_point.svg:{0}:{0}:K".subst(iconHeight))
}

let failIcon = {
  rendObj = ROBJ_IMAGE
  size = [iconHeight, iconHeight]
  color = RedFailColor
  image = Picture("ui/skin#skull.svg:{0}:{0}:K".subst(iconHeight))
}

let calendarIcon = faComp("calendar-o", {
  fontSize = smallIconHeight
})

function mkRaidName(battle, params) {
  let raidNameLocId = (battle?.battleAreaInfo.raidName ?? "").split("+")
  if ((raidNameLocId?[0] ?? "") == "")
    return mkText(loc("raidInfo/unknown/short"), h2_txt)
  let resLocId = "_".join(raidNameLocId.filter(@(v) v != "ordinary"))
  return mkText(loc(resLocId), {
    size = [flex(), SIZE_TO_CONTENT]
    behavior = Behaviors.Marquee
    group = params?.group
    scrollOnHover = true
  }.__update(h2_txt))
}


function mkTimeBlock(battle) {
  let time = battle?.gameDuration ?? battle.trackPoints?[battle.trackPoints.len() - 1]?.timestamp ?? 0
  return mkText(secondsToStringLoc(time))
}

let mkRaidDateTimeBlock = @(battle) {
  flow = FLOW_HORIZONTAL
  gap = mkText(" — ")
  valign = ALIGN_CENTER
  children = [
    {
      flow = FLOW_HORIZONTAL
      gap = hdpx(4)
      valign = ALIGN_CENTER
      children = [
        calendarIcon
        mkText(battle?.dateTime != null && battle.dateTime != ""
          ? format_unixtime(dateFormatString, battle.dateTime.tointeger())
          : loc("baseDebriefing/unknownDate"))
      ]
    }
    mkTimeBlock(battle)
  ]
}

let visual_params = {size = battleResultCardSize, padding = 0}
function mkBattleCard(battle) {
  let state = Computed(@() journalBattleResult.get()?.id )
  return mkSelectPanelItem({
    visual_params
    state
    idx = battle.id
    border_align = BD_LEFT
    onSelect = function(_) {
      journalBattleResult.set(battle)
      currentTab.set("battleHistory/history")
      updateMapContext(battle?.battleAreaInfo.scene, mapSize)
      updateDebriefingContractsData(isOnPlayerBase.get(), battle)
    }
    children = @(params) {
      size = battleResultCardSize
      flow = FLOW_HORIZONTAL
      gap = hdpx(10)
      padding = [hdpx(4), hdpx(12)]
      valign = ALIGN_CENTER
      children = [
        isBattleSuccessiful(battle) ? successIcon : failIcon
        {
          size = [flex(), SIZE_TO_CONTENT]
          flow = FLOW_VERTICAL
          gap = hdpx(4)
          clipChildren = true
          children = [
            mkRaidName(battle, params)
            mkRaidDateTimeBlock(battle)
          ]
        }
      ]
    }
  })
}

function mkNexusCard(battle) {
  let state = Computed(@() journalBattleResult.get()?.id)
  return mkSelectPanelItem({
    visual_params
    state
    idx = battle.id
    border_align = BD_LEFT
    onSelect = function(_) {
      journalBattleResult.set(battle)
      currentTab.set("baseDebriefing/stats")
      debriefingScene.set(battle?.battleAreaInfo.scene)
    }
    children = @(params) {
      size = battleResultCardSize
      flow = FLOW_HORIZONTAL
      gap = hdpx(10)
      padding = [hdpx(4), hdpx(12)]
      valign = ALIGN_CENTER
      children = [
        battle?.isWinner ? successIcon : failIcon
        {
          size = [flex(), SIZE_TO_CONTENT]
          flow = FLOW_VERTICAL
          gap = hdpx(4)
          children = [
            mkRaidName(battle, params)
            mkRaidDateTimeBlock(battle)
          ]
        }
      ]
    }
  })
}

let mkBattlesList = @(battleResults) battleResults.len() <= 0
  ? mkTextArea(loc("battleResult/empty"), body_txt)
  : makeVertScrollExt({
    flow = FLOW_VERTICAL
    gap = VertSelectPanelGap
    children = battleResults.map(@(v) v?.isNexus ? mkNexusCard(v) : mkBattleCard(v)).reverse()
  }, { size = [SIZE_TO_CONTENT, flex()] })

let historyContent = {
  size = flex()
  flow = FLOW_HORIZONTAL
  gap = hdpx(10)
  children = [
    {
      flow = FLOW_VERTICAL
      gap = hdpx(10)
      children = [
        mkDebriefingMap(mapSize)
        @() {
          watch = journalBattleResult
          size = [flex(), SIZE_TO_CONTENT]
          children = mkTeamBlock(journalBattleResult.get(), hdpxi(86))
        }
      ]
    }
    {
      size = flex()
      flow = FLOW_VERTICAL
      gap = hdpx(20)
      padding = [0,0, hdpx(10), 0]
      children = [
        debriefingLog
        debriefingStats
      ]
    }
  ]
}

let mkEvacuatedItems = @(itemsToShow) itemsToShow.len() <= 0 ? null : {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  gap = hdpx(10)
  children = [
    mkText(loc("baseDebriefing/evacuated"), h2_txt)
    mkDebriefingItemsList(itemsToShow, MAX_ITEM_TO_SHOW)
  ]
}

let mkChronotracesList = @(openedReseachNodesV2, chronotracesProgression)
  openedReseachNodesV2.len() <= 0 && chronotracesProgression.len() <= 0 ? null : {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      mkText(loc("baseDebriefing/chronotraces"), h2_txt)
      mkDebriefingCronotracesList(openedReseachNodesV2, chronotracesProgression, MAX_ITEM_TO_SHOW)
    ]
}

let arrow = faComp("arrow-right", { fontSize = hdpx(25) })

let mkAmExchangeBlock = @(AMResource) {
  size = [flex(), ph(100)]
  minHeight = hdpx(114)
  flow = FLOW_VERTICAL
  gap = hdpx(5)
  children = [
    mkText(loc("activeMatter"), h2_txt)
    {
      size = flex()
      flow = FLOW_HORIZONTAL
      gap = hdpx(10)
      valign = ALIGN_CENTER
      children = [
        mkActiveMatterStorageWidget(AMResource)
        arrow
        inventoryItem(mkFakeItem("credit_coins_pile", { count = AMResource * 100 }), null)
      ]
    }
  ]
}

let mkDailyRewardsBlock = @(monolithCreditsCount, AMResource) {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  gap = { size = [flex(0.2), SIZE_TO_CONTENT]}
  children = [
    monolithCreditsCount <= 0 ? null : {
      size = [flex(1.6), SIZE_TO_CONTENT]
      children = mkDailyRewardsStats(monolithCreditsCount)
    }
    AMResource <= 0 ? null : mkAmExchangeBlock(AMResource)
  ]
}

function resourceAndItems() {
  if (journalBattleResult.get() == null)
    return { watch = journalBattleResult }
  let battle = journalBattleResult.get()
  let { battleStat = {}, chronotracesProgression = [], loadout = [], dailyStatRewards = {},
    openedReseachNodesV2 = [] } = battle
  let { AMResource = 0 } = battleStat
  let monolithCreditsCount = dailyStatRewards.reduce(@(acc, v) acc+=v, 0)
  let hasEvacuatedItems = loadout.findindex(@(v) v?.isFoundInRaid)
  if (dailyStatRewards.len() <= 0
    && loadout.len() <= 0
    && hasEvacuatedItems == null
    && openedReseachNodesV2.len() <= 0
    && chronotracesProgression.len() <= 0
    && AMResource <= 0
    && monolithCreditsCount <= 0
  )
    return {
      watch = journalBattleResult
      size = [flex(), mapSize[1]]
      children = mkText(loc("baseDebriefing/noData"), { hplace = ALIGN_CENTER, vplace =  ALIGN_CENTER }.__update(h2_txt))
    }

  return {
    watch = journalBattleResult
    size = flex()
    flow = FLOW_VERTICAL
    gap = hdpx(20)
    children = [
      mkEvacuatedItems(loadout.filter(@(v) v?.isFoundInRaid))
      mkChronotracesList(openedReseachNodesV2, chronotracesProgression)
      mkDailyRewardsBlock(monolithCreditsCount, AMResource)
    ]
  }
}

let rewardsContent =  {
  size = flex()
  flow = FLOW_HORIZONTAL
  gap = hdpx(10)
  children = [
    {
      flow = FLOW_VERTICAL
      gap = hdpx(10)
      children = [
        mkDebriefingMap(mapSize)
        @() {
          watch = journalBattleResult
          size = const [flex(), SIZE_TO_CONTENT]
          children = mkTeamBlock(journalBattleResult.get(), hdpxi(86))
        }
      ]
    }
    {
      size = flex()
      flow = FLOW_VERTICAL
      gap = hdpx(20)
      padding = const [0,0, hdpx(10), 0]
      children = resourceAndItems
    }
  ]
}

function mkNexusCreditsBlock(data) {
  let { credits = 0 } = data
  if (credits <= 0)
    return null
  return {
    size = [flex(), ph(100)]
    minHeight = hdpx(114)
    flow = FLOW_VERTICAL
    gap = hdpx(5)
    children = [
      mkText(loc("credits"), h2_txt)
      {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        gap = hdpx(10)
        valign = ALIGN_CENTER
        children = inventoryItem(mkFakeItem("credit_coins_pile", { count = credits }), null)
      }
    ]
  }
}

function nexusRewardsContent() {
  let isEmpty = (journalBattleResult.get()?.credits ?? 0) <= 0
  return {
    watch = journalBattleResult
    size = flex()
    flow = FLOW_HORIZONTAL
    gap = hdpx(10)
    children = [
      mkMapContainer(nexusMapSize)
      {
        size = flex()
        children = [
          !isEmpty ? null
            : mkText(loc("baseDebriefing/noData"), { hplace = ALIGN_CENTER, vplace =  ALIGN_CENTER }.__update(h2_txt))
          mkNexusCreditsBlock(journalBattleResult.get())
        ]
      }
    ]
  }
}

let statsBlockSeparator = {
  rendObj = ROBJ_SOLID
  size = [hdpx(2), flex()]
  color = BtnBdNormal
  margin = [0, hdpx(10)]
}

function statsBlock() {
  let { players, team } = journalBattleResult.get()
  if (players.len() == 0)
    return { watch = journalBattleResult }

  let playersByTeam = players.reduce(function(res, pData, pId) {
    let pTeam = pData.team
    if (pTeam not in res)
      res[pTeam] <- {}
    res[pTeam][pId] <- pData
    return res
  }, {})

  let allyTeam = playersByTeam[team]
  let enemyTeam = playersByTeam.filter(@(_, k) k != team).values()?[0] ?? {}
  let sortByScore = @(a, b, teamData) teamData[b]?.stats.score <=> teamData[a]?.stats.score
  let allyTeamArr = allyTeam.keys().sort(@(a, b) sortByScore(a, b, allyTeam))
  let enemyTeamArr = enemyTeam.keys().sort(@(a, b) sortByScore(a, b, enemyTeam))
  return {
    watch = journalBattleResult
    size = flex()
    flow = FLOW_HORIZONTAL
    gap = statsBlockSeparator
    children = [
      {
        size = flex()
        flow = FLOW_VERTICAL
        gap = const hdpx(10)
        halign = ALIGN_CENTER
        children = [
          mkText(const loc("nexus/playerTeam"), { color = allyTeamColor }.__update(h2_txt))
          statsHeader
          makeVertScrollExt({
            size = [flex(), SIZE_TO_CONTENT]
            flow = FLOW_VERTICAL
            children = allyTeamArr.map(@(eid, idx) @() {
              watch = userInfo
              rendObj = ROBJ_SOLID
              size = const [flex(), SIZE_TO_CONTENT]
              padding = const [hdpx(10), hdpx(8)]
              color = eid == userInfo.get().userId ? ItemBgColor
                : mul_color(idx == 0 || idx % 2 == 0 ? ItemBgColor : BtnBgNormal, 1.0, 0.4)
              flow = FLOW_HORIZONTAL
              gap = const { size = flex() }
              children = [
                {
                  flow = FLOW_HORIZONTAL
                  gap = const hdpx(10)
                  children = [
                    mkText(idx + 1, {
                      size = const [hdpx(40), SIZE_TO_CONTENT]
                      halign = ALIGN_CENTER
                    }.__update(body_txt))
                    mkText(remap_nick(allyTeam[eid].name), body_txt)
                  ]
                }
                mkPlayerStats(allyTeam?[eid].stats ?? defStats)
              ]
            })
          }, { styling = thinAndReservedPaddingStyle })
        ]
      }
      {
        flow = FLOW_VERTICAL
        size = flex()
        gap = const hdpx(10)
        halign = ALIGN_CENTER
        children = [
          const mkText(loc("nexus/enemyTeam"), { color = RedWarningColor }.__update(h2_txt))
          statsHeader(true)
          makeVertScrollExt({
            size = [flex(), SIZE_TO_CONTENT]
            flow = FLOW_VERTICAL
            children = enemyTeamArr.map(@(eid, idx) @() {
              rendObj = ROBJ_SOLID
              size = const [flex(), SIZE_TO_CONTENT]
              padding = const [hdpx(10), hdpx(8)]
              color = mul_color(idx == 0 || idx % 2 == 0 ? ItemBgColor : BtnBgNormal, 1.0, 0.4)
              flow = FLOW_HORIZONTAL
              gap = const { size = flex() }
              children = [
                {
                  flow = FLOW_HORIZONTAL
                  gap = const hdpx(10)
                  children = [
                    mkText(idx + 1, {
                      size = const [hdpx(40), SIZE_TO_CONTENT]
                      halign = ALIGN_CENTER
                    }.__update(body_txt))
                    mkText(remap_nick(enemyTeam[eid].name), body_txt)
                  ]
                }
                mkPlayerStats(enemyTeam?[eid].stats ?? defStats)
              ]
            })
          }, { styling = thinAndReservedPaddingStyle })
        ]
      }
    ]
  }
}

function gameResultTitle() {
  let { isWinner, modeSpecificData, team } = journalBattleResult.get()
  let text = isWinner ? loc("nexus/victory") : loc("nexus/defeat")
  let color = isWinner ? allyTeamColor : RedWarningColor
  let localPlayerScore = modeSpecificData?.score[team.tostring()]
  let enemyScore = modeSpecificData.len() <= 0 ? null
    : modeSpecificData.score.filter(@(_v, t) t != team.tostring()).values()[0]
  return {
    watch = journalBattleResult
    rendObj = ROBJ_SOLID
    size = [flex(), SIZE_TO_CONTENT]
    halign = ALIGN_CENTER
    color = ConsoleFillColor
    padding = const [hdpx(8), 0]
    flow = FLOW_VERTICAL
    children = [
      mkText(text, { color }.__update(h1_txt))
      localPlayerScore == null || enemyScore == null ? null : {
        flow = FLOW_HORIZONTAL
        gap = mkText(" : ", h2_txt)
        valign = ALIGN_CENTER
        children = [
          mkText(localPlayerScore, { color = allyTeamColor }.__update(h2_txt))
          mkText(enemyScore, { color = RedWarningColor }.__update(h2_txt))
        ]
      }
    ]
  }
}

let mvpOrder = [NexusMvpReason.MOST_KILLS, NexusMvpReason.MOST_BEACON_CAPTURES, NexusMvpReason.MOST_HELP]

function mkMvpBlock() {
  let { mvps, players, team } = journalBattleResult.get()
  if (mvps.len() <= 0)
    return { watch = journalBattleResult }
  let scoresTbl = getScoresTbl()
  return {
    watch = journalBattleResult
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    gap = hdpx(50)
    halign = ALIGN_CENTER
    children = mvpOrder.map(function(mvpBlock) {
      let data = mvps?[mvpBlock.tostring()]
      if (data == null)
        return null
      let { owner } = data
      let titleLoc = mvpBlock == NexusMvpReason.MOST_KILLS ? "stats/mostKills"
        : mvpBlock == NexusMvpReason.MOST_BEACON_CAPTURES ? "stats/mostCaptures"
        : "stats/mostAssists"
      let descLoc = mvpBlock == NexusMvpReason.MOST_KILLS ? "stats/maxKills"
        : mvpBlock == NexusMvpReason.MOST_BEACON_CAPTURES ? "stats/maxCaptures"
        : "stats/maxAssists"
      let playerData = players[owner]
      let count = mvpBlock == NexusMvpReason.MOST_KILLS ? playerData.stats.kill
        : mvpBlock == NexusMvpReason.MOST_BEACON_CAPTURES ? playerData.stats.beacon_capture
        : (playerData.stats.beacon_reset + playerData.stats.assist)
      let totalScore = playerData.stats.score
      let hint = mvpBlock != NexusMvpReason.MOST_HELP ? null
        : loc("nexus/mvpAssistsHint", {
          assist = colorize(InfoTextValueColor, $"{playerData.stats.assist * scoresTbl.assist }"),
          portal = colorize(InfoTextValueColor, $"{playerData.stats.beacon_reset * scoresTbl.beacon_reset}")
        })
      let color = playerData.team == team ? allyTeamColor : RedWarningColor
      return mkMvpPlayerBlock(playerData.name, loc(titleLoc), loc(descLoc, { count, counts = count }),
        playerData.team, totalScore, hint, color)
    })
  }
}

let statsContent = {
  size = flex()
  flow = FLOW_VERTICAL
  gap = const hdpx(10)
  children = [
    gameResultTitle
    mkMvpBlock
    statsBlock
  ]
}

let tabConstr = @(locId, params) mkText(loc(locId), params.__update( { fontFx = null }, body_txt))

let mkTabsList = @(isNexus) [
  {
    id = "baseDebriefing/stats"
    childrenConstr = @(params) tabConstr("nexus/nexusStatsWnd", params)
    content = statsContent
    isNexus = true
  }
  {
    id = "baseDebriefing/rewards"
    childrenConstr = @(params) tabConstr("baseDebriefing/rewards", params)
    content = nexusRewardsContent
    isNexus = true
  }
  { id = "battleHistory/history"
    childrenConstr = @(params) tabConstr("baseDebriefing/history", params)
    content = historyContent
    isNexus = false
  }
  {
    id = "battleHistory/rewards"
    childrenConstr = @(params) tabConstr("baseDebriefing/rewards", params)
    content = rewardsContent
    isNexus = false
  }
].filter(@(v) v.isNexus == isNexus)

let getCurTabContent = @(tabId, tabsList) tabsList.findvalue(@(v) v.id == tabId)?.content


function raidDetails() {
  let tabsList = mkTabsList(journalBattleResult.get()?.isNexus ?? false)
  let tabsUi = mkTabs({
    tabs = tabsList
    currentTab = currentTab.get()
    onChange = @(tab) currentTab.set(tab.id)
  })
  let tabContent = getCurTabContent(currentTab.get(), tabsList)
  return {
    watch = [currentTab, journalBattleResult]
    size = flex()
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      tabsUi
      tabContent
    ]
  }
}

function mkBattleResultTab() {
  let battleResults = createBattleResultsComputed()
  return function() {
    let results = battleResults.get().filter(@(result) (result?.version ?? -1) == CURRENT_VERSION)
    let hasResults = results.len() > 0
    return {
      watch = battleResults
      size = flex()
      flow = FLOW_VERTICAL
      gap = hdpx(10)
      onDetach = @() journalBattleResult.set(null)
      onAttach = function() {
        if (hasResults) {
          let battle = results[results.len() - 1]
          journalBattleResult.set(battle)
          if (battle?.isNexus) {
            currentTab.set("baseDebriefing/stats")
            debriefingScene.set(battle?.battleAreaInfo.scene)
          }
          updateDebriefingContractsData(isOnPlayerBase.get(), results[results.len() - 1])
        }
      }
      children = [
        mkText(loc("statisticsMenu/overwriteWarning", {maxSavedBattleResults}), const {color = mul_color(TextNormal, 0.5)}.__update(sub_txt) )
        {
          size = flex()
          flow = FLOW_HORIZONTAL
          gap = hdpx(20)
          children = [
            mkBattlesList(results)
            hasResults ? raidDetails : null
          ]
        }
      ]
    }
  }
}

return mkBattleResultTab
