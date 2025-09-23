from "%sqGlob/dasenums.nut" import NexusMvpReason
from "%ui/components/colors.nut" import TextNormal, GreenSuccessColor, RedWarningColor, BtnBdNormal,
  BtnBgNormal, ItemBgColor, InfoTextValueColor, ConsoleFillColor, BtnBdDisabled
from "%ui/hud/menus/nexus_stats.nut" import mkPlayerStats, statsHeader, mkMvpPlayerBlock, getScoresTbl
from "%ui/mainMenu/debriefing_common_components.nut" import mkChronotracesList, mkPlayerExpBlock, DEF_ANIM_DURATION, openRewardWidnow, showUnseenRewardsMessage
from "%ui/fonts_style.nut" import body_txt, fontawesome, h2_txt, h1_txt, tiny_txt
from "eventbus" import eventbus_send
from "%dngscripts/sound_system.nut" import sound_play
from "%ui/components/commonComponents.nut" import mkConsoleScreen, mkText, mkTitleString, mkTooltiped, mkTabs
from "%ui/components/button.nut" import textButton
from "%ui/helpers/time.nut" import secondsToStringLoc
from "%ui/mainMenu/stdPanel.nut" import wrapInStdPanel, mkCloseStyleBtn
from "%ui/hud/menus/components/inventoryItem.nut" import inventoryItem
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem
from "%ui/helpers/remap_nick.nut" import remap_nick
import "%ui/components/colorize.nut" as colorize
from "%ui/components/scrollbar.nut" import makeVertScrollExt, thinAndReservedPaddingStyle
from "%ui/profile/battle_results.nut" import isBattleResultInHistory, saveNexusBattleResultToHistory
from "%ui/components/accentButton.style.nut" import accentButtonStyle
from "%ui/mainMenu/menus/options/player_interaction_option.nut" import isStreamerMode, playerRandName
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
import "%ui/mainMenu/baseDebriefingSample.nut" as loadSample
from "tiledMap.behaviors" import TiledMap
from "%ui/mainMenu/baseDebriefingSample.nut" import loadNexusDebriefingSample
import "%ui/components/fontawesome.map.nut" as fa
import "%ui/control/gui_buttons.nut" as JB
import "%ui/complaints/complainWnd.nut" as complain
import "%ui/components/contextMenu.nut" as contextMenu
from "%ui/mainMenu/baseDebriefingMap.nut" import mapSize
from "%ui/mainMenu/baseDebriefingLog.nut" import debriefingSessionId
from "%ui/components/cursors.nut" import setTooltip

let { lastNexusResult } = require("%ui/profile/profileState.nut")
let userInfo = require("%sqGlob/userInfo.nut")
let { isInPlayerSession } = require("%ui/hud/state/gametype_state.nut")
let { curentHudMenusIds } = require("%ui/hud/hud_menus_state.nut")
let { BaseDebriefingMenuId } = require("%ui/mainMenu/baseDebriefing.nut")
let { defStats } = require("%ui/hud/menus/nexus_stats.nut")
let { showRewardsAnimations, levelRewards, haveSeenRewards } = require("%ui/mainMenu/debriefing_common_components.nut")
let { onlineSettingUpdated } = require("%ui/options/onlineSettings.nut")

const NEXUS_DEBRIEFING_ID = "nexusDebriefingId"

let currentTab = Watched("baseDebriefing/stats")
let allyTeamColor = 0xFF18e7e6

let showStatsAnimations = Watched(true)
let canShowCloseBtn = Watched(false)
let debugShowWindow = Watched(false)

console_register_command(function() {
  loadNexusDebriefingSample()
  debugShowWindow.set(true)
}, "nexusDebriefing.showSample")

function closeBaseDebriefing() {
  if (levelRewards.get().len() > 0) {
    openRewardWidnow()
    haveSeenRewards.set(true)
  }
  eventbus_send("hud_menus.close", { id = NEXUS_DEBRIEFING_ID })
  showStatsAnimations.set(true)
  showRewardsAnimations.set(true)
  lastNexusResult.set(null)
}

let setTab = @(tab) currentTab.set(tab)

function nextBackBtn() {
  let isNext = currentTab.get() == "baseDebriefing/stats"
  let locId = isNext ? "baseDebriefing/nextWindowButton" : "mainmenu/btnBack"
  let action = function() {
    setTab(isNext ? "baseDebriefing/rewards" : "baseDebriefing/stats")
    canShowCloseBtn.set(true)
    if (isNext)
      showStatsAnimations.set(false)
    else
      showRewardsAnimations.set(false)
  }
  return {
    watch = currentTab
    vplace = ALIGN_BOTTOM
    children = textButton(loc(locId), action, {
      hotkeys = [[$"^Esc | {JB.B}", {description = loc("mainmenu/btnClose")}]]
    })
  }
}

function mkNexusCreditsBlock(data, animStep) {
  let { credits = 0 } = data
  if (credits <= 0)
    return null
  return @() {
    watch = showRewardsAnimations
    rendObj = ROBJ_BOX
    size = FLEX_H
    fillColor = ConsoleFillColor
    borderWidth = static hdpx(1)
    borderColor = BtnBdDisabled
    padding = static hdpx(10)
    minHeight = hdpx(114)
    flow = FLOW_VERTICAL
    gap = hdpx(5)
    transform = {}
    animations = !showRewardsAnimations.get() ? null : [
      { prop = AnimProp.opacity, from = 0, to = 0, duration = animStep * DEF_ANIM_DURATION, play = true }
      { prop = AnimProp.translate, from = [sw(50), 0], to = [0, 0], delay = animStep * DEF_ANIM_DURATION
        duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic, onStart  = @() sound_play("ui_sounds/card_appear") }
    ]
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

let timeIcon = {
  rendObj = ROBJ_TEXT
  text = fa["clock-o"]
  color = TextNormal
}.__update(fontawesome)

let showNexusDebriefingWindow = Computed(
  @() debugShowWindow.get()
  || (lastNexusResult.get()?.id != null
      && lastNexusResult.get().id.len() > 0
      && onlineSettingUpdated.get()
      && !isBattleResultInHistory(lastNexusResult.get()?.id)
      && !isInPlayerSession.get()
      && curentHudMenusIds.get()?[NEXUS_DEBRIEFING_ID] != null
      && curentHudMenusIds.get()?[BaseDebriefingMenuId] != null))

function mkNexusDebriefingMenu() {
  let closeXBtn = mkCloseStyleBtn(closeBaseDebriefing)

  function closeOrRewardBtn() {
    let text = levelRewards.get().len() <= 0 ? loc("baseDebriefing/closeButton")
      : loc("baseDebriefing/getReward")
    return {
      hplace = ALIGN_RIGHT
      children = textButton(text, closeBaseDebriefing, {
        hotkeys = [[$"^Esc | {JB.B}", { description = text }]]
      }.__update(accentButtonStyle))
    }
  }

  let buttonsBlock = {
    flow = FLOW_HORIZONTAL
    gap = static hdpx(10)
    hplace = ALIGN_RIGHT
    vplace = ALIGN_BOTTOM
    children = [
      nextBackBtn
      closeOrRewardBtn
    ]
  }

  function resourceAndItems() {
    let { openedReseachNodesV2 = [], chronotracesProgression = [], credits = 0 } = lastNexusResult.get()

    if (credits <= 0
      && openedReseachNodesV2.len() <= 0
      && chronotracesProgression.len() <= 0
    )
      return {
        watch = lastNexusResult
        size = flex()
        children = [
          mkText(loc("baseDebriefing/noData"), { hplace = ALIGN_CENTER, vplace =  ALIGN_CENTER }.__update(h2_txt))
          buttonsBlock
        ]
      }
    let chronoAnimStep = 2
    let creditsAnimStep = credits > 0 && (openedReseachNodesV2.len() > 0 || chronotracesProgression.len() > 0) ? 3 : chronoAnimStep
    return {
      watch = lastNexusResult
      size = flex()
      flow = FLOW_VERTICAL
      gap = static hdpx(10)
      children = [
        mkChronotracesList(openedReseachNodesV2, chronotracesProgression, chronoAnimStep)
        mkNexusCreditsBlock(lastNexusResult.get(), creditsAnimStep)
        { size = flex() }
        buttonsBlock
      ]
    }
  }

  let rewardsContent = @() {
    size = static [flex(), mapSize[1]]
    flow = FLOW_HORIZONTAL
    gap = static hdpx(10)
    children = [
      function() {
        let { experienceBlock = {}, openedReseachNodesV2 = [], chronotracesProgression = [] } = lastNexusResult.get()
        let oppositeBlock = openedReseachNodesV2.len() > 0 || chronotracesProgression.len() > 0
          ? mkChronotracesList(openedReseachNodesV2, chronotracesProgression)
          : null
        return {
          watch = lastNexusResult
          size = static [mapSize[0], flex()]
          children = mkPlayerExpBlock(experienceBlock, calc_comp_size(oppositeBlock)?[1])
        }
      }
      resourceAndItems
    ]
  }

  let statsBlockSeparator = {
    rendObj = ROBJ_SOLID
    size = static [hdpx(2), flex()]
    color = BtnBdNormal
    margin = static [0, hdpx(10)]
  }

  function statsBlock() {
    let { players, team, mvps } = lastNexusResult.get()
    if (players.len() == 0)
      return { watch = lastNexusResult }

    let playersByTeam = players.reduce(function(res, pData, pId) {
      let pTeam = pData.team
      if (pTeam not in res)
        res[pTeam] <- {}
      res[pTeam][pId] <- pData
      return res
    }, {})

    let allyTeam = playersByTeam?[team] ?? {}
    let enemyTeam = playersByTeam.filter(@(_, k) k != team).values()?[0] ?? {}
    let sortByScore = @(a, b, teamData) teamData[b]?.stats.score <=> teamData[a]?.stats.score
    let allyTeamArr = allyTeam.keys().sort(@(a, b) sortByScore(a, b, allyTeam))
    let enemyTeamArr = enemyTeam.keys().sort(@(a, b) sortByScore(a, b, enemyTeam))
    let delayIdx = mvps.len() <= 0 ? 4 : 5
    let complaintAction = @(userId, name) complain(debriefingSessionId.get().tostring(), userId, name)
    return {
      watch = lastNexusResult
      rendObj = ROBJ_BOX
      size = flex()
      fillColor = ConsoleFillColor
      borderWidth = static hdpx(1)
      borderColor = BtnBdDisabled
      padding = static [hdpx(10), hdpx(2)]
      flow = FLOW_HORIZONTAL
      gap = statsBlockSeparator
      transform = {}
      animations = !showStatsAnimations.get() ? null : [
        { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION * delayIdx, play = true }
        { prop = AnimProp.translate, from = [-sw(100), 0], to = [0, 0], delay = DEF_ANIM_DURATION * delayIdx,
          duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic, onStart  = @() sound_play("ui_sounds/card_appear") }
      ]
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
              children = allyTeamArr.map(function(eid, idx) {
                let stateFlags = Watched(0)
                return function() {
                  let canCompaint = eid != userInfo.get().userId
                    && eid != null
                    && (allyTeam[eid]?.name ?? "") != ""
                    && debriefingSessionId.get() != null
                  return {
                    watch = [userInfo, stateFlags, debriefingSessionId]
                    rendObj = ROBJ_BOX
                    size = FLEX_H
                    padding = static [hdpx(10), hdpx(8)]
                    fillColor = eid == userInfo.get().userId ? ItemBgColor
                      : mul_color(idx == 0 || idx % 2 == 0 ? ItemBgColor : BtnBgNormal, 1.0, 0.4)
                    borderWidth = (stateFlags.get() & S_HOVER) && canCompaint ? hdpx(1) : 0
                    flow = FLOW_HORIZONTAL
                    gap = static { size = flex() }
                    behavior = Behaviors.Button
                    onElemState = @(sf) stateFlags.set(sf)
                    onClick = function(event) {
                      if (canCompaint)
                        contextMenu(event.screenX + 1, event.screenY + 1, fsh(30), [{
                          text = $"{loc("btn/complain")} {remap_nick(allyTeam[eid].name)}"
                          action = @() complaintAction(eid, allyTeam[eid].name)
                        }])
                    }
                    onHover = @(on) setTooltip(on && canCompaint ? $"{loc("btn/complain")} {remap_nick(allyTeam[eid].name)}" : null)
                    children = [
                      @() {
                        watch = [userInfo, isStreamerMode, playerRandName]
                        flow = FLOW_HORIZONTAL
                        gap = static hdpx(10)
                        children = [
                          mkText(idx + 1, {
                            size = static [hdpx(40), SIZE_TO_CONTENT]
                            halign = ALIGN_CENTER
                          }.__update(body_txt))
                          isStreamerMode.get() && userInfo.get().name == remap_nick(allyTeam[eid].name)
                            ? mkText(playerRandName.get(), body_txt)
                            : mkText(remap_nick(allyTeam[eid].name), body_txt)
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
              children = enemyTeamArr.map(function(eid, idx) {
                let stateFlags = Watched(0)
                return function() {
                  let canCompaint = eid != null
                    && (enemyTeam[eid]?.name ?? "") != ""
                    && debriefingSessionId.get() != null
                  return {
                    watch = [stateFlags, debriefingSessionId]
                    rendObj = ROBJ_BOX
                    size = FLEX_H
                    padding = static [hdpx(10), hdpx(8)]
                    fillColor = mul_color(idx == 0 || idx % 2 == 0 ? ItemBgColor : BtnBgNormal, 1.0, 0.4)
                    flow = FLOW_HORIZONTAL
                    gap = static { size = flex() }
                    borderWidth = (stateFlags.get() & S_HOVER) && canCompaint ? hdpx(1) : 0
                    behavior = Behaviors.Button
                    onElemState = @(sf) stateFlags.set(sf)
                    onClick = function(event) {
                      if (canCompaint)
                        contextMenu(event.screenX + 1, event.screenY + 1, fsh(30), [{
                          text = $"{loc("btn/complain")} {remap_nick(enemyTeam[eid].name)}"
                          action = @() complaintAction(eid, enemyTeam[eid].name)
                        }])
                    }
                    onHover = @(on) setTooltip(on && canCompaint ? $"{loc("btn/complain")} {remap_nick(enemyTeam[eid].name)}" : null)
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
    let { isWinner, modeSpecificData, team } = lastNexusResult.get()
    let text = isWinner ? loc("nexus/victory") : loc("nexus/defeat")
    let color = isWinner ? allyTeamColor : RedWarningColor
    let localPlayerScore = modeSpecificData?.score[team.tostring()]
    let enemyScore = modeSpecificData.len() <= 0 ? null
      : modeSpecificData.score.filter(@(_v, t) t != team.tostring()).values()[0]
    return {
      watch = [lastNexusResult, showStatsAnimations]
      rendObj = ROBJ_SOLID
      size = FLEX_H
      halign = ALIGN_CENTER
      color = ConsoleFillColor
      padding = static [hdpx(8), 0]
      flow = FLOW_VERTICAL
      transform = {}
      animations = !showStatsAnimations.get() ? null : [
        { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION * 3, play = true }
        { prop = AnimProp.translate, from = [-sw(100), 0], to = [0, 0], delay = DEF_ANIM_DURATION * 3,
          duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic, onStart = @() sound_play("ui_sounds/card_appear") }
      ]
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
    let { mvps, players, team } = lastNexusResult.get()
    if (mvps.len() <= 0)
      return { watch = lastNexusResult }
    let scoresTbl = getScoresTbl()
    return {
      watch = [lastNexusResult, showStatsAnimations]
      size = FLEX_H
      flow = FLOW_HORIZONTAL
      gap = hdpx(50)
      halign = ALIGN_CENTER
      transform = {}
      animations = !showStatsAnimations.get() ? null : [
        { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION * 4, play = true }
        { prop = AnimProp.translate, from = [-sw(100), 0], to = [0, 0], delay = DEF_ANIM_DURATION * 4,
          duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic, onStart  = @() sound_play("ui_sounds/card_appear") }
      ]
      children = mvpOrder.map(function(mvpBlock) {
        let data = mvps?[mvpBlock.tostring()]
        if (data == null)
          return null
        let { owner } = data
        let titleLoc = mvpBlock == NexusMvpReason.MOST_KILLS ? "stats/mostKills"
          : mvpBlock == NexusMvpReason.MOST_BEACON_CAPTURES ? "stats/mostCaptures"
          : "stats/mostAssists"
        let descLoc = mvpBlock == NexusMvpReason.MOST_KILLS ? "stats/maxKills"
          : mvpBlock == NexusMvpReason.MOST_BEACON_CAPTURES ? "stats/capturesScore"
          : "stats/maxAssists"
        let playerData = players[owner]
        let count = mvpBlock == NexusMvpReason.MOST_KILLS ? playerData.stats.kill
          : mvpBlock == NexusMvpReason.MOST_BEACON_CAPTURES ? playerData.stats.beacon_capture
          : playerData.stats.beacon_reset + playerData.stats.assist
        let totalScore = playerData.stats.score
        let hint = mvpBlock != NexusMvpReason.MOST_HELP ? null
          : loc("nexus/mvpAssistsHint", {
            assist = colorize(InfoTextValueColor, $"{playerData.stats.assist * scoresTbl.assist }"),
            portal = colorize(InfoTextValueColor, $"{playerData.stats.beacon_reset * scoresTbl.beacon_reset}")
          })
        let color = playerData.team == team ? allyTeamColor : RedWarningColor
        return mkMvpPlayerBlock(playerData.name, loc(titleLoc), loc(descLoc, { count, counts = count}),
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
      {
        flow = FLOW_HORIZONTAL
        gap = hdpx(10)
        hplace = ALIGN_RIGHT
        vplace = ALIGN_BOTTOM
        children = nextBackBtn
      }
    ]
  }

  let tabConstr = @(locId, params) mkText(loc(locId), params.__merge( { fontFx = null }, body_txt))

  let tabsList = [
    {
      id = "baseDebriefing/stats"
      childrenConstr = @(params) tabConstr("nexus/nexusStatsWnd", params)
      content = statsContent
    }
    {
      id = "baseDebriefing/rewards"
      childrenConstr = @(params) tabConstr("baseDebriefing/rewards", params)
      content = rewardsContent
    }
  ]

  let getCurTabContent = @(tabId) tabsList.findvalue(@(v) v.id == tabId)?.content

  function playerTrackWindow() {
    let tabsUi = mkTabs({
      tabs = tabsList
      currentTab = currentTab.get()
      onChange = function(tab) {
        currentTab.set(tab.id)
        canShowCloseBtn.set(true)
        if (tab.id == "baseDebriefing/rewards")
          showStatsAnimations.set(false)
        else
          showRewardsAnimations.set(false)
      }
    })
    let tabContent = getCurTabContent(currentTab.get())
    return {
      watch = currentTab
      size = flex()
      flow = FLOW_VERTICAL
      gap = hdpx(10)
      children = [
        tabsUi
        tabContent
      ]
    }
  }

  let mkTime = @(seconds) mkTooltiped({
    valign = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    gap = hdpx(4)
    children = [
      timeIcon
      mkText(secondsToStringLoc(seconds), body_txt)
    ]
  }, loc("baseDebriefing/timeTooltip"), static { hplace = ALIGN_RIGHT })

  function windowTitle() {
    let { isWinner=false, gameDuration = 0, battleAreaInfo = {}, sessionId = null } = lastNexusResult.get()
    let { raidName = "" } = battleAreaInfo
    debriefingSessionId.set(sessionId)
    let headerColor = isWinner ? GreenSuccessColor : RedWarningColor
    local text = isWinner ? loc("baseDebriefing/successfulRaid") : loc("baseDebriefing/unsuccessfulRaid")
    if (raidName != "") {
      let raidNameSplitet = raidName.split("+")
      let raidNameLocId = raidNameSplitet?[1] == null ? "missionInfo/unknown/short"
        : "_".join(raidNameSplitet.filter(@(v) v != "ordinary"))
      text = $"{text} {loc(raidNameLocId)}"
    }
    return {
      watch = [lastNexusResult, showStatsAnimations]
      size = FLEX_H
      children = [
        {
          rendObj = ROBJ_SOLID
          size = static [flex(), ph(100)]
          color = mul_color(headerColor, 0.5)
          transform = { pivot = [0, 1] }
          animations = !showStatsAnimations.get() ? null : [
            { prop = AnimProp.scale, from = [0.03, 1], to = [0.03, 1], duration = DEF_ANIM_DURATION * 2, play = true,
              onStart  = @() sound_play("ui_sounds/card_appear") }
            { prop = AnimProp.opacity, from = 1, to = 0.3, duration = DEF_ANIM_DURATION,
              play = true, easing = CosineFull }
            { prop = AnimProp.opacity, from = 1, to = 0.3, duration = DEF_ANIM_DURATION,
              delay = DEF_ANIM_DURATION, play = true, easing = CosineFull }
            { prop = AnimProp.scale, from = [0.03, 1], to = [1, 1], duration = DEF_ANIM_DURATION,
              delay = DEF_ANIM_DURATION * 2 play = true, easing = InOutCubic }
          ]
        }
        {
          size = FLEX_H
          valign = ALIGN_CENTER
          padding = static [0, hdpx(10)]
          flow = FLOW_HORIZONTAL
          gap = hdpx(10)
          transform = !showStatsAnimations.get() ? null : {}
          animations = [
            { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION * 2, play = true,
              onStart  = @() sound_play("ui_sounds/card_appear") }
            { prop = AnimProp.opacity, from = 0, to = 1, delay = DEF_ANIM_DURATION * 2, duration = DEF_ANIM_DURATION, play = true }
          ]
          children = [
            mkTitleString(text)
            { size = flex() }
            gameDuration <= 0 ? null : mkTime(gameDuration)
            closeXBtn
          ]
        }
      ]
    }
  }

  function updateRewards() {
    let { experienceBlock = {} } = lastNexusResult.get()
    showRewardsAnimations.set(true)
    if ((experienceBlock?.openedChronogenes.len() ?? 0) > 0) {
      levelRewards.set(experienceBlock.openedChronogenes)
      haveSeenRewards.set(false)
    }
  }

  let getContent = @() wrapInStdPanel(NEXUS_DEBRIEFING_ID, @() {
    size = [flex(), mapSize[1] + hdpx(80)]
    clipChildren = true
    onAttach = function() {
      updateRewards()
      sound_play("ui_sounds/raid_debriefing")
    }
    onDetach = function() {
      lastNexusResult.set(null)
      debugShowWindow.set(false)
      currentTab.set("baseDebriefing/stats")
      eventbus_send("profile_server.mark_base_debriefing_shown", {})
      showStatsAnimations.set(true)
      showRewardsAnimations.set(false)
      debriefingSessionId.set(null)
      if (!haveSeenRewards.get())
        showUnseenRewardsMessage()
      haveSeenRewards.set(true)
    }
    children = [
      mkConsoleScreen(playerTrackWindow)
      function() {
        if (debriefingSessionId.get() == null)
          return { watch = debriefingSessionId }
        return {
          watch = debriefingSessionId
          hplace = ALIGN_LEFT
          vplace = ALIGN_BOTTOM
          pos = [hdpx(10), hdpx(3)]
          children = mkText(debriefingSessionId.get(), { color = Color(30,30,30,2) }.__merge(tiny_txt))
        }
      }
    ]
  }, "", null, windowTitle)

  return {
    getContent
    autoShow = showNexusDebriefingWindow
    id = NEXUS_DEBRIEFING_ID
  }
}

let reactToNexusNeedShowDebriefing = function(needToShow) {
  log($"reactToNexusNeedShowDebriefing: needToShow={needToShow}")
  if (needToShow) {
    saveNexusBattleResultToHistory(lastNexusResult.get().__merge({ isNexus = true }))
    eventbus_send("hud_menus.open", { id = NEXUS_DEBRIEFING_ID })
  }
}

showNexusDebriefingWindow.subscribe_with_nasty_disregard_of_frp_update(reactToNexusNeedShowDebriefing)

reactToNexusNeedShowDebriefing(showNexusDebriefingWindow.get())

return {
  NEXUS_DEBRIEFING_ID
  mkNexusDebriefingMenu
}
