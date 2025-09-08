from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
from "math" import cos, PI, floor

let { h2_txt, body_txt } = require("%ui/fonts_style.nut")
let { playerProfileOpenedRecipes, allCraftRecipes, marketItems,
  playerProfileChronotracesCount, craftTasks, playerBaseState, playerProfileAllResearchNodes,
  playerProfileOpenedNodes, playerStats } = require("%ui/profile/profileState.nut")
let { InfoTextDescColor, InfoTextValueColor, BtnBgDisabled, BtnBgSelected, BtnPrimaryBgNormal,
  BtnPrimaryTextNormal, BtnTextNormal, ControlBg, BtnBdSelected, BtnBgFocused
} = require("%ui/components/colors.nut")
let { makeVertScrollExt, reservedPaddingStyle, makeVertScroll } = require("%ui/components/scrollbar.nut")
let { mkSelectPanelItem, mkText, mkTextWithFAIcon, VertSelectPanelGap, BD_LEFT, BD_CENTER,
  mkTooltiped, underlineComp, fontIconButton, mkTextArea } = require("%ui/components/commonComponents.nut")
let { secondsToStringLoc } = require("%ui/helpers/time.nut")
let { getRecipeIcon, getCraftResultItems, mkCraftResultsItems, researchOpenedMarker } = require("craftIcons.nut")
let checkBox = require("%ui/components/checkbox.nut")
let faComp = require("%ui/components/faComp.nut")
let craftCategories = require("%ui/mainMenu/categories/craftCategories.nut")
let { eventbus_send, eventbus_subscribe_onehit, eventbus_subscribe } = require("eventbus")
let { showMessageWithContent, showMsgbox } = require("%ui/components/msgbox.nut")
let { mkCountdownTimerPerSec } = require("%ui/helpers/timers.nut")
let { button, textButton } = require("%ui/components/button.nut")
let { showMsgBoxResult } = require("%ui/components/profileAnswerMsgBox.nut")
let { EventSetReplicatorData } = require("dasevents")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let { accentButtonStyle } = require("%ui/components/accentButton.style.nut")
let { get_sync_time } = require("net")
let { Horiz } = require("%ui/components/slider.nut")
let { monolithLevelOffers, currentMonolithLevel } = require("%ui/mainMenu/monolith/monolith_common.nut")
let tooltipBox = require("%ui/components/tooltipBox.nut")
let { isInBattleState } = require("%ui/state/appState.nut")
let { mkResearchNet, getRecipeProgress } = require("%ui/mainMenu/researchNet.nut")
let { utf8ToUpper, utf8ToLower, toIntegerSafe } = require("%sqstd/string.nut")
let { selectedPrototype, startReplication, getRecipeMonolithUnlock, selectedPrototypeMonolithData, showMonolithMsgBox,
  profileActionInProgress, craftsReady, setCraftsReadyCount, craftMsgbox, mkMonolithLinkIcon, onlyEarnedRecipesFilter,
  onlyOpenedBlueprintsFilter, selectedCategory, prototypeTypes, inputBlock, filterTextInput, getRecipeName,
  mkNotifMarkWithExclamationSign } = require("%ui/mainMenu/craft_common_pkg.nut")
let marketCategories = require("%ui/mainMenu/categories/marketCategories.nut")
let colorize = require("%ui/components/colorize.nut")
let { cronotracesIcon } = require("%ui/mainMenu/currencyIcons.nut")

let scrollToRecipe = Watched(null)
let showAsTree = Watched(false)

let filterBlockSize = sw(15)
let craftIconSize = [hdpxi(94), hdpxi(94)]
let notifCircleSize = hdpxi(30)

function cosineFull(p){
  return 0.5 - cos(p * PI * 2) * 0.5
}


function getCronotraceIncomeInfo(templateOrId) {
  let marketLotId = toIntegerSafe(templateOrId, 0, false)
  let marketLot = marketItems.get()?[templateOrId].children.items
  let itemTemplateName = marketLotId == 0 ? templateOrId : marketLot?[0].templateName ?? ""
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(itemTemplateName)
  let data = template?.getCompValNullable("item__chronotracesProgressionInfo")?.getAll() ?? {}
  return data
}

function addPointsMsgBox(node_id, needResearchPoints, currentResearchPoints) {
  let curChronotracesCount = playerProfileChronotracesCount.get()
  if (curChronotracesCount <= 0) {
    showMsgbox({ text = $"{loc("research/zeroChronotraces")}{loc("research/descMsgBox/closedNodeDesc")}" })
    return
  }
  let maxChronotracesToAdd = clamp(curChronotracesCount, 1, needResearchPoints - currentResearchPoints)
  let sendCount = Watched(maxChronotracesToAdd)

  let addPointsPanel = @() {
    watch = playerProfileChronotracesCount
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    size = const [ flex(), SIZE_TO_CONTENT ]
    children = {
      flow = FLOW_VERTICAL
      size = const [ flex(), SIZE_TO_CONTENT ]
      halign = ALIGN_CENTER
      gap = hdpx(10)
      children = [
        {
          size = const [sw(25), hdpx(20)]
          children = Horiz(sendCount, {
            min = 1
            max = maxChronotracesToAdd
            step = 1
            setValue = @(v) sendCount.set(v.tointeger())
            bgColor = BtnBgFocused
          })
        }
        {
          flow = FLOW_HORIZONTAL
          size = const [ sw(25), SIZE_TO_CONTENT ]
          gap = const { size = flex() }
          children = [
            const mkText(1, body_txt)
            @() {
              watch = sendCount
              children = mkText(sendCount.get(), { color = InfoTextValueColor }.__update(h2_txt))
            }
            mkText(maxChronotracesToAdd, body_txt)
          ]
        }
      ]
    }
  }

  let buttons = [
    const { text = loc("Cancel"), isCurrent = true, isCancel = true },
    {
      text = loc("research/addPointsToResearch"),
      action = @() eventbus_send("profile.add_chronotraces_to_research_node", { node_id, chronotraces_count=sendCount.get() })
    }
  ]

  return showMessageWithContent({
    content = {
      flow = FLOW_VERTICAL
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      gap = hdpx(10)
      children = [
        const mkText(loc("research/addPointsToResearch"), h2_txt)
        addPointsPanel
      ]
    },
    buttons
  })
}

function craftInfoBlock() {
  let recipe_id = selectedPrototype.get()
  if (!recipe_id)
    return const{ watch = selectedPrototype }

  let recipe = allCraftRecipes.get()[recipe_id]
  let playerRecipe = playerProfileOpenedRecipes.get().findvalue(@(v) v.prototypeId == recipe_id)

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
    let chronotraceIncome = getCronotraceIncomeInfo(recipe.results.keys()[0])
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
      padding = const [0, hdpx(4), 0, hdpx(4)]
      size = const [flex(), SIZE_TO_CONTENT]
      gap = hdpx(5)
      children = [
        playerResearch != null && needResearchPoints - currentResearchPoints > 0 ? fontIconButton("plus", @() addPointsMsgBox(node_id, needResearchPoints, currentResearchPoints)) : null
        const { size = [flex(), SIZE_TO_CONTENT] }
        { flow = FLOW_HORIZONTAL gap = hdpx(10) valign = ALIGN_CENTER children = [
          const cronotracesIcon(h2_txt.fontSize*0.8),
          mkText(currentResearchPoints, h2_txt),
          const mkText("/", h2_txt),
          mkText(needResearchPoints, h2_txt)
        ]}
        const { size = [flex(), SIZE_TO_CONTENT] }
        faComp("question-circle", {
          fontSize = hdpxi(28)
          color = InfoTextDescColor
          behavior = Behaviors.Button
          onHover = @(on) setTooltip(!on ? null
            : playerResearch == null
              ? loc("research/descMsgBox/closedIndependentNodeTitleDesc")
              : tooltipBox({
                  size = const [hdpx(400), SIZE_TO_CONTENT]
                  flow = FLOW_VERTICAL
                  children = [
                    mkTextArea(loc("research/descMsgBox/openedNode",
                      { neededCount = colorize(InfoTextValueColor, needResearchPoints - currentResearchPoints)
                        neededCountDiff = needResearchPoints - currentResearchPoints
                      }))
                  ].extend(hints.map(@(v) mkTextArea(loc(v.locId, { count = colorize(InfoTextValueColor, v.value )}),
                      const { color = InfoTextDescColor })))
                })
            )
        })
      ]
    }
  }

  let icon = {
    size = const [ flex(), SIZE_TO_CONTENT ]
    children = [
      getRecipeIcon(recipe_id, const [hdpx(260), hdpx(260)],
        playerRecipe != null ? 1.0 : currentResearchPoints.tofloat() / needResearchPoints,
        playerRecipe != null ? "full" : "silhouette")
      playerRecipe == null ? {
        rendObj = ROBJ_BOX
        borderWidth = const [hdpx(1), 0, hdpx(1), 0]
        fillColor = Color(20, 20, 20, 200)
        margin = const [0, 0, hdpx(20), 0]
        size = const [ flex(), SIZE_TO_CONTENT ]
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
    size = const [ flex(), SIZE_TO_CONTENT ]
    gap = const { size = [ flex(), SIZE_TO_CONTENT ] }
    children = [ text1, const {size = flex()}, text2 ]
  })

  let recipeName = infoText(mkText(loc("research/craftRecipe"), { color = InfoTextDescColor }),
    mkText(loc(getRecipeName(recipe)), { color = InfoTextValueColor }))

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
    watch = [ selectedPrototype, playerProfileOpenedRecipes, playerProfileOpenedNodes, playerProfileAllResearchNodes ]
    rendObj = ROBJ_SOLID
    color = ControlBg
    size = const [hdpx(400), flex()]
    padding = hdpx(20)
    flow = FLOW_VERTICAL
    gap = hdpx(20)
    clipChildren = true
    children = [
      icon
      {
        size = const [flex(), SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        children = [
          recipeName
          normalCraftTime
        ]
      }
      results
    ]
  }
}

let noRecipesFoundMsg = const {
  size = [ flex(), sh(20) ]
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = mkText(loc("craft/noRecipesFoundByFiltering"), h2_txt)
}

let mkProgressBar = @(craftTime, timeLeftWatched) @() {
  watch = timeLeftWatched
  size = flex()
  rendObj = ROBJ_SOLID
  color = BtnBgSelected
  margin = hdpx(1) 
  transform = {
    scale = [(craftTime - timeLeftWatched.get()).tofloat() / craftTime, 1.0]
    pivot = [0.0, 0.5]
  }
}

let timeLeftToString = @(timeLeft) timeLeft > 0 ? secondsToStringLoc(timeLeft) : loc("craft/done")

let craftDoneAnim = @(id, playFromStart) {
  prop = AnimProp.fillColor,
  from = BtnPrimaryBgNormal,
  to = Color(20, 110, 125, 255),
  duration = 3.0,
  loop = true,
  play = playFromStart,
  easing = function(_anim_internal_t) { 
    return cosineFull(get_sync_time() / 3.0) 
  }
  trigger=$"craftDoneAnim_{id}"
}

let mkSpeedUpButton = @() button(
  const faComp("forward", {
    fontSize = hdpx(20)
    padding = [0,0,0, hdpx(1)]
  }),
  @() showMsgbox(const { text = loc("craft/noSpeedUp")}),
  {
    size = const hdpx(35)
    hplace = ALIGN_RIGHT
    vplace = ALIGN_CENTER
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    stopMouse = true
    onHover = @(on) setTooltip(on ? const loc("craft/speedUp") : null)
  }
)

const iconSize = 35

function mkCraftSlot(slot, idx) {
  let isProcessing = slot.status == "processing"
  let isClosed = slot.status == "unavailable"
  let countdown = isProcessing ? mkCountdownTimerPerSec(Watched(slot.task.craftCompleteAt)) : Watched(0)
  let canStart = Computed(@() !isClosed
    && !isProcessing
    && (craftTasks.get()?.len() ?? 0) < (playerBaseState.get()?.openedReplicatorDevices ?? 0))
  let hasCountDown = Computed(@() isProcessing && countdown.get() != 0)
  let needAnim = Computed(@() !isClosed && isProcessing && countdown.get() == 0.0)

  return function() {
    let recipe = allCraftRecipes.get()?[slot?.task.craftRecipeId]
    let craftTime = slot?.task.startedBroken ? recipe?.brokenCraftTime : recipe?.craftTime
    let isAccent = needAnim.get() ? true
      : canStart.get() || (!isClosed && countdown.get() == 0)
    let textColor = isAccent ? BtnPrimaryTextNormal : null
    setCraftsReadyCount()
    return {
      watch = [profileActionInProgress, canStart, allCraftRecipes, hasCountDown, needAnim]
      size = flex()
      key = $"idx_{needAnim.get()}"
      children = button({
        size = flex()
        children = [
          isProcessing && hasCountDown.get() ? mkProgressBar(craftTime, countdown) : null
          {
            size = flex()
            borderColor = BtnBdSelected
            padding = const [0, hdpx(6)]
            flow = FLOW_HORIZONTAL
            gap = const hdpx(4)
            children = [
              !isProcessing
                ? const { size = [ hdpx(iconSize), 0 ] }
                : getRecipeIcon(slot?.task.craftRecipeId, [ hdpx(iconSize), hdpx(iconSize) ], 1, "full")
                  .__update(const { hplace = ALIGN_LEFT })
              {
                size = flex()
                flow = FLOW_VERTICAL
                halign = ALIGN_CENTER
                valign = ALIGN_CENTER
                gap = const hdpx(-4)
                children = [
                  function() {
                    let textToShow = canStart.get() ? loc("craft/chooseReplication", { number = idx + 1 })
                      : isProcessing ? timeLeftToString(countdown?.get())
                      : loc("craft/slotUnavailableBtnText", { number = idx + 1 })
                    return {
                      watch = countdown
                      children = mkText(textToShow, {
                        color = textColor
                        fontSize = const hdpx(16)
                        fontFxColor = const Color(0,0,0,30)
                      })
                    }
                  }
                  isProcessing ? mkText(loc(getRecipeName(recipe)), {
                    size = const [flex(), SIZE_TO_CONTENT]
                    behavior = Behaviors.Marquee
                    scrollOnHover = false
                    color = textColor
                    fontSize = hdpx(16)
                    halign = ALIGN_CENTER
                    fontFxColor = const Color(0,0,0,30)
                  }) : null
                ]
              }
              isProcessing && hasCountDown.get() ? mkSpeedUpButton() : const { size = [hdpx(35), 0]}
            ]
          }
        ]
      }, function() {
        if (isProcessing && countdown?.get() == 0) {
          profileActionInProgress.set(true)
          let taskIds = [slot.task.taskId_int64]
          eventbus_subscribe_onehit($"profile_server.complete_craft_tasks.result#{slot.task.taskId_int64}", function(result) {
            showMsgBoxResult(loc("craft/resultReceived"), result)
            profileActionInProgress.set(false)
            setCraftsReadyCount()
          })
          eventbus_send("profile_server.complete_craft_tasks", taskIds)
        }
        else {
          if (isClosed) {
            craftMsgbox(loc("craft/slotUnavailableMsg", { number = idx }))
            return
          }
          else if (isProcessing) {
            craftMsgbox(loc("craft/extractionInProgressMsg", { number = idx + 1 }))
            return
          }
          startReplication(idx)
        }
      }, {
        size = flex()
        animations = needAnim.get() ? [craftDoneAnim(idx, true)] : null
        isEnabled = !profileActionInProgress.get()
      }.__update(isAccent ? accentButtonStyle
        : isClosed ? { style = { BtnBgNormal = BtnBgDisabled } }
        : {}
      )
      )
    }
  }
}

function mkClaimAllButton(craftSlotsData) {
  let fastestCraft = craftSlotsData.reduce(function(res, v) {
    let { task = {}, status } = v
    if (status == "processing" && ((task?.craftCompleteAt ?? 0) < res || res == 0))
      res = task.craftCompleteAt
    return res
  }, 0)
  let countdown = fastestCraft > 0 ? mkCountdownTimerPerSec(Watched(fastestCraft)) : Watched(null)
  let hasAnyCompleted = Computed(@() fastestCraft != 0 && countdown.get() != null && countdown.get() == 0)
  return function() {
    let isAccent = hasAnyCompleted.get()
    return {
      watch = hasAnyCompleted
      key = $"claimAll_{hasAnyCompleted.get()}"
      size = [flex(), SIZE_TO_CONTENT]
      children = button(mkText(loc("craft/claimAll"), {
        color = isAccent ? BtnPrimaryTextNormal : const mul_color(BtnTextNormal, 0.5, 2)
        hplace = ALIGN_CENTER
        fontFx = null
      }.__update(body_txt)),
      function() {
        let taskIds = craftSlotsData
          .filter(@(v) v.status == "processing" && v.task.craftCompleteAt <= get_sync_time())
          .map(@(v) v.task.taskId_int64)
        if (taskIds.len() <= 0) {
          showMsgbox(const { text = loc("craft/noCompletedReplications") })
          return
        }
        let idsString = ",".join(taskIds)
        profileActionInProgress.set(true)
        eventbus_send("profile_server.complete_craft_tasks", taskIds)
        eventbus_subscribe($"profile_server.complete_craft_tasks.result#{idsString}", function(result) {
          showMsgBoxResult(loc("craft/resultReceived"), result)
          profileActionInProgress.set(false)
          setCraftsReadyCount()
        })
      }
      {
        size = const [flex(), hdpx(50)]
        margin = 0
        isEnabled = !profileActionInProgress.get()
        animations = isAccent ? [craftDoneAnim("claimAll", true)] : null
      }.__update(isAccent ? accentButtonStyle : const {} ))
    }
  }
}

function mkCraftSlots(claimAllBtn = null) {
  let craftSlotsData = Computed(function() {
    let maxReplicatorDevices = playerBaseState.get()?.maxReplicatorDevices ?? 0
    if (maxReplicatorDevices == 0)
      return []
    let ret = array(maxReplicatorDevices, const { status = "unavailable" })

    foreach (task in craftTasks.get()) {
      ret[task.replicatorSlotIdx] = {
        status = "processing"
        task
      }
    }
    let openedReplicators = playerBaseState.get()?.openedReplicatorDevices ?? -1
    foreach (idx, replicator in ret) {
      if (replicator.status == "unavailable" && idx < openedReplicators)
        ret[idx] = const { status = "empty" }
    }

    return ret
  })

  return function() {
    if (isOnboarding.get())
      return const { watch = isOnboarding }
    return {
      watch = [craftSlotsData, isOnboarding]
      size = flex()
      halign = ALIGN_CENTER
      flow = FLOW_VERTICAL
      gap = const hdpx(10)
      children = [
        {
          size = flex()
          flow = FLOW_VERTICAL
          gap = -1
          children = craftSlotsData.get().map(@(slot, idx) mkCraftSlot(slot, idx))
        }
        claimAllBtn?(craftSlotsData.get())
      ]
    }
  }
}

function mkCraftSelection() {
  function mkRecipeButton(prototype_id) {
    let recipeId = playerProfileOpenedRecipes.get().findindex(@(v) v.prototypeId == prototype_id)
    let allNodes = playerProfileAllResearchNodes.get()
    let node_id = allNodes.findindex(@(v) v.containsRecipe == prototype_id)
    let playerResearch = playerProfileOpenedNodes.get().findvalue(@(v) v.prototypeId == node_id)
    let locked = playerResearch == null
    let research = allNodes?[node_id]
    let progress = recipeId == null
      ? getRecipeProgress(playerResearch?.currentResearchPoints, research?.requireResearchPointsToComplete)
      : 1.0

    let icon = getRecipeIcon(prototype_id, craftIconSize, progress,
      recipeId == null ? "silhouette" : "full")
    let prototype = allCraftRecipes.get()[prototype_id]
    let name = getRecipeName(prototype)
    let monolithUnlockData = !locked ? null
      : getRecipeMonolithUnlock(prototype_id, name, marketItems.get(), monolithLevelOffers.get(),
          playerStats.get(), currentMonolithLevel.get())
    let recipeName = mkText(loc(name), {
      size = const [flex(), SIZE_TO_CONTENT]
      behavior = Behaviors.Marquee
      halign = ALIGN_CENTER
      delay = 1
      speed = const hdpx(50)
    })
    let recipe = playerProfileOpenedRecipes.get()?[recipeId]
    let broken =
      prototype.craftsUntilBroke != 0 &&
      ((recipe ? recipe.craftsLeft : 1) <= 0)

    let iconAndName = {
      size = const flex()
      halign = ALIGN_CENTER
      flow = FLOW_VERTICAL
      gap = const hdpx(4)
      valign = ALIGN_CENTER
      children = [
        {
          children = [
            icon,
            playerResearch != null && progress < 1.0 ? researchOpenedMarker : null
          ]
        }
        recipeName
      ]
    }

    let statusIcon = {
      hplace = ALIGN_RIGHT
      children = locked
        ? const faComp("lock")
        : broken ? const mkTooltiped(faComp("chain-broken"), tooltipBox(mkText(loc("craft/brokenTooltip")))) : null
    }

    let monolithLinkIcon = monolithUnlockData == null ? null
      : mkMonolithLinkIcon(monolithUnlockData, @() showMonolithMsgBox(monolithUnlockData))
    return mkSelectPanelItem({children = {
      padding = hdpx(10)
      size = flex()
      children = [
        statusIcon
        progress == 1 && recipeId == null ? mkNotifMarkWithExclamationSign(notifCircleSize) : null
        monolithLinkIcon
        iconAndName
      ]
    },
    state=selectedPrototype,
    onSelect = function(selPrototype) {
      selectedPrototypeMonolithData.set(monolithUnlockData)
      selectedPrototype.set(selPrototype)
    }
    idx=prototype_id,
    visual_params={ padding = 0 size = flex() key = prototype_id}
    border_align = BD_CENTER
    onlySelectedBd = true
    onDoubleClick = function() {
      if (monolithUnlockData != null) {
        showMonolithMsgBox(monolithUnlockData)
        return
      }
      startReplication()
    }
    sound = {
      click  = locked ? "ui_sounds/button_inactive" : "ui_sounds/button_click"
      hover  = "ui_sounds/button_highlight"
      active = null
    }
    })
  }

  let filteredRecipes = Computed(function() {
    let recipes = []
    let openedNodes = []
    let unavailableRecipes = []
    let selectedCat = selectedCategory.get()
    let protoTypes = prototypeTypes.get()
    let allRecipes = allCraftRecipes.get()

    let data = selectedCat == null ? allRecipes
      : allRecipes.filter(@(prototype)
          prototype.results.findindex(@(_v, k) protoTypes?[k] == selectedCat) != null)

    let openedRecipes = playerProfileOpenedRecipes.get()
    let openedNodesData = playerProfileOpenedNodes.get()
    let earned = onlyEarnedRecipesFilter.get()
    let openedFilter = onlyOpenedBlueprintsFilter.get()

    foreach (proto_id, recipeData in data) {
      let recipeIdx = openedRecipes.findindex(@(v) v.prototypeId == proto_id)
      if (filterTextInput.get() != ""
        && !utf8ToLower(loc(getRecipeName(recipeData))).contains(utf8ToLower(filterTextInput.get()))
      )
        continue

      let playerResearch = openedNodesData.findvalue(@(v) v.prototypeId == proto_id)
      let recipeRecived = recipeIdx != null
      if (recipeRecived)
        recipes.append(proto_id)
      else if (playerResearch)
        openedNodes.append(proto_id)
      else
        unavailableRecipes.append(proto_id)
    }
    return earned && openedFilter ? recipes.extend(openedNodes)
      : earned ? recipes
      : openedFilter ? openedNodes
      : recipes.extend(openedNodes, unavailableRecipes)
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
        children.append(recipes?[i] ? mkRecipeButton(recipes[i]) : { size=flex() })
      }
      it+=itemsPerLine
      return children
    }
    let tiled = [].resize(recipes.len() / itemsPerLine + 1)
    tiled.apply(@(_v){
      flow = FLOW_HORIZONTAL
      size = const [flex(), hdpx(150)]
      gap = const hdpx(5)
      children = getLine()
    })

    return tiled
  }
  let scrollHandler = ScrollHandler()
  let craftList = @() {
    watch = [playerProfileOpenedRecipes, selectedCategory, allCraftRecipes, onlyEarnedRecipesFilter, playerStats,
      onlyEarnedRecipesFilter, playerProfileAllResearchNodes, playerProfileOpenedNodes, onlyOpenedBlueprintsFilter]
    rendObj = ROBJ_SOLID
    size = flex()
    color = ControlBg
    children = makeVertScrollExt(@() {
      watch = filteredRecipes
      size = const [flex(), SIZE_TO_CONTENT]
      gap = const hdpx(5)
      flow = FLOW_VERTICAL
      onAttach = function() {
        if (scrollToRecipe.get() == null)
          return
        let recipeIdx = filteredRecipes.get().findindex(@(v) v == scrollToRecipe.get())
        if (recipeIdx == null)
          return
        let line = floor(recipeIdx / 4.0)
        scrollHandler.scrollToY(line * hdpx(150) + (line - 1) * hdpx(5))
        scrollToRecipe.set(null)
      }
      children = getRecipes(filteredRecipes.get())
    }, {
      styling = reservedPaddingStyle
      scrollHandler
    })
  }

  let categoryBtnParams = {state=selectedCategory
    visual_params = const {
      padding = hdpx(15)
      size = [flex(), hdpx(50)]
      halign = ALIGN_LEFT
      valign = ALIGN_CENTER
    }
    border_align = BD_LEFT
  }
  let allCat = mkSelectPanelItem({children = const mkTextWithFAIcon("circle-o", loc($"marketCategory/All")),  idx=null}.__update(categoryBtnParams))

  function GetCategoriesButtons() {
    let buttons = []
    buttons.append(allCat)

    let filterTypes = prototypeTypes.get()
      .reduce(@ (res, val) !res.contains(val) ? res.append(val) : res, [])
      .sort(@(a, b) marketCategories[a]?.idx <=> marketCategories[b]?.idx)
    for (local i = 0; i < filterTypes.len(); i++) {
      let typeIcon = craftCategories?[filterTypes[i]].faIcon
      if (!typeIcon)
        continue
      let panel = mkSelectPanelItem({
        children = mkTextWithFAIcon(typeIcon, loc($"marketCategory/{filterTypes[i]}")),
        idx=filterTypes[i]}.__update(categoryBtnParams))
      buttons.append(panel)
    }
    return buttons
  }

  let showRecipesAsTree = checkBox(showAsTree, mkTextArea(loc("craft/showAsTree")),
    { override = {
      size = [flex(), SIZE_TO_CONTENT]
      padding = [0,0,0, hdpx(5)]
    }})

  let earnedRecipesFilter = checkBox(onlyEarnedRecipesFilter, mkTextArea(loc("craft/filter/onlyEarnedRecipes")),
    { override = {
      size = [flex(), SIZE_TO_CONTENT]
      padding = [0,0,0, hdpx(5)]
    }})

  let earnedBlueprintsFilter = checkBox(onlyOpenedBlueprintsFilter, mkTextArea(loc("craft/filter/onlyOpenedRecipes")),
    { override = {
      size = [flex(), SIZE_TO_CONTENT]
      padding = [0,0,0, hdpx(5)]
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
    padding = const [hdpx(10), hdpx(11)]
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    children = [
      {
        size = const [SIZE_TO_CONTENT, flex()]
        flow = FLOW_VERTICAL
        gap = hdpx(5)
        children = [
          {
            size = const [hdpx(400), hdpx(220)]
            children = mkCraftSlots(mkClaimAllButton)
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

return {
  getRecipeName
  craftsReady
  selectedPrototype
  selectedCategory
  mkCraftSelection
  scrollToRecipe
}
