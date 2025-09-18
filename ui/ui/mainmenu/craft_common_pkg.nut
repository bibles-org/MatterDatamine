from "%dngscripts/sound_system.nut" import sound_play
from "%ui/fonts_style.nut" import h2_txt, body_txt
from "%ui/components/colors.nut" import BtnTextNormal, RedWarningColor, GreenSuccessColor, NotificationBg,
  TextHighlight, TextNormal, BtnBgFocused, ControlBgOpaque, BtnBgDisabled, InfoTextValueColor
from "%ui/components/commonComponents.nut" import mkText, fontIconButton, mkTextArea
from "%ui/components/msgbox.nut" import showMsgbox, showMessageWithContent
from "dasevents" import CmdShowUiMenu
from "%ui/mainMenu/currencyIcons.nut" import monolithTokensColor
from "%ui/popup/player_event_log.nut" import addPlayerLog, mkPlayerLog
from "%ui/components/itemIconComponent.nut" import itemIconNoBorder
from "eventbus" import eventbus_send, eventbus_subscribe_onehit
from "%ui/mainMenu/craftIcons.nut" import getRecipeIcon, mkCraftResultsItems, getCraftResultItems
from "net" import get_sync_time
from "%ui/mainMenu/craftScreenState.nut" import craftScreens
from "dagor.debug" import logerr
from "%ui/components/button.nut" import button, textButton
from "%ui/components/modalWindows.nut" import addModalWindow, removeModalWindow
from "%ui/components/cursors.nut" import setTooltip
from "%ui/components/textInput.nut" import textInput
from "%ui/mainMenu/currencyIcons.nut" import monolithTokensTextIcon, monolithTokensColor
from "%ui/components/slider.nut" import Horiz
from "%ui/mainMenu/stdPanel.nut" import mkCloseStyleBtn
import "%ui/components/colorize.nut" as colorize
import "%ui/components/faComp.nut" as faComp
from "%ui/components/mkLightBox.nut" import mkLightBox
from "%sqstd/string.nut" import toIntegerSafe
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { playerProfileMonolithTokensCount, craftTasks, playerBaseState, allCraftRecipes, marketItems,
  playerProfileOpenedNodes, playerProfileChronotracesCount, playerProfileAllResearchNodes
} = require("%ui/profile/profileState.nut")
let { MonolithMenuId, monolithSelectedLevel, selectedMonolithUnlock, currentMonolithLevel, currentTab
} = require("%ui/mainMenu/monolith/monolith_common.nut")
let { playerLogsColors } = require("%ui/popup/player_event_log.nut")
let { currencyPanel } = require("%ui/mainMenu/currencyPanel.nut")
let { craftScreenState } = require("%ui/mainMenu/craftScreenState.nut")

let selectedPrototype = Watched(null)
let gamepadHoveredPrototype = Watched(null)
let prototypeToReplicate = Computed(@() gamepadHoveredPrototype.get() ?? selectedPrototype.get())
let selectedPrototypeMonolithData = Watched(null)
let profileActionInProgress = Watched(false)
let craftsReady = Watched(0)
let onlyEarnedRecipesFilter = Watched(false)
let onlyOpenedBlueprintsFilter = Watched(false)
let selectedCategory = Watched(null)
let filterTextInput = Watched("")

const CHRONOTRACE_UID_WND = "chronotracesWnd"

let largeRecipeIconHeight = hdpxi(193)
let chronotracesWndSize = static [hdpx(400), hdpx(182)]

function getRequirementsMonolithData(data, playerStats, monolithLevels, curMonolithLevel) {
  let { requirements = {} } = data
  let { stats = {}, unlocks = [], monolithAccessLevel = 0 } = requirements
  if (stats.len() <= 0 && unlocks.len() <= 0 && monolithAccessLevel <= 0)
    return []
  let plStat = playerStats?.statsCurrentSeason ?? {}
  let statsRes = []
  foreach (k1, v1 in stats) {
    let inner = plStat?[k1] ?? {}
    foreach (k2, v2 in v1) {
      let cur = inner?[k2] ?? 0
      let needed = v2
      let color = cur >= needed ? GreenSuccessColor : RedWarningColor
      statsRes.append(mkText(loc($"monolith/{k1}/{k2}", { cur, needed }), { color }.__update(body_txt)))
    }
  }

  let unlockStrings = unlocks.map(function(v) {
    let color = playerStats.unlocks.contains(v) ? GreenSuccessColor : RedWarningColor
    return mkText(loc($"stats/{v}"), { color }.__update(body_txt))
  })

  let requireAccessLevelStrings = curMonolithLevel >= monolithAccessLevel ? null
    : mkText(loc($"monolith/level" { level = loc(monolithLevels?[monolithAccessLevel - 1].offerName) }),
        { color = RedWarningColor }.__update(body_txt))

  let res = [requireAccessLevelStrings].extend(
    unlockStrings
    statsRes
    ).filter(@(v) v != null)
  if (res.len() <= 0)
    return res
  res.insert(0, mkTextArea(loc("monolith/requirementsNotMetMsgbox"), {
    halign = ALIGN_CENTER, size = SIZE_TO_CONTENT }.__merge(body_txt)))
  return res
}

function getRecipeName(recipe) {
  if (recipe?.name == null)
    return loc("unknown_item")

  if (recipe.name != "")
    return recipe.name

  let templateName = recipe.results?[0].reduce(@(a,v,k) v.len() == 0 ? k : a, "")
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
  let itemName = template.getCompValNullable("item__name")

  return itemName
}

function openChronotracesWindow(event, node_id, needResearchPoints, currentResearchPoints, isDoubleClicked = false) {
  let curChronotracesCount = playerProfileChronotracesCount.get()
  if (curChronotracesCount <= 0) {
    showMsgbox({ text = $"{loc("research/zeroChronotraces")}{loc("research/descMsgBox/closedNodeDesc")}" })
    return
  }
  if (curChronotracesCount == 1) {
    showMessageWithContent({
      content = {
        size = static [sw(80), SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        gap = static hdpx(20)
        halign = ALIGN_CENTER
        children = [
          mkTextArea(loc("research/addOnePoint", { blueprint = colorize(InfoTextValueColor, loc(getRecipeName(allCraftRecipes.get()[node_id])))}),
            { halign = ALIGN_CENTER }.__merge(h2_txt))
          getRecipeIcon(node_id, [largeRecipeIconHeight, largeRecipeIconHeight], 0.0, "silhouette")
        ]
      }
      buttons = [
        {
          text = loc("Yes")
          action = function() {
            eventbus_send("profile.add_chronotraces_to_research_node", { node_id, chronotraces_count = 1 })
            removeModalWindow(CHRONOTRACE_UID_WND)
          }
          isCurrent = true
        },
        {
          text = loc("No")
          isCancel = true
        }
      ]
    })
    return
  }
  let needMore = needResearchPoints - currentResearchPoints
  let maxChronotracesToAdd = needMore > 0 ? clamp(curChronotracesCount, 1, needMore) : 0
  let sendCount = Watched(maxChronotracesToAdd)
  let maxCountText = mkText(maxChronotracesToAdd)
  let inputWidth = calc_comp_size(mkText(maxChronotracesToAdd, body_txt))[0]

  let countInput = {
    size = [inputWidth + hdpx(10), SIZE_TO_CONTENT]
    children = textInput(sendCount, {
      textmargin = hdpx(5)
      margin = 0
      onEscape = function() {
        if (sendCount.get() == 1)
          set_kb_focus(null)
        sendCount.set(1)
      }
      onChange = function(value) {
        let intVal = value == "" ? 1 : toIntegerSafe(value, 1, false)
        if (intVal <= 1)
          sendCount.set(1)
        else if (intVal >= maxChronotracesToAdd)
          sendCount.set(maxChronotracesToAdd)
        else
          sendCount.set(intVal)
      }
      maxChars = maxChronotracesToAdd.tostring().len()
      isValidResult = @(val) type(val) == "integer"
      setValue = @(_v) null
      inputType = "num"
      fontSize = body_txt.fontSize
    })
  }

  let addPointsPanel = {
    size = FLEX_H
    flow = FLOW_VERTICAL
    gap = static hdpx(6)
    children = [
      {
        size = static [flex() hdpx(20)]
        children = Horiz(sendCount, {
          min = maxChronotracesToAdd > 1 ? 1 : 0
          max = maxChronotracesToAdd
          step = 1
          setValue = function(v) {
            local rv = v
            if (type(v) == "string")
              rv = toIntegerSafe(v,1,false)
            else
              rv = v.tointeger()
            sendCount.set(rv > 0 ? rv : 1)
          }
          bgColor = BtnBgFocused
        })
      }
      {
        size = FLEX_H
        flow = FLOW_HORIZONTAL
        gap = static { size = flex() }
        valign = ALIGN_CENTER
        children = [
          maxChronotracesToAdd > 1 ? static mkText(1) : static mkText(0)
          countInput
          maxCountText
        ]
      }
    ]
  }

  let { b, t, r, l } = event.targetRect
  let yPos = sh(100) - b <= chronotracesWndSize[1] * 1.5
    ? t - chronotracesWndSize[1] - hdpx(5)
    : b + hdpx(5)
  let wndPos = isDoubleClicked ? [(r + l) / 2 - chronotracesWndSize[0] / 2, yPos] : [l - hdpx(18), b + hdpx(14)]
  return addModalWindow({
    key = CHRONOTRACE_UID_WND
    onClick = null
    children = [
      mkLightBox([{l, r, b, t}, [node_id]])
      {
        rendObj = ROBJ_BOX
        size = chronotracesWndSize
        fillColor = ControlBgOpaque
        borderWidth = hdpx(1)
        borderRadius = hdpx(1)
        borderColor = BtnBgDisabled
        pos = wndPos
        flow = FLOW_VERTICAL
        gap = static hdpx(10)
        padding = static hdpx(10)
        halign = ALIGN_CENTER
        behavior = Behaviors.Button
        onClick = null
        children = [
          {
            size = FLEX_H
            flow = FLOW_VERTICAL
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            gap = hdpx(10)
            children = [
              {
                size = FLEX_H
                valign = ALIGN_CENTER
                halign = ALIGN_RIGHT
                children = [
                  mkText(loc(getRecipeName(allCraftRecipes.get()[node_id])), {
                    hplace = ALIGN_CENTER
                  }.__merge(body_txt))
                  mkCloseStyleBtn(@() removeModalWindow(CHRONOTRACE_UID_WND))
                ]
              }
              addPointsPanel
            ]
          }
          textButton(loc("research/addPointsToResearch"),
            function() {
              eventbus_send("profile.add_chronotraces_to_research_node", { node_id, chronotraces_count=sendCount.get() })
              removeModalWindow(CHRONOTRACE_UID_WND)
            })
        ]
      }
    ]
  })
}


function getRecipeMonolithUnlock(prototypeId, name, marketOffers, monolithLevels, playerStats, curMonolithLevel) {
  let marketId = marketOffers.findindex(@(v) v?.children.researchNodes[0] == prototypeId)
  if (marketId == null)
    return null
  let marketItem = marketOffers[marketId]
  let { buyable = false, additionalPrice = {}, requirements = {} } = marketItem
  let isAlreadyBought = playerStats?.purchasedUniqueMarketOffers.findindex(@(v) v.tostring() == marketId) != null
  if (!buyable || (additionalPrice?.monolithTokensCount ?? 0) <= 0 || isAlreadyBought)
    return null

  let { monolithAccessLevel = null } = requirements
  if (monolithAccessLevel == null)
    return null
  let unlocksAtMonolithLevel = monolithAccessLevel - 1
  let monolithRequirements = getRequirementsMonolithData(marketItem, playerStats, monolithLevels, curMonolithLevel)

  return {
    unlocksAtMonolithLevel
    name
    monolithUnlockToSend = marketItem.children.unlocks[0]
    text = $"{loc("market/requreMonolithLevel")} {loc(monolithLevels?[unlocksAtMonolithLevel].offerName)}"
    price = additionalPrice.monolithTokensCount
    offerId = marketId
    prototypeId
    monolithRequirements
  }
}

function showMonolithMsgBox(data) {
  let { unlocksAtMonolithLevel, monolithUnlockToSend, text, price, offerId, prototypeId,
    name, monolithRequirements } = data
  let buttons = [
    { text = loc("Cancel"), isCurrent = true, isCancel = true }
    {
      text = loc("market/goToMonolith"),
      action = function() {
        monolithSelectedLevel.set(unlocksAtMonolithLevel + 1)
        selectedMonolithUnlock.set(monolithUnlockToSend)
        currentTab.set("monolithLevelId")
        ecs.g_entity_mgr.broadcastEvent(CmdShowUiMenu({menuName = MonolithMenuId}))
      }
    }
  ]

  let showUnlockButton = unlocksAtMonolithLevel >= 0
    && unlocksAtMonolithLevel < currentMonolithLevel.get()
    && monolithRequirements.len() <= 0

  if (showUnlockButton) {
    buttons.append({
      text = $"{loc("market/monolithOffer/unlockNow")} {colorize(monolithTokensColor, monolithTokensTextIcon)}{price}"
      customStyle = {
        style = {
          TextNormal = price > playerProfileMonolithTokensCount.get() ? RedWarningColor : BtnTextNormal
        }
        textParams = {
          rendObj = ROBJ_TEXTAREA
          behavior = Behaviors.TextArea
        }
      }
      action = function() {
        if (price > playerProfileMonolithTokensCount.get()) {
          let mkNoMonotithTokensLog = {
            id = monolithUnlockToSend
            content = mkPlayerLog({
              titleText = loc("market/transactionDeclined")
              bodyIcon = itemIconNoBorder("monolith_credit_coins_pile", { width = hdpxi(40), height = hdpxi(40) })
              bodyText = loc("monolith/notEnoughMonolithTokensLog")
              logColor = playerLogsColors.warningLog
            })
          }
          addPlayerLog(mkNoMonotithTokensLog)
        }
        else {
          sound_play("ui_sounds/mark_item_3d")
          eventbus_send("profile_server.buyLots", [ { id = offerId, count = 1, usePremium = false } ])
        }
      }
    })
  }

  let content = {
    size = static [sw(70), SIZE_TO_CONTENT]
    children = [
      !showUnlockButton ? null : {
        hplace = ALIGN_RIGHT
        vplace = ALIGN_TOP
        flow = FLOW_HORIZONTAL
        gap = hdpx(10)
        children = currencyPanel
      }
      {
        size = FLEX_H
        halign = ALIGN_CENTER
        flow = FLOW_VERTICAL
        gap = hdpx(20)
        children = [
          mkText(text, h2_txt)
          getRecipeIcon(prototypeId, [largeRecipeIconHeight, largeRecipeIconHeight], 0.0, "silhouette")
          mkText(loc(name), h2_txt)
          monolithRequirements.len() <= 0 ? null : {
            size = FLEX_H
            flow = FLOW_VERTICAL
            gap = hdpx(2)
            hplace = ALIGN_CENTER
            halign = ALIGN_CENTER
            padding = static [0,0, hdpx(10), 0]
            children = monolithRequirements
          }
        ]
      }
    ]
  }
  showMessageWithContent({ content, buttons })
}

function setCraftsReadyCount() {
  local craftsReadyCount = 0
  foreach (craft in craftTasks.get()) {
    let endsIn = craft.craftCompleteAt
    if (endsIn <= get_sync_time())
      craftsReadyCount++
  }
  craftsReady.set(craftsReadyCount)
  return craftsReadyCount
}

function resetCraftTimer() {
  local timerNum = 0
  foreach (task in craftTasks.get()) {
    let waitTime = task.craftCompleteAt - get_sync_time() + 0.1
    if (waitTime > 0) {
      let id = $"crafts_timer_{timerNum}"
      gui_scene.resetTimeout(waitTime, function() {
        let oldCount = craftsReady.get()
        let newCount = setCraftsReadyCount()
        if (oldCount < newCount) {
          sound_play("ui_sounds/process_complete")
        }
      }, id)
      timerNum++
    }
  }
}

let craftMsgbox = @(text) showMessageWithContent({
  content = {
    rendObj = ROBJ_TEXTAREA
    behavior = Behaviors.TextArea
    text = text
    halign = ALIGN_CENTER
  }.__update(h2_txt)
})

function startReplication(idx = null, event = null) {
  if (prototypeToReplicate.get() == null) {
    showMsgbox({text=loc("craft/itemNotSelected")})
    return
  }

  if (selectedPrototypeMonolithData.get() != null) {
    showMonolithMsgBox(selectedPrototypeMonolithData.get())
    return
  }

  if (!(allCraftRecipes.get()?[prototypeToReplicate.get()].isOpened)) {
    let recipe = allCraftRecipes.get()[prototypeToReplicate.get()]
    let playerResearch = playerProfileOpenedNodes.get().findvalue(@(v) v.prototypeId == prototypeToReplicate.get())
    if (playerResearch == null) {
      let craftResultItems = getCraftResultItems(recipe.results).slice(0, 1)
      showMessageWithContent({
        content = {
          size = static [sw(80), SIZE_TO_CONTENT]
          flow = FLOW_VERTICAL
          gap = static hdpx(40)
          halign = ALIGN_CENTER
          vplace = ALIGN_CENTER
          children = [
            mkTextArea(loc("craft/startUnresearchedRecipe"), { halign = ALIGN_CENTER }.__merge(h2_txt))
            {
              children = [
                mkCraftResultsItems(craftResultItems)
                faComp("paw", {
                  color = TextHighlight
                  padding = static hdpx(4)
                  fontSize = hdpx(20)
                  behavior = Behaviors.Button
                  skipDirPadNav = true
                  transform = {}
                  animations = [{prop = AnimProp.color, from = TextHighlight, to = TextNormal, duration = 1,
                    play = true, loop = true, easing = CosineFull }]
                  onHover = @(on) setTooltip(on ? loc("items/item_created_by_zone") : null)
                })
              ]
            }
          ]
        }
      })
    }
    else {
      let node_id = playerProfileAllResearchNodes.get().findindex(@(v) v.containsRecipe == prototypeToReplicate.get())
      let research = playerProfileAllResearchNodes.get()?[node_id]
      let needResearchPoints = research?.requireResearchPointsToComplete ?? -1
      let currentResearchPoints = playerResearch?.currentResearchPoints ?? 0
      if (idx != null) {
        showMsgbox({ text = loc("research/descMsgBox/openedNodeReq", { neededCount = needResearchPoints, neededCountDiff = needResearchPoints }) })
        return
      }
      if (needResearchPoints <= currentResearchPoints) {
        eventbus_send("profile_server.claim_craft_recipe", { node_id })
      }
      else {
        openChronotracesWindow(event, node_id, needResearchPoints, currentResearchPoints, true)
      }
    }
    return
  }

  local idxToSet = idx
  let openedCount = playerBaseState.get()?.openedReplicatorDevices ?? 0
  let queueCount = 1 + (playerBaseState.get()?.replicatorDeviceQueueSize.x ?? 0) + (playerBaseState.get()?.replicatorDeviceQueueSize.y ?? 0)
  if (idxToSet == null && openedCount > 0) {
    for (local i = 0; i < openedCount; i++) {
      let busyReplicator = craftTasks.get().findvalue(@(v) v.replicatorSlotIdx == i)
      if (busyReplicator == null) {
        idxToSet = i
        break
      }
    }
    if (idxToSet == null) {
      let modulesCraftTime = craftTasks.get().reduce(function(res, task) {
        let { replicatorSlotIdx, craftCompleteAt } = task
        if (replicatorSlotIdx not in res)
          res[replicatorSlotIdx] <- craftCompleteAt
        else
          res[replicatorSlotIdx] += craftCompleteAt
        return res
      }, {})

      let fastestTask = modulesCraftTime.reduce(function(res, time, module) {
        if ("time" not in res || time < res.time)
          return { time, fastestIndex = module }
        return res
      }, {})
      idxToSet = fastestTask.fastestIndex
    }
  }
  if (idxToSet == null) {
    craftMsgbox(loc("craft/allReplicatorsIsFullButton"))
    return
  }
  let currentTaskCount = (craftTasks.get().filter(@(v) v?.replicatorSlotIdx == idxToSet)).len()
  if (currentTaskCount >= queueCount) {
    craftMsgbox(loc("craft/moduleAndQueueInProgress", { number = idxToSet + 1 }))
    return
  }

  eventbus_subscribe_onehit($"profile_server.add_craft_task.result#{idxToSet}", function(_) {
    profileActionInProgress.set(false)
    resetCraftTimer()
  })

  profileActionInProgress.set(true)
  eventbus_send("profile_server.add_craft_task", {
    craft_recipe_id = prototypeToReplicate.get(),
    replicatorSlotIdx = idxToSet
  })
  craftScreenState.set(craftScreens.craftProgress)
}

let mkMonolithLinkIcon = @(monolithUnlockData, action) button(
  mkText(monolithTokensTextIcon, {
    fontSize = hdpxi(17)
    color = monolithTokensColor
    pos = [hdpx(1), 0]
  }),
  action,
  {
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = hdpx(25)
    onHover = @(on) setTooltip(on ? loc(monolithUnlockData.text) : null)
    stopHover = true
    skipDirPadNav = true
  })

let mkSmallMonolithLinkIcon = @(monolithUnlockData, action) button(
  mkText(monolithTokensTextIcon, {
    fontSize = hdpxi(14)
    color = monolithTokensColor
  }),
  action,
  {
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = hdpx(19)
    margin = hdpx(2)
    onHover = @(on) setTooltip(on ? loc(monolithUnlockData.text) : null)
    stopHover = true
    skipDirPadNav = true
  })

let getItemTemplate = @(template_name) template_name
  ? ecs.g_entity_mgr.getTemplateDB().getTemplateByName(template_name)
  : null

let prototypeTypes = Computed(function() {
  let prototype_2_type = {}
  let market = marketItems.get()
  if (market.len() == 0)
    return []
  foreach(_proto_id, prototype in allCraftRecipes.get()) {
    let protoKey = prototype.results?[0].reduce(@(a,v,k) v.len() == 0 ? k : a, "") ?? ""
    let template = getItemTemplate(protoKey)
    if (!template) {
      continue
    }

    let filter = template.getCompValNullable("item__filterType") ?? "loot"
    prototype_2_type[protoKey] <- filter
  }
  return prototype_2_type
})

let deleteInputTextBtn = fontIconButton("icon_buttons/x_btn.svg", @() filterTextInput.set(""),
  { padding = hdpx(2) })

let inputBlock = {
  size = FLEX_H
  margin = static [0,0, hdpx(10),0]
  flow = FLOW_HORIZONTAL
  gap = hdpx(10)
  valign = ALIGN_CENTER
  children = [
    textInput(filterTextInput, {
      placeholder = loc("search by name")
      textmargin = hdpx(5)
      margin = 0
      onChange = @(value) filterTextInput.set(value)
      onEscape = function() {
        if (filterTextInput.get() == "")
          set_kb_focus(null)
        filterTextInput.set("")
      }
    }.__update(body_txt))
    function() {
      if (filterTextInput.get() == "")
        return { watch = filterTextInput }
      return {
        watch = filterTextInput
        children = deleteInputTextBtn
      }
    }
  ]
}

let mkNotifMarkWithExclamationSign = @(size) {
  rendObj = ROBJ_SOLID
  size = [ size, size ]
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  hplace = ALIGN_RIGHT
  vplace = ALIGN_TOP
  margin = hdpx(2)
  color = NotificationBg
  children = faComp("exclamation", {
    pos = [ 1, 1 ]
    fontSize = size * 0.7
    color = Color(20,20,20)
  })
}

function startRecipeReplication(event = null) {
  if (profileActionInProgress.get())
    return
  if (selectedPrototypeMonolithData.get() != null) {
    showMonolithMsgBox(selectedPrototypeMonolithData.get())
    return
  }
  startReplication(null, event)
}


return freeze({
  selectedPrototype
  gamepadHoveredPrototype
  startReplication
  getRecipeMonolithUnlock
  selectedPrototypeMonolithData
  showMonolithMsgBox
  profileActionInProgress
  craftsReady
  craftMsgbox
  setCraftsReadyCount
  mkMonolithLinkIcon
  mkSmallMonolithLinkIcon
  onlyEarnedRecipesFilter
  onlyOpenedBlueprintsFilter
  selectedCategory
  inputBlock
  filterTextInput
  prototypeTypes
  getRecipeName
  mkNotifMarkWithExclamationSign
  startRecipeReplication
  largeRecipeIconHeight
  openChronotracesWindow
})
