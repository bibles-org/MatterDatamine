from "%ui/components/commonComponents.nut" import mkConsoleScreen, mkText, mkTitleString, mkTooltiped, mkTabs
from "%ui/mainMenu/debriefing_common_components.nut" import mkEvacuatedItems, mkChronotracesList, mkDailyRewardsBlock, mkPlayerExpBlock,
  DEF_ANIM_DURATION, openRewardWidnow, showUnseenRewardsMessage
from "%ui/fonts_style.nut" import body_txt, fontawesome, h2_txt
from "%ui/components/colors.nut" import TextNormal, GreenSuccessColor, RedWarningColor, ConsoleFillColor, BtnBdDisabled
from "eventbus" import eventbus_send
from "%dngscripts/sound_system.nut" import sound_play
from "%ui/components/button.nut" import textButton
from "%ui/mainMenu/baseDebriefingTeamStats.nut" import debriefingStats, mkTeamBlock
from "%ui/mainMenu/baseDebriefingMap.nut" import mkDebriefingMap
from "%ui/helpers/time.nut" import secondsToStringLoc
from "%ui/mainMenu/stdPanel.nut" import wrapInStdPanel, mkCloseStyleBtn
from "%ui/profile/battle_results.nut" import isBattleResultInHistory, saveBattleResultToHistory
from "%ui/components/accentButton.style.nut" import accentButtonStyle
import "%ui/components/fontawesome.map.nut" as fa
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
from "%ui/mainMenu/baseDebriefingSample.nut" import loadBaseDebriefingSample
import "%ui/control/gui_buttons.nut" as JB
from "%ui/mainMenu/baseDebriefingMap.nut" import mapSize

let { lastBattleResult } = require("%ui/profile/profileState.nut")
let { isInPlayerSession } = require("%ui/hud/state/gametype_state.nut")
let { debriefingLog } = require("%ui/mainMenu/baseDebriefingLog.nut")
let { curentHudMenusIds } = require("%ui/hud/hud_menus_state.nut")
let { showRewardsAnimations, levelRewards, haveSeenRewards } = require("%ui/mainMenu/debriefing_common_components.nut")
let { onlineSettingUpdated } = require("%ui/options/onlineSettings.nut")

const BaseDebriefingMenuId = "baseDebriefingMenu"

let currentTab = Watched("baseDebriefing/history")
let debugShowWindow = Watched(false)
let showHistoryAnimations = Watched(true)

console_register_command(@() debugShowWindow.set(!debugShowWindow.get()), "baseDebriefing.show")
console_register_command(function() {
  loadBaseDebriefingSample()
  debugShowWindow.set(true)
}, "baseDebriefing.showSample")

function closeBaseDebriefing() {
  let needRewards = lastBattleResult.get()?.needRewards ?? true
  if (levelRewards.get().len() > 0 && needRewards) {
    openRewardWidnow()
    haveSeenRewards.set(true)
  }
  eventbus_send("hud_menus.close", static { id = BaseDebriefingMenuId })
  lastBattleResult.set(null)
}

let closeXBtn = mkCloseStyleBtn(closeBaseDebriefing)

function closeOrRewardBtn(needRewards = true) {
  let text = !needRewards || levelRewards.get().len() <= 0 ? loc("baseDebriefing/closeButton")
    : loc("baseDebriefing/getReward")
  return {
    hplace = ALIGN_RIGHT
    children = textButton(text, closeBaseDebriefing, {
      hotkeys = [[$"^Esc | {JB.B}", { description = text }]]
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
      transform = static{}
      animations = !showHistoryAnimations.get() ? null : static [
        { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION * 4, play = true }
        { prop = AnimProp.translate, from = [sw(50), 0], to = [0, 0], delay = DEF_ANIM_DURATION * 4,
          duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic, onStart  = @() sound_play("ui_sounds/card_appear") }
      ]
      children = debriefingLog
    }
    {
      rendObj = ROBJ_BOX
      size = FLEX_H
      fillColor = ConsoleFillColor
      borderWidth = static hdpx(1)
      borderColor = BtnBdDisabled
      padding = static hdpx(10)
      transform = static{}
      animations = !showHistoryAnimations.get() ? null : static [
        { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION * 5, play = true }
        { prop = AnimProp.translate, from = [sw(50), 0], to = [0, 0], delay = DEF_ANIM_DURATION * 5,
          duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic, onStart  = @() sound_play("ui_sounds/card_appear") }
      ]
      children = debriefingStats
    }
  ]
}

let setTab = @(tab) currentTab.set(tab)

let nextBackCloseBtnStates = {
  BACK =  {text = loc("mainmenu/btnBack"), action = function(){setTab("baseDebriefing/history"); showRewardsAnimations.set(false);}}
  NEXT =  {text = loc("baseDebriefing/nextWindowButton"), action = function(){setTab("baseDebriefing/rewards");showHistoryAnimations.set(false);}}
  CLOSE = {text = loc("baseDebriefing/closeButton"), action=@() closeBaseDebriefing(), style=accentButtonStyle}
}

function nextBackCloseBtn() {
  let needRewards = lastBattleResult.get()?.needRewards ?? true
  let isFirstTab = currentTab.get() == "baseDebriefing/history"
  let {text, action, style={}} = nextBackCloseBtnStates[needRewards && isFirstTab ? "NEXT" : (isFirstTab ? "CLOSE" : "BACK")]
  return {
    watch = currentTab
    vplace = ALIGN_BOTTOM
    children = textButton(text, action, {
      hotkeys = [[$"^Esc | {JB.B}", {description = text}]]
    }.__update(style))
  }
}

function resourceAndItems() {
  let { dailyStatRewards = {}, loadout = [], battleStat = {}, openedReseachNodesV2 = [],
  chronotracesProgression = [], needRewards = true } = lastBattleResult.get()
  let { AMResource = 0 } = battleStat
  let monolithCreditsCount = dailyStatRewards.reduce(@(acc, v) acc+=v, 0)
  if (dailyStatRewards.len() <= 0
    && loadout.len() <= 0
    && openedReseachNodesV2.len() <= 0
    && chronotracesProgression.len() <= 0
    && AMResource <= 0
    && monolithCreditsCount <= 0
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
            nextBackCloseBtn
            closeOrRewardBtn(needRewards)
          ]
        }
      ]
    }
  let evacuatedItems = loadout.filter(@(v) v?.isFoundInRaid)
  let chronoAnimStep = evacuatedItems.len() && (openedReseachNodesV2.len() > 0 || chronotracesProgression.len() > 0) ? 3 : 2
  let dailyAnimStep = monolithCreditsCount > 0 || AMResource > 0 ? chronoAnimStep + 1 : chronoAnimStep
  return {
    watch = lastBattleResult
    size = flex()
    flow = FLOW_VERTICAL
    gap = { size = FLEX_V }
    children = [
      {
        size = FLEX_H
        flow = FLOW_VERTICAL
        gap = static hdpx(10)
        padding = static [0, hdpx(10), 0, 0]
        children = [
          mkEvacuatedItems(evacuatedItems)
          mkChronotracesList(openedReseachNodesV2, chronotracesProgression, chronoAnimStep)
          mkDailyRewardsBlock(monolithCreditsCount, AMResource, dailyAnimStep)
        ]
      }
      {
        flow = FLOW_HORIZONTAL
        gap = static hdpx(10)
        hplace = ALIGN_RIGHT
        vplace = ALIGN_BOTTOM
        children = [
          nextBackCloseBtn
          closeOrRewardBtn(needRewards)
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
      && onlineSettingUpdated.get()
      && !isBattleResultInHistory(lastBattleResult.get()?.id)
      && !isInPlayerSession.get()
      && curentHudMenusIds.get()?[BaseDebriefingMenuId] != null
      && curentHudMenusIds.get()?[BaseDebriefingMenuId] != "nexusDebriefingId"
    )
)

let historyContent = @() {
  size = FLEX_H
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
          transform = static {}
          animations = !showHistoryAnimations.get() ? null : static [
            { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION * 3, play = true }
            { prop = AnimProp.translate, from = [-sw(50), 0], to = [0, 0], delay = DEF_ANIM_DURATION * 3
              duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic, onStart  = @() sound_play("ui_sounds/card_appear") }
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
              watch = static [lastBattleResult, showHistoryAnimations]
              rendObj = ROBJ_BOX
              size = FLEX_H
              fillColor = ConsoleFillColor
              borderWidth = static hdpx(1)
              borderColor = BtnBdDisabled
              padding = static hdpx(10)
              flow = FLOW_HORIZONTAL
              transform = static {}
              animations = !showHistoryAnimations.get() ? null : static [
                { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION * 6, play = true }
                { prop = AnimProp.translate, from = [sw(50), 0], to = [0, 0], delay = DEF_ANIM_DURATION * 6,
                  duration = DEF_ANIM_DURATION, play = true, easing = InOutCubic, onStart  = @() sound_play("ui_sounds/card_appear") }
              ]
              children = [
                mkTeamBlock(lastBattleResult.get())
                {
                  flow = FLOW_HORIZONTAL
                  gap = hdpx(10)
                  vplace = ALIGN_BOTTOM
                  children = nextBackCloseBtn
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
  size = static [flex(), mapSize[1]]
  flow = FLOW_HORIZONTAL
  gap = static hdpx(10)
  children = [
    function() {
      let { experienceBlock = {}, loadout = {}, openedReseachNodesV2 = [], chronotracesProgression = []
        } = lastBattleResult.get()
      let extractedItems = loadout.filter(@(v) v?.isFoundInRaid)
      let oppositeBlock = extractedItems.len() > 0 ? mkEvacuatedItems(extractedItems)
        : openedReseachNodesV2.len() > 0 || chronotracesProgression.len() > 0 ? mkChronotracesList(openedReseachNodesV2, chronotracesProgression)
        : null

      return {
        watch = lastBattleResult
        size = static [mapSize[0], flex()]
        children = mkPlayerExpBlock(experienceBlock, calc_comp_size(oppositeBlock)?[1] ?? 0)
      }
    }
    resourceAndItems
  ]
}

let tabConstr = @(locId, params) mkText(loc(locId), params.__merge( { fontFx = null }, body_txt))

let baseTab = freeze({ id = "baseDebriefing/history"
  childrenConstr = @(params) tabConstr("baseDebriefing/history", params)
  content = historyContent
})

let rewardsTab = freeze({
  id = "baseDebriefing/rewards"
  childrenConstr = @(params) tabConstr("baseDebriefing/rewards", params)
  content = rewardsContent
  isAvailableFunc = @() lastBattleResult.get()?.needRewards ?? true
  watch = lastBattleResult
  unavailableHoverHint = loc("baseDebriefing/noData")
})

let getCurTabContent = @(tabsList, tabId) tabsList.findvalue(@(v) v.id == tabId)?.content

let tabsList = [baseTab, rewardsTab]

function mkBaseDebriefingMenu() {
  let tabsWatcheds = [currentTab]
  foreach (v in tabsList.map(@(t) type(t?.watch)=="array" ? t.watch : [t?.watch])){
    if (v.len() > 0)
      tabsWatcheds.extend(v)
  }
  function playerTrackWindow() {
    let tabs = tabsList.filter(@(v) "isAvailableFunc" not in v || v?.isAvailableFunc())
    let tabsUi = mkTabs({
      tabs
      currentTab = currentTab.get()
      onChange = function(tab) {
        currentTab.set(tab.id)
        if (tab.id == "baseDebriefing/history")
          showRewardsAnimations.set(false)
        else
          showHistoryAnimations.set(false)
      }
    })
    return {
      size = FLEX_H
      flow = FLOW_VERTICAL
      watch = tabsWatcheds
      gap = hdpx(10)
      children = [
        @() {
          watch = showHistoryAnimations
          size = FLEX_H
          transform = static {}
          animations = !showHistoryAnimations.get() ? null : static [
            { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION * 2, play = true }
            { prop = AnimProp.translate, from = [-sw(50), 0], to = [0, 0], duration = DEF_ANIM_DURATION,
              delay = DEF_ANIM_DURATION * 2 play = true, easing = InOutCubic, onStart  = @() sound_play("ui_sounds/card_appear") }
          ]
          children = tabsUi
        }
        @() {
          watch = currentTab
          size = flex()
          children = getCurTabContent(tabs, currentTab.get())
        }
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
    let { battleStat = static {}, trackPoints = null, battleAreaInfo = static {} } = lastBattleResult.get()
    let headerColor = battleStat?.isSuccessRaid ? GreenSuccessColor : RedWarningColor
    let { raidName = null } = battleAreaInfo
    local text = battleStat?.isSuccessRaid ? loc("baseDebriefing/successfulRaid") : loc("baseDebriefing/unsuccessfulRaid")
    if (raidName != null) {
      let raidNameSplitet = raidName.split("+")
      let raidNameLocId = raidNameSplitet?[1] == null ? "missionInfo/unknown/short"
        : "_".join(raidNameSplitet.filter(@(v) v != "ordinary" && v != "raid"))
      text = $"{text} {loc(raidNameLocId)}"
    }
    let raidTime = (trackPoints == null || trackPoints.len() == 0) ? 0
      : trackPoints[trackPoints.len() - 1].timestamp

    return {
      watch = [lastBattleResult, showHistoryAnimations]
      size = FLEX_H
      children = [
        {
          rendObj = ROBJ_SOLID
          size = static [flex(), ph(100)]
          color = mul_color(headerColor, 0.5)
          transform = static { pivot = [0, 1] }
          animations = !showHistoryAnimations.get() ? null : static  [
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
          transform = !showHistoryAnimations.get() ? null : {}
          animations = static [
            { prop = AnimProp.opacity, from = 0, to = 0, duration = DEF_ANIM_DURATION * 2, play = true }
            { prop = AnimProp.opacity, from = 0, to = 1, delay = DEF_ANIM_DURATION * 2, onStart  = @() sound_play("ui_sounds/card_appear"),
              duration = DEF_ANIM_DURATION, play = true }
          ]
          gap = hdpx(5)
          children = [
            mkTitleString(text)
            static {size=static [flex(), 0]}
            mkTime(raidTime)
            closeXBtn
          ]
        }
      ]
    }
  }

  function updateRewards() {
    showRewardsAnimations.set(true)
    let { experienceBlock = {} } = lastBattleResult.get()
    if ((experienceBlock?.openedChronogenes.len() ?? 0) > 0) {
      levelRewards.set(experienceBlock.openedChronogenes)
      haveSeenRewards.set(false)
    }
  }

  let getContent = @() wrapInStdPanel(BaseDebriefingMenuId, @() {
    size = [flex(),  mapSize[1] + hdpx(80)]
    clipChildren = true
    onAttach = function() {
      updateRewards()
      sound_play("ui_sounds/raid_debriefing")
    }
    onDetach = function() {
      debugShowWindow.set(false)
      currentTab.set("baseDebriefing/history")
      lastBattleResult.set(null)
      showHistoryAnimations.set(true)
      showRewardsAnimations.set(false)
      if (!haveSeenRewards.get())
        showUnseenRewardsMessage()
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


showDebriefingWindow.subscribe_with_nasty_disregard_of_frp_update(function(v) {
  if (v) {
    saveBattleResultToHistory(lastBattleResult.get())
    eventbus_send("hud_menus.open", { id = BaseDebriefingMenuId })
  }
})

return {
  BaseDebriefingMenuId
  mkBaseDebriefingMenu
  resourceAndItems
  showDebriefingWindow
}
