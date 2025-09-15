from "%sqstd/string.nut" import utf8ToUpper, utf8ToLower, toIntegerSafe
from "%ui/components/colors.nut" import InfoTextDescColor, InfoTextValueColor, BtnBgDisabled, BtnBgSelected,
  BtnPrimaryBgNormal, BtnPrimaryTextNormal, BtnTextNormal, ControlBg, BtnBdSelected, BtnBdTransparent,
  BtnPrimaryBgSelected, BtnBgNormal
from "%ui/components/commonComponents.nut" import mkSelectPanelItem, mkText, mkTextWithFAIcon, VertSelectPanelGap,
  BD_LEFT, BD_CENTER, mkTooltiped, underlineComp, fontIconButton, mkTextArea
from "%ui/mainMenu/craft_common_pkg.nut" import startReplication, getRecipeMonolithUnlock, showMonolithMsgBox, setCraftsReadyCount,
  craftMsgbox, mkMonolithLinkIcon, getRecipeName, mkNotifMarkWithExclamationSign, startRecipeReplication, largeRecipeIconHeight,
  openChronotracesWindow
from "%ui/fonts_style.nut" import h2_txt, body_txt
from "%ui/components/scrollbar.nut" import makeVertScrollExt, reservedPaddingStyle, makeVertScroll
from "%ui/helpers/time.nut" import secondsToStringLoc
from "%ui/mainMenu/craftIcons.nut" import getRecipeIcon, getCraftResultItems, mkCraftResultsItems
import "%ui/components/checkbox.nut" as checkBox
import "%ui/components/faComp.nut" as faComp
from "eventbus" import eventbus_send, eventbus_subscribe_onehit, eventbus_subscribe
from "%ui/components/msgbox.nut" import showMsgbox, showMessageWithContent
from "%ui/helpers/timers.nut" import mkCountdownTimerPerSec
from "%ui/components/button.nut" import button, textButton, buttonWithGamepadHotkey
from "%ui/components/profileAnswerMsgBox.nut" import showMsgBoxResult
from "dasevents" import EventSetReplicatorData
from "%ui/components/cursors.nut" import setTooltip
from "%ui/components/accentButton.style.nut" import accentButtonStyle
from "net" import get_sync_time
import "%ui/components/tooltipBox.nut" as tooltipBox
from "%ui/mainMenu/researchNet.nut" import mkResearchNet, getRecipeProgress
import "%ui/components/colorize.nut" as colorize
from "%ui/mainMenu/currencyIcons.nut" import cronotracesIcon
from "%ui/components/textInput.nut" import textInput
from "%dngscripts/globalState.nut" import nestWatched
from "%ui/profile/profileState.nut" import allCraftRecipes, marketItems, craftTasks,
  playerBaseState, playerProfileAllResearchNodes, playerProfileOpenedNodes, playerStats
from "%ui/mainMenu/craftIcons.nut" import researchOpenedMarker
from "%ui/hud/state/onboarding_state.nut" import isOnboarding
from "%ui/mainMenu/monolith/monolith_common.nut" import monolithLevelOffers, currentMonolithLevel, MonolithMenuId,
  monolithSelectedLevel, selectedMonolithUnlock, monolithSectionToReturn, currentTab
from "%ui/state/appState.nut" import isInBattleState
from "%ui/mainMenu/craft_common_pkg.nut" import selectedPrototype, selectedPrototypeMonolithData,
  profileActionInProgress, craftsReady, onlyEarnedRecipesFilter,onlyOpenedBlueprintsFilter, selectedCategory,
  prototypeTypes, inputBlock, filterTextInput, gamepadHoveredPrototype
from "%ui/hud/menus/components/inventoryActionsHints.nut" import hoverPcHotkeysPresentation
from "%ui/components/pcHoverHotkeyHitns.nut" import hoverHotkeysWatchedList
from "%ui/hud/menus/components/inventoryItemTypes.nut" import REPLICATOR_ITEM
from "%ui/control/active_controls.nut" import isGamepad
import "%ui/components/gamepadImgByKey.nut" as gamepadImgByKey
import "%ui/mainMenu/categories/craftCategories.nut" as craftCategories
import "%ui/mainMenu/categories/marketCategories.nut" as marketCategories
from "%ui/hud/hud_menus_state.nut" import openMenu

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
from "math" import cos, PI, floor

let scrollToRecipe = Watched(null)
let showAsTree = Watched(false)

let filterBlockSize = sw(15)
let craftIconSize = [hdpxi(94), hdpxi(94)]
let notifCircleSize = hdpxi(30)
let taskIndexesList = nestWatched("taskIndexesList", [0,0,0,0])
let iconSize = static hdpx(38)
let queueIconSize = static hdpx(48)
let slotBtnHeight = static hdpx(40)
let queueBlockWidth = hdpx(77)

enum QueueStatus {
  CLOSED
  OPENED
  IN_QUEUE
  ACTIVE
  FINISHED
}

function getCronotraceIncomeInfo(templateOrId) {
  let marketLotId = toIntegerSafe(templateOrId, 0, false)
  let marketLot = marketItems.get()?[templateOrId].children.items
  let itemTemplateName = marketLotId == 0 ? templateOrId : marketLot?[0].templateName ?? ""
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(itemTemplateName)
  let data = template?.getCompValNullable("item__chronotracesProgressionInfo")?.getAll() ?? {}
  return data
}

function craftInfoBlock() {
  let recipe_id = selectedPrototype.get()
  if (!recipe_id)
    return static{ watch = selectedPrototype }

  let recipe = allCraftRecipes.get()[recipe_id]
  let isRecipeObtained = recipe?.isOpened ?? false

  let playerResearch = playerProfileOpenedNodes.get().findvalue(@(v) v.prototypeId == recipe_id)
  let allNodes = playerProfileAllResearchNodes.get()
  let node_id = allNodes.findindex(@(v) v.containsRecipe == recipe_id)
  let research = allNodes?[node_id]

  let needResearchPoints = research?.requireResearchPointsToComplete ?? -1
  let currentResearchPoints = playerResearch?.currentResearchPoints ?? 0

  let unlockResearchButton = textButton(loc("research/getRecipe"), function() {
    eventbus_send("profile_server.claim_craft_recipe", { node_id })
  })

  function mkChronogenesTitle() {
    let templateName = recipe.results?[0].reduce(@(a,v,k) a = v.len() == 0 ? k : a, "")
    let chronotraceIncome = getCronotraceIncomeInfo(templateName)
    let incomeData = [].append(chronotraceIncome?.once ?? {}, chronotraceIncome?.repeatedly ?? {})
    let hints = []
    incomeData.each(@(data)
      data.each(@(v, k) hints.append({
        locId = $"chronotraceIncome/{k}"
        value = v
      }))
    )
    return {
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      padding = static [0, hdpx(4)]
      size = FLEX_H
      gap = static hdpx(5)
      children = [
        playerResearch == null || needResearchPoints - currentResearchPoints <= 0 ? null
          : fontIconButton("plus", @(event) openChronotracesWindow(event, node_id, needResearchPoints, currentResearchPoints))
        static { size = FLEX_H }
        { flow = FLOW_HORIZONTAL gap = hdpx(10) valign = ALIGN_CENTER children = [
          static cronotracesIcon(h2_txt.fontSize*0.8),
          mkText(currentResearchPoints, h2_txt),
          static mkText("/", h2_txt),
          mkText(needResearchPoints, h2_txt)
        ]}
        static { size = FLEX_H }
        faComp("question-circle", {
          fontSize = hdpxi(28)
          color = InfoTextDescColor
          behavior = Behaviors.Button
          onHover = @(on) setTooltip(!on ? null
            : playerResearch == null
              ? loc("research/descMsgBox/closedIndependentNodeTitleDesc")
              : tooltipBox({
                  size = static [hdpx(400), SIZE_TO_CONTENT]
                  flow = FLOW_VERTICAL
                  children = [
                    mkTextArea(loc("research/descMsgBox/openedNode",
                      { neededCount = colorize(InfoTextValueColor, needResearchPoints - currentResearchPoints)
                        neededCountDiff = needResearchPoints - currentResearchPoints
                      }))
                  ].extend(hints.map(@(v) mkTextArea(loc(v.locId, { count = colorize(InfoTextValueColor, v.value )}),
                      static { color = InfoTextDescColor })))
                })
            )
        })
      ]
    }
  }

  let icon = {
    size = FLEX_H
    children = [
      getRecipeIcon(recipe_id, static [largeRecipeIconHeight, largeRecipeIconHeight],
        isRecipeObtained || needResearchPoints == 0 ? 1.0 : currentResearchPoints.tofloat() / needResearchPoints,
        isRecipeObtained ? "full" : "silhouette")
      !isRecipeObtained ? {
        rendObj = ROBJ_BOX
        borderWidth = static [hdpx(1), 0, hdpx(1), 0]
        fillColor = Color(20, 20, 20, 200)
        margin = static [0, 0, hdpx(20), 0]
        size = FLEX_H
        padding = hdpx(10)
        gap = hdpx(10)
        vplace = ALIGN_BOTTOM
        hplace = ALIGN_CENTER
        valign = ALIGN_CENTER
        halign = ALIGN_CENTER
        flow = FLOW_VERTICAL
        children = [
          mkChronogenesTitle()
          playerResearch == null ? mkText(utf8ToUpper(loc("research/blocked")), body_txt) : null
          needResearchPoints <= currentResearchPoints ? unlockResearchButton : null
        ]
      } : null
    ]
  }

  let infoText = @(text1, text2) underlineComp({
    flow = FLOW_HORIZONTAL
    size = FLEX_H
    gap = hdpx(4)
    children = [ text1, text2 ]
  })

  let recipeName = infoText(mkText(loc("research/craftRecipe"), { color = InfoTextDescColor }),
    mkText(loc(getRecipeName(recipe)), {
      size = FLEX_H
      behavior = Behaviors.Marquee
      color = InfoTextValueColor
      speed = hdpx(50)
    }))

  let normalCraftTime = infoText(mkText(loc("research/craftTime"), {color = InfoTextDescColor}),
    mkText($"{secondsToStringLoc(recipe.craftTime)}", {color = InfoTextValueColor}))
  let craftResultItems = getCraftResultItems(recipe.results)

  let results = {
    size = flex()
    gap = hdpx(8)
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    children = [
      mkText(loc("craft/extractionResult"), {color = InfoTextDescColor})
      makeVertScroll(mkCraftResultsItems(craftResultItems))
    ]
  }

  return {
    watch = [selectedPrototype, playerProfileOpenedNodes, playerProfileAllResearchNodes, allCraftRecipes]
    rendObj = ROBJ_SOLID
    size = static [hdpx(400), flex()]
    color = ControlBg
    padding = static hdpx(10)
    flow = FLOW_VERTICAL
    gap = static hdpx(20)
    clipChildren = true
    children = [
      icon
      {
        size = FLEX_H
        flow = FLOW_VERTICAL
        gap = hdpx(4)
        clipChildren = true
        children = [
          recipeName
          normalCraftTime
        ]
      }
      results
    ]
  }
}

let noRecipesFoundMsg = static {
  size = static [ flex(), sh(20) ]
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = mkText(loc("craft/noRecipesFoundByFiltering"), h2_txt)
}

let mkProgressBar = @(craftTime, timeLeftWatched) @() {
  watch = timeLeftWatched
  rendObj = ROBJ_SOLID
  size = flex()
  color = BtnBgSelected
  margin = static [hdpx(1), 0]
  transform = {
    scale = [(craftTime - timeLeftWatched.get()).tofloat() / craftTime, 1.0]
    pivot = [0.0, 0.5]
  }
}

let timeLeftToString = @(timeLeft) timeLeft > 0 ? secondsToStringLoc(timeLeft) : loc("craft/done")

let craftDoneAnim = static [{ prop = AnimProp.fillColor, from = BtnPrimaryBgNormal, to = mul_color(BtnPrimaryBgNormal, 0.6),
  duration = 3.0, loop = true, play = true, easing = CosineFull }]

let craftActiveAnim = static [{ prop = AnimProp.borderColor, from = BtnBdSelected, to = BtnBdTransparent,
  duration = 1.5, loop = true, play = true, easing = CosineFull }]

function focusMonolithLevel(idx, isQueue = false, isFeatured = false) {
  let levelsToFocus = []
  let offerName = isQueue ? "ReplicatorQueue" : "ReplicatorDevice"
  foreach (id, item in marketItems.get()) {
    if (item?.offerName.contains(offerName)
      && !playerStats.get().purchasedUniqueMarketOffers.contains(id.tointeger())
      && item?.isPermanent == isFeatured
    )
      levelsToFocus.append(item)
  }

  if (levelsToFocus.len() > 0) {
    let res = levelsToFocus.sort(@(a, b) a.requirements.monolithAccessLevel
      <=> b.requirements.monolithAccessLevel)
    monolithSelectedLevel.set(isFeatured ? 0 : res[0].requirements.monolithAccessLevel)
    selectedMonolithUnlock.set(res[0].children.baseUpgrades[0])
    monolithSectionToReturn.set("craftWindow")
    currentTab.set("monolithLevelId")
    openMenu(MonolithMenuId)
  }
  else
    craftMsgbox(loc("craft/slotUnavailableMsg", { number = idx + 1 }))
}

function mkCraftSlot(slot, idx, countdown, isFeatured) {
  let { status, processingIdx = 0, tasksList = [] } = slot
  let task = tasksList?[processingIdx]
  let { craftRecipeId = null, startedBroken = false } = task
  let isProcessing = status == "processing"
  let isClosed = status == "unavailable"
  let canStart = !isClosed && !isProcessing
  let hasCountDown = Computed(@() isProcessing && countdown.get() != 0)
  let needAnim = Computed(@() !isClosed && isProcessing && !hasCountDown.get())
  let canClaimAll = Computed(@() isProcessing && !hasCountDown.get() && taskIndexesList.get()[idx] >= 1)
  return function() {
    if (isProcessing && !hasCountDown.get() && !profileActionInProgress.get()) {
      let nextIdx = processingIdx + 1
      if (tasksList?[nextIdx] != null)
        taskIndexesList.mutate(@(v) v[idx] += 1)
    }
    let recipe = allCraftRecipes.get()?[craftRecipeId]
    let craftTime = startedBroken ? recipe?.brokenCraftTime : recipe?.craftTime
    let isAccent = needAnim.get() ? true
      : canStart || (!isClosed && countdown.get() == 0)
    let textColor = isAccent ? BtnPrimaryTextNormal : null
    setCraftsReadyCount()
    return {
      watch = [profileActionInProgress, allCraftRecipes, hasCountDown, needAnim, canClaimAll]
      size = FLEX_H
      children = button(
        {
          size = flex()
          children = [
            {
              size = flex()
              flow = FLOW_HORIZONTAL
              children = [
                canClaimAll.get() || !isProcessing || recipe == null ? null
                  : getRecipeIcon(craftRecipeId, [iconSize, iconSize], 1, "full")
                    .__update(static { padding = [0,0,0,hdpx(1)] })
                isProcessing && hasCountDown.get() ? mkProgressBar(craftTime, countdown) : null
              ]
            }
            {
              size = [pw(75), flex()]
              flow = FLOW_VERTICAL
              halign = ALIGN_CENTER
              hplace = ALIGN_CENTER
              valign = ALIGN_CENTER
              gap = static hdpx(-4)
              clipChildren = true
              children = canClaimAll.get()
                ? mkText(loc("craft/claimAll", { number = idx + 1 }))
                : [
                    function() {
                      let textToShow = canStart ? loc("craft/startReplication", { number = idx + 1 })
                        : isProcessing ? timeLeftToString(countdown?.get())
                        : loc("craft/slotUnavailableBtnText", { number = idx + 1 })
                      return {
                        watch = [countdown, taskIndexesList]
                        children = mkText(textToShow, {
                          color = textColor
                          fontSize = static hdpx(16)
                          fontFxColor = static Color(0,0,0,30)
                        })
                      }
                    }
                    isProcessing ? mkText(loc(getRecipeName(recipe)), {
                      size = FLEX_H
                      behavior = Behaviors.Marquee
                      scrollOnHover = false
                      color = textColor
                      fontSize = hdpx(16)
                      halign = ALIGN_CENTER
                      speed = hdpx(50)
                      fontFxColor = static Color(0,0,0,30)
                    }) : null
                  ]
            }
          ]
        },
        function() {
          if (isClosed) {
            focusMonolithLevel(idx, false, isFeatured)
            return
          }
          else if (isProcessing && !hasCountDown.get()) {
            profileActionInProgress.set(true)
            let taskIds = tasksList.reduce(@(res, v)
              v.craftCompleteAt <= get_sync_time() ? res.append(v.taskId_int64) : res, [])
            let idsString = ",".join(taskIds)
            profileActionInProgress.set(true)
            taskIndexesList.mutate(@(v) v[idx] = 0)
            eventbus_send("profile_server.complete_craft_tasks", taskIds)
            eventbus_subscribe($"profile_server.complete_craft_tasks.result#{idsString}", function(result) {
              showMsgBoxResult(loc("craft/resultReceived"), result)
              profileActionInProgress.set(false)
              setCraftsReadyCount()
            })
          }
          else if (isProcessing && tasksList.len() >= (
              (playerBaseState.get()?.replicatorDeviceQueueSize.x ?? 0) + (playerBaseState.get()?.replicatorDeviceQueueSize.y ?? 0))) {
            craftMsgbox(loc("craft/moduleAndQueueInProgress", { number = idx + 1 }))
            return
          }
          else
            startReplication(idx)
        },
        {
          size = static [flex(), slotBtnHeight]
          animations = needAnim.get() ? craftDoneAnim : null
          key = $"{idx}_{needAnim.get()}"
          style = {
            BtnBgNormal = isClosed
              ? (isFeatured ? Color(135, 115, 70) : BtnBgDisabled)
              : (isFeatured ? Color(170, 123, 0) : BtnBgNormal)
          }
          isEnabled = !profileActionInProgress.get()
        }.__update(isAccent ? accentButtonStyle : {})
      )
    }
  }
}

let mkQueueIcon = @(icon, color = InfoTextValueColor, override = {}) faComp(icon, {
  fontSize = static hdpx(18)
  padding = static [-hdpx(1), hdpx(1)]
  color
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
}.__merge(override))

function mkQueuSlot(slot, moduleIdx, queueIdx, queueStatus, countdown) {
  let { status, task = null, isFeatured = false } = slot
  let { craftRecipeId = null, startedBroken = false, taskId_int64 = 0, craftCompleteAt = 0 } = task
  return function() {
    let isClosed = status == "unavailable" || queueStatus.get() == QueueStatus.CLOSED
    let isInQueue = queueStatus.get() == QueueStatus.IN_QUEUE
    let isActive = queueStatus.get() == QueueStatus.ACTIVE
    let canClaim = queueStatus.get() == QueueStatus.FINISHED
    let recipe = allCraftRecipes.get()?[craftRecipeId]
    let craftTime = startedBroken ? recipe?.brokenCraftTime : recipe?.craftTime
    setCraftsReadyCount()
    local content = null
    if (isClosed)
      content = mkQueueIcon("lock")
    else if (isActive || isInQueue) {
      content = function() {
        let progress = isActive && craftTime != null && craftTime > 0 ? (craftTime - countdown.get()).tofloat() / craftTime : 0
        return {
          watch = countdown
          size = flex()
          hplace = ALIGN_CENTER
          vplace = ALIGN_CENTER
          children = [
            getRecipeIcon(craftRecipeId, [queueIconSize, queueIconSize], progress, "full", [queueBlockWidth, queueBlockWidth])
            mkQueueIcon("close", InfoTextValueColor, { hplace = ALIGN_RIGHT, vplace = ALIGN_TOP })
          ]
        }
      }
    }
    else if (canClaim)
      content = getRecipeIcon(craftRecipeId, [queueIconSize, queueIconSize], 1, "full", [queueBlockWidth, queueBlockWidth])
    else
      content = mkQueueIcon("plus")
    return {
      watch = [profileActionInProgress, queueStatus]
      size = static [flex(), slotBtnHeight]
      children = button(
        content,
        function() {
          if (isClosed) {
            focusMonolithLevel(moduleIdx, queueIdx != 0, isFeatured)
            return
          }
          if (isInQueue || isActive) {
            if (isActive)
            showMessageWithContent({
                content = {
                  flow = FLOW_VERTICAL
                  gap = hdpx(10)
                  halign = ALIGN_CENTER
                  children = [
                    mkText(loc("craft/deleteQueueRecipe"), h2_txt)
                    mkText(loc(getRecipeName(recipe), body_txt))
                    getRecipeIcon(craftRecipeId, static [largeRecipeIconHeight, largeRecipeIconHeight], 1, "full")
                  ]
                }
                buttons = [
                  {
                    text = loc("Yes")
                    action = function() {
                      if ((craftCompleteAt - get_sync_time() - 0.5) <= 0) {
                        showMsgbox({ text = loc("craft/craftIsAlreadyDone") })
                        return
                      }
                      profileActionInProgress.set(true)
                      eventbus_send("profile_server.remove_craft_tasks", [taskId_int64])
                    }
                    isCurrent = true
                  },
                  {
                    text = loc("No")
                    isCancel = true
                  }
                ]
              })
            else {
              profileActionInProgress.set(true)
              eventbus_send("profile_server.remove_craft_tasks", [taskId_int64])
            }
            eventbus_subscribe_onehit($"profile_server.remove_craft_tasks.result",
              @(_v) profileActionInProgress.set(false))
            return
          }
          else if (canClaim) {
            profileActionInProgress.set(true)
            eventbus_subscribe_onehit($"profile_server.complete_craft_tasks.result#{taskId_int64}", function(result) {
              showMsgBoxResult(loc("craft/resultReceived"), result)
              profileActionInProgress.set(false)
              setCraftsReadyCount()
              taskIndexesList.mutate(@(v) v[moduleIdx] = max(v[moduleIdx] - 1, 0))
            })
            eventbus_send("profile_server.complete_craft_tasks", [taskId_int64])
          }
          else
            startReplication(moduleIdx)
        },
        {
          size = static flex()
          key = $"queue_{queueStatus.get()}"
          padding = static hdpx(1)
          style = { BtnBgNormal = isClosed
            ? (isFeatured ? Color(135, 115, 70) : BtnBgDisabled)
            : (isFeatured ? Color(170, 123, 0) : BtnBgNormal)
          }
          animations = canClaim ? craftDoneAnim
            : isActive ? craftActiveAnim
            : null
          tooltipText = isClosed ? (isFeatured ? loc("craft/featuredQueueClosed") : loc("craft/queueClosed"))
            : isInQueue || isActive ? loc("craft/deleteFromQueue", { name = colorize(InfoTextValueColor, loc(getRecipeName(recipe))) })
            : canClaim ? loc("craft/claimCraft", { name = colorize(InfoTextValueColor, loc(getRecipeName(recipe))) })
            : function() {
              if (allCraftRecipes.get()?[selectedPrototype.get()] == null)
                return loc("craft/itemNotSelected")
              else
                return  loc("craft/setQueue", { name = colorize(InfoTextValueColor, loc(getRecipeName(allCraftRecipes.get()[selectedPrototype.get()]))) })
            }
          isEnabled = !profileActionInProgress.get()
        }.__update(canClaim ? accentButtonStyle : {})
      )
    }
  }
}

function isQueueFeatured(status, index, openedCommonQueues, openedFeaturedQueues, maxCommonQueues) {
  if (status == "unavailable")
    return index > maxCommonQueues

  if (openedCommonQueues == 0 && openedFeaturedQueues == 0)
    return index > maxCommonQueues

  if (index <= openedCommonQueues)
    return false

  if (index <= openedCommonQueues + openedFeaturedQueues)
    return true

  let closedCommon = maxCommonQueues - openedCommonQueues

  if (index <= openedCommonQueues + openedFeaturedQueues + closedCommon)
    return false

  return true
}

function mkCraftSlots() {
  let mkCraftQueueBlock = @(slot, moduleIdx, countdown) function() {
    let { maxReplicatorDeviceQueueSize = {}, replicatorDeviceQueueSize = {} } = playerBaseState.get() ?? {}
    let maxCommonQueues = maxReplicatorDeviceQueueSize?.x ?? 0
    let maxFeaturedQueues = maxReplicatorDeviceQueueSize?.y ?? 0
    let openedCommonQueues = replicatorDeviceQueueSize?.x ?? 0
    let openedFeaturedQueues = replicatorDeviceQueueSize?.y ?? 0
    let slotsCount = maxCommonQueues + maxFeaturedQueues + 1
    let { status, tasksList = array(slotsCount), processingIdx = -1 } = slot
    let tasksToShow = array(slotsCount).map(@(_, i) i < tasksList.len() ? tasksList[i] : null)
    let result = tasksToShow.sort(@(a, b) (b?.craftCompleteAt != null) <=> (a?.craftCompleteAt != null)
      || (a?.craftCompleteAt ?? -1) <=> (b?.craftCompleteAt ?? -1))

    return {
      watch = playerBaseState
      size = FLEX_H
      flow = FLOW_HORIZONTAL
      gap = static hdpx(4)
      children = result.map(function(task, index) {
        let isFeatured = isQueueFeatured(status, index, openedCommonQueues, openedFeaturedQueues, maxCommonQueues)
        let queueStatus = Computed(function() {
          let openedQueueCount = openedCommonQueues + openedFeaturedQueues
          return status == "unavailable" || index > openedQueueCount ? QueueStatus.CLOSED
            : status == "empty" || (status == "processing" && task == null) ? QueueStatus.OPENED
            : status == "processing" && index > processingIdx && task != null ? QueueStatus.IN_QUEUE
            : status == "processing" && index == processingIdx && countdown.get() > 0 ? QueueStatus.ACTIVE
            : QueueStatus.FINISHED
        })
        return mkQueuSlot({ status, task, isFeatured }, moduleIdx, index, queueStatus, countdown)
      })
    }
  }

  return function() {
    if (isOnboarding.get())
      return static { watch = isOnboarding }
    let { maxReplicatorDevices = 0 } = playerBaseState.get()
    return {
      watch = [playerBaseState, isOnboarding]
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap = hdpx(20)
      children = array(maxReplicatorDevices).map(function(_v, moduleIdx) {
        let craftDataByIdx = Computed(function() {
          let openedModulesCount = playerBaseState.get()?.openedReplicatorDevices ?? -1
          if (moduleIdx >= openedModulesCount)
            return static { status = "unavailable" }
          else {
            local res = { status = "empty" }
            let tasksList = craftTasks.get().filter(@(v) v?.replicatorSlotIdx == moduleIdx)
            if (tasksList.len() > 0)
              res = {
                status = "processing"
                tasksList
                processingIdx = taskIndexesList.get()[moduleIdx]
              }
            return res
          }
        })
        return function() {
          let { status, processingIdx = 0, tasksList = [] } = craftDataByIdx.get()
          let task = tasksList?[processingIdx]
          let { craftCompleteAt = 0 } = task
          let countdown = status == "processing" ? mkCountdownTimerPerSec(Watched(craftCompleteAt), $"{moduleIdx}")
            : Watched(0)
          return {
            watch = craftDataByIdx
            size = FLEX_H
            flow = FLOW_VERTICAL
            gap = hdpx(4)
            children = [
              mkCraftSlot(craftDataByIdx.get(), moduleIdx, countdown, moduleIdx == (maxReplicatorDevices - 1)),
              {
                size = FLEX_H
                flow = FLOW_HORIZONTAL
                gap = static hdpx(10)
                children = mkCraftQueueBlock(craftDataByIdx.get(), moduleIdx, countdown)
              }
            ]
          }
        }
      })
    }
  }
}

let mkStartReplicationHotkey = @(itemPrototype) function() {
  if (!isGamepad.get() || itemPrototype != gamepadHoveredPrototype.get())
    return { watch = [isGamepad, gamepadHoveredPrototype] }
  return {
    watch = [isGamepad, gamepadHoveredPrototype]
    vplace = ALIGN_CENTER
    children = gamepadImgByKey.mkImageCompByDargKey("J:X")
  }
}

function mkCraftSelection() {
  function mkRecipeButton(prototype_id) {
    let node_id = Computed(function() {
      let allNodes = playerProfileAllResearchNodes.get()
      return allNodes.findindex(@(v) v.containsRecipe == prototype_id)
    })
    let playerResearch = Computed(@() playerProfileOpenedNodes.get().findvalue(@(v) v.prototypeId == node_id.get()))
    return function() {
      let recipe = allCraftRecipes.get()[prototype_id]
      let isRecipeObtained = recipe?.isOpened ?? false
      let locked = playerResearch.get() == null
      let research = playerProfileAllResearchNodes.get()?[node_id.get()]
      let progress = isRecipeObtained
        ? 1.0
        : getRecipeProgress(playerResearch.get()?.currentResearchPoints, research?.requireResearchPointsToComplete)

      let icon = getRecipeIcon(prototype_id, craftIconSize, progress, isRecipeObtained ? "full" : "silhouette")
      let name = getRecipeName(recipe)
      let monolithUnlockData = !locked ? null
        : getRecipeMonolithUnlock(prototype_id, name, marketItems.get(), monolithLevelOffers.get(),
            playerStats.get(), currentMonolithLevel.get())
      let recipeName = mkText(loc(name), {
        size = FLEX_H
        behavior = Behaviors.Marquee
        halign = ALIGN_CENTER
        delay = 1
        speed = static hdpx(50)
      })

      let broken = recipe.craftsUntilBroke != 0 && ((recipe ? recipe.craftsUntilBroke : 1) <= 0)

      let iconAndName = {
        size = static flex()
        halign = ALIGN_CENTER
        flow = FLOW_VERTICAL
        gap = static hdpx(4)
        valign = ALIGN_CENTER
        children = [
          {
            children = [
              icon,
              playerResearch.get() != null && progress < 1.0 ? researchOpenedMarker : null
            ]
          }
          recipeName
        ]
      }

      let statusIcon = {
        hplace = ALIGN_RIGHT
        children = locked
          ? static faComp("lock")
          : broken ? mkTooltiped(faComp("chain-broken"), tooltipBox(mkText(loc("craft/brokenTooltip")))) : null
      }

      let monolithLinkIcon = monolithUnlockData == null ? null
        : mkMonolithLinkIcon(monolithUnlockData, @() showMonolithMsgBox(monolithUnlockData))
      return {
        watch = [playerResearch, allCraftRecipes, node_id, marketItems, monolithLevelOffers,
          playerProfileAllResearchNodes, playerStats, currentMonolithLevel]
        size = flex()
        children = mkSelectPanelItem({
          children = {
            padding = hdpx(10)
            size = flex()
            children = [
              statusIcon
              progress == 1 && !isRecipeObtained ? mkNotifMarkWithExclamationSign(notifCircleSize) : null
              monolithLinkIcon
              iconAndName
              mkStartReplicationHotkey(prototype_id)
            ]
          },
          state = selectedPrototype,
          onSelect = function(selPrototype) {
            selectedPrototypeMonolithData.set(monolithUnlockData)
            selectedPrototype.set(selPrototype)
          }
          idx = prototype_id,
          visual_params = {
            size = flex()
            padding = 0
            key = prototype_id
            hotkeys = [["J:X", { action = @(event) startRecipeReplication(event),
              description = loc("item/action/startFastestReplication") }]]
            xmbNode = XmbNode()
            border_align = BD_CENTER
          }
          onlySelectedBd = true
          onHover = function(on) {
            if (!on) {
              hoverHotkeysWatchedList.set(null)
              if (isGamepad.get()) {
                gamepadHoveredPrototype.set(null)
                selectedPrototypeMonolithData.set(null)
              }
              return
            }
            let pcHotkeysHints = hoverPcHotkeysPresentation[REPLICATOR_ITEM.name](prototype_id)
            hoverHotkeysWatchedList.set(pcHotkeysHints)
            if (isGamepad.get()) {
              gamepadHoveredPrototype.set(prototype_id)
              selectedPrototypeMonolithData.set(monolithUnlockData)
            }
          }
          onDoubleClick = @(event) startRecipeReplication(event)
          sound = {
            click  = locked ? "ui_sounds/button_inactive" : "ui_sounds/button_click"
            hover  = "ui_sounds/button_highlight"
            active = null
          }
        })
      }
    }
  }

  let filteredRecipes = Computed(function() {
    let recipes = []
    let openedNodes = []
    let unavailableRecipes = []
    let selectedCat = selectedCategory.get()
    let protoTypes = prototypeTypes.get()
    let allCraftRecipesV = allCraftRecipes.get()
    let playerProfileAllResearchNodesV = playerProfileAllResearchNodes.get()
    let allRecipes = allCraftRecipesV.filter(@(_v, k) k in playerProfileAllResearchNodesV)
    let data = selectedCat == null ? allRecipes : allRecipes.filter(@(prototype)
      prototype.results.findindex(function(v) {
        let rType = protoTypes?[v.keys()[0]]
        return selectedCat == rType
      }) != null)

    let openedRecipes = allCraftRecipesV.filter(@(v) v?.isOpened)
    let openedNodesData = playerProfileOpenedNodes.get()
    let earned = onlyEarnedRecipesFilter.get()
    let openedFilter = onlyOpenedBlueprintsFilter.get()

    foreach (proto_id, recipeData in data) {
      if (filterTextInput.get() != ""
        && !utf8ToLower(loc(getRecipeName(recipeData))).contains(utf8ToLower(filterTextInput.get()))
      )
        continue

      let playerResearch = openedNodesData.findvalue(@(v) v.prototypeId == proto_id)
      let recipeRecived = proto_id in openedRecipes
      if (recipeRecived)
        recipes.append(proto_id)
      else if (playerResearch)
        openedNodes.append(proto_id)
      else
        unavailableRecipes.append(proto_id)
    }

    let fullyProgressedAndObtainedNodes = []
    let fullyProgressedNodes = []
    let justOpenedNodes = []
    foreach (pid in openedNodes){
      let recipe = allCraftRecipesV[pid]
      let isRecipeObtained = recipe?.isOpened ?? false
      let node_id = playerProfileAllResearchNodesV.findindex(@(v) v.containsRecipe == pid)
      let presearch = openedNodesData.findvalue(@(v) v.prototypeId == node_id)
      let progress = isRecipeObtained
        ? 1.0
        : getRecipeProgress(presearch?.currentResearchPoints, playerProfileAllResearchNodesV?[pid].requireResearchPointsToComplete)
      if (progress == 1 && isRecipeObtained)
        fullyProgressedAndObtainedNodes.append(pid)
      else if (progress == 1 && !isRecipeObtained)
        fullyProgressedNodes.append(pid)
      else
        justOpenedNodes.append(pid)
    }

    return earned && openedFilter
      ? recipes.extend(openedNodes)
      : earned
        ? recipes
        : openedFilter
          ? openedNodes
          : recipes.extend(fullyProgressedAndObtainedNodes, fullyProgressedNodes, justOpenedNodes, unavailableRecipes)
  })

  function getRecipes(recipes) {
    if (recipes.len() == 0)
      return noRecipesFoundMsg
    let itemsPerLine = 4
    local it = 0
    function getLine() {
      if (it >= recipes.len())
        return { size=flex() }

      let children = []
      for (local i = it; i < it + itemsPerLine; i++) {
        children.append(recipes?[i] ? mkRecipeButton(recipes[i]) : static { size=flex() })
      }
      it+=itemsPerLine
      return children
    }
    let tiled = [].resize(recipes.len() / itemsPerLine + 1)
    tiled.apply(@(_v){
      flow = FLOW_HORIZONTAL
      size = static [flex(), hdpx(150)]
      gap = static hdpx(5)
      children = getLine()
    })

    return tiled
  }
  let scrollHandler = ScrollHandler()
  let craftList = @() {
    watch = [selectedCategory, allCraftRecipes, onlyEarnedRecipesFilter, playerStats, onlyEarnedRecipesFilter,
      playerProfileAllResearchNodes, playerProfileOpenedNodes, onlyOpenedBlueprintsFilter]
    rendObj = ROBJ_SOLID
    size = flex()
    color = ControlBg
    xmbNode = XmbContainer({
      canFocus = false
      scrollSpeed = 5.0
      isViewport = true
      scrollToEdge = true
    })
    children = makeVertScrollExt(@() {
      watch = filteredRecipes
      size = FLEX_H
      gap = static hdpx(5)
      flow = FLOW_VERTICAL
      onAttach = function() {
        if (scrollToRecipe.get() == null)
          return
        let recipeIdx = filteredRecipes.get().findindex(@(v) v == scrollToRecipe.get())
        if (recipeIdx == null)
          return
        let line = floor(recipeIdx / 4.0)
        scrollHandler.scrollToY(line * hdpx(150) + (line - 1) * hdpx(5))
      }
      children = getRecipes(filteredRecipes.get())
    }, {
      styling = reservedPaddingStyle
      scrollHandler
    })
  }

  let categoryBtnParams = {
    state = selectedCategory
    visual_params = static {
      padding = hdpx(15)
      size = static [flex(), hdpx(50)]
      halign = ALIGN_LEFT
      valign = ALIGN_CENTER
    }
    border_align = BD_LEFT
  }
  let allCat = mkSelectPanelItem({children = static mkTextWithFAIcon("circle-o", loc($"marketCategory/All")),  idx=null}.__update(categoryBtnParams))

  function GetCategoriesButtons() {
    let buttons = []
    buttons.append(allCat)

    let filterTypes = prototypeTypes.get()
      .reduce(@ (res, val) !res.contains(val) ? res.append(val) : res, [])
      .sort(@(a, b) marketCategories[a]?.idx <=> marketCategories[b]?.idx)
    for (local i = 0; i < filterTypes.len(); i++) {
      let typeIcon = craftCategories?[filterTypes[i]].icon != null
        ? $"itemFilter/{craftCategories[filterTypes[i]].icon}.svg"
        : craftCategories?[filterTypes[i]].faIcon
      if (!typeIcon)
        continue
      let panel = mkSelectPanelItem({
        children = mkTextWithFAIcon(typeIcon, loc($"marketCategory/{filterTypes[i]}")),
        idx = filterTypes[i]}.__update(categoryBtnParams))
      buttons.append(panel)
    }
    return buttons
  }

  let showRecipesAsTree = checkBox(showAsTree, mkTextArea(loc("craft/showAsTree")), {
    hotkeys = [["J:RS", { description = { skip = true } }]]
    override = {
      size = FLEX_H
      padding = static [0, hdpx(5)]
    }})

  let earnedRecipesFilter = checkBox(onlyEarnedRecipesFilter, mkTextArea(loc("craft/filter/onlyEarnedRecipes")),
    { override = {
      size = FLEX_H
      padding = static [0,0,0, hdpx(5)]
    }})

  let earnedBlueprintsFilter = checkBox(onlyOpenedBlueprintsFilter, mkTextArea(loc("craft/filter/onlyOpenedRecipes")),
    { override = {
      size = FLEX_H
      padding = static [0,0,0, hdpx(5)]
      isInteractive = !onlyEarnedRecipesFilter.get()
    }})

  let filters = @() {
    watch = prototypeTypes
    rendObj = ROBJ_SOLID
    size = [ filterBlockSize, flex() ]
    color = ControlBg
    children = [
      {
        size = flex()
        flow = FLOW_VERTICAL
        gap = VertSelectPanelGap
        children = [inputBlock, showRecipesAsTree, earnedRecipesFilter, earnedBlueprintsFilter].extend(GetCategoriesButtons())
      }
    ]
  }

  let wndContent = @() {
    watch = showAsTree
    size = flex()
    flow = FLOW_HORIZONTAL
    gap = hdpx(10)
    padding = static [hdpx(10), hdpx(11)]
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER

    children = [
      {
        size = FLEX_V
        flow = FLOW_VERTICAL
        gap = hdpx(10)
        children = [
          {
            size = static [hdpx(400), SIZE_TO_CONTENT]
            children = mkCraftSlots()
          }
          craftInfoBlock
        ]
      },
      showAsTree.get() ? mkResearchNet() : craftList,
      filters
    ]
  }

  return {
    size = flex()
    children = wndContent
  }
}


function updateReplicatorInWorld() {
  if (isInBattleState.get())
    return
  let openedReplicators = playerBaseState.get()?.openedReplicatorDevices ?? 0
  let sortedTasks = [].resize(openedReplicators, [])
  foreach (task in craftTasks.get()) {
    
    
    if (sortedTasks?[task.replicatorSlotIdx])
      sortedTasks[task.replicatorSlotIdx] = task
  }

  for(local i=0; i < sortedTasks.len(); i++){
    let task = sortedTasks[i]
    let recipe = allCraftRecipes.get()?[task?.craftRecipeId]
    let craftTime = task?.startedBroken ? recipe?.brokenCraftTime : recipe?.craftTime

    ecs.g_entity_mgr.broadcastEvent(EventSetReplicatorData({
      replicatorIdx = i
      replicatorDoneAt = task?.craftCompleteAt ?? 0
      replicatorTime = craftTime ?? 0
      replicatorIsEmpty = task?.craftCompleteAt == null
    }))
  }
}

playerBaseState.subscribe(@(_) updateReplicatorInWorld())
craftTasks.subscribe(@(_) updateReplicatorInWorld())
allCraftRecipes.subscribe(@(_) updateReplicatorInWorld())
updateReplicatorInWorld()

return freeze({
  getRecipeName
  craftsReady
  selectedPrototype
  selectedCategory
  mkCraftSelection
  scrollToRecipe
})
