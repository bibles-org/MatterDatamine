from "%sqGlob/dasenums.nut" import NexusMvpReason
from "%ui/profile/battle_results.nut" import createBattleResultsComputed, maxSavedBattleResults, CURRENT_VERSION
from "%ui/components/commonComponents.nut" import mkText, mkTextArea, mkSelectPanelItem, BD_LEFT, VertSelectPanelGap, mkTabs
from "%ui/hud/menus/nexus_stats.nut" import mkPlayerStats, statsHeader, mkMvpPlayerBlock, getScoresTbl
from "%ui/mainMenu/debriefing_common_components.nut" import mkEvacuatedItems, mkChronotracesList, mkDailyRewardsBlock
from "%ui/fonts_style.nut" import h2_txt, body_txt, h1_txt, sub_txt, tiny_txt
from "dagor.time" import format_unixtime
from "%ui/helpers/time.nut" import secondsToStringLoc
import "%ui/components/faComp.nut" as faComp
from "%ui/mainMenu/baseDebriefingMap.nut" import mkDebriefingMap, updateMapContext
from "%ui/mainMenu/baseDebriefingTeamStats.nut" import debriefingStats, mkTeamBlock
from "%ui/components/scrollbar.nut" import makeVertScrollExt, thinAndReservedPaddingStyle
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem
from "%ui/mainMenu/debriefing/debriefing_quests_state.nut" import updateDebriefingContractsData
from "%ui/hud/menus/components/inventoryItem.nut" import inventoryItem
from "%ui/mainMenu/nexus_debriefing_map.nut" import mkMapContainer
from "%ui/helpers/remap_nick.nut" import remap_nick
import "%ui/components/colorize.nut" as colorize
from "%ui/mainMenu/menus/options/player_interaction_option.nut" import isStreamerMode, playerRandName
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
from "%ui/components/colors.nut" import BtnBgNormal, BtnBgSelected, RedFailColor, BtnBdNormal, BtnBdDisabled,
  ItemBgColor, InfoTextValueColor, ConsoleFillColor, RedWarningColor, TextNormal
from "%ui/mainMenu/baseDebriefingLog.nut" import debriefingLog, debriefingSessionId, complaintList, fakeComplaintList
import "%ui/complaints/complainWnd.nut" as complain
import "%ui/components/contextMenu.nut" as contextMenu
from "%ui/components/cursors.nut" import setTooltip
from "%ui/profile/battle_results.nut" import journalBattleResult, saveComplaintListToHistory

let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")
let { debriefingScene } = require("%ui/mainMenu/nexus_debriefing_map.nut")
let { defStats } = require("%ui/hud/menus/nexus_stats.nut")
let userInfo = require("%sqGlob/userInfo.nut")

#allow-auto-freeze

let battleResultCardSize = [hdpx(300), hdpx(73)]
let iconHeight = hdpxi(24)
let smallIconHeight = hdpxi(14)
let mapHeight = min(sh(50), hdpx(500))
let allyTeamColor = 0xFF18e7e6

let currentTab = Watched("battleHistory/history")

let mapSize = [mapHeight, mapHeight]

let dateFormatString = "%d %b %H:%M"

let isBattleSuccessiful = @(battle) battle?.battleStat?.isSuccessRaid ?? false

let successIcon = {
  rendObj = ROBJ_IMAGE
  size = iconHeight
  color = Color(153, 240, 143)
  image = Picture("ui/skin#extraction_point.svg:{0}:{0}:K".subst(iconHeight))
}

let failIcon = {
  rendObj = ROBJ_IMAGE
  size = iconHeight
  color = RedFailColor
  image = Picture("ui/skin#skull.svg:{0}:{0}:K".subst(iconHeight))
}

let calendarIcon = faComp("calendar-o", {
  fontSize = smallIconHeight
})

function mkRaidName(battle, params) {
  let raidNameLocId = (battle?.battleAreaInfo.raidName ?? "").split("+")
  if ((raidNameLocId?[1] ?? "") == "")
    return mkText(loc("missionInfo/unknown/short"), body_txt)
  let resLocId = "_".join(raidNameLocId.filter(@(v) v != "ordinary" && v!="raid"))
  return mkText(loc(resLocId), {
    size = FLEX_H
    behavior = Behaviors.Marquee
    group = params?.group
    scrollOnHover = true
  }.__update(body_txt))
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
      debriefingSessionId.set(battle?.sessionId)
      currentTab.set("battleHistory/history")
      updateMapContext(battle?.battleAreaInfo.scene, mapSize)
      updateDebriefingContractsData(isOnPlayerBase.get(), battle)
    }
    children = @(params) {
      size = battleResultCardSize
      flow = FLOW_HORIZONTAL
      gap = hdpx(10)
      padding = static [hdpx(4), hdpx(12)]
      valign = ALIGN_CENTER
      children = [
        isBattleSuccessiful(battle) ? successIcon : failIcon
        {
          size = FLEX_H
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
      debriefingSessionId.set(battle?.sessionId)
      currentTab.set("baseDebriefing/stats")
      debriefingScene.set(battle?.battleAreaInfo.scene)
    }
    children = @(params) {
      size = battleResultCardSize
      flow = FLOW_HORIZONTAL
      gap = hdpx(10)
      padding = static [hdpx(4), hdpx(12)]
      valign = ALIGN_CENTER
      children = [
        battle?.isWinner ? successIcon : failIcon
        {
          size = FLEX_H
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
  }, { size = FLEX_V })

let historyContent = {
  size = flex()
  flow = FLOW_HORIZONTAL
  gap = hdpx(10)
  children = [
    {
      size = FLEX_V
      children = [
        mkDebriefingMap(mapSize)
        @() {
          watch = journalBattleResult
          rendObj = ROBJ_BOX
          size = FLEX_H
          fillColor = ConsoleFillColor
          borderWidth = static hdpx(1)
          borderColor = BtnBdDisabled
          padding = static hdpx(10)
          vplace = ALIGN_BOTTOM
          children = mkTeamBlock(journalBattleResult.get(), hdpxi(90), body_txt)
        }
      ]
    }
    {
      size = flex()
      flow = FLOW_VERTICAL
      gap = hdpx(10)
      children = [
        debriefingLog
        {
          rendObj = ROBJ_BOX
          size = FLEX_H
          fillColor = ConsoleFillColor
          borderWidth = static hdpx(1)
          borderColor = BtnBdDisabled
          padding = static hdpx(10)
          vplace = ALIGN_BOTTOM
          children = debriefingStats
        }
      ]
    }
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
      children = mkText(loc("baseDebriefing/noData"), static { hplace = ALIGN_CENTER, vplace =  ALIGN_CENTER }.__update(h2_txt))
    }

  return {
    watch = journalBattleResult
    size = flex()
    flow = FLOW_VERTICAL
    gap = hdpx(39)
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
          rendObj = ROBJ_BOX
          size = FLEX_H
          fillColor = ConsoleFillColor
          borderWidth = static hdpx(1)
          borderColor = BtnBdDisabled
          padding = static hdpx(10)
          children = mkTeamBlock(journalBattleResult.get(), hdpxi(90), body_txt)
        }
      ]
    }
    {
      size = flex()
      flow = FLOW_VERTICAL
      gap = hdpx(20)
      padding = static [0,0, hdpx(10), 0]
      children = resourceAndItems
    }
  ]
}

function mkNexusCreditsBlock(data) {
  let { credits = 0 } = data
  if (credits <= 0)
    return null
  return {
    rendObj = ROBJ_BOX
    size = FLEX_H
    fillColor = ConsoleFillColor
    borderWidth = static hdpx(1)
    borderColor = BtnBdDisabled
    padding = static hdpx(10)
    minHeight = hdpx(114)
    flow = FLOW_VERTICAL
    gap = hdpx(5)
    children = [
      mkText(loc("credits"), h2_txt)
      {
        size = FLEX_H
        flow = FLOW_HORIZONTAL
        gap = hdpx(10)
        valign = ALIGN_CENTER
        children = inventoryItem(mkFakeItem("credit_coins_pile", { count = credits }), null)
      }
    ]
  }
}

function nexusRewardsContent() {
  let { openedReseachNodesV2 = [], chronotracesProgression = [], credits = 0 } = journalBattleResult.get()
  if (credits <= 0
    && openedReseachNodesV2.len() <= 0
    && chronotracesProgression.len() <= 0
  )
    return {
      watch = journalBattleResult
      size = static [flex(), mapSize[1]]
      flow = FLOW_HORIZONTAL
      gap = static hdpx(10)
      children = [
        mkMapContainer(mapSize)
        mkText(loc("baseDebriefing/noData"), {
          size = flex()
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
        }.__update(h2_txt))
      ]
    }
  return {
    watch = journalBattleResult
    size = flex()
    flow = FLOW_HORIZONTAL
    gap = static hdpx(10)
    children = [
      mkMapContainer(mapSize)
      {
        size = flex()
        flow = FLOW_VERTICAL
        gap = static hdpx(10)
        children = [
          mkChronotracesList(openedReseachNodesV2, chronotracesProgression)
          mkNexusCreditsBlock(journalBattleResult.get())
        ]
      }
    ]
  }
}

let statsBlockSeparator = {
  rendObj = ROBJ_SOLID
  size = static [hdpx(2), flex()]
  color = BtnBdNormal
  margin = static [0, hdpx(10)]
}

function statsBlock() {
  let { players, team } = journalBattleResult.get()
  if (players.len() == 0)
    return { watch = journalBattleResult }
  #forbid-auto-freeze
  let playersByTeam = players.reduce(function(res, pData, pId) {
    #forbid-auto-freeze
    let pTeam = pData.team
    if (pTeam not in res)
      res[pTeam] <- {}
    res[pTeam][pId] <- pData
    return res
  }, {})
  #allow-auto-freeze
  let allyTeam = playersByTeam[team]
  let enemyTeam = playersByTeam.filter(@(_, k) k != team).values()?[0] ?? {}
  let sortByScore = @(a, b, teamData) teamData[b]?.stats.score <=> teamData[a]?.stats.score
  let allyTeamArr = allyTeam.keys().sort(@(a, b) sortByScore(a, b, allyTeam))
  let enemyTeamArr = enemyTeam.keys().sort(@(a, b) sortByScore(a, b, enemyTeam))
  let complaintAction = @(userId, name) complain(debriefingSessionId.get().tostring(), userId, name,
    function() {
      if (userId == null || userId == $"{ecs.INVALID_ENTITY_ID}" || userId == ecs.INVALID_ENTITY_ID)
        fakeComplaintList.mutate(@(v) v[name] <- true)
      else
        complaintList.mutate(@(v) v[userId] <- true)
      saveComplaintListToHistory(journalBattleResult.get()?.id, complaintList.get())
      saveComplaintListToHistory(journalBattleResult.get()?.id, fakeComplaintList.get())
    })
  return {
    watch = journalBattleResult
    rendObj = ROBJ_BOX
    size = flex()
    fillColor = ConsoleFillColor
    borderWidth = static hdpx(1)
    borderColor = BtnBdDisabled
    padding = static [hdpx(10), hdpx(2)]
    flow = FLOW_HORIZONTAL
    gap = statsBlockSeparator
    children = [
      {
        size = flex()
        flow = FLOW_VERTICAL
        gap = static hdpx(10)
        halign = ALIGN_CENTER
        children = [
          mkText(static loc("nexus/playerTeam"), { color = allyTeamColor }.__update(h2_txt))
          statsHeader
          makeVertScrollExt({
            size = FLEX_H
            flow = FLOW_VERTICAL
            behavior = Behaviors.Button
            xmbNode = XmbContainer({
              canFocus = false
              wrap = false
              scrollSpeed = 5.0
            })
            children = allyTeamArr.map(function(eid, idx) {
              let stateFlags = Watched(0)
              return function() {
                let canCompain = eid != userInfo.get().userId
                  && eid != null
                  && (allyTeam[eid]?.name ?? "") != ""
                  && debriefingSessionId.get() != null
                  && allyTeam[eid]?.name not in (journalBattleResult.get()?.complaintList ?? {})
                  && eid not in (journalBattleResult.get()?.complaintList ?? {})
                let hasComplained = allyTeam[eid]?.name in (journalBattleResult.get()?.complaintList ?? {})
                  || eid in (journalBattleResult.get()?.complaintList ?? {})
                return {
                  watch = [userInfo, stateFlags, debriefingSessionId]
                  rendObj = ROBJ_BOX
                  size = FLEX_H
                  padding = static [hdpx(10), hdpx(8)]
                  fillColor = eid == userInfo.get().userId ? ItemBgColor
                    : mul_color(idx == 0 || idx % 2 == 0 ? ItemBgColor : BtnBgNormal, 1.0, 0.4)
                  flow = FLOW_HORIZONTAL
                  gap = static { size = flex() }
                  borderWidth = (stateFlags.get() & S_HOVER) && (canCompain || hasComplained) ? hdpx(1) : 0
                  xmbNode = XmbNode()
                  behavior = Behaviors.Button
                  onElemState = @(sf) stateFlags.set(sf)
                  onClick = function(event) {
                    if (canCompain)
                      contextMenu(event.screenX + 1, event.screenY + 1, fsh(30), [{
                        text = $"{loc("btn/complain")} {remap_nick(allyTeam[eid].name)}"
                        action = @() complaintAction(eid, allyTeam[eid].name)
                      }])
                  }
                  onHover = @(on) setTooltip(on && canCompain ? $"{loc("btn/complain")} {remap_nick(allyTeam[eid].name)}"
                    : on && hasComplained ? loc("msg/complain/complainSent")
                    : null)
                  children = [
                    @() {
                      watch = [isStreamerMode, playerRandName]
                      flow = FLOW_HORIZONTAL
                      gap = static hdpx(10)
                      children = [
                        mkText(idx + 1, {
                          size = static [hdpx(40), SIZE_TO_CONTENT]
                          halign = ALIGN_CENTER
                        }.__update(body_txt))
                        mkText(isStreamerMode.get() && remap_nick(allyTeam[eid].name) == userInfo.get().name
                          ? playerRandName.get()
                          : remap_nick(allyTeam[eid].name), body_txt)
                      ]
                    }
                    mkPlayerStats(allyTeam?[eid].stats ?? defStats)
                  ]
                }
              }
            })
          }, { styling = thinAndReservedPaddingStyle })
        ]
      }
      {
        flow = FLOW_VERTICAL
        size = flex()
        gap = static hdpx(10)
        halign = ALIGN_CENTER
        children = [
          static mkText(loc("nexus/enemyTeam"), { color = RedWarningColor }.__update(h2_txt))
          statsHeader(true)
          makeVertScrollExt({
            size = FLEX_H
            flow = FLOW_VERTICAL
            xmbNode = XmbContainer({
              canFocus = false
              wrap = false
              scrollSpeed = 5.0
            })
            children = enemyTeamArr.map(function(eid, idx) {
              let stateFlags = Watched(0)
              return function() {
                let canCompain = eid != null
                  && (enemyTeam[eid]?.name ?? "") != ""
                  && debriefingSessionId.get() != null
                  && enemyTeam[eid]?.name not in (journalBattleResult.get()?.complaintList ?? {})
                  && eid not in (journalBattleResult.get()?.complaintList ?? {})
                let hasComplained = enemyTeam[eid]?.name in (journalBattleResult.get()?.complaintList ?? {})
                  || eid in (journalBattleResult.get()?.complaintList ?? {})
                return {
                  watch = [stateFlags, debriefingSessionId]
                  rendObj = ROBJ_BOX
                  size = FLEX_H
                  behavior = Behaviors.Button
                  xmbNode = XmbNode()
                  padding = static [hdpx(10), hdpx(8)]
                  fillColor = mul_color(idx == 0 || idx % 2 == 0 ? ItemBgColor : BtnBgNormal, 1.0, 0.4)
                  flow = FLOW_HORIZONTAL
                  gap = static { size = flex() }
                  borderWidth = (stateFlags.get() & S_HOVER) && (canCompain || hasComplained) ? hdpx(1) : 0
                  onElemState = @(sf) stateFlags.set(sf)
                    onClick = function(event) {
                      if (canCompain)
                        contextMenu(event.screenX + 1, event.screenY + 1, fsh(30), [{
                          text = $"{loc("btn/complain")} {remap_nick(enemyTeam[eid].name)}"
                          action = @() complaintAction(eid, enemyTeam[eid].name)
                        }])
                    }
                    onHover = @(on) setTooltip(on && canCompain ? $"{loc("btn/complain")} {remap_nick(enemyTeam[eid].name)}"
                      : on && hasComplained ? loc("msg/complain/complainSent")
                      : null)
                  children = [
                    {
                      flow = FLOW_HORIZONTAL
                      gap = static hdpx(10)
                      children = [
                        mkText(idx + 1, {
                          size = static [hdpx(40), SIZE_TO_CONTENT]
                          halign = ALIGN_CENTER
                        }.__update(body_txt))
                        mkText(remap_nick(enemyTeam[eid].name), body_txt)
                      ]
                    }
                    mkPlayerStats(enemyTeam?[eid].stats ?? defStats)
                  ]
                }
              }
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
    size = FLEX_H
    halign = ALIGN_CENTER
    color = ConsoleFillColor
    padding = static [hdpx(8), 0]
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
    size = FLEX_H
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
      let hint = mvpBlock == NexusMvpReason.MOST_KILLS ? loc("stats/mostKills")
        : mvpBlock == NexusMvpReason.MOST_BEACON_CAPTURES ? loc("stats/mostCaptures")
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
  gap = static hdpx(10)
  children = [
    gameResultTitle
    mkMvpBlock
    statsBlock
  ]
}

let tabConstr = @(locId, params) mkText(loc(locId), params.__merge( { fontFx = null }, body_txt))

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
    isAvailable = Computed(@() journalBattleResult.get()?.needRewards ?? true)
    unavailableHoverHint = loc("baseDebriefing/noData")
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
    isAvailable = Computed(@() journalBattleResult.get()?.needRewards ?? true)
    unavailableHoverHint = loc("baseDebriefing/noData")
  }
].filter(@(v) v.isNexus == isNexus)

let getCurTabContent = @(tabId, tabsList) tabsList.findvalue(@(v) v.id == tabId)?.content


function raidDetails() {
  let tabsList = mkTabsList(journalBattleResult.get()?.isNexus ?? false)
  let tabsUi = mkTabs({
    tabs = tabsList
    currentTab = currentTab.get()
    onChange = @(tab) currentTab.set(tab.id)
    override = { disableHotkeys = true }
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
      onDetach = function() {
        journalBattleResult.set(null)
        debriefingSessionId.set(null)
        complaintList.set({})
        fakeComplaintList.set({})
      }
      onAttach = function() {
        if (hasResults) {
          let battle = results[results.len() - 1]
          journalBattleResult.set(battle)
          debriefingSessionId.set(battle?.sessionId)
          if (battle?.isNexus) {
            currentTab.set("baseDebriefing/stats")
            debriefingScene.set(battle?.battleAreaInfo.scene)
          }
          updateDebriefingContractsData(isOnPlayerBase.get(), results[results.len() - 1])
        }
      }
      children = [
        {
          size = flex()
          flow = FLOW_VERTICAL
          gap = hdpx(10)
          children = [
            mkText(loc("statisticsMenu/overwriteWarning", {maxSavedBattleResults}), static {color = mul_color(TextNormal, 0.5)}.__merge(sub_txt) )
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
        function() {
          if (debriefingSessionId.get() == null)
            return { watch = debriefingSessionId }
          return {
            watch = debriefingSessionId
            hplace = ALIGN_RIGHT
            pos = [0, hdpx(70)]
            children = mkText(debriefingSessionId.get(), { color = Color(30,30,30,2) }.__merge(tiny_txt))
          }
        }
      ]
    }
  }
}

return mkBattleResultTab
