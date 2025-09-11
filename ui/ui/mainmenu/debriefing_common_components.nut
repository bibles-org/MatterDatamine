from "%ui/components/colors.nut" import BtnBgNormal, InfoTextValueColor, ConsoleFillColor, BtnBgHover, BtnBgDisabled, ModalBgTint, BtnBdDisabled
from "%ui/hud/menus/notes/player_progression.nut" import levelLineExpColor, levelLineExpBackgroundColor
from "%ui/fonts_style.nut" import body_txt, h2_txt, h1_txt, giant_txt
from "%ui/components/commonComponents.nut" import mkText, mkTextArea, underlineComp
from "%ui/components/button.nut" import textButton, button
from "%ui/hud/menus/components/inventoryItem.nut" import inventoryItem
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem
import "%ui/components/colorize.nut" as colorize
from "%dngscripts/sound_system.nut" import sound_play
from "%ui/mainMenu/horisontalItemList.nut" import mkDebriefingCronotracesList, mkDebriefingItemsList
from "%ui/components/cursors.nut" import setTooltip
from "%ui/components/numbersAnimation.nut" import animateNumbers
from "%ui/components/accentButton.style.nut" import accentButtonStyle
import "%ui/components/faComp.nut" as faComp
from "%ui/mainMenu/clonesMenu/clonesMenuCommon.nut" import mkChronogeneImage, getChronogeneTooltip
from "%ui/components/modalWindows.nut" import addModalWindow, removeModalWindow
from "%ui/popup/player_event_log.nut" import addPlayerLog, mkPlayerLog
from "%ui/components/itemIconComponent.nut" import itemIconNoBorder
from "%ui/components/msgbox.nut" import showMessageWithContent
from "%ui/mainMenu/baseDebriefingTeamStats.nut" import mkDailyRewardsStats
from "%ui/hud/menus/components/amStorage.nut" import mkActiveMatterStorageWidget
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { playerExperienceToLevel } = require("%ui/profile/profileState.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { currentPlayerLevelHasExp, currentPlayerLevelNeedExp, playerCurrentLevel } = require("%ui/hud/menus/notes/player_progression.nut")
let { inventoryImageParams } = require("%ui/hud/menus/components/inventoryItemImages.nut")
let { marketIconSize } = require("%ui/popup/player_event_log.nut")

const MAX_ITEM_TO_SHOW = 10
const DEF_ANIM_DURATION = 0.4
const EXP_ANIM_TRIGGER = "expAnimTrigger"
const REWARD_WND_UID = "rewardWndUid"
const REWARDS_COUNT = 9
const REWARDS_PER_ROW = 3
const CARD_ANIM_DURATION = 0.2
const CARD_ANIM_OVERLAP = 0.1

let showRewardsAnimations = Watched(false)

let levelRewards = Watched([])
let haveSeenRewards = Watched(true)
let debugShowWindow = Watched(false)
let isCardInteractive = Watched(false)
let selectedRewardIdxs = Watched([])
let canShowRewardsIdxs = Watched([])

let rewardCardSize = [hdpx(150), hdpx(150)]

let allExpIncomes = [
  {
    headerLocId = "baseDebriefing/battleIncome"
    stats = ["dealtDamage", "receivedDamage", "lootedBodies", "medicineUsed"]
  }
  {
    headerLocId = "baseDebriefing/exploreIncome"
    stats = ["playTime", "playerPathLen", "lootedCommonContainers", "lootedSecretContainers"]
  }
]

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
      return static { watch = [ levelRewards, selectedRewardIdxs ] }
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
      animations = static [
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
          sound_play("ui_sounds/level_up_reward_select")
          selectedRewardIdxs.mutate(@(v) v.append(idx))
          canShowRewardsIdxs.mutate(@(v) v.append(idx))
        },
        {
          size = rewardCardSize
          key = $"reaward_{idx}"
          transform = static {}
          animations = [
            { prop = AnimProp.translate, from = [-sw(100), sh(25)], to = [-sw(100), sh(25)], onFinish = @() sound_play("ui_sounds/level_up_reward_drop"),
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
    foreach (templateName in levelRewards.get()) {
      let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
      let itemName = template?.getCompValNullable("item__name")
      let item = { itemTemplate = templateName }
      let icon = mkChronogeneImage(item, { slotSize = marketIconSize, width = marketIconSize[0],
        height = marketIconSize[1] })
      addPlayerLog({
        id = item
        content = mkPlayerLog({
          titleFaIcon = "user"
          bodyIcon = {
            hplace = ALIGN_CENTER
            vplace = ALIGN_CENTER
            children = icon
          }
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
    size = static [flex(), sh(70)]
    halign = ALIGN_CENTER
    padding = hdpx(10)
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      rewardWindowTitle
      {
        flow = FLOW_VERTICAL
        gap = hdpx(10)
        size = FLEX_V
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

function showUnseenRewardsMessage() {
  let content = {
    flow = FLOW_VERTICAL
    gap = hdpx(40)
    size = FLEX_H
    halign = ALIGN_CENTER
    children = [
      @() {
        watch = playerCurrentLevel
        children = mkText(loc("levelReward/windowTitle", { level = playerCurrentLevel.get() + 1 }), h1_txt)
      }
      @() {
        watch = levelRewards
        size = FLEX_H
        valign = ALIGN_CENTER
        halign = ALIGN_CENTER
        flow = FLOW_HORIZONTAL
        gap = hdpx(10)
        children = levelRewards.get()
          .map(function(reward) {
            let item = { itemTemplate = reward }
            let icon = mkChronogeneImage(item, { slotSize = rewardCardSize, width = inventoryImageParams.width,
              height = inventoryImageParams.height })
            return {
              rendObj = ROBJ_SOLID
              color = BtnBgNormal
              size = rewardCardSize
              halign = ALIGN_CENTER
              valign = ALIGN_CENTER
              behavior = Behaviors.Button
              onHover = @(on) setTooltip(on ? getChronogeneTooltip(item) : null)
              children = icon
            }
          })
      }
    ]
  }
  showMessageWithContent({ content })
}

let mkEvacuatedItems = @(itemsToShow) itemsToShow.len() <= 0 ? null : @() {
  watch = showRewardsAnimations
  rendObj = ROBJ_BOX
  size = FLEX_H
  fillColor = ConsoleFillColor
  borderWidth = static hdpx(1)
  borderColor = BtnBdDisabled
  padding = static hdpx(10)
  flow = FLOW_VERTICAL
  gap = hdpx(10)
  transform = static{}
  animations = !showRewardsAnimations.get() ? null : static [
    { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION * 2, play = true }
    { prop = AnimProp.translate, from = [sw(50), 0], to = [0, 0], delay = DEF_ANIM_DURATION * 2,
      duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic, onStart  = @() sound_play("ui_sounds/card_appear") }
    ]
  children = [
    static mkText(loc("baseDebriefing/evacuated"), h2_txt)
    mkDebriefingItemsList(itemsToShow, MAX_ITEM_TO_SHOW)
  ]
}

let mkChronotracesList = @(openedReseachNodesV2, chronotracesProgression, animStep = 0)
  openedReseachNodesV2.len() <= 0 && chronotracesProgression.len() <= 0 ? null : @() {
    watch = showRewardsAnimations
    rendObj = ROBJ_BOX
    size = FLEX_H
    fillColor = ConsoleFillColor
    borderWidth = static hdpx(1)
    borderColor = BtnBdDisabled
    padding = static hdpx(10)
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    transform = static {}
    animations = !showRewardsAnimations.get() ? null : [
      { prop = AnimProp.opacity, from = 0, to = 0, duration = animStep * DEF_ANIM_DURATION, play = true }
      { prop = AnimProp.translate, from = [sw(50), 0], to = [0, 0], delay = animStep * DEF_ANIM_DURATION,
        duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic, onStart  = @() sound_play("ui_sounds/card_appear") }
    ]
    children = [
      static mkText(loc("baseDebriefing/chronotraces"), h2_txt)
      mkDebriefingCronotracesList(openedReseachNodesV2, chronotracesProgression, MAX_ITEM_TO_SHOW)
    ]
}

let arrow = faComp("arrow-right", { fontSize = hdpx(25) })
let mkAmExchangeBlock = @(AMResource) {
  size = static [flex(), ph(100)]
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

let mkDailyRewardsBlock = @(monolithCreditsCount, AMResource, animStep = 0) @() {
  watch = showRewardsAnimations
  rendObj = ROBJ_BOX
  size = FLEX_H
  fillColor = ConsoleFillColor
  borderWidth = static hdpx(1)
  borderColor = BtnBdDisabled
  padding = static hdpx(10)
  flow = FLOW_VERTICAL
  gap = { size = flex() }
  transform = {}
  animations = !showRewardsAnimations.get() ? null : [
    { prop = AnimProp.opacity, from = 0, to = 0, duration = animStep * DEF_ANIM_DURATION, play = true }
    { prop = AnimProp.translate, from = [sw(50), 0], to = [0, 0], delay = animStep * DEF_ANIM_DURATION,
      duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic, onStart  = @() sound_play("ui_sounds/card_appear") }
  ]
  children = [
    {
      size = FLEX_H
      flow = FLOW_HORIZONTAL
      gap = { size = static [flex(0.2), SIZE_TO_CONTENT] }
      children = [
        monolithCreditsCount <= 0 ? null : mkDailyRewardsStats(monolithCreditsCount)
        AMResource <= 0 ? null : mkAmExchangeBlock(AMResource)
      ]
    }
  ]
}

function mkExpPointer(expBefore, expAfter, needAnim, ratioToUse) {
  let xPose = ratioToUse <= 10 ? hdpx(20)
    : ratioToUse >= 90 ? -hdpx(20)
    : 0
  return {
    rendObj = ROBJ_SOLID
    size = static [hdpx(4), hdpx(20)]
    pos = [0, -hdpx(10)]
    halign = ALIGN_CENTER
    children = {
      flow = FLOW_HORIZONTAL
      pos = [xPose, -hdpx(30)]
      children = [!needAnim || expBefore == expAfter
        ? mkText($"{expAfter}", { color = InfoTextValueColor }.__update(body_txt))
        : animateNumbers(expAfter, { color = InfoTextValueColor }.__update(body_txt), {
            digitAnimDuration = DEF_ANIM_DURATION * 2
            trigger = "digitsTrigger"
            startValue = expBefore
          })
        mkText(" XP", { color = InfoTextValueColor }.__update(body_txt))]
    }
  }
}

let mkPlayerLevelExpLine = function(expBefore, expAfter, curLevelExp) {
  let curExp = curLevelExp.tofloat()
  let levelRatioBefore = (expBefore >= 0 ? expBefore.tofloat() : 0) / curExp
  let levelRatio = expAfter.tofloat() / curExp - levelRatioBefore
  let ratioToUse = clamp(levelRatio * 100, 0, 100)
  let opacity = Watched(0)
  return @() {
    size = static [flex(), hdpx(10)]
    children = [
      static {
        rendObj = ROBJ_SOLID
        size = flex()
        color = levelLineExpBackgroundColor
      }
      {
        size = static [pw(100), flex()]
        flow = FLOW_HORIZONTAL
        children = [
          {
            rendObj = ROBJ_SOLID
            size = [ pw(min(levelRatioBefore * 100, 100)), flex() ]
            color = levelLineExpColor
          }
          @() {
            watch = [showRewardsAnimations, opacity]
            rendObj = ROBJ_SOLID
            size = [pw(ratioToUse), flex()]
            color = BtnBgHover
            halign = ALIGN_RIGHT
            opacity = opacity.get()
            transform = static {pivot = [0, 0.5]}
            transitions = [{prop = AnimProp.opacity, duration = DEF_ANIM_DURATION/2.0 easing = InOutCubic}]
            animations = !showRewardsAnimations.get() ? null : [
              { prop = AnimProp.opacity, from = 0, to = 0, duration = 2 * DEF_ANIM_DURATION, play = true, onFinish = function() {
                opacity.set(1)
                sound_play("ui_sounds/level_up_xp")
              }}
              static { prop = AnimProp.scale, from = [0, 1], to = [1, 1], duration = DEF_ANIM_DURATION,
                easing = InOutCubic, trigger = EXP_ANIM_TRIGGER,
                onFinish = function() { anim_start("digitsTrigger") }}
            ]
            children = mkExpPointer(expBefore, expAfter, showRewardsAnimations.get(), ratioToUse)
          }
        ]
      }
    ]
  }
}

let mkPlayerExpIncomeBlock = @(stats, needAnim) {
  rendObj = ROBJ_BOX
  size = flex()
  fillColor = ConsoleFillColor
  borderWidth = static hdpx(1)
  borderColor = BtnBdDisabled
  padding = static hdpx(10)
  flow = FLOW_VERTICAL
  gap = static hdpx(20)
  transform = {}
  animations = !needAnim ? null : [
    static { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION, play = true }
    static { prop = AnimProp.translate, from = static [-sw(50), 0], to = static [0, 0], delay = DEF_ANIM_DURATION,
      duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic, onFinish = @() anim_start(EXP_ANIM_TRIGGER), onStart  = @() sound_play("ui_sounds/card_appear") }
  ]
  children = allExpIncomes.map(@(income) {
    size = FLEX_H
    flow = FLOW_VERTICAL
    gap = static hdpx(10)
    children = [
      mkText(loc(income.headerLocId), h2_txt)
      {
        size = FLEX_H
        flow = FLOW_VERTICAL
        gap = static hdpx(2)
        children = income.stats.map(@(stat) underlineComp({
          size = FLEX_H
          flow = FLOW_HORIZONTAL
          gap = { size = FLEX_H }
          padding = hdpx(5)
          children = [
            mkText(loc($"expIncome/{stat}"), body_txt)
            mkText($"{stats?[stat] ?? ""} XP", { color = InfoTextValueColor }.__update(body_txt))
          ]
        }))
      }
    ]
  })
}

let mkPlayerExpBlock = @(experienceBlock, expLineBlockHeight) function() {
  let { expBeforeRewarding = 0, expRewards = {} } = experienceBlock
  local expBefore = expBeforeRewarding - (playerExperienceToLevel.get()?[playerCurrentLevel.get() - 1] ?? 0)
  expBefore = expBefore >= 0 ? expBefore : 0
  let expAfter = currentPlayerLevelHasExp.get()
  return {
    watch = [currentPlayerLevelHasExp, currentPlayerLevelNeedExp, playerCurrentLevel,
      showRewardsAnimations, playerExperienceToLevel]
    size = flex()
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    transform = static {}
    animations = !showRewardsAnimations.get() ? null : [
      { prop = AnimProp.translate, from = static [-sw(50), 0], to = static [0, 0], duration = DEF_ANIM_DURATION,
        play = true, easing = InOutCubic, onFinish = @() anim_start(EXP_ANIM_TRIGGER) }
    ]
    behavior = Behaviors.Button
    children = [
      {
        rendObj = ROBJ_BOX
        size = [flex(), max(expLineBlockHeight, hdpxi(139))]
        fillColor = ConsoleFillColor
        borderWidth = static hdpx(1)
        borderColor = BtnBdDisabled
        padding = static hdpx(10)
        flow = FLOW_VERTICAL
        gap = hdpx(10)
        children = [
          mkTextArea($"{loc("player_progression/currentLevel")} {colorize(InfoTextValueColor, playerCurrentLevel.get() + 1)}",
          { margin = static [0,0, hdpx(40), 0] }.__update(h2_txt))
          {
            size = flex()
            flow = FLOW_VERTICAL
            valign = ALIGN_CENTER
            children = [
              mkPlayerLevelExpLine(expBefore, expAfter, currentPlayerLevelNeedExp.get())
              {
                size = FLEX_H
                children = [
                  mkText($"{expBefore} XP", body_txt)
                  mkText($"{currentPlayerLevelNeedExp.get()} XP", { hplace = ALIGN_RIGHT }.__update(body_txt))
                ]
              }
            ]
          }
        ]
      }
      mkPlayerExpIncomeBlock(expRewards, showRewardsAnimations.get())
    ]
  }
}

return freeze({
  mkEvacuatedItems
  mkChronotracesList
  mkDailyRewardsBlock
  mkPlayerExpBlock
  openRewardWidnow
  levelRewards
  haveSeenRewards
  debugShowWindow
  isCardInteractive
  selectedRewardIdxs
  canShowRewardsIdxs
  showUnseenRewardsMessage
  DEF_ANIM_DURATION
  showRewardsAnimations
})