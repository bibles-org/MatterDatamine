from "%ui/ui_library.nut" import *

import "%dngscripts/ecs.nut" as ecs
import "%ui/mainMenu/baseDebriefingSample.nut" as loadSample

let { body_txt, fontawesome, h2_txt, h1_txt, giant_txt } = require("%ui/fonts_style.nut")
let { TextNormal, GreenSuccessColor, RedWarningColor, BtnBgHover, InfoTextValueColor, ModalBgTint, ConsoleFillColor,
  BtnBgNormal, BtnBgDisabled } = require("%ui/components/colors.nut")
let { lastBattleResult, playerExperienceToLevel } = require("%ui/profile/profileState.nut")
let { isInPlayerSession } = require("%ui/hud/state/gametype_state.nut")
let { eventbus_send } = require("eventbus")
let { mkConsoleScreen, mkText, mkTextArea, mkTitleString, mkTooltiped, mkTabs
} = require("%ui/components/commonComponents.nut")
let { textButton, button } = require("%ui/components/button.nut")
let { mkDebriefingItemsList, mkDebriefingCronotracesList } = require("%ui/mainMenu/horisontalItemList.nut")
let { debriefingStats, mkTeamBlock, mkDailyRewardsStats } = require("%ui/mainMenu/baseDebriefingTeamStats.nut")
let { debriefingLog } = require("%ui/mainMenu/baseDebriefingLog.nut")
let { mkDebriefingMap, mapSize } = require("%ui/mainMenu/baseDebriefingMap.nut")
let fa = require("%ui/components/fontawesome.map.nut")
let { secondsToStringLoc } = require("%ui/helpers/time.nut")
let { wrapInStdPanel, mkCloseStyleBtn } = require("stdPanel.nut")
let { inventoryItem } = require("%ui/hud/menus/components/inventoryItem.nut")
let { mkFakeItem } = require("%ui/hud/menus/components/fakeItem.nut")
let { curentHudMenusIds } = require("%ui/hud/hud_menus_state.nut")
let JB = require("%ui/control/gui_buttons.nut")
let faComp = require("%ui/components/faComp.nut")
let { mkActiveMatterStorageWidget } = require("%ui/hud/menus/components/amStorage.nut")
let { isBattleResultInHistory, saveBattleResultToHistory } = require("%ui/profile/battle_results.nut")
let { currentPlayerLevelHasExp, currentPlayerLevelNeedExp, playerCurrentLevel,
  levelLineExpColor, levelLineExpBackgroundColor } = require("%ui/hud/menus/notes/player_progression.nut")
let colorize = require("%ui/components/colorize.nut")
let { animateNumbers } = require("%ui/components/numbersAnimation.nut")
let { addModalWindow, removeModalWindow } = require("%ui/components/modalWindows.nut")
let { accentButtonStyle } = require("%ui/components/accentButton.style.nut")
let { addPlayerLog, mkPlayerLog, marketIconSize } = require("%ui/popup/player_event_log.nut")
let { itemIconNoBorder } = require("%ui/components/itemIconComponent.nut")
let tooltipBox = require("%ui/components/tooltipBox.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let { showMessageWithContent } = require("%ui/components/msgbox.nut")
let { mkChronogeneImage, getChronogeneTooltip } = require("%ui/mainMenu/clonesMenu/clonesMenuCommon.nut")
let { inventoryImageParams } = require("%ui/hud/menus/components/inventoryItemImages.nut")

const BaseDebriefingMenuId = "baseDebriefingMenu"
const MAX_ITEM_TO_SHOW = 11
const DEF_ANIM_DURATION = 0.4
const EXP_ANIM_TRIGGER = "expAnimTrigger"
const REWARD_WND_UID = "rewardWndUid"
const REWARDS_COUNT = 9
const REWARDS_PER_ROW = 3
const CARD_ANIM_DURATION = 0.2
const CARD_ANIM_OVERLAP = 0.1

let currentTab = Watched("baseDebriefing/history")
let showHistoryAnimations = Watched(true)
let showRewardsAnimations = Watched(true)
let levelRewards = Watched([])
let haveSeenRewards = Watched(true)
let debugShowWindow = Watched(false)
let isCardInteractive = Watched(false)
let selectedRewardIdxs = Watched([])
let canShowRewardsIdxs = Watched([])

let rewardCardSize = [hdpx(150), hdpx(150)]

console_register_command(@() debugShowWindow.set(!debugShowWindow.get()), "baseDebriefing.show")
console_register_command(function() {
  loadSample()
  debugShowWindow.set(true)
}, "baseDebriefing.showSample")

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
  eventbus_send("hud_menus.close", const { id = BaseDebriefingMenuId })
  lastBattleResult.set(null)
  showHistoryAnimations.set(true)
  showRewardsAnimations.set(true)
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

let statsAndLog = @() {
  watch = showHistoryAnimations
  size = flex()
  flow = FLOW_VERTICAL
  gap = hdpx(10)
  children = [
    {
      size = flex()
      transform = const{}
      animations = !showHistoryAnimations.get() ? null : const [
        { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION * 4, play = true }
        { prop = AnimProp.translate, from = [sw(50), 0], to = [0, 0], delay = DEF_ANIM_DURATION * 4,
          duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic }
      ]
      children = debriefingLog
    }
    {
      size = const[flex(), SIZE_TO_CONTENT]
      transform = const{}
      animations = !showHistoryAnimations.get() ? null : const [
        { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION * 5, play = true }
        { prop = AnimProp.translate, from = [sw(50), 0], to = [0, 0], delay = DEF_ANIM_DURATION * 5,
          duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic }
      ]
      children = debriefingStats
    }
  ]
}


let mkEvacuatedItems = @(itemsToShow) itemsToShow.len() <= 0 ? null : @() {
  watch = showRewardsAnimations
  size = const [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  gap = hdpx(10)
  transform = const{}
  animations = !showRewardsAnimations.get() ? null
    : const [{ prop = AnimProp.translate, from = [sw(50), 0], to = [0, 0],
        duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic }]
  children = [
    const mkText(loc("baseDebriefing/evacuated"), h2_txt)
    mkDebriefingItemsList(itemsToShow, MAX_ITEM_TO_SHOW)
  ]
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

let setTab = @(tab) currentTab.set(tab)

function nextBackBtn() {
  let isNext = currentTab.get() == "baseDebriefing/history"
  let locId = isNext ? "baseDebriefing/nextWindowButton" : "mainmenu/btnBack"
  let action = function() {
    setTab(isNext ? "baseDebriefing/rewards" : "baseDebriefing/history")
    if (isNext)
      showHistoryAnimations.set(false)
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

let mkDailyRewardsBlock = @(monolithCreditsCount, AMResource, animStep) @() {
  watch = showRewardsAnimations
  size = [ flex(), SIZE_TO_CONTENT ]
  flow = FLOW_VERTICAL
  gap = { size = flex() }
  transform = {}
  animations = !showRewardsAnimations.get() ? null : [
    { prop = AnimProp.opacity, from = 0, to = 0, duration = animStep * DEF_ANIM_DURATION, play = true }
    { prop = AnimProp.translate, from = [sw(50), 0], to = [0, 0], delay = animStep * DEF_ANIM_DURATION,
      duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic }
  ]
  children = [
    {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      gap = { size = [flex(0.2), SIZE_TO_CONTENT] }
      children = [
        monolithCreditsCount <= 0 ? null : mkDailyRewardsStats(monolithCreditsCount)
        AMResource <= 0 ? null : mkAmExchangeBlock(AMResource)
      ]
    }
  ]
}

let playerLevelExpLine = function(expBefore, expAfter, curLevelExp, animStep) {
  let curExp = curLevelExp.tofloat()
  let levelRatioBefore = (expBefore >= 0 ? expBefore.tofloat() : 0) / curExp
  let levelRatio = expAfter.tofloat() / curExp - levelRatioBefore
  return {
    size = const [flex(), hdpx(10)]
    clipChildren = true
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
            size = [ pw(clamp(levelRatioBefore * 100, 0, 100)), flex() ]
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
                  startValue = min(0, expBefore)
                })
              ].append(const mkText(" XP", body_txt))
          }
          mkText($"{currentPlayerLevelNeedExp.get()} XP", const { hplace = ALIGN_RIGHT }.__update(body_txt))
        ]
      }
    ]
  }
}

function resourceAndItems() {
  let { dailyStatRewards = {}, loadout = [], battleStat = {},
    openedReseachNodesV2 = [], chronotracesProgression = [], experienceBlock = {} } = lastBattleResult.get()
  let { AMResource = 0 } = battleStat
  let monolithCreditsCount = dailyStatRewards.reduce(@(acc, v) acc+=v, 0)
  if (dailyStatRewards.len() <= 0
    && loadout.len() <= 0
    && openedReseachNodesV2.len() <= 0
    && chronotracesProgression.len() <= 0
    && AMResource <= 0
    && monolithCreditsCount <= 0
    && experienceBlock.len() <= 0
  )
    return {
      watch = lastBattleResult
      size = [flex(), mapSize[1]]
      children = [
        mkText(loc("baseDebriefing/noData"), { hplace = ALIGN_CENTER, vplace =  ALIGN_CENTER }.__update(h2_txt))
        {
          flow = FLOW_HORIZONTAL
          gap = hdpx(10)
          hplace = ALIGN_RIGHT
          vplace = ALIGN_BOTTOM
          children = [
            nextBackBtn
            closeOrRewardBtn
          ]
        }
      ]
    }
  let evacuatedItems = loadout.filter(@(v) v?.isFoundInRaid)
  let chronoAnimStep = evacuatedItems.len() && (openedReseachNodesV2.len() > 0 || chronotracesProgression.len() > 0) ? 1 : 0
  let dailyAnimStep = monolithCreditsCount > 0 || AMResource > 0 ? chronoAnimStep + 1 : chronoAnimStep
  let expAnimStep = dailyAnimStep + 1

  return {
    watch = lastBattleResult
    size = flex()
    flow = FLOW_VERTICAL
    gap = hdpx(20)
    children = [
      mkEvacuatedItems(evacuatedItems)
      mkChronotracesList(openedReseachNodesV2, chronotracesProgression, chronoAnimStep)
      mkDailyRewardsBlock(monolithCreditsCount, AMResource, dailyAnimStep)
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

let timeIcon = {
  rendObj = ROBJ_TEXT
  text = fa["clock-o"]
  color = TextNormal
}.__update(fontawesome)

let showDebriefingWindow = Computed(
  @() debugShowWindow.get()
    || (
         lastBattleResult.get()?.id != null
      && lastBattleResult.get().id.len() > 0
      && !isBattleResultInHistory(lastBattleResult.get()?.id)
      && !isInPlayerSession.get()
      && curentHudMenusIds.get()?[BaseDebriefingMenuId] != null
      && curentHudMenusIds.get()?[BaseDebriefingMenuId] != "nexusDebriefingId"
    )
)

let historyContent = @() {
  size = const [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  gap = hdpx(20)
  children = [
    @() {
      watch = showHistoryAnimations
      size = [flex(), mapSize[1]]
      flow = FLOW_HORIZONTAL
      gap = hdpx(10)
      children = [
        {
          transform = const {}
          animations = !showHistoryAnimations.get() ? null : const [
            { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION * 3, play = true }
            { prop = AnimProp.translate, from = [-sw(50), 0], to = [0, 0], delay = DEF_ANIM_DURATION * 3
              duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic }
          ]
          children = mkDebriefingMap()
        }
        {
          size = flex()
          flow = FLOW_VERTICAL
          gap = hdpx(10)
          children = [
            statsAndLog
            @() {
              watch = const [lastBattleResult, showHistoryAnimations]
              size = const [flex(), SIZE_TO_CONTENT]
              flow = FLOW_HORIZONTAL
              transform = const {}
              animations = !showHistoryAnimations.get() ? null : const [
                { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION * 6, play = true }
                { prop = AnimProp.translate, from = [sw(50), 0], to = [0, 0], delay = DEF_ANIM_DURATION * 6,
                  duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic }
              ]
              children = [
                mkTeamBlock(lastBattleResult.get())
                {
                  flow = FLOW_HORIZONTAL
                  gap = hdpx(10)
                  vplace = ALIGN_BOTTOM
                  children = nextBackBtn
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}

let rewardsContent = @() {
  size = [flex(), mapSize[1]]
  flow = FLOW_HORIZONTAL
  gap = hdpx(10)
  children = [
    mkDebriefingMap()
    @() {
      watch = showRewardsAnimations
      size = flex()
      flow = FLOW_HORIZONTAL
      gap = hdpx(10)
      children = resourceAndItems
    }
  ]
}

let tabConstr = @(locId, params) mkText(loc(locId), params.__update( { fontFx = null }, body_txt))

let tabsList = [
  { id = "baseDebriefing/history"
    childrenConstr = @(params) tabConstr("baseDebriefing/history", params)
    content = historyContent
  }
  {
    id = "baseDebriefing/rewards"
    childrenConstr = @(params) tabConstr("baseDebriefing/rewards", params)
    content = rewardsContent
  }
]

let getCurTabContent = @(tabId) tabsList.findvalue(@(v) v.id == tabId)?.content

function mkBaseDebriefingMenu(){
  function playerTrackWindow() {
    let tabsUi = mkTabs({
      tabs = tabsList
      currentTab = currentTab.get()
      onChange = function(tab) {
        currentTab.set(tab.id)
        if (tab.id == "baseDebriefing/history")
          showRewardsAnimations.set(false)
        else
          showHistoryAnimations.set(false)
      }
    })
    let tabContent = getCurTabContent(currentTab.get())
    return {
      watch = currentTab
      size = const [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap = hdpx(10)
      children = [
        @() {
          watch = showHistoryAnimations
          size = [flex(), SIZE_TO_CONTENT]
          transform = const {}
          animations = !showHistoryAnimations.get() ? null : const [
            { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION * 2, play = true }
            { prop = AnimProp.translate, from = [-sw(50), 0], to = [0, 0], duration = DEF_ANIM_DURATION,
              delay = DEF_ANIM_DURATION * 2 play = true, easing = InOutCubic }
          ]
          children = tabsUi
        }
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
  }, loc("baseDebriefing/timeTooltip"), const { hplace = ALIGN_RIGHT })

  function windowTitle() {
    let { battleStat = const {}, trackPoints = null, battleAreaInfo = const {}, experienceBlock = const {} } = lastBattleResult.get()
    let headerColor = battleStat?.isSuccessRaid ? GreenSuccessColor : RedWarningColor
    let { raidName = null } = battleAreaInfo
    local text = battleStat?.isSuccessRaid ? loc("baseDebriefing/successfulRaid") : loc("baseDebriefing/unsuccessfulRaid")
    if (raidName != null) {
      let raidNameSplitet = raidName.split("+")
      let raidNameLocId = raidNameSplitet?[0] == null ? "raidInfo/unknown/short"
        : "_".join(raidNameSplitet.filter(@(v) v != "ordinary"))
      text = $"{text} {loc(raidNameLocId)}"
    }
    let raidTime = (trackPoints == null || trackPoints.len() == 0) ? 0
      : trackPoints[trackPoints.len() - 1].timestamp

    if ((experienceBlock?.openedChronogenes.len() ?? 0) > 0) {
      levelRewards.set(experienceBlock.openedChronogenes)
      haveSeenRewards.set(false)
    }
    return {
      watch = [lastBattleResult, showHistoryAnimations]
      size = const [flex(), SIZE_TO_CONTENT]
      children = [
        {
          rendObj = ROBJ_SOLID
          size = const [flex(), ph(100)]
          color = mul_color(headerColor, 0.5)
          transform = const { pivot = [0, 1] }
          animations = !showHistoryAnimations.get() ? null : const  [
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
          size = const [flex(), SIZE_TO_CONTENT]
          valign = ALIGN_CENTER
          padding = const [0, hdpx(10)]
          flow = FLOW_HORIZONTAL
          transform = !showHistoryAnimations.get() ? null : {}
          animations = const [
            { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION * 2, play = true }
            { prop = AnimProp.opacity, from = 0, to = 1, delay = DEF_ANIM_DURATION * 2, duration = DEF_ANIM_DURATION, play = true }
          ]
          gap = hdpx(5)
          children = [
            mkTitleString(text)
            const {size=[flex(), 0]}
            mkTime(raidTime)
            closeXBtn
          ]
        }
      ]
    }
  }

  let getContent = @() wrapInStdPanel(BaseDebriefingMenuId, @() {
    size = [flex(),  mapSize[1] + hdpx(80)]
    clipChildren = true
    onDetach = function() {
      debugShowWindow.set(false)
      currentTab.set("baseDebriefing/history")
      lastBattleResult.set(null)
      showHistoryAnimations.set(true)
      showRewardsAnimations.set(true)
      if (!haveSeenRewards.get()) {
        let content = {
          flow = FLOW_VERTICAL
          gap = hdpx(40)
          size = [flex(), SIZE_TO_CONTENT]
          halign = ALIGN_CENTER
          children = [
            @() {
              watch = playerCurrentLevel
              children = mkText(loc("levelReward/windowTitle", { level = playerCurrentLevel.get() + 1 }), h1_txt)
            }
            @() {
              watch = levelRewards
              size = [flex(), SIZE_TO_CONTENT]
              valign = ALIGN_CENTER
              halign = ALIGN_CENTER
              flow = FLOW_HORIZONTAL
              gap = hdpx(10)
              children = levelRewards.get()
                .map(@(reward) inventoryItem(mkFakeItem(reward, { key = reward }), null, {}, rewardCardSize))
            }
          ]
        }
        showMessageWithContent({ content })
      }
      haveSeenRewards.set(true)
    }
    children = mkConsoleScreen(playerTrackWindow)
  }, "", null, windowTitle)

  return {
    getContent
    autoShow = showDebriefingWindow
    id = BaseDebriefingMenuId
  }
}


showDebriefingWindow.subscribe(function(v) {
  if (v) {
    saveBattleResultToHistory(lastBattleResult.get())
    eventbus_send("hud_menus.open", { id = BaseDebriefingMenuId })
  }
  else if (isBattleResultInHistory(lastBattleResult.get()?.id))
    lastBattleResult.set(null)
})

return {
  BaseDebriefingMenuId
  mkBaseDebriefingMenu
  resourceAndItems
  showDebriefingWindow
}
