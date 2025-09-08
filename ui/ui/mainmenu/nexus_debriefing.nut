from "%ui/ui_library.nut" import *

import "%dngscripts/ecs.nut" as ecs
import "%ui/mainMenu/baseDebriefingSample.nut" as loadSample
from "tiledMap.behaviors" import TiledMap

let { body_txt, fontawesome, h2_txt, h1_txt, giant_txt } = require("%ui/fonts_style.nut")
let { TextNormal, GreenSuccessColor, RedWarningColor, BtnBdNormal, BtnBgNormal, ItemBgColor, InfoTextValueColor,
  ConsoleFillColor, BtnBgHover, BtnBgDisabled, ModalBgTint } = require("%ui/components/colors.nut")
let { lastNexusResult, playerExperienceToLevel } = require("%ui/profile/profileState.nut")
let userInfo = require("%sqGlob/userInfo.nut")
let { isInPlayerSession } = require("%ui/hud/state/gametype_state.nut")
let { eventbus_send } = require("eventbus")
let { mkConsoleScreen, mkText, mkTitleString, mkTooltiped, mkTabs, mkTextArea
} = require("%ui/components/commonComponents.nut")
let { textButton, button } = require("%ui/components/button.nut")
let { mapSize } = require("%ui/mainMenu/baseDebriefingMap.nut")
let { mkMapContainer, debriefingScene, debriefingRaidName
} = require("%ui/mainMenu/nexus_debriefing_map.nut")
let fa = require("%ui/components/fontawesome.map.nut")
let { secondsToStringLoc } = require("%ui/helpers/time.nut")
let { wrapInStdPanel, mkCloseStyleBtn } = require("stdPanel.nut")
let { inventoryItem } = require("%ui/hud/menus/components/inventoryItem.nut")
let { mkFakeItem } = require("%ui/hud/menus/components/fakeItem.nut")
let { curentHudMenusIds } = require("%ui/hud/hud_menus_state.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { BaseDebriefingMenuId } = require("%ui/mainMenu/baseDebriefing.nut")
let { mkPlayerStats, defStats, statsHeader, mkMvpPlayerBlock, getScoresTbl
} = require("%ui/hud/menus/nexus_stats.nut")
let { remap_nick } = require("%ui/helpers/remap_nick.nut")
let { NexusMvpReason } = require("%sqGlob/dasenums.nut")
let colorize = require("%ui/components/colorize.nut")
let { makeVertScrollExt, thinAndReservedPaddingStyle } = require("%ui/components/scrollbar.nut")
let { isBattleResultInHistory, saveNexusBattleResultToHistory } = require("%ui/profile/battle_results.nut")
let { mkDebriefingCronotracesList } = require("%ui/mainMenu/horisontalItemList.nut")
let { currentPlayerLevelHasExp, currentPlayerLevelNeedExp, playerCurrentLevel,
  levelLineExpColor, levelLineExpBackgroundColor } = require("%ui/hud/menus/notes/player_progression.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let tooltipBox = require("%ui/components/tooltipBox.nut")
let { animateNumbers } = require("%ui/components/numbersAnimation.nut")
let { accentButtonStyle } = require("%ui/components/accentButton.style.nut")
let faComp = require("%ui/components/faComp.nut")
let { mkChronogeneImage, getChronogeneTooltip } = require("%ui/mainMenu/clonesMenu/clonesMenuCommon.nut")
let { inventoryImageParams } = require("%ui/hud/menus/components/inventoryItemImages.nut")
let { addModalWindow, removeModalWindow } = require("%ui/components/modalWindows.nut")
let { addPlayerLog, mkPlayerLog, marketIconSize } = require("%ui/popup/player_event_log.nut")
let { itemIconNoBorder } = require("%ui/components/itemIconComponent.nut")

const NEXUS_DEBRIEFING_ID = "nexusDebriefingId"
const DEF_ANIM_DURATION = 0.4
const MAX_ITEM_TO_SHOW = 11
const EXP_ANIM_TRIGGER = "expAnimTrigger"
const REWARD_WND_UID = "rewardWndUid"
const REWARDS_COUNT = 9
const REWARDS_PER_ROW = 3
const CARD_ANIM_DURATION = 0.2
const CARD_ANIM_OVERLAP = 0.1

let currentTab = Watched("baseDebriefing/stats")
let allyTeamColor = 0xFF18e7e6

let showStatsAnimations = Watched(true)
let showRewardsAnimations = Watched(true)
let canShowCloseBtn = Watched(false)
let levelRewards = Watched([])
let haveSeenRewards = Watched(true)
let isCardInteractive = Watched(false)
let selectedRewardIdxs = Watched([])
let canShowRewardsIdxs = Watched([])

let rewardCardSize = [hdpx(150), hdpx(150)]

let rewardWindowTitle = @() {
  watch = playerCurrentLevel
  children = mkText(loc("levelReward/windowTitle", { level = playerCurrentLevel.get() + 1 }), h1_txt)
}

let drawsPatternImage = {
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
  rendObj = ROBJ_IMAGE
  size = flex()
  color = Color(90, 90, 90, 50)
  image = Picture("!ui/skin#draws_pattern.svg:{0}:{0}:K".subst(sh(5)))
}

let cardContent = {
  size = flex()
  halign = ALIGN_CENTER
  children = [
    drawsPatternImage
    faComp("question", {
      vplace = ALIGN_CENTER
      hplace = ALIGN_CENTER
      fontSize = giant_txt.fontSize
    })
  ]
}

function selectedRewardCard(cardIdx) {
  return function () {
    if (levelRewards.get().len() <= 0)
      return const { watch = [ levelRewards, selectedRewardIdxs ] }
    let rewardToOpen = levelRewards.get()?[selectedRewardIdxs.get().findindex(@(v) v == cardIdx)]
    let item = { itemTemplate = rewardToOpen }
    let icon = mkChronogeneImage(item, { slotSize = rewardCardSize, width = inventoryImageParams.width,
      height = inventoryImageParams.height })
    return {
      watch = [ levelRewards, selectedRewardIdxs ]
      rendObj = ROBJ_SOLID
      key = $"{rewardToOpen}"
      color = BtnBgNormal
      size = rewardCardSize
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      behavior = Behaviors.Button
      onHover = @(on) setTooltip(on ? getChronogeneTooltip(item) : null)
      animations = const [
        { prop = AnimProp.opacity, from = 0, to = 1, duration = CARD_ANIM_DURATION, play = true }
      ]
      children = icon
    }
  }
}

function mkRewardCard(idx) {
  let isSelected = Computed(@() selectedRewardIdxs.get().contains(idx))
  let isEnabled = Computed(@() !isSelected.get() && canShowRewardsIdxs.get().len() < levelRewards.get().len())
  return @() {
    watch = [isCardInteractive, isSelected, selectedRewardIdxs, canShowRewardsIdxs]
    key = $"rewardCard_{idx}"
    children = isSelected.get() ? selectedRewardCard(idx)
      : button(cardContent, function() {
          if (!isCardInteractive.get() || !isEnabled.get())
            return
          selectedRewardIdxs.mutate(@(v) v.append(idx))
          canShowRewardsIdxs.mutate(@(v) v.append(idx))
        },
        {
          size = rewardCardSize
          key = $"reaward_{idx}"
          transform = const {}
          animations = [
            { prop = AnimProp.translate, from = [-sw(100), sh(25)], to = [-sw(100), sh(25)],
              duration = idx * (CARD_ANIM_DURATION - CARD_ANIM_OVERLAP), play = true, easing = OutCubic },
            { prop = AnimProp.translate, from = [-sw(100), sh(25)], to = [0, 0], duration = CARD_ANIM_DURATION,
              delay = idx * (CARD_ANIM_DURATION - CARD_ANIM_OVERLAP), play = true, easing = InOutCubic, onFinish = function() {
                if (idx == REWARDS_COUNT - 1)
                  isCardInteractive.set(true)
              }}
          ]
          style = isEnabled.get() ? {} : {
            BtnBgNormal = BtnBgDisabled
            BtnBgHover = BtnBgDisabled
          }
          tooltipText = !isEnabled.get() ? loc("levelReward/chooseCardDisabled") : loc("levelReward/chooseCard")
      })
  }
}

function rewardsBlock() {
  let rows = []
  let allCards = array(REWARDS_COUNT)
  foreach (idx, _v in allCards) {
    let rowIdx = idx.tofloat() / REWARDS_PER_ROW
    if (rows.len() <= rowIdx)
      rows.append([])
    rows[rowIdx].append(mkRewardCard(idx))
  }
  return {
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = rows.map(@(v) {
      flow = FLOW_HORIZONTAL
      gap = hdpx(10)
      children = v
    })
  }
}

let claimRewardButton = @() {
  watch = [canShowRewardsIdxs, levelRewards]
  children = textButton(loc("rewards/collect"), function() {
    removeModalWindow(REWARD_WND_UID)
    foreach (item in levelRewards.get()) {
      let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(item)
      let itemName = template?.getCompValNullable("item__name")
      addPlayerLog({
        id = item
        content = mkPlayerLog({
          titleFaIcon = "user"
          bodyIcon = itemIconNoBorder(item, { width = marketIconSize[0], height = marketIconSize[1] })
          titleText = loc("item/received")
          bodyText = loc(itemName)
        })
      })
    }
    levelRewards.set([])
    isCardInteractive.set(false)
    selectedRewardIdxs.set([])
    canShowRewardsIdxs.set([])
  }, {
    opacity = canShowRewardsIdxs.get().len() == levelRewards.get().len() ? 1 : 0
    hotkeys = [[$"Esc | {JB.B}"]]
  }.__update(accentButtonStyle))
}

let openRewardWidnow = @() addModalWindow({
  key = REWARD_WND_UID
  rendObj = ROBJ_WORLD_BLUR_PANEL
  fillColor = ModalBgTint
  onClick = @() null
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = {
    rendObj = ROBJ_WORLD_BLUR_PANEL
    fillColor = ConsoleFillColor
    size = [flex(), sh(70)]
    halign = ALIGN_CENTER
    padding = hdpx(10)
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      rewardWindowTitle
      {
        flow = FLOW_VERTICAL
        gap = hdpx(10)
        size = [SIZE_TO_CONTENT, flex()]
        valign = ALIGN_CENTER
        halign = ALIGN_CENTER
        children = [
          mkText(loc("levelReward/choose"), body_txt)
          rewardsBlock
        ]
      }
      claimRewardButton
    ]
  }
})

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

function mkNexusCreditsBlock(data) {
  let { credits = 0 } = data
  if (credits <= 0)
    return null
  return @() {
    watch = showRewardsAnimations
    size = [flex(), SIZE_TO_CONTENT]
    minHeight = hdpx(114)
    flow = FLOW_VERTICAL
    gap = hdpx(5)
    transform = {}
    animations = !showRewardsAnimations.get() ? null : [
      { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION, play = true }
      { prop = AnimProp.translate, from = [sw(50), 0], to = [0, 0], delay = DEF_ANIM_DURATION
        duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic }
    ]
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

let timeIcon = {
  rendObj = ROBJ_TEXT
  text = fa["clock-o"]
  color = TextNormal
}.__update(fontawesome)

let showNexusDebriefingWindow = Computed(
  @() lastNexusResult.get()?.id != null
    && lastNexusResult.get().id.len() > 0
    && !isBattleResultInHistory(lastNexusResult.get()?.id)
    && !isInPlayerSession.get()
    && curentHudMenusIds.get()?[NEXUS_DEBRIEFING_ID] != null
    && curentHudMenusIds.get()?[BaseDebriefingMenuId] != null)

function mkNexusDebriefingMenu() {
  let mapBlock = @() {
    watch = showRewardsAnimations
    transform = {}
    animations = !showRewardsAnimations.get() ? null : [
      { prop = AnimProp.translate, from = [-sw(50), 0], to = [0, 0],
        duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic }
    ]
    children = mkMapContainer(mapSize)
  }

  let mkChronotracesList = @(openedReseachNodesV2, chronotracesProgression, animStep)
    openedReseachNodesV2.len() <= 0 && chronotracesProgression.len() <= 0 ? null : @() {
      watch = showRewardsAnimations
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap = hdpx(10)
      transform = {}
      animations = !showRewardsAnimations.get() ? null : [
        { prop = AnimProp.opacity, from = 0, to = 0, duration = animStep * DEF_ANIM_DURATION, play = true }
        { prop = AnimProp.translate, from = [sw(50), 0], to = [0, 0], delay = animStep * DEF_ANIM_DURATION,
          duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic }
      ]
      children = [
        mkText(loc("baseDebriefing/chronotraces"), h2_txt)
        mkDebriefingCronotracesList(openedReseachNodesV2, chronotracesProgression, MAX_ITEM_TO_SHOW)
      ]
    }

  let playerLevelExpLine = function(expBefore, expAfter, curLevelExp, animStep) {
    let curExp = curLevelExp.tofloat()
    let levelRatioBefore = (expBefore >= 0 ? expBefore.tofloat() : 0) / curExp
    let levelRatio = expAfter.tofloat() / curExp - levelRatioBefore
    return {
      size = const [flex(), hdpx(10)]
      children = [
        const {
          rendObj = ROBJ_SOLID
          size = flex()
          color = levelLineExpBackgroundColor
        }
        {
          size = const [pw(100), flex()]
          flow = FLOW_HORIZONTAL
          children = [
            {
              rendObj = ROBJ_SOLID
              size = [ pw(min(levelRatioBefore * 100, 100)), flex() ]
              color = levelLineExpColor
            }
            @() {
              watch = showRewardsAnimations
              rendObj = ROBJ_SOLID
              size = [pw(clamp(levelRatio * 100, 0, 100)), flex()]
              color = BtnBgHover
              transform = const { pivot = [0, 1] }
              animations = !showRewardsAnimations.get() ? null : [
                { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION * (animStep + 1),
                  play = true }
                const { prop = AnimProp.scale, from = [0, 1], to = [1, 1], duration = DEF_ANIM_DURATION * 2,
                  easing = InOutCubic, trigger = EXP_ANIM_TRIGGER }
                const { prop = AnimProp.opacity, from = 1, to = 0.5, duration = 2,
                  easing = CosineFull, trigger = EXP_ANIM_TRIGGER, loop = true }
              ]
            }
          ]
        }
      ]
    }
  }

  let mkPlayerExpBlock = @(experienceBlock, animStep) function() {
    let { expBeforeRewarding = 0, expRewards = {} } = experienceBlock
    local expBefore = expBeforeRewarding - (playerExperienceToLevel.get()?[playerCurrentLevel.get() - 1] ?? 0)
    expBefore = expBefore >= 0 ? expBefore : 0
    let expAfter = currentPlayerLevelHasExp.get()
    let needAnim = showRewardsAnimations.get() && expBefore < expAfter
    let expIncome = expRewards.filter(@(v) v > 0)
    return {
      watch = [currentPlayerLevelHasExp, currentPlayerLevelNeedExp, playerCurrentLevel,
        showRewardsAnimations, playerExperienceToLevel]
      size = const [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap = hdpx(4)
      transform = const {}
      animations = !showRewardsAnimations.get() ? null : [
        { prop = AnimProp.opacity, from = 0, to = 0, duration = animStep * DEF_ANIM_DURATION, play = true }
        { prop = AnimProp.translate, from = const [sw(50), 0], to = const [0, 0], delay = animStep * DEF_ANIM_DURATION,
          duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic, onFinish = @() anim_start(EXP_ANIM_TRIGGER) }
      ]
      behavior = Behaviors.Button
      onHover = function(on) {
        if (!on)
          return setTooltip(null)
        else if (expIncome.len() <= 0)
          return setTooltip(loc("expIncome/empty"))
        return setTooltip(tooltipBox({
          size = const [hdpx(300), SIZE_TO_CONTENT]
          minWidth = SIZE_TO_CONTENT
          flow = FLOW_VERTICAL
          gap = hdpx(4)
          children = expIncome.keys()
            .sort(@(a, b) a <=> b)
            .map(function(stat) {
              let locId = $"expIncome/{stat}"
              return {
                size = const [flex(), SIZE_TO_CONTENT]
                children = [
                  mkText(loc(locId))
                  mkText(expIncome[stat], const { hplace = ALIGN_RIGHT, color = InfoTextValueColor })
                ]
              }
            })
        }))
      }
      children = [
        mkTextArea($"{loc("player_progression/currentLevel")} {colorize(InfoTextValueColor, playerCurrentLevel.get() + 1)}",
          { margin = const [0,0, hdpx(4), 0] }.__update(h2_txt))
        playerLevelExpLine(expBefore, expAfter, currentPlayerLevelNeedExp.get(), animStep)
        {
          size = const [flex(), SIZE_TO_CONTENT]
          valign = ALIGN_CENTER
          children = [
            {
              flow = FLOW_HORIZONTAL
              gap = const hdpx(4)
              valign = ALIGN_CENTER
              children = [!needAnim
                ? mkText(expAfter, body_txt)
                : animateNumbers(expAfter, body_txt, {
                    digitAnimDuration = DEF_ANIM_DURATION * 2
                    trigger = EXP_ANIM_TRIGGER
                    delay = DEF_ANIM_DURATION
                    startValue = expBefore
                  })
                ].append(const mkText(" XP", body_txt))
            }
            mkText($"{currentPlayerLevelNeedExp.get()} XP", const { hplace = ALIGN_RIGHT }.__update(body_txt))
          ]
        }
      ]
    }
  }

  let closeXBtn = mkCloseStyleBtn(closeBaseDebriefing)

  function closeOrRewardBtn() {
    let text = levelRewards.get().len() <= 0 ? loc("baseDebriefing/closeButton")
      : loc("baseDebriefing/getReward")
    return {
      hplace = ALIGN_RIGHT
      children = textButton(text, closeBaseDebriefing, {
        hotkeys = const [[$"^Esc | {JB.B}", { description = text }]]
      }.__update(accentButtonStyle))
    }
  }

  function resourceAndItems() {
    let { openedReseachNodesV2 = [], chronotracesProgression = [], experienceBlock = {}, credits = 0 } = lastNexusResult.get()

    if (credits <= 0
      && openedReseachNodesV2.len() <= 0
      && chronotracesProgression.len() <= 0
      && experienceBlock.len() <= 0
    )
      return {
        watch = lastNexusResult
        size = flex()
        children = mkText(loc("baseDebriefing/noData"), { hplace = ALIGN_CENTER, vplace =  ALIGN_CENTER }.__update(h2_txt))
      }

    let chronoAnimStep = credits > 0 && (openedReseachNodesV2.len() > 0 || chronotracesProgression.len() > 0) ? 1 : 0
    let dailyAnimStep = credits > 0 ? chronoAnimStep + 1 : chronoAnimStep
    let expAnimStep = dailyAnimStep + 1

    return {
      watch = lastNexusResult
      size = flex()
      flow = FLOW_VERTICAL
      gap = hdpx(20)
      children = [
        mkChronotracesList(openedReseachNodesV2, chronotracesProgression, chronoAnimStep)
        mkNexusCreditsBlock(lastNexusResult.get())
        mkPlayerExpBlock(experienceBlock, expAnimStep)
        { size = flex() }
        {
          flow = FLOW_HORIZONTAL
          gap = hdpx(10)
          hplace = ALIGN_RIGHT
          children = [
            nextBackBtn
            closeOrRewardBtn
          ]
        }
      ]
    }
  }

  let rewardsContent = @() {
    watch = lastNexusResult
    size = flex()
    flow = FLOW_HORIZONTAL
    gap = hdpx(10)
    children = [
      mapBlock
      resourceAndItems
    ]
  }

  let statsBlockSeparator = {
    rendObj = ROBJ_SOLID
    size = [hdpx(2), flex()]
    color = BtnBdNormal
    margin = [0, hdpx(10)]
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
    return {
      watch = lastNexusResult
      size = flex()
      flow = FLOW_HORIZONTAL
      gap = statsBlockSeparator
      transform = {}
      animations = !showStatsAnimations.get() ? null : [
        { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION * delayIdx, play = true }
        { prop = AnimProp.translate, from = [-sw(100), 0], to = [0, 0], delay = DEF_ANIM_DURATION * delayIdx,
          duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic }
      ]
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
    let { isWinner, modeSpecificData, team } = lastNexusResult.get()
    let text = isWinner ? loc("nexus/victory") : loc("nexus/defeat")
    let color = isWinner ? allyTeamColor : RedWarningColor
    let localPlayerScore = modeSpecificData?.score[team.tostring()]
    let enemyScore = modeSpecificData.len() <= 0 ? null
      : modeSpecificData.score.filter(@(_v, t) t != team.tostring()).values()[0]
    return {
      watch = [lastNexusResult, showStatsAnimations]
      rendObj = ROBJ_SOLID
      size = [flex(), SIZE_TO_CONTENT]
      halign = ALIGN_CENTER
      color = ConsoleFillColor
      padding = const [hdpx(8), 0]
      flow = FLOW_VERTICAL
      transform = {}
      animations = !showStatsAnimations.get() ? null : [
        { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION * 3, play = true }
        { prop = AnimProp.translate, from = [-sw(100), 0], to = [0, 0], delay = DEF_ANIM_DURATION * 3,
          duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic }
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
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      gap = hdpx(50)
      halign = ALIGN_CENTER
      transform = {}
      animations = !showStatsAnimations.get() ? null : [
        { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION * 4, play = true }
        { prop = AnimProp.translate, from = [-sw(100), 0], to = [0, 0], delay = DEF_ANIM_DURATION * 4,
          duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic }
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
    gap = const hdpx(10)
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

  let tabConstr = @(locId, params) mkText(loc(locId), params.__update( { fontFx = null }, body_txt))

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
  }, loc("baseDebriefing/timeTooltip"), { hplace = ALIGN_RIGHT })

  function windowTitle() {
    let { isWinner, gameDuration = 0, battleAreaInfo = {}, experienceBlock = {} } = lastNexusResult.get()
    let { scene, raidName = "" } = battleAreaInfo
    let headerColor = isWinner ? GreenSuccessColor : RedWarningColor
    local text = isWinner ? loc("baseDebriefing/successfulRaid") : loc("baseDebriefing/unsuccessfulRaid")
    if (raidName != "") {
      let raidNameSplitet = raidName.split("+")
      let raidNameLocId = raidNameSplitet?[0] == null ? "raidInfo/unknown/short"
        : "_".join(raidNameSplitet.filter(@(v) v != "ordinary"))
      text = $"{text} {loc(raidNameLocId)}"
    }
    debriefingScene.set(scene)
    debriefingRaidName.set(raidName)
    if ((experienceBlock?.openedChronogenes.len() ?? 0) > 0) {
      levelRewards.set(experienceBlock.openedChronogenes)
      haveSeenRewards.set(false)
    }
    return {
      watch = [lastNexusResult, showStatsAnimations]
      size = [flex(), SIZE_TO_CONTENT]
      children = [
        {
          rendObj = ROBJ_SOLID
          size = [flex(), ph(100)]
          color = mul_color(headerColor, 0.5)
          transform = { pivot = [0, 1] }
          animations = !showStatsAnimations.get() ? null : [
            { prop = AnimProp.scale, from = [0.03, 1], to = [0.03, 1], duration = DEF_ANIM_DURATION * 2, play = true }
            { prop = AnimProp.opacity, from = 1, to = 0.3, duration = DEF_ANIM_DURATION,
              play = true, easing = CosineFull }
            { prop = AnimProp.opacity, from = 1, to = 0.3, duration = DEF_ANIM_DURATION,
              delay = DEF_ANIM_DURATION, play = true, easing = CosineFull }
            { prop = AnimProp.scale, from = [0.03, 1], to = [1, 1], duration = DEF_ANIM_DURATION,
              delay = DEF_ANIM_DURATION * 2 play = true, easing = InOutCubic }
          ]
        }
        {
          size = [flex(), SIZE_TO_CONTENT]
          valign = ALIGN_CENTER
          padding = [0, hdpx(10)]
          flow = FLOW_HORIZONTAL
          gap = hdpx(10)
          transform = !showStatsAnimations.get() ? null : {}
          animations = [
            { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION * 2, play = true }
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

  let getContent = @() wrapInStdPanel(NEXUS_DEBRIEFING_ID, @() {
    size = [flex(), mapSize[1] + hdpx(80)]
    clipChildren = true
    onDetach = function() {
      lastNexusResult.set(null)
      currentTab.set("baseDebriefing/stats")
      eventbus_send("profile_server.mark_base_debriefing_shown", {})
    }
    children = mkConsoleScreen(playerTrackWindow)
  }, "", null, windowTitle)

  return {
    getContent
    autoShow = showNexusDebriefingWindow
    id = NEXUS_DEBRIEFING_ID
  }
}

showNexusDebriefingWindow.subscribe(function(v) {
  if (v) {
    saveNexusBattleResultToHistory(lastNexusResult.get().__merge({ isNexus = true }))
    eventbus_send("hud_menus.open", { id = NEXUS_DEBRIEFING_ID })
  }
})

return {
  NEXUS_DEBRIEFING_ID
  mkNexusDebriefingMenu
}
