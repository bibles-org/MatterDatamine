from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { h2_txt, body_txt } = require("%ui/fonts_style.nut")
let { BtnTextNormal, RedWarningColor, GreenSuccessColor, NotificationBg } = require("%ui/components/colors.nut")
let { mkText, fontIconButton } = require("%ui/components/commonComponents.nut")
let { playerProfileMonolithTokensCount, craftTasks, playerProfileOpenedRecipes, playerBaseState, allCraftRecipes,
  marketItems } = require("%ui/profile/profileState.nut")
let { showMsgbox, showMessageWithContent } = require("%ui/components/msgbox.nut")
let { MonolithMenuId, monolithSelectedLevel, selectedMonolithUnlock, currentMonolithLevel
} = require("%ui/mainMenu/monolith/monolith_common.nut")
let { CmdShowUiMenu } = require("dasevents")
let { monolithTokensTextIcon, monolithTokensColor } = require("%ui/mainMenu/currencyIcons.nut")
let { addPlayerLog, mkPlayerLog, playerLogsColors } = require("%ui/popup/player_event_log.nut")
let { itemIconNoBorder } = require("%ui/components/itemIconComponent.nut")
let { sound_play } = require("%dngscripts/sound_system.nut")
let { eventbus_send, eventbus_subscribe_onehit } = require("eventbus")
let { currencyPanel } = require("%ui/mainMenu/currencyPanel.nut")
let { getRecipeIcon } = require("craftIcons.nut")
let { get_sync_time } = require("net")
let { craftScreens, craftScreenState } = require("%ui/mainMenu/craftScreenState.nut")
let { logerr } = require("dagor.debug")
let { button } = require("%ui/components/button.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let { textInput } = require("%ui/components/textInput.nut")
let faComp = require("%ui/components/faComp.nut")

let selectedPrototype = Watched(null)
let selectedPrototypeMonolithData = Watched(null)
let profileActionInProgress = Watched(false)
let craftsReady = Watched(0)
let onlyEarnedRecipesFilter = Watched(false)
let onlyOpenedBlueprintsFilter = Watched(false)
let selectedCategory = Watched(null)
let filterTextInput = Watched("")

function closeCraftWindow() {
  selectedPrototype.set(null)
}

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
  res.insert(0, mkText(loc("monolith/requirementsNotMetMsgbox"), body_txt))
  return res
}


function getRecipeMonolithUnlock(prototypeId, name, marketOffers, monolithLevels, playerStats, curMonolithLevel) {
  let marketItem = marketOffers.findvalue(@(v) v?.children.researchNodes[0] == prototypeId)
  if (marketItem == null)
    return null
  let { buyable = false, additionalPrice = {}, id = null, requirements = {} } = marketItem
  let isAlreadyBought = playerStats?.purchasedUniqueMarketOffers
    .findindex(@(v) id != null && v.tostring() == id) != null
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
    monolithUnlockToSend = marketItem.children.researchNodes[0]
    text = $"{loc("market/requreMonolithLevel")} {loc(monolithLevels?[unlocksAtMonolithLevel].offerName)}"
    price = additionalPrice.monolithTokensCount
    offerId = id
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
        monolithSelectedLevel.set(unlocksAtMonolithLevel)
        selectedMonolithUnlock.set(monolithUnlockToSend)
        ecs.g_entity_mgr.broadcastEvent(CmdShowUiMenu({menuName = MonolithMenuId}))
      }
    }
  ]

  let showUnlockButton = unlocksAtMonolithLevel != 0
    && unlocksAtMonolithLevel < currentMonolithLevel.get()
    && monolithRequirements.len() <= 0

  if (showUnlockButton) {
    buttons.append({
      text = $"{loc("market/monolithOffer/unlockNow")} {monolithTokensTextIcon}{price}"
      customStyle = { style = {
        TextNormal = price > playerProfileMonolithTokensCount.get() ? RedWarningColor : BtnTextNormal
      }}
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
          addPlayerLog(mkNoMonotithTokensLog(monolithUnlockToSend))
        }
        else {
          sound_play("ui_sounds/mark_item_3d")
          eventbus_send("profile_server.buyLots", [ { id = offerId, count = 1 } ])
        }
      }
    })
  }

  let content = {
    size = [sw(70), SIZE_TO_CONTENT]
    children = [
      !showUnlockButton ? null : {
        hplace = ALIGN_RIGHT
        vplace = ALIGN_TOP
        flow = FLOW_HORIZONTAL
        gap = hdpx(10)
        children = currencyPanel
      }
      {
        size = [flex(), SIZE_TO_CONTENT]
        halign = ALIGN_CENTER
        flow = FLOW_VERTICAL
        gap = hdpx(20)
        children = [
          mkText(text, h2_txt)
          getRecipeIcon(prototypeId, [hdpxi(300), hdpxi(300)], 0.0, "silhouette")
          mkText(loc(name), h2_txt)
          monolithRequirements.len() <= 0 ? null : {
            size = [flex(), SIZE_TO_CONTENT]
            flow = FLOW_VERTICAL
            gap = hdpx(2)
            hplace = ALIGN_CENTER
            halign = ALIGN_CENTER
            padding = [0,0, hdpx(10), 0]
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

function startReplication(idx = null) {
  if (selectedPrototype.get() == null) {
    showMsgbox({text=loc("craft/itemNotSelected")})
    return
  }

  if (selectedPrototypeMonolithData.get() != null) {
    showMonolithMsgBox(selectedPrototypeMonolithData.get())
    return
  }

  let playerRecipe = playerProfileOpenedRecipes.get().findvalue(@(v) v.prototypeId == selectedPrototype.get())
  if (playerRecipe == null) {
    showMsgbox({text=loc("craft/startUnresearchedRecipe")})
    return
  }

  local idxToSet = idx
  if (idxToSet == null) {
    for (local i = 0; i < (playerBaseState.get()?.openedReplicatorDevices ?? 0); i++) {
      if (craftTasks.get()?[i] == null || craftTasks.get()[i].replicatorSlotIdx != i) {
        idxToSet = i
        break
      }
    }
  }
  if (idxToSet == null)
    return
  if (craftTasks.get().findvalue(@(v) v?.replicatorSlotIdx == idxToSet) != null) {
    craftMsgbox(loc("craft/extractionInProgressMsg", { number = idxToSet + 1 }))
    return
  }

  eventbus_subscribe_onehit($"profile_server.add_craft_task.result#{idxToSet}", function(_) {
    profileActionInProgress.set(false)
    resetCraftTimer()
  })

  profileActionInProgress.set(true)
  eventbus_send("profile_server.add_craft_task", {
    craft_recipe_id = selectedPrototype.get(),
    replicatorSlotIdx = idxToSet
  })
  craftScreenState.set(craftScreens.craftProgress)
  closeCraftWindow()
}

let mkMonolithLinkIcon = @(monolithUnlockData, action) button(
  mkText(monolithTokensTextIcon, {
    fontSize = hdpxi(17)
    color = monolithTokensColor
  }),
  action,
  {
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = [hdpx(25), hdpx(25)]
    onHover = @(on) setTooltip(on ? loc(monolithUnlockData.text) : null)
    stopHover = true
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
    size = [hdpx(19), hdpx(19)]
    margin = hdpx(2)
    onHover = @(on) setTooltip(on ? loc(monolithUnlockData.text) : null)
    stopHover = true
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
    local protoKey = prototype.results.keys()[0]
    local template = getItemTemplate(protoKey)
    if (!template) {
      let marketTemplate = market?[protoKey].children.items[0].templateName
      if (!marketTemplate) {
        logerr($"craftSelection: cant find the {protoKey} in either the templates or the marketItems")
        continue
      }
      template = getItemTemplate(marketTemplate)
    }

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
  size = [flex(), SIZE_TO_CONTENT]
  margin = [0,0, hdpx(10),0]
  flow = FLOW_HORIZONTAL
  gap = hdpx(10)
  valign = ALIGN_CENTER
  children = [
    textInput(filterTextInput, {
      placeholder = loc("search by name")
      textmargin = hdpx(5)
      margin = 0
      onChange = @(value) filterTextInput.set(value)
      onEscape = @() filterTextInput.set("")
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

function getRecipeName(recipe) {
  if (recipe?.name == null)
    return loc("unknown_item")

  if (recipe.name != "")
    return recipe.name

  let result = recipe.results.keys()[0]
  local templateName = result

  if (marketItems.get()?[result]) {
    let market = marketItems.get()[result]
    templateName = market.children.items[0].templateName
  }

  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
  let itemName = template.getCompValNullable("item__name")

  return itemName
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

return {
  selectedPrototype
  startReplication
  getRecipeMonolithUnlock
  selectedPrototypeMonolithData
  showMonolithMsgBox
  profileActionInProgress
  craftsReady
  craftMsgbox
  closeCraftWindow
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
}
