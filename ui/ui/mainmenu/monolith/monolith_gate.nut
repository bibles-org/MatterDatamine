from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { h2_txt, body_txt, h1_txt } = require("%ui/fonts_style.nut")
let { GreenSuccessColor, RedWarningColor, panelRowColor, TextDisabled,
  TextNormal, BtnBgNormal, BtnBgActive } = require("%ui/components/colors.nut")
let { mkText, mkSelectPanelItem, mkSelectPanelTextCtor, BD_LEFT, mkTextArea, panelParams
    } = require("%ui/components/commonComponents.nut")
let { mkFakeItem } = require("%ui/hud/menus/components/fakeItem.nut")
let { button } = require("%ui/components/button.nut")
let { accentButtonStyle } = require("%ui/components/accentButton.style.nut")
let { utf8ToUpper, startsWith, toIntegerSafe } = require("%sqstd/string.nut")
let faComp = require("%ui/components/faComp.nut")
let { marketItems, playerStats, playerProfileMonolithTokensCount, playerProfileAllResearchNodes,
  allCraftRecipes, playerProfileMonolithTokensCountUpdate } = require("%ui/profile/profileState.nut")
let { eventbus_send, eventbus_subscribe } = require("eventbus")
let { CmdRequestOnboardingBuyMonolithAccess, CmdShowUiMenu } = require("dasevents")
let { thinAndReservedPaddingStyle, makeVertScrollExt } = require("%ui/components/scrollbar.nut")
let { showMsgbox, showMessageWithContent } = require("%ui/components/msgbox.nut")
let { MT, monolithSelectedLevel, monolithLevelOffers, selectedMonolithUnlock, currentMonolithLevel } = require("monolith_common.nut")
let { sound_play } = require("%dngscripts/sound_system.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let { getLotFromItem, getBaseUpgradeFromItem } = require("%ui/mainMenu/market/inventoryToMarket.nut")
let { showItemInMarket } = require("%ui/hud/menus/components/inventoryItemUtils.nut")
let { isOnboarding, onboardingMonolithFirstLevelUnlocked } = require("%ui/hud/state/onboarding_state.nut")
let { creditsTextIcon, monolithTokensTextIcon } = require("%ui/mainMenu/currencyIcons.nut")
let { closeAllMenus } = require("%ui/hud/hud_menus_state.nut")
let { stashItems, backpackItems, inventoryItems, safepackItems } = require("%ui/hud/state/inventory_items_es.nut")
let { mkChronogeneDoll, getChronogeneFullBodyPresentation, mkMainChronogeneInfoStrings } = require("%ui/mainMenu/clonesMenu/clonesMenuCommon.nut")
let { addModalWindow, removeModalWindow } = require("%ui/components/modalWindows.nut")
let { smallInventoryImageParams, inventoryItemImage, largeInventoryImageParams } = require("%ui/hud/menus/components/inventoryItemImages.nut")
let { buildInventoryItemTooltip } = require("%ui/hud/menus/components/inventoryItemTooltip.nut")
let { hoverHotkeysWatchedList } = require("%ui/components/pcHoverHotkeyHitns.nut")
let { mkRarityIconByItem } = require("%ui/hud/menus/components/inventoryItemRarity.nut")
let { mkNotificationCircle } = require("%ui/mainMenu/notificationMark.nut")
let colorize = require("%ui/components/colorize.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { addPlayerLog, mkPurchaseLogData, mkPlayerLog, marketIconSize  } = require("%ui/popup/player_event_log.nut")
let { getRecipeIcon } = require("%ui/mainMenu/craftIcons.nut")
let { selectedPrototype, selectedCategory, scrollToRecipe } = require("%ui/mainMenu/craftSelection.nut")
let { getRecipeName } = require("%ui/mainMenu/craft_common_pkg.nut")
let { CRAFT_WND_ID } = require("%ui/mainMenu/researchAndCraft.nut")
let { glareAnimation, animChildren } = require("%ui/components/glareAnimation.nut")

let btnHeight = hdpx(50)
let checkIconHeight = hdpxi(20)
let statusIconWidth = hdpxi(50)
let suitRewardSize = [hdpxi(350), hdpxi(480)]
let iconParams = {
  width = hdpxi(60)
  height = hdpxi(35)
  transform = {}
  animations = []
  slotSize = [hdpxi(70), hdpxi(50)]
}
let buttonSize = [hdpx(200), hdpx(50)]
let smallRecipeIcon = [hdpx(25), hdpx(25)]

let unlockedButtonColor = Color(20, 40, 30, 165)
let unlockedButtonStyle = {
  BtnBgNormal = unlockedButtonColor
}

const MONOLITH_LEVEL_ID = "monolithLevelId"
const MONOLITH_REWARD_WND = "monolithRewardWnd"
const REWARD_SUIT_TPL = "suit_militant_light_b_prem_item" 
const SHOW_MONOLITH_ACTIVATE_BUTTON_ON_LEVEL = 11

let stashDevice = {
  offerName = "Stash"
  children = {
    baseUpgrades = ["Stash"]
  }
  requirements = {
    monolithAccessLevel = 1
  }
  rewardTemplate =  "unlock_base_upgrade_Stash"
  itemType = "immidiateAccessAfterLevelUnlocking"
}

let shegolskoe = {
  offerName = "Shegolskoe"
  children = {
    raid_unlock = ["shegolskoe"]
  }
  requirements = {
    monolithAccessLevel = 1
  }
  rewardTemplate = "unlock_contract_reward_unlock"
  itemType = "immidiateAccessAfterLevelUnlocking"
}

let money = {
  offerName = "Money"
  children = {
    currency = 10000
  }
  requirements = {
    monolithAccessLevel = 1
  }
  rewardTemplate = "unlock_credit_coins_pile"
  itemType = "immidiateAccessAfterLevelUnlocking"
}

let mkStatusIcon = @(icon, color) faComp(icon, {
  fontSize = checkIconHeight
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  color
})

let disabledStyle = {color = TextDisabled}.__update(body_txt)
let gap = hdpx(4)

function isRequirementsMet(data) {
  let statReq = data?.requirements.stats ?? {}
  foreach(gamemode, requirements in statReq) {
    let playerGamemodeStats = playerStats.get()?.statsCurrentSeason?[gamemode] ?? {}
    foreach (k, v in requirements) {
      if ((playerGamemodeStats?[k] ?? 0) < v)
        return false
    }
  }
  let unlocks = data?.requirements.unlocks ?? []
  foreach (unl in unlocks) {
    if (!playerStats.get().unlocks.contains(unl))
      return false
  }

  let requireAccessLevel = data?.requirements.monolithAccessLevel ?? 0
  if (currentMonolithLevel.get() < requireAccessLevel)
    return false

  return true
}

function getPriceInItems(level, inventory) {
  let itemPrices = level?.additionalPrice.items ?? {}
  let itemPricesArr = {}
  let itemsToCheck = inventory
  foreach (k, v in itemPrices) {
    let has = itemsToCheck.reduce(function(accumulator, item) {
      if (item?.itemTemplate == k) {
        accumulator++
      }
      return accumulator
    }, 0)
    itemPricesArr[k] <- {
      need = v
      has
    }
  }
  return itemPricesArr
}

function mkLevelRow(level, isUnlocked, accessGranted) {
  let text = mkSelectPanelTextCtor(loc("monolith/level", { level=loc(level.offerName) }),
    !isUnlocked && !accessGranted
      ? disabledStyle.__merge({ hplace = ALIGN_LEFT })
      : body_txt.__merge({ hplace = ALIGN_LEFT }))

  let levelCanBePurchased = (!isUnlocked && accessGranted) ?
    Computed(function() {
      if (isOnboarding.get() && !onboardingMonolithFirstLevelUnlocked.get()) {
        return true
      }

      let requirementsMet = isRequirementsMet(level)
      if (!requirementsMet) {
        return false
      }

      let price = level?.additionalPrice.monolithTokensCount ?? 0
      let itemPrice = getPriceInItems(level, [].extend(stashItems.get(),  inventoryItems.get(), backpackItems.get(), safepackItems.get()) )
      let enoughItems = itemPrice.findvalue(@(v) v.has < v.need) == null
      let notEnoughMoney = playerProfileMonolithTokensCount.get() < price || !enoughItems
      if (notEnoughMoney) {
        return false
      }

      return true
    }) : null

  return @(params) @() {
    watch = levelCanBePurchased
    size = [flex(), SIZE_TO_CONTENT]
    valign = ALIGN_CENTER
    gap
    flow = FLOW_HORIZONTAL
    children = [
      {
        behavior = Behaviors.Marquee
        size = [ flex(), SIZE_TO_CONTENT ]
        children = text(params)
      }
      isUnlocked ? mkStatusIcon("check", GreenSuccessColor) :
        !accessGranted ? mkStatusIcon("lock", TextDisabled) :
        !levelCanBePurchased?.get() ? null : {
          margin = hdpx(5)
          size = [ hdpx(12), hdpx(12) ]
          children = mkNotificationCircle()
        }
    ]
  }
}

function getUnlockLogData(monolithUnlockId, dataType, count) {
  if (type(monolithUnlockId) != "string" || !startsWith(monolithUnlockId, "unlock_"))
    return null
  let templateName = monolithUnlockId.replace("unlock_", "")
  let offerId = getLotFromItem({ itemTemplate = templateName })
  let itemMarketOffer = marketItems.get()?[offerId]
  let att = []
  for (local i=1; i < (itemMarketOffer?.children.items.len() ?? 0); i++)
    att.append(itemMarketOffer.children.items[i].templateName)
  let logData = mkPurchaseLogData(templateName, att, null, count)
  if (dataType == "item")
    logData.__update({
      titleFaIcon = "user"
      titleText = loc("item/received")
    })
  else
    logData.__update({
      titleFaIcon = "unlock"
      titleText = loc("monolith/itemUnlockedTooltip")
    })
  return logData
}

function showSpecificLog(id, dataType = "unlock", count = -1) {
  let playerLog = getUnlockLogData(id, dataType, count)
  if (playerLog == null)
    return
  addPlayerLog({
    id
    content = mkPlayerLog(playerLog)
  })
}

eventbus_subscribe("profile_server.profile_finish_onboarding_phase.result", function(res) {
  let { unlocks = [] } = res?.result.player_stats
  if (unlocks.contains("onboarding_finished")) {
    onboardingMonolithFirstLevelUnlocked.set(true)
    showSpecificLog(money.rewardTemplate, "item", money.children.currency)
    let playerLog = getUnlockLogData(shegolskoe.rewardTemplate, "unlock", 1)
      .__update({ bodyText = $"{loc("monolith/unlockAreaPrefix")} {loc(shegolskoe.children.raid_unlock[0])}"})
    addPlayerLog({
      id = shegolskoe.rewardTemplate
      content = mkPlayerLog(playerLog)
    })
    showSpecificLog(stashDevice.rewardTemplate)
  }
})

let unlockIdToBuy = Watched(null)
eventbus_subscribe("profile_server.buyLots.result", function(_) {
  let monolithUnlock = marketItems.get()?[unlockIdToBuy.get()?.tostring()]
  if (monolithUnlock != null) {
    let { items = [], unlocks = [], baseUpgrades = [], researchNodes = [] } = monolithUnlock.children

    foreach (item in items)
      showSpecificLog(item, "item")

    let unlocksList = [].extend(baseUpgrades, unlocks)
    foreach (unlock in unlocksList) {
      if (unlock == "MonolithAccessLevel")
        addPlayerLog({
          id = monolithUnlock.offerName
          content = mkPlayerLog({
            titleFaIcon = "unlock"
            titleText = loc("monolith/itemUnlockedTooltip")
            bodyText = $"{loc("monolith/unlocked")}: {loc(monolithUnlock.offerName)}"
          })
        })
      else
        showSpecificLog(unlock)
    }
    foreach (research in researchNodes) {
      let recipe = allCraftRecipes.get()[research]
      addPlayerLog({
        id = research
        content = mkPlayerLog({
          titleFaIcon = "unlock"
          titleText = loc("monolith/itemUnlockedTooltip")
          bodyIcon = {
            size = iconParams.slotSize
            halign = ALIGN_CENTER
            vplace = ALIGN_CENTER
            children = getRecipeIcon(research, [smallInventoryImageParams.width, marketIconSize[1]])
          }
          bodyText = $"{loc("monolith/unlocked")}: {loc(getRecipeName(recipe))}"
        })
      })
    }
  }
  unlockIdToBuy.set(null)
})

let visual_params = {
  size = [flex(), hdpx(55)]
  valign = ALIGN_CENTER
}

let levelsList = @(list){
  size = [hdpx(377), flex()]
  children = makeVertScrollExt({
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = hdpx(2)
    children = list.map(@(v, idx) function() {
      local isUnlocked = false
      if (isOnboarding.get())
        isUnlocked = onboardingMonolithFirstLevelUnlocked.get() && monolithSelectedLevel.get() == 0
      else
        isUnlocked = playerStats.get()?.purchasedUniqueMarketOffers.findindex(@(offer) offer.tostring() == v.offerId) != null

      let accessGranted = v.requirements.monolithAccessLevel <= currentMonolithLevel.get()
      let level = idx

      return {
        watch = currentMonolithLevel
        children = mkSelectPanelItem({
          visual_params = visual_params.__merge(isUnlocked ? const { style=unlockedButtonStyle } : const {})
          children = mkLevelRow(v, isUnlocked, accessGranted)
          idx = level
          state = monolithSelectedLevel
          onSelect = @(lvl) monolithSelectedLevel.set(lvl)
          border_align = BD_LEFT
        })
      }.__update(visual_params)
    })
  }, { size = flex() })
}

let mkUnlockItemName = @(name) mkText(loc(name), {
  size = [ flex(), SIZE_TO_CONTENT ]
  behavior = Behaviors.Marquee
  scrollOnHover = false
  speed = hdpx(50)
  margin = [0, hdpx(4),0,0]
}.__update(body_txt))

function mkRequirementText(cur, needed, locId) {
  let color = cur >= needed ? GreenSuccessColor : RedWarningColor
  return mkText(loc(locId, { cur, needed }), { color })
}

function goToCraft(id) {
  selectedCategory.set(null)
  selectedPrototype.set(id)
  scrollToRecipe.set(id)
  ecs.g_entity_mgr.broadcastEvent(CmdShowUiMenu({menuName = CRAFT_WND_ID}))
}

function mkRecipeIcon(prototypeId) {
  let recipeId = playerProfileAllResearchNodes.get()[prototypeId].containsRecipe
  let recipe = allCraftRecipes.get()[recipeId]
  return button(@() {
    watch = [playerProfileAllResearchNodes, allCraftRecipes]
    padding = hdpx(1)
    children = getRecipeIcon(recipeId, smallRecipeIcon),
  }, @() goToCraft(prototypeId),
  {
    onHover = @(on) setTooltip(on ? loc("research/craftRecipeResult", { name = loc(getRecipeName(recipe)) } ) : null)
    stopHover = true
    hplace = ALIGN_LEFT
    pos = [-hdpx(7), hdpx(3)]
  })
}

function mkUnlockRow(levelUnlocked, unlockOffer) {
  local itemMarketOffer = null

  local itemNamePrefix = unlockOffer?.itemNamePrefixOverride
  local tooltipOnBuyButton = ""
  let mkUnlockFakeItem = @(template, attachments=null, additional={}) mkFakeItem(template, {
    backgoundDisabled = true
  }.__update(additional), attachments)
  local fake = null
  local itemName = null
  local recipeAdditionalIcon = null
  local key = null

  if (unlockOffer?.children.unlocks.len()) {
    let templateName = unlockOffer.children.unlocks[0].replace("unlock_", "")
    let offerId = getLotFromItem({ itemTemplate = templateName })
    itemMarketOffer = marketItems.get()?[offerId]
    let att = []
    for (local i=1; i < (itemMarketOffer?.children.items.len() ?? 0); i++){
      att.append(itemMarketOffer.children.items[i].templateName)
    }

    fake = mkUnlockFakeItem(templateName, att)

    itemNamePrefix = itemNamePrefix ?? loc("monolith/unlockPrefix")
    tooltipOnBuyButton = loc("monolith/butButtonTooltip/getAccessToUnlock")
    if ((unlockOffer.children?.researchNodes ?? []).len() > 0) {
      let prototypeId = unlockOffer.children.researchNodes[0]
      recipeAdditionalIcon = mkRecipeIcon(prototypeId)
      itemNamePrefix = loc("monolith/unlockItemBlueprintPrefix")
    }
    key = unlockOffer.children.unlocks[0]
  }
  else if (unlockOffer?.children.baseUpgrades.len()) {
    let templateName = $"base_upgrade_{unlockOffer.children.baseUpgrades[0]}"
    fake = mkUnlockFakeItem(templateName)
    let offerId = getBaseUpgradeFromItem({ itemTemplate = unlockOffer.children.baseUpgrades[0] })
    itemMarketOffer = marketItems.get()?[offerId]
    itemNamePrefix = itemNamePrefix ?? loc("monolith/baseUpgradePrefix")
    tooltipOnBuyButton = loc("monolith/butButtonTooltip/upgradeBase")

    key = unlockOffer.children.baseUpgrades[0]
  }
  else if (unlockOffer?.children.items.len()){
    let templateName = unlockOffer?.children.items[0].templateName
    fake = mkUnlockFakeItem(templateName)
    itemNamePrefix = itemNamePrefix ?? loc("monolith/itemPrefix")
    tooltipOnBuyButton = loc("monolith/butButtonTooltip/getItem")

    key = unlockOffer.children.items[0]
  }
  else if (unlockOffer?.children.raid_unlock.len()) {
    let templateName = "contract_reward_unlock"
    fake = mkUnlockFakeItem(templateName, null, { itemName = unlockOffer.children.raid_unlock[0]})
    itemNamePrefix = itemNamePrefix ?? loc("monolith/unlockAreaPrefix")
  }
  else if ((unlockOffer?.children.currency ?? 0) > 0) {
    let templateName = "credit_coins_pile"
    fake = mkUnlockFakeItem(templateName)
    itemNamePrefix = itemNamePrefix ?? loc("monolith/creditsPrefix")
    itemName = $"{creditsTextIcon}{unlockOffer?.children.currency.tostring()}"
  }
  else if ((unlockOffer?.children.researchNodes ?? []).len() > 0) {
    let prototypeId = unlockOffer.children.researchNodes[0]
    let recipeId = playerProfileAllResearchNodes.get()[prototypeId].containsRecipe
    let recipe = allCraftRecipes.get()[recipeId]
    let templateOrId = recipe.results.keys()[0]
    let marketLotId = toIntegerSafe(templateOrId, 0, false)
    let marketLot = marketItems.get()?[templateOrId].children.items
    let templateName = marketLotId == 0 ? templateOrId : marketLot?[0].templateName ?? ""
    itemMarketOffer = marketLotId
    fake = mkUnlockFakeItem(templateName).__update({
      tooltip = loc("amCleaner/recipe", { name = getRecipeName(recipe) })
      goTo = goToCraft
      id = prototypeId
      iconToUse = {
        size = iconParams.slotSize
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        children = getRecipeIcon(recipeId, [iconParams.width, iconParams.height])
      }
    })
    itemNamePrefix = itemNamePrefix ?? loc("monolith/unlockPrefix")
    itemName = loc(getRecipeName(recipe))
    key = prototypeId
  }
  else {
    itemNamePrefix = itemNamePrefix ?? ""
  }

  
  local unlockText = ""
  let additionalRequirements = unlockOffer?.requirements.unlocks ?? []
  if (additionalRequirements.len() > 0) {
    foreach (unlock in additionalRequirements) {
      let hasUnlock = (playerStats.get()?.unlocks.findindex(@(v) unlock == v) != null)
      if (!hasUnlock) {
        unlockText = $"{unlockText}\n{loc($"stats/{unlock}")}"
      }
    }
  }
  let canBePurchased = Computed(function() {
    if (!additionalRequirements.len())
      return true

    let unlocks = playerStats.get()?.unlocks ?? []
    foreach (unlock in additionalRequirements) {
      let hasUnlock = (unlocks.findindex(@(v) unlock == v) != null)
      if (!hasUnlock)
        return false
    }
    return true
  })

  let itemIcon = fake?.iconToUse ? fake.iconToUse
    : fake ? inventoryItemImage(fake, iconParams)
    : null
  if (!itemName)
    itemName = loc(fake?.itemName)

  let buyOnLvlUnlock = unlockOffer?.itemType == "immidiateAccessAfterLevelUnlocking"
  let price = unlockOffer?.additionalPrice.monolithTokensCount ?? 0

  let offerBought = Computed(@()
    (playerStats.get()?.purchasedUniqueMarketOffers.findindex(@(v) unlockOffer?.offerId != null && v.tostring() == unlockOffer.offerId) != null) ||
    (buyOnLvlUnlock && levelUnlocked)
  )
  let showPrice = Computed(@() price != 0 && !offerBought.get() && levelUnlocked && canBePurchased.get() )

  function resetSelectedMonolithUnlock() {
    if (key == selectedMonolithUnlock.get())
      selectedMonolithUnlock.set("")
  }

  function showMsgboxItemInfo() {
    hoverHotkeysWatchedList.set(null)
    showMessageWithContent({
      content = {
        size = SIZE_TO_CONTENT
        flow = FLOW_VERTICAL
        halign = ALIGN_CENTER
        gap = hdpx(10)
        children = [
          inventoryItemImage(fake, largeInventoryImageParams)
          buildInventoryItemTooltip(fake)
        ]
      }
    })
  }

  function goToMarket() {
    if (itemMarketOffer == null || (unlockOffer?.children.baseUpgrades.len() ?? 0) > 0) {
      showMsgboxItemInfo()
      return
    }
    if (isOnboarding.get()) {
      showMsgbox(
        {text=loc("notAvailableYet"),
        buttons = [
          { text = loc("mainmenu/btnBack"), isCancel = true }
        ]
      })
    }
    else
      showItemInMarket( { itemTemplate = itemMarketOffer?.children.items[0].templateName })
  }

  function buyItem() {
    if (unlockIdToBuy.get() != null)
      return
    if (offerBought.get()) {
      if (fake?.goTo != null)
        fake?.goTo(fake.id)
      else
        goToMarket()
      return
    }
    if (!levelUnlocked || !canBePurchased.get()) {
      sound_play("ui_sounds/button_exit")
      let showItemName = itemName == null ? "" : itemName
      if (unlockText != "")
        showMsgbox({ text = loc("monolith/unlockReq", { unlock = unlockText, item = showItemName}) })
      else
        showMsgbox({ text = loc("monolith/itemRequiresMonolithLevel") })
    }
    else if (playerProfileMonolithTokensCount.get() < price) {
      sound_play("ui_sounds/button_exit")
      anim_start($"currency_panel_{monolithTokensTextIcon}")
      anim_start($"not_enough_money_{monolithTokensTextIcon}")
      showMsgbox({text=loc("monolith/notEnoughMonolithTokens")})
    }
    else {
      anim_start($"currency_panel_{monolithTokensTextIcon}")
      sound_play("ui_sounds/mark_item_3d")
      eventbus_send("profile_server.buyLots", [ { id = unlockOffer.offerId, count = 1 } ])
      unlockIdToBuy.set(unlockOffer.offerId)
    }
  }

  let infoButton = @() {
    watch = offerBought
    size = flex()
    children = button(mkStatusIcon("info", TextNormal),
      function() {
        if (fake?.goTo != null)
          fake.goTo(fake.id)
        else
          goToMarket()
      }
      {
        size = flex()
        style = offerBought.get() ? unlockedButtonStyle : null
        onHover = function(on) {
          setTooltip(on ? fake?.tooltip ?? buildInventoryItemTooltip(fake) : null)
          hoverHotkeysWatchedList.set(on ? [{
            hotkeys = ["LMB"]
            locId = itemMarketOffer != null ? "inventory/toMarket" : "inventory/info"
            order = 0
            showInTooltip = true
          }] : null)

          resetSelectedMonolithUnlock()
        }
      }
    )
  }

  function getTooltip(watch = [], buyPrice = 0) {
    let priceColor = buyPrice > 0 && playerProfileMonolithTokensCount.get() <= buyPrice
      ? RedWarningColor
      : GreenSuccessColor
    let getUnlockText = @() offerBought.get() ? colorize(GreenSuccessColor, loc("monolith/itemUnlockedTooltip"))
      : !levelUnlocked ? colorize(RedWarningColor, loc("monolith/itemRequiresMonolithLevelTooltip"))
      : canBePurchased.get() ? colorize(priceColor, loc($"{tooltipOnBuyButton} {MT}{price}"))
      : colorize(RedWarningColor, loc("monolith/unlockReq/hint", { unlock = unlockText }))

    return @(){
      watch
      children = buildInventoryItemTooltip(fake.__merge({ additionalDesc = [ getUnlockText() ] }))
    }
  }

  let buttonItemName = itemMarketOffer != null || unlockOffer?.itemType == "chronogene"
    ? @() {
        watch = [ showPrice, offerBought, canBePurchased ]
        size = flex()
        children = button ({
          size = flex()
          children = [
            mkRarityIconByItem(fake)
            {
              size = flex()
              valign = ALIGN_CENTER
              flow = FLOW_HORIZONTAL
              gap = hdpx(5)
              padding = [ 0, hdpx(10) ]
              children = [
                {
                  children = [
                    recipeAdditionalIcon
                    itemIcon
                  ]
                },
                itemName == null ? null : mkUnlockItemName($"{itemNamePrefix} {itemName}"),
                showPrice.get() ? mkText($"{MT} {price}", body_txt) : null,
                (!canBePurchased.get() || !levelUnlocked) ? mkStatusIcon("lock", RedWarningColor) : null
              ]
            }
          ]
        },
          buyItem,
        {
          style = offerBought.get() ? unlockedButtonStyle : null
          size = flex()
          onHover = function(on) {
            setTooltip(on ? getTooltip([offerBought, playerProfileMonolithTokensCount], price) : null)
            resetSelectedMonolithUnlock()

            hoverHotkeysWatchedList.set(on ? [{
              hotkeys = ["LMB"]
              locId = offerBought.get() ? "inventory/toMarket" : "monolith/butButtonTooltip/getAccessToUnlock"
              order = 0
              showInTooltip = true
            }] : null)
          }
        })
      }
    : @() {
        watch = [ showPrice, offerBought, canBePurchased ]
        rendObj = ROBJ_SOLID
        size = flex()
        color = offerBought.get() ? unlockedButtonColor : BtnBgNormal
        behavior = Behaviors.Button
        onHover = function(on) {
          setTooltip(on ? getTooltip() : null)
          resetSelectedMonolithUnlock()
        }
        children = [
          mkRarityIconByItem(fake)
          {
            valign = ALIGN_CENTER
            padding = [ 0, hdpx(10) ]
            flow = FLOW_HORIZONTAL
            gap = hdpx(5)
            size = flex()
            children = [
              itemIcon,
              itemName == null ? null : mkUnlockItemName($"{itemNamePrefix} {itemName}"),
              showPrice.get() ? mkText($"{MT} {price}", body_txt) : null,
              (!canBePurchased.get() || !levelUnlocked) ? mkStatusIcon("lock", RedWarningColor) : null
            ]
          }
        ]
      }

  return @() {
    watch = [ canBePurchased, offerBought ]
    size = [flex(), smallInventoryImageParams.slotSize[1] ]
    valign = ALIGN_CENTER
    onDetach = @() resetSelectedMonolithUnlock()
    children = [
      {
        gap = hdpx(4)
        size = flex()
        flow = FLOW_HORIZONTAL
        children = [
          buttonItemName
          {
            rendObj = ROBJ_SOLID
            size = [ statusIconWidth, flex() ]
            color = offerBought.get() ? unlockedButtonColor : panelRowColor
            valign = ALIGN_CENTER
            children = infoButton
          }
        ]
      }
      function() {
        if (selectedMonolithUnlock.get() != key)
          return { watch = selectedMonolithUnlock }
        return {
          watch = selectedMonolithUnlock
          rendObj = ROBJ_BOX
          size = flex()
          borderColor = BtnBgActive
          borderWidth = hdpx(2)
          animations = [{ prop=AnimProp.opacity, from=0.2, to=1, duration=2, easing=CosineFull, play=true, loop=true }]
          clipChildren = true
          children = animChildren(glareAnimation())
        }
      }
    ]
  }.__merge(key ? { key } : {}) 
}

function fillUnlockBlock(isLevelUnlocked, list, title, appendTo) {
  if (!list?.len())
    return

  appendTo.append(mkText(title, { margin = appendTo.len() > 0
    ? [hdpx(14), 0, hdpx(10), 0]
    : [0, 0, hdpx(10), 0] }.__update(h2_txt)))

  foreach (unl in list) {
    appendTo.append(mkUnlockRow(isLevelUnlocked, unl))
  }
}

function getRequirementsBlock(data) {
  let statReq = data?.requirements.stats ?? {}
  let plStat = playerStats.get()?.statsCurrentSeason ?? {}
  let stats = []
  foreach (k1, v1 in statReq) {
    let inner = plStat?[k1] ?? {}
    foreach (k2, v2 in v1) {
      stats.append(mkRequirementText(inner?[k2] ?? 0, v2, $"monolith/{k1}/{k2}"))
    }
  }
  let unlocks = data?.requirements.unlocks ?? []
  let unlockStrings = unlocks.map(function(v) {
    let color = playerStats.get().unlocks.contains(v) ? GreenSuccessColor : RedWarningColor
    return mkText(loc($"stats/{v}"), { color })
  })
  let requireAccessLevel = (data?.requirements.monolithAccessLevel ?? 0)

  let accessColor = currentMonolithLevel.get() >= requireAccessLevel
    ? GreenSuccessColor
    : RedWarningColor
  let requireAccessLevelStrings = requireAccessLevel <= 0 ? null
    : mkText(loc($"monolith/level" { level = loc(monolithLevelOffers.get()?[requireAccessLevel-1].offerName) }),
        { color = accessColor })

  return [requireAccessLevelStrings].extend(
    unlockStrings
    stats).filter(@(v) v != null)
}

function getAdditionalPriceBlock(data, inventory) {
  let price = getPriceInItems(data, inventory)

  let childrens = []
  foreach (itemTemplateName, val in price) {
    let itemTempl = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(itemTemplateName)
    let itemLoc = itemTempl?.getCompValNullable("item__name") ?? "unknown"

    let color = val.need <= val.has ? GreenSuccessColor : RedWarningColor
    childrens.append(
      mkText($"{loc(itemLoc)} ({val.has}/{val.need})", { color })
    )
  }
  return childrens
}

function mkRequirementsBlock(data) {
  let req = getRequirementsBlock(data)

  return {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      {
        flow = FLOW_VERTICAL
        size = [ flex(), SIZE_TO_CONTENT ]
        children = [
          req.len() ? mkText(loc("monolith/requirements")) : null
          req.len() ? {
            size = [flex(), SIZE_TO_CONTENT]
            flow = FLOW_VERTICAL
            children = req
          } : null
        ]
      }.__merge(panelParams)
      function() {
        let watch = [stashItems, backpackItems, inventoryItems, safepackItems]
        let additionalPrice = getAdditionalPriceBlock(data, [].extend(stashItems.get(), backpackItems.get(), inventoryItems.get(), safepackItems.get()) )
        if (additionalPrice.len() <= 0)
          return { watch }
        return {
          watch
          flow = FLOW_VERTICAL
          size = [ flex(), SIZE_TO_CONTENT ]
          children = [
            mkText(loc("monolith/additionalPrice"))
            {
              size = [ flex(), SIZE_TO_CONTENT ]
              flow = FLOW_VERTICAL
              children = additionalPrice
            }
          ]
        }.__merge(panelParams)
      }
    ]
  }
}

let mkNextLevelButton = @(levelData) function() {
  local lvlBought = false
  if (isOnboarding.get()) {
    lvlBought = onboardingMonolithFirstLevelUnlocked.get() && monolithSelectedLevel.get() == 0
  }
  else {
    lvlBought = playerStats.get()?.purchasedUniqueMarketOffers.findindex(@(v) v.tostring() == levelData.offerId) != null
  }
  let requireAccessLevel = (levelData?.requirements.monolithAccessLevel ?? 0)
  let lvlAvailable = requireAccessLevel <= currentMonolithLevel.get()
  let price = levelData?.additionalPrice.monolithTokensCount ?? 0

  let itemPrice = getPriceInItems(levelData, [].extend(stashItems.get(), inventoryItems.get(), backpackItems.get(), safepackItems.get()) )
  let enoughItems = itemPrice.findvalue(@(v) v.has < v.need) == null

  let notEnoughMoney = playerProfileMonolithTokensCount.get() < price || !enoughItems
  let requirementsMet = isRequirementsMet(levelData)

  let isAccentButton = !(lvlBought || notEnoughMoney || !lvlAvailable || !requirementsMet)

  let priceStrings = $"{MT} {price}"

  let notBoughtComp =  {
    flow = FLOW_VERTICAL
    gap = hdpx(4)
    halign = ALIGN_CENTER
    children = [
      mkText(utf8ToUpper(loc("monolith/nextLevel")), {
        fontFx = null
      }.__update(h2_txt))
      !lvlAvailable ? null
        : mkText(priceStrings, {
            fontFx = null
          }.__update(h2_txt))
    ]
  }
  let boughtComp = {
    flow = FLOW_HORIZONTAL
    gap = hdpx(4)
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      mkText(loc("monolith/unlocked"), { color = GreenSuccessColor }.__update(h2_txt))
      mkStatusIcon("check", GreenSuccessColor)
    ]
  }
  return {
    watch = [playerStats, stashItems, backpackItems, inventoryItems, safepackItems, currentMonolithLevel]
    size = [ flex(), hdpx(94) ]
    children = button(
      lvlBought ? boughtComp : notBoughtComp
      function() {
        if (lvlBought)
          showMsgbox({text=loc("monolith/levelAlreadyUnlocked")})
        else if (!requirementsMet)
          showMsgbox({text=loc("monolith/requirementsNotMetMsgbox")})
        else if (!enoughItems)
          showMsgbox({text=loc("monolith/notEnoughItems")})
        else if (notEnoughMoney)
          showMsgbox({text=loc("monolith/notEnoughMonolithTokens")})
        else {
          if (unlockIdToBuy.get() != null)
            return
          sound_play("am/ui/base_activation_start")
          if (isOnboarding.get()) {
            playerProfileMonolithTokensCountUpdate((playerProfileMonolithTokensCount.get() ?? 0) - price)
            ecs.g_entity_mgr.broadcastEvent(CmdRequestOnboardingBuyMonolithAccess())
          }
          else {
            eventbus_send("profile_server.buyLots", [ { id = levelData.offerId, count = 1 } ])
            unlockIdToBuy.set(levelData.offerId)
          }
        }
      },
      {
        isEnabled = !lvlBought
        size = [ flex(), hdpx(94) ]
        borderWidth = lvlBought ? 0 : hdpx(1)
        halign = ALIGN_CENTER
        vplace = ALIGN_BOTTOM
      }.__update( isAccentButton ? accentButtonStyle : {} )
    )
  }
}


let mkLevelInteractiveBlock = @(levelData) @() {
  watch = [ playerStats, onboardingMonolithFirstLevelUnlocked, stashItems ]
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  gap = hdpx(6)
  vplace = ALIGN_BOTTOM
  halign = ALIGN_RIGHT
  children = [
    mkRequirementsBlock(levelData)
    mkNextLevelButton(levelData)
  ]
}

let mkLevelImage = memoize(@(isLastLevel) {
  rendObj = ROBJ_IMAGE
  size = flex()
  imageValign = ALIGN_TOP
  imageHalign = ALIGN_CENTER
  keepAspect = KEEP_ASPECT_FILL
  image = Picture(isLastLevel
    ? "ui/gate_portal_thumbnails/gate_to_monolith_opened.avif"
    : "ui/gate_portal_thumbnails/gate_to_monolith_activated.avif"
  )
})

function levelImage() {
  let level = monolithSelectedLevel.get()
  let levels = monolithLevelOffers.get()
  let isLastLevel = level!=null && (level+1)==levels?.len()
  return {
    watch = [monolithSelectedLevel, monolithLevelOffers]
    size = flex()
    children = mkLevelImage(isLastLevel)
  }
}

let rightPanelSize = hdpx(600)

function mkLevelBlock(level, levels) {
  let data = levels?[level]
  
  return {
    size = [rightPanelSize, flex()]
    children = [
      
      mkLevelInteractiveBlock(data)
    ]
  }
}

let unlocksList = @(list, levels) function() {
  if ((list?.len() ?? 0) == 0)
    return { watch = monolithSelectedLevel }

  let level = levels[monolithSelectedLevel.get()]

  let isLevelUnlocked = isOnboarding.get() ?
    (onboardingMonolithFirstLevelUnlocked.get() && monolithSelectedLevel.get() == 0) :
    playerStats.get()?.purchasedUniqueMarketOffers.findindex(@(v) v.tostring() == level.offerId) != null

  let currentList = list[monolithSelectedLevel.get()]
  let unlockOffers = []
  let itemOffers = []
  let baseUpgradeOffers = []
  let immidiateAccessAfterLevelUnlocking = []
  foreach (offer in currentList) {
    if (offer?.itemType == "baseUpgrades")
      baseUpgradeOffers.append(offer)
    else if (offer?.itemType == "unlock")
      unlockOffers.append(offer)
    else if (offer?.itemType == "chronogene")
      itemOffers.append(offer)
    else if (offer?.itemType == "immidiateAccessAfterLevelUnlocking")
      immidiateAccessAfterLevelUnlocking.append(offer)
  }

  let unlocksArr = []
  let sortOffers = @(a, b) ((a?.levelSorting ?? 0) <=> (b?.levelSorting ?? 0) || a.offerId <=> b.offerId)
  fillUnlockBlock(isLevelUnlocked, immidiateAccessAfterLevelUnlocking, loc("monolith/immidiateAccessAfterLevelUnlockingBlock"), unlocksArr)
  fillUnlockBlock(isLevelUnlocked, unlockOffers.sort(sortOffers), loc("monolith/unlockBlock"), unlocksArr)
  fillUnlockBlock(isLevelUnlocked, itemOffers.sort(sortOffers), loc("monolith/itemBlock"), unlocksArr)
  fillUnlockBlock(isLevelUnlocked, baseUpgradeOffers.sort(sortOffers), loc("monolith/baseUpgradeBlock"), unlocksArr)

  let scrollHandler = ScrollHandler()

  return {
    watch = [ monolithSelectedLevel, onboardingMonolithFirstLevelUnlocked, currentMonolithLevel ]
    size = flex()
    flow = FLOW_HORIZONTAL
    gap = hdpx(20)
    onAttach = @() scrollHandler.scrollToChildren(@(desc) desc?.key == selectedMonolithUnlock.get(), 2, false, true)
    children = [
      makeVertScrollExt({
        size = [ flex(), SIZE_TO_CONTENT ]
        flow = FLOW_VERTICAL
        gap = hdpx(4)
        children = unlocksArr
      }, {
        scrollHandler
        size = flex()
        styling = thinAndReservedPaddingStyle
      })
      mkLevelBlock(monolithSelectedLevel.get(), levels)
    ]
  }
}

let corticalVaultsQuery = ecs.SqQuery("cortical_vaults_status_ui_query", {
  comps_rq = ["onboarding_state_machine"]
})

function activateMonolith() {
  let alreadyActivated = corticalVaultsQuery.perform(@(_evt, _comps) true)

  if (alreadyActivated)
    return

  ecs.g_entity_mgr.createEntity("onboarding_state_machine", {})
  closeAllMenus()
  removeModalWindow(MONOLITH_REWARD_WND)
}

let acceptMonolithBtn = button(
  mkText(loc("monolith/letsGoToTheMonolith/msgbox/ok"), {
    fontFx = null
  }.__update(body_txt)),
  activateMonolith,
  {
    size = buttonSize
    halign = ALIGN_CENTER
  }.__update(accentButtonStyle)
)

let mkCloseMonolithBtn = @(text) button(
  mkText(text, { fontFx = null }.__update(body_txt)),
  @() removeModalWindow(MONOLITH_REWARD_WND),
  {
    size = buttonSize
    halign = ALIGN_CENTER
    hotkeys = [[$"^{JB.B} | Esc", { description = loc("Cancel") }]]
  }
)

function blueDoorBlock() {
  let alterReward = mkFakeItem(REWARD_SUIT_TPL)
  let { iconName, templateName } = alterReward
  let isUnlocked = playerStats.get()?.unlocks.contains("unlock_monolith_gate")
  return {
    watch = playerStats
    rendObj = ROBJ_WORLD_BLUR_PANEL
    size = flex()
    color = Color(200,200,200,200)
    fillColor = Color(0,0,7,102)
    halign = ALIGN_CENTER
    padding = hdpx(20)
    flow = FLOW_VERTICAL
    children = [
      {
        size = flex()
        flow = FLOW_HORIZONTAL
        gap = hdpx(10)
        children = [
          {
            size = suitRewardSize
            flow = FLOW_VERTICAL
            gap = hdpx(20)
            halign = ALIGN_CENTER
            children = [
              mkChronogeneDoll(iconName, suitRewardSize,
                getChronogeneFullBodyPresentation(templateName).__update({ iconScale = 1.1 }))
              mkMainChronogeneInfoStrings(alterReward, { halign = ALIGN_CENTER }, true)
            ]
          }
          mkTextArea(loc("monolith/blueDoorDesc"), {
            halign = ALIGN_RIGHT
            pos = [0, hdpx(20)]
          }.__update(body_txt))
        ]
      }
      mkTextArea(loc("monolith/fullResetWarning"),
        {
          color = isUnlocked ? RedWarningColor : TextNormal
          halign = ALIGN_CENTER
        }.__update(h2_txt))
    ]
  }
}

let redDoorBlock = function() {
  let isUnlocked = playerStats.get()?.unlocks.contains("unlock_monolith_gate")
  return {
    rendObj = ROBJ_WORLD_BLUR_PANEL
    size = flex()
    color = Color(200,200,200,200)
    fillColor = Color(7,0,0,102)
    halign = ALIGN_CENTER
    padding = hdpx(20)
    flow = FLOW_VERTICAL
    gap = hdpx(20)
    children = [
      {
        size = flex()
        flow = FLOW_HORIZONTAL
        gap = hdpx(10)
        children = [
          mkTextArea(loc("monolith/redDoorDesc"), {
            pos = [0, hdpx(20)]
          }.__update(body_txt))
          {
            rendObj = ROBJ_IMAGE
            pos = [0, hdpx(28)]
            size = suitRewardSize
            image = Picture("ui/monolithLbReward.avif")
          }
        ]
      }
      mkTextArea(loc("monolith/leaderboardEnteringWarning"),
      {
        color = isUnlocked ? RedWarningColor : TextNormal
        halign = ALIGN_CENTER
      }.__update(h2_txt))
    ]
  }
}

function monolithActivationMessagebox() {
  return addModalWindow({
    rendObj = ROBJ_SOLID
    size = flex()
    key = MONOLITH_REWARD_WND
    color = Color(20, 20, 20)
    onClick = @() null
    halign = ALIGN_CENTER
    flow = FLOW_VERTICAL
    padding = fsh(3)
    gap = hdpx(40)
    children = [
      mkTextArea(loc("monolith/activationTitle"), { halign = ALIGN_CENTER }.__update(h1_txt))
      mkTextArea(loc("monolith/activationDesc"), { halign = ALIGN_CENTER }.__update(h2_txt))
      {
        size = flex()
        halign = ALIGN_CENTER
        flow = FLOW_HORIZONTAL
        gap = hdpx(30)
        children = [
          blueDoorBlock
          redDoorBlock
        ]
      }
      function() {
        let isUnlocked = playerStats.get()?.unlocks.contains("unlock_monolith_gate")
        return {
          watch = playerStats
          size = [flex(), SIZE_TO_CONTENT]
          halign = ALIGN_CENTER
          flow = FLOW_VERTICAL
          gap = hdpx(30)
          children = [
            {
              flow = FLOW_HORIZONTAL
              gap = hdpx(30)
              children = !isUnlocked ? mkCloseMonolithBtn(loc("Ok")) : [
                mkCloseMonolithBtn(loc("monolith/letsGoToTheMonolith/msgbox/cancel"))
                acceptMonolithBtn
              ]
            }
          ]
        }
      }
    ]
  })
}

function letsGoToTheMonolithButton() {
  let accessLevel = currentMonolithLevel.get()
  let isUnlocked = playerStats.get()?.unlocks.contains("unlock_monolith_gate")
  let hasAlreadyOpenedMonolith = playerStats.get()?.unlocks.contains("unlock_monolith_path_choosed") ?? false
  let watch = [ playerStats, currentMonolithLevel ]
  if (hasAlreadyOpenedMonolith || (accessLevel < SHOW_MONOLITH_ACTIVATE_BUTTON_ON_LEVEL && !isUnlocked))
    return { watch }
  let buttonStyle = isUnlocked ? accentButtonStyle : {}

  return {
    watch
    size = [ flex(), SIZE_TO_CONTENT ]
    children = button({
        hplace = ALIGN_CENTER
        vplace = ALIGN_CENTER
        children = mkText(loc("monolith/letsGoToTheMonolithButton"), { fontFx = null }.__update(h2_txt))
        padding = [ hdpx(20), hdpx(5) ]
      },
      monolithActivationMessagebox, {
        size = [ flex(), SIZE_TO_CONTENT ]
      }.__update(buttonStyle)
    )
  }
}

function monolithGateUi() {
  let levelsArr = monolithLevelOffers.get()

  let monolithOffers = [].resize(levelsArr.len(), null).map(@(_) [])

  foreach (k, v in marketItems.get()) {
    let accessLevel = v?.requirements.monolithAccessLevel ?? 0
    if (accessLevel <= 0)
      continue

    let unlocking = v?.children.baseUpgrades ?? []
    if (unlocking.contains("MonolithAccessLevel")) {
      foreach (unl in v?.children.unlocks ?? []) {
        monolithOffers[accessLevel].append({
          offerName = loc(unl)
          children = {
            unlocks = [ unl ]
          }
          requirements = {
            monolithAccessLevel = accessLevel + 1
          }
          itemType = "immidiateAccessAfterLevelUnlocking"
          
          
          
          tooltipOverride = loc("monolith/accessToAgencyContract")
          itemNamePrefixOverride = ""
        })
      }
      continue
    }

    monolithOffers[accessLevel-1].append(v.__merge({offerId = k}))
  }

  if (monolithOffers?[0])
    monolithOffers[0].append(money, shegolskoe, stashDevice)

  let offers =  @() {
    watch = monolithLevelOffers
    size = flex()
    flow = FLOW_VERTICAL
    gap = hdpx(20)
    children = [
      {
        size = [flex(), btnHeight]
        valign = ALIGN_CENTER
        children = mkText(loc("monolith/gateTitle"), h2_txt)
      }
      {
        size = flex()
        flow = FLOW_HORIZONTAL
        gap = hdpx(20)
        children = [
          {
            flow = FLOW_VERTICAL
            size = [hdpx(377), flex()]
            gap = hdpx(20)
            children = [
              levelsList(levelsArr)
              letsGoToTheMonolithButton
            ]
          }
          unlocksList(monolithOffers, levelsArr)
        ]
      }
    ]
  }

  return {
    size = flex()
    children = [
      {hplace = ALIGN_RIGHT halign = ALIGN_CENTER size = [rightPanelSize, hdpx(670)] children = levelImage }
      offers
    ]
  }
}

return {
  monolithGateUi
  MONOLITH_LEVEL_ID
  isRequirementsMet
  getPriceInItems
}
