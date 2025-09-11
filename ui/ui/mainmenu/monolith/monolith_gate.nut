from "%dngscripts/sound_system.nut" import sound_play
from "%sqstd/string.nut" import utf8ToUpper, startsWith
from "%ui/components/colors.nut" import GreenSuccessColor, RedWarningColor, panelRowColor, TextDisabled,
  TextNormal, BtnBgNormal, BtnBdSelected, OrangeHighlightColor, TextHighlight, InfoTextValueColor
from "%ui/components/commonComponents.nut" import mkText, mkSelectPanelItem, mkSelectPanelTextCtor, BD_LEFT, BD_NONE,
  mkTextArea, panelParams, mkTooltiped, mkDescTextarea, selectPanelTextFromCtor
from "%ui/profile/profileState.nut" import playerProfileMonolithTokensCountUpdate
from "%ui/fonts_style.nut" import h2_txt, body_txt, h1_txt, tiny_txt
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem
from "%ui/components/button.nut" import button, buttonWithGamepadHotkey
from "%ui/components/accentButton.style.nut" import AlertButtonStyle, accentButtonStyle
import "%ui/components/faComp.nut" as faComp
from "dagor.math" import Point2
import "math" as math
from "dagor.debug" import logerr
from "eventbus" import eventbus_send, eventbus_subscribe
from "dasevents" import CmdRequestOnboardingBuyMonolithAccess, CmdShowUiMenu
from "%ui/components/scrollbar.nut" import makeVertScrollExt
from "%ui/components/msgbox.nut" import showMsgbox, showMessageWithContent
from "%ui/components/purchase_confirm_msgbox.nut" import showCurrencyPurchaseMsgBox, showNotEnoghPremiumMsgBox
from "%ui/components/cursors.nut" import setTooltip
from "%ui/mainMenu/market/inventoryToMarket.nut" import getLotFromItem, getBaseUpgradeFromItem
from "%ui/hud/menus/components/inventoryItemUtils.nut" import showItemInMarket
from "%ui/hud/hud_menus_state.nut" import closeAllMenus, openMenu
from "%ui/mainMenu/clonesMenu/clonesMenuCommon.nut" import mkChronogeneDoll, getChronogeneFullBodyPresentation,
  mkMainChronogeneInfoStrings, mkAlterIconParams, ClonesMenuId, AlterSelectionSubMenuId
from "%ui/components/modalWindows.nut" import addModalWindow, removeModalWindow
from "%ui/hud/menus/components/inventoryItemImages.nut" import inventoryItemImage
from "%ui/hud/menus/components/inventoryItemTooltip.nut" import buildInventoryItemTooltip
from "%ui/hud/menus/components/inventoryItemRarity.nut" import mkRarityIconByItem
from "%ui/mainMenu/notificationMark.nut" import mkNotificationCircle
import "%ui/components/colorize.nut" as colorize
from "%ui/popup/player_event_log.nut" import addPlayerLog, mkPurchaseLogData, mkPlayerLog
from "%ui/mainMenu/craftIcons.nut" import getRecipeIcon
from "%ui/mainMenu/craft_common_pkg.nut" import getRecipeName
from "%ui/hud/menus/components/inventoryItemsPresetPreview.nut" import fakeItemAsAttaches
from "%ui/components/glareAnimation.nut" import glareAnimation, animChildren
from "%ui/mainMenu/clonesMenu/mainChronogeneSelection.nut" import selectedPreviewAlter, hoveredAlter, alterToFocus, updateAlterTemplateInShowroom
from "%ui/mainMenu/clonesMenu/itemGenes.nut" import allChronogenesInGame
from "%ui/mainMenu/currencyIcons.nut" import monolithTokensTextIcon, creditsTextIcon, monolithTokensColor, creditsColor, premiumColor, premiumCreditsTextIcon
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { marketItems, playerStats, playerProfileMonolithTokensCount, playerProfilePremiumCredits, playerProfileAllResearchNodes, allRecipes } = require("%ui/profile/profileState.nut")
let { monolithSelectedLevel, monolithLevelOffers, selectedMonolithUnlock, currentMonolithLevel, permanentMonolithLevelOffers } = require("%ui/mainMenu/monolith/monolith_common.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { stashItems, backpackItems, inventoryItems, safepackItems } = require("%ui/hud/state/inventory_items_es.nut")
let { smallInventoryImageParams, largeInventoryImageParams } = require("%ui/hud/menus/components/inventoryItemImages.nut")
let { hoverHotkeysWatchedList } = require("%ui/components/pcHoverHotkeyHitns.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { marketIconSize } = require("%ui/popup/player_event_log.nut")
let { selectedPrototype, selectedCategory, scrollToRecipe } = require("%ui/mainMenu/craftSelection.nut")
let { CRAFT_WND_ID } = require("%ui/mainMenu/researchAndCraft.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let { joyAHintOverrideText } = require("%ui/hotkeysPanelStateComps.nut")

let btnHeight = hdpx(50)
let checkIconHeight = hdpxi(20)
let statusIconWidth = hdpxi(50)
let suitRewardSize = [hdpxi(350), hdpxi(597)]
let iconParams = {
  width = hdpxi(60)
  height = hdpxi(35)
  transform = {}
  animations = []
  slotSize = [hdpxi(70), hdpxi(50)]
}

let suitIconParams = {
  width = hdpxi(60)
  height = hdpxi(70)
  transform = {}
  animations = []
  slotSize = [hdpxi(70), hdpxi(50)]
}

let purchaseIconParams = {
  width = hdpxi(300)
  height = hdpxi(300)
  shading = "full"
  slotSize = [hdpxi(300), hdpxi(300)]
}
let smallRecipeIcon = [hdpx(25), hdpx(25)]

let unlockedButtonColor = Color(20, 40, 30, 165)
let unlockedButtonStyle = {
  BtnBgNormal = unlockedButtonColor
}

let hoveredSlot = Watched(null)
let purchaseInProgress = Watched(false)

const MONOLITH_LEVEL_ID = "monolithLevelId"
const MONOLITH_REWARD_WND = "monolithRewardWnd"
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

let disabledStyle = freeze({color = TextDisabled}.__update(body_txt))
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
      : static body_txt.__merge({ hplace = ALIGN_LEFT }))

  let levelCanBePurchased = (!isUnlocked && accessGranted) ?
    Computed(function() {
      if (isOnboarding.get()) {
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
    size = FLEX_H
    valign = ALIGN_CENTER
    gap
    flow = FLOW_HORIZONTAL
    children = [
      {
        behavior = Behaviors.Marquee
        size = FLEX_H
        children = text(params)
      }
      isUnlocked ? mkStatusIcon("check", GreenSuccessColor) :
        !accessGranted ? mkStatusIcon("lock", TextDisabled) :
        !levelCanBePurchased?.get() ? null : {
          margin = hdpx(5)
          size = hdpx(12)
          children = mkNotificationCircle()
        }
    ]
  }
}

let permanentLevelRowCtor = mkSelectPanelTextCtor(loc("monolith/permanentLevel"),
  { hplace = ALIGN_LEFT, color = TextHighlight }.__merge(body_txt))
let permanentLevelRow = @(params) {
  size = FLEX_H
  clipChildren = true
  children = {
    behavior = Behaviors.Marquee
    size = FLEX_H
    children = permanentLevelRowCtor(params)
  }
  valign = ALIGN_CENTER
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
  if (logData == null)
    return null
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
  purchaseInProgress.set(false)
  let monolithUnlock = marketItems.get()?[unlockIdToBuy.get()?.tostring()]
  if (monolithUnlock != null) {
    let { items = [], unlocks = [], baseUpgrades = [], researchNodes = [], craftRecipes = [] } = monolithUnlock.children

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
      else {
        let nameToUse = startsWith(unlock, "unlock") ? unlock : $"unlock_base_upgrade_{unlock.replace("+", "_")}"
        showSpecificLog(nameToUse)
      }
    }
    foreach (research in researchNodes) {
      let recipe = allRecipes.get()[research]
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
    foreach (recipeId in craftRecipes) {
      let recipe = allRecipes.get()[recipeId]
      let recipeTemplate = $"fuse_result_{recipe.name}"
      let fakedRecipeItem = mkFakeItem(recipeTemplate)

      addPlayerLog({
        id = recipeId
        content = mkPlayerLog({
          titleFaIcon = "unlock"
          titleText = loc("monolith/itemUnlockedTooltip")
          bodyIcon = {
            size = iconParams.slotSize
            halign = ALIGN_CENTER
            vplace = ALIGN_CENTER
            children = inventoryItemImage(fakedRecipeItem, iconParams)
          }
          bodyText = $"{loc("monolith/unlocked")}: {loc(fakedRecipeItem.name)}"
        })
      })
    }
  }
  unlockIdToBuy.set(null)
})

let visual_params = {
  size = static [flex(), hdpx(55)]
  valign = ALIGN_CENTER
  xmbNode = XmbNode()
}

let permanentVisualParams = static {
  size = [flex(), hdpx(55)]
  xmbNode = XmbNode()
  style = {
    SelBgNormal = AlertButtonStyle.style.BtnBgNormal
  }
}

let mkLevelPanel = @(levelData, idx) function() {
  let { isPermanent = false } = levelData
  local isUnlocked = false
  if (isOnboarding.get()) {
    if (isPermanent) {
      monolithSelectedLevel.set(1)
      return { watch = isOnboarding }
    }
    isUnlocked = false
  }
  else
    isUnlocked = playerStats.get()?.purchasedUniqueMarketOffers.findindex(@(offer) offer.tostring() == levelData.offerId) != null

  let accessGranted = levelData.requirements.monolithAccessLevel <= currentMonolithLevel.get()
  let level = idx

  return {
    watch = [currentMonolithLevel, playerStats, isOnboarding]
    xmbNode = XmbContainer({
      canFocus = false
      wrap = false
      scrollSpeed = 5.0
    })
    children = mkSelectPanelItem({
      visual_params = isPermanent
        ? permanentVisualParams
        : visual_params.__merge(isUnlocked ? static { style=unlockedButtonStyle } : static {})
      children = isPermanent ? permanentLevelRow : mkLevelRow(levelData, isUnlocked, accessGranted)
      idx = level
      state = monolithSelectedLevel
      onSelect = @(lvl) monolithSelectedLevel.set(lvl)
      border_align = isPermanent ? BD_NONE : BD_LEFT
    })
  }.__update(visual_params)
}

let levelsList = @(list, levelStartIdx) {
  size = static [hdpx(377), flex()]
  children = makeVertScrollExt({
    size = FLEX_H
    flow = FLOW_VERTICAL
    gap = hdpx(2)
    children = list.map(@(v, idx) mkLevelPanel(v, idx + levelStartIdx))
  }, { size = flex() })
}

let mkUnlockItemName = @(name, prefix = "") {
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  gap = hdpx(4)
  valign = ALIGN_BOTTOM
  children = [
    mkText(loc(prefix), {
      color = Color(180, 180, 220, 200)
      pos = static [0, -hdpx(2)]
    }.__merge(tiny_txt))
    mkText(loc(name), {
      size = FLEX_H
      behavior = Behaviors.Marquee
      scrollOnHover = false
      speed = hdpx(50)
      margin = static [0, hdpx(4),0,0]
    }.__merge(body_txt))
  ]
}

function mkRequirementText(cur, needed, locId) {
  let color = cur >= needed ? GreenSuccessColor : RedWarningColor
  return mkTooltiped(mkText(loc(locId, { cur, needed }), { color }), loc($"{locId}/desc"))
}

function goToCraft(id) {
  selectedCategory.set(null)
  selectedPrototype.set(id)
  scrollToRecipe.set(id)
  openMenu(CRAFT_WND_ID)
}

function goToMainAlters(suit) {
  let { itemTemplate } = suit
  alterToFocus.set(suit)
  updateAlterTemplateInShowroom(itemTemplate, Point2(0.6, 0.5))
  selectedPreviewAlter.set(suit)
  openMenu($"{ClonesMenuId}/{AlterSelectionSubMenuId}")
}

function mkRecipeIcon(prototypeId, isSmall = true) {
  let recipeId = playerProfileAllResearchNodes.get()[prototypeId].containsRecipe
  let recipe = allRecipes.get()[recipeId]
  return button(@() {
    watch = [playerProfileAllResearchNodes, allRecipes]
    padding = hdpx(1)
    children = getRecipeIcon(recipeId, isSmall ? smallRecipeIcon : [purchaseIconParams.width, purchaseIconParams.height]),
  }, @() goToCraft(prototypeId),
  {
    onHover = @(on) setTooltip(on ? loc("research/craftRecipeResult", { name = loc(getRecipeName(recipe)) } ) : null)
    stopHover = true
    hplace = ALIGN_LEFT
    pos = static [-hdpx(7), -hdpx(3)]
    skipDirPadNav = true
    isEnabled = isSmall
  })
}

let mkPurchaseRecipeIcon = @(prototypeId) mkRecipeIcon(prototypeId, false)

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

  if (unlockOffer?.children.items.len()) {
    let templateName = unlockOffer?.children.items[0].templateName
    local attachmentsToUse = []
    local suitOverrideData = {}
    if (unlockOffer?.itemType == "suits") {
      let { attachments, alterIconParams } = mkAlterIconParams(templateName)
      attachmentsToUse = attachments
      suitOverrideData = alterIconParams.__merge({
        iconScale = (alterIconParams?.iconScale ?? 1) * 0.7,
        goToMainAlters
      })
    }
    fake = mkUnlockFakeItem(templateName, attachmentsToUse, unlockOffer?.itemType == "suits" ? suitOverrideData : {})
    itemNamePrefix = itemNamePrefix ?? loc("monolith/itemPrefix")
    tooltipOnBuyButton = loc("monolith/butButtonTooltip/getItem")
    key = unlockOffer?.itemType == "suits" ? templateName : unlockOffer.children.items[0]
  }
  else if (unlockOffer?.children.baseUpgrades.len()) {
    let baseUpgradeName = unlockOffer.children.baseUpgrades[0].replace("+", "_")
    let templateName = $"base_upgrade_{baseUpgradeName}"
    fake = mkUnlockFakeItem(templateName)
    let offerId = getBaseUpgradeFromItem({ itemTemplate = unlockOffer.children.baseUpgrades[0] })
    itemMarketOffer = marketItems.get()?[offerId]
    itemNamePrefix = itemNamePrefix ?? loc("monolith/baseUpgradePrefix")
    tooltipOnBuyButton = loc("monolith/butButtonTooltip/upgradeBase")

    key = unlockOffer.children.baseUpgrades[0]
  }
  else if (unlockOffer?.children.unlocks.len()) {
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
    let recipe = allRecipes.get()[recipeId]
    let templateName = recipe.results?[0].keys()[0]
    itemMarketOffer = marketItems.get()?[unlockOffer.offerId]
    tooltipOnBuyButton = loc("monolith/butButtonTooltip/getAccessToUnlock")
    fake = mkUnlockFakeItem(templateName).__update({
      tooltip = loc("amCleaner/recipe", { name = loc(getRecipeName(recipe)) })
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
  else if ((unlockOffer?.children.craftRecipes ?? []).len() > 0) {
    let recipeId = unlockOffer.children.craftRecipes[0]
    let recipe = allRecipes.get()[recipeId]
    let recipeTemplate = $"fuse_result_{recipe.name}"
    itemMarketOffer = marketItems.get()?[unlockOffer.offerId]
    tooltipOnBuyButton = loc("monolith/butButtonTooltip/getAccessToUnlock")
    fake = mkUnlockFakeItem(recipeTemplate).__update({
      id = recipeId
    })
    itemNamePrefix = itemNamePrefix ?? loc("monolith/refinerRecipePrefix")
    itemName = loc(fake.name)
    key = recipeId
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

  let additionalLockStages = unlockOffer?.requirements.noUnlocks ?? []
  if (additionalLockStages.len() > 0) {
    foreach (stage in additionalLockStages) {
      let hasAccess = (playerStats.get()?.unlocks.findindex(@(v) stage == v) != null)
      if (hasAccess)
        unlockText = $"{unlockText}\n{loc($"stats/{stage}")}"
    }
  }

  let canBePurchased = Computed(function() {
    if (!additionalRequirements.len() && !additionalLockStages.len())
      return true

    let unlocks = playerStats.get()?.unlocks ?? []
    foreach (unlock in additionalRequirements) {
      let hasUnlock = (unlocks.findindex(@(v) unlock == v) != null)
      if (!hasUnlock)
        return false
    }
    foreach (stage in additionalLockStages) {
      let hasAccess = (unlocks.findindex(@(v) stage == v) != null)
      if (hasAccess)
        return false
    }
    return true
  })

  let itemIcon = fake?.iconToUse ? fake.iconToUse
    : fake ? inventoryItemImage(fake, unlockOffer?.itemType == "suits" ? suitIconParams : iconParams,
        unlockOffer?.itemType != "suits" ? {} : {
          clipChildren = true
          padding = [hdpx(1), 0]
        })
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
    if (itemMarketOffer == null
        || (unlockOffer?.children.baseUpgrades.len() ?? 0) > 0
        || unlockOffer?.itemType == "refinerRecipe") {
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
    if (purchaseInProgress.get())
      return
    if (unlockIdToBuy.get() != null)
      return
    if (offerBought.get()) {
      if (fake?.goToMainAlters != null)
        goToMainAlters(fake)
      else if (fake?.goTo != null)
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
      showCurrencyPurchaseMsgBox({
        currency = "monolith"
        price
        cb = function() {
          eventbus_send("profile_server.buyLots", [ { id = unlockOffer.offerId, count = 1, usePremium = false } ])
          purchaseInProgress.set(true)
          unlockIdToBuy.set(unlockOffer.offerId)
        }
        icon = {
          flow = FLOW_HORIZONTAL
          gap = static hdpx(10)
          valign = ALIGN_CENTER
          children = [
            fake?.iconToUse ?? inventoryItemImage(fake, purchaseIconParams)
            unlockOffer?.children.researchNodes[0] == null ? null
              : mkPurchaseRecipeIcon(unlockOffer.children.researchNodes[0])
          ]
        }
        name = $"{itemNamePrefix ?? ""} {itemName ?? loc(fake?.itemName)}"
      })
    }
  }

  let infoButton = @() {
    watch = offerBought
    size = flex()
    children = button(mkStatusIcon("info", TextNormal),
      function() {
        if (fake?.goToMainAlters != null)
          goToMainAlters(fake)
        else if (fake?.goTo != null)
          fake.goTo(fake.id)
        else
          goToMarket()
      }
      {
        size = flex()
        skipDirPadNav = true
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
      : TextNormal
    let unlockTextColor = buyPrice > 0 && playerProfileMonolithTokensCount.get() <= buyPrice
      ? RedWarningColor
      :GreenSuccessColor
    let getUnlockText = @() offerBought.get() ? colorize(GreenSuccessColor, loc("monolith/itemUnlockedTooltip"))
      : !levelUnlocked ? colorize(RedWarningColor, loc("monolith/itemRequiresMonolithLevelTooltip"))
      : canBePurchased.get() ? loc($"{colorize(unlockTextColor, tooltipOnBuyButton)} {colorize(monolithTokensColor, monolithTokensTextIcon)}{colorize(priceColor, price)}")
      : colorize(RedWarningColor, loc("monolith/unlockReq/hint", { unlock = unlockText }))

    return @(){
      watch
      children = buildInventoryItemTooltip(fake.__merge({ additionalDescFunc = @(_) [ getUnlockText() ] }))
    }
  }

  function gamepadHoverAction(on) {
    if (isGamepad.get()) {
      if (on) {
        hoveredSlot.set(fake?.templateName)
        joyAHintOverrideText.set(loc("btn/buy"))
      }
      else {
        hoveredSlot.set(null)
        joyAHintOverrideText.set(null)
      }
    }
  }

  function buttonItemName() {
    let hasAlreadyBought = unlockOffer?.offerId != null &&
      playerStats.get()?.purchasedUniqueMarketOffers.findindex(@(offer) offer.tostring() == unlockOffer.offerId) != null
    return {
      watch = [showPrice, offerBought, canBePurchased, hoveredSlot, playerStats]
      size = flex()
      children = button ({
        size = flex()
        children = [
          mkRarityIconByItem(fake)
          {
            size = flex()
            flow = FLOW_HORIZONTAL
            gap = hdpx(5)
            padding = static [ 0, hdpx(10) ]
            valign = ALIGN_CENTER
            children = [
              {
                valign = ALIGN_BOTTOM
                children = [
                  recipeAdditionalIcon
                  itemIcon
                ]
              },
              itemName == null ? null : mkUnlockItemName(itemName, itemNamePrefix),
              !showPrice.get() ? null
                : mkTextArea($"{colorize(monolithTokensColor, monolithTokensTextIcon)}{price}",
                  { size = SIZE_TO_CONTENT }.__merge(body_txt)),
              (!hasAlreadyBought && (!canBePurchased.get() || !levelUnlocked))
                ? mkStatusIcon("lock", RedWarningColor)
                : null
            ]
          }
        ]
      },
      buyItem,
      {
        style = offerBought.get() ? unlockedButtonStyle : null
        size = flex()
        xmbNode = XmbNode()
        hotkeys = hoveredSlot.get() == null || hoveredSlot.get() != fake?.templateName ? null
          : [["J:X", { description = loc("show_info_btn"), action = function() {
            if (hoveredSlot.get()?.goToMainAlters != null)
              goToMainAlters(fake)
            else if (hoveredSlot.get()?.goTo != null)
              hoveredSlot.get().goTo(fake.id)
            else
              goToMarket()
            }}
          ]]
        onHover = function(on) {
          setTooltip(on ? getTooltip([offerBought, playerProfileMonolithTokensCount], price) : null)
          resetSelectedMonolithUnlock()

          hoverHotkeysWatchedList.set(on ? [{
            hotkeys = ["LMB"]
            locId = offerBought.get() ? "inventory/toMarket" : "monolith/butButtonTooltip/getAccessToUnlock"
            order = 0
            showInTooltip = true
          }] : null)

          gamepadHoverAction(on)
        }
      })
    }
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
          borderColor = BtnBdSelected
          borderWidth = hdpx(2)
          animations = [{ prop=AnimProp.borderColor, from=BtnBdSelected, to=TextNormal, duration=1.5, easing=CosineFull, play=true, loop=true }]
          clipChildren = true
          children = animChildren(glareAnimation({ duration = 4, from = [-hdpx(200), 0], to = [hdpx(2000), 0] }))
        }
      }
    ]
  }.__merge(key ? { key } : {}) 
}

function fillUnlockBlock(isLevelUnlocked, list, title, appendTo) {
  if (!list?.len())
    return

  appendTo.append(mkText(title, {
    margin = appendTo.len() > 0
      ? [hdpx(10), 0, hdpx(4), 0]
      : [0, 0, hdpx(4), 0]
    color = InfoTextValueColor
    }))

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
      mkTooltiped(mkText($"{loc(itemLoc)} ({val.has}/{val.need})", { color }),
        loc("monolith/additionalPrice/desc", {items = colorize(OrangeHighlightColor, loc(itemLoc))}))
    )
  }
  return childrens
}

function mkRequirementsBlock(data) {
  let req = getRequirementsBlock(data)

  return {
    size = FLEX_H
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      {
        flow = FLOW_VERTICAL
        size = FLEX_H
        children = [
          req.len() ? mkText(loc("monolith/requirements")) : null
          req.len() ? {
            size = FLEX_H
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
          size = FLEX_H
          children = [
            mkText(loc("monolith/additionalPrice"))
            {
              size = FLEX_H
              flow = FLOW_VERTICAL
              children = additionalPrice
            }
          ]
        }.__merge(panelParams)
      }
    ]
  }
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

let mkNextLevelButton = @(levelData) function() {
  local lvlBought = false
  if (isOnboarding.get()) {
    lvlBought = false
  }
  else {
    lvlBought = playerStats.get()?.purchasedUniqueMarketOffers.findindex(@(v) v.tostring() == levelData.offerId) != null
  }
  let requireAccessLevel = (levelData?.requirements.monolithAccessLevel ?? 0)
  let lvlAvailable = requireAccessLevel <= currentMonolithLevel.get()
  let price = levelData?.additionalPrice.monolithTokensCount ?? 0
  let premiumPrice = levelData?.additionalPrice.premiumCreditsCount ?? 0

  let itemPrice = getPriceInItems(levelData, [].extend(stashItems.get(), inventoryItems.get(), backpackItems.get(), safepackItems.get()) )
  let enoughItems = itemPrice.findvalue(@(v) v.has < v.need) == null

  let notEnoughMoney = playerProfileMonolithTokensCount.get() < price || !enoughItems
  let notEnoughPremiumMoney = playerProfilePremiumCredits.get() < premiumPrice
  let requirementsMet = isRequirementsMet(levelData)

  let isAccentButton = !(lvlBought || notEnoughMoney || !lvlAvailable || !requirementsMet)
  let isAccentPremiumButton = !(lvlBought || notEnoughPremiumMoney || !lvlAvailable || !requirementsMet)

  let priceStrings = $"{colorize(monolithTokensColor, monolithTokensTextIcon)}{price}"
  let premiumPriceStrings = $"{colorize(premiumColor, premiumCreditsTextIcon)}{premiumPrice}"

  let monolithLvlButtonStyle = @(is_lvl_bought, need_accent = false, weight = 1.0) {
    isEnabled = !is_lvl_bought
    size = [ flex(weight), hdpx(94) ]
    borderWidth = is_lvl_bought ? 0 : hdpx(1)
    halign = ALIGN_CENTER
    vplace = ALIGN_BOTTOM
    hotkeys = is_lvl_bought ? null : [["J:Y", { description = { skip = true }}]]
  }.__update( need_accent ? accentButtonStyle : {} )

  let alreadyBoughtButton = buttonWithGamepadHotkey(
    {
      flow = FLOW_HORIZONTAL
      gap = hdpx(4)
      vplace = ALIGN_CENTER
      hplace = ALIGN_CENTER
      children = [
        mkText(loc("monolith/unlocked"), { color = GreenSuccessColor }.__update(h2_txt))
        mkStatusIcon("check", GreenSuccessColor)
      ]
    },
    @() null,
    monolithLvlButtonStyle(true)
  )

  let lockedAccessButton = buttonWithGamepadHotkey(
    {
      flow = FLOW_HORIZONTAL
      gap = hdpx(4)
      vplace = ALIGN_CENTER
      hplace = ALIGN_CENTER
      children = [
        mkText(loc("monolith/locked"), { color = RedWarningColor }.__update(h2_txt))
        mkStatusIcon("close", RedWarningColor)
      ]
    },
    @() null,
    monolithLvlButtonStyle(true)
  )

  let additionalPrice = premiumPrice <= 0 ? priceStrings
    : loc("monolith/nextLevelPrice", { monolith = priceStrings, premium = premiumPriceStrings})

  let monolythTokensBuyButton = buttonWithGamepadHotkey(
    {
      flow = FLOW_VERTICAL
      gap = hdpx(4)
      halign = ALIGN_CENTER
      hplace = ALIGN_CENTER
      children = [
        mkText(utf8ToUpper(loc("monolith/nextLevel")), { fontFx = null }.__update(h2_txt))
        mkTextArea(additionalPrice, { fontFx = null, halign = ALIGN_CENTER }.__update(h2_txt))
      ]
    },
    function() {
      if (purchaseInProgress.get())
        return
      if (!requirementsMet)
        showMsgbox({text=loc("monolith/requirementsNotMetMsgbox")})
      else if (!enoughItems)
        showMsgbox({text=loc("monolith/notEnoughItems")})
      else {
        let buttons = [{
          text = $"{loc("inventory/directPurchase")} {priceStrings}"
          action = function() {
            if (notEnoughMoney)
              showMsgbox({text=loc("monolith/notEnoughMonolithTokens")})
            else {
              sound_play("am/ui/base_activation_start")
              if (isOnboarding.get()) {
                playerProfileMonolithTokensCountUpdate((playerProfileMonolithTokensCount.get() ?? 0) - price)
                ecs.g_entity_mgr.broadcastEvent(CmdRequestOnboardingBuyMonolithAccess())
              }
              else {
                eventbus_send("profile_server.buyLots", [ { id = levelData.offerId, count = 1, usePremium = false } ])
                purchaseInProgress.set(true)
                unlockIdToBuy.set(levelData.offerId)
              }
            }
          }
          customStyle = { textParams = { rendObj = ROBJ_TEXTAREA, behavior = Behaviors.TextArea } }
            .__merge(isAccentButton ? accentButtonStyle : {})
          isCurrent = true
        },
        {
          text = loc("Cancel")
          isCancel = true
        }]
        if (premiumPrice > 0) {
          buttons.insert(1, {
            text = $"{loc("inventory/directPurchase")} {premiumPriceStrings}"
            action = function() {
              if (notEnoughPremiumMoney)
                showNotEnoghPremiumMsgBox()
              else {
                sound_play("am/ui/base_activation_start")
                eventbus_send("profile_server.buyLots", [ { id = levelData.offerId, count = 1, usePremium = true } ])
                purchaseInProgress.set(true)
                unlockIdToBuy.set(levelData.offerId)
              }
            }
            customStyle = { textParams = { rendObj = ROBJ_TEXTAREA, behavior = Behaviors.TextArea } }
              .__merge(isAccentPremiumButton ? accentButtonStyle : {})
            isCurrent = true
          })
        }
        let priceBlock = premiumPrice <= 0 ? $"{loc("price")} {priceStrings}"
          : loc("monolith/nextLevelPrice", { monolith = priceStrings, premium = premiumPriceStrings})
        showCurrencyPurchaseMsgBox({
          icon = {
            size = static [hdpxi(300), hdpxi(300)]
            children = mkLevelImage(monolithSelectedLevel.get() != null
              && monolithSelectedLevel.get() == (monolithLevelOffers.get() ?? [])?.len())
          }
          name = loc("monolith/level", { level = loc(levelData.offerName) })
          customPrice = mkTextArea(priceBlock, { fontFx = null, halign = ALIGN_CENTER }.__update(h2_txt))
          buttons
        })
      }
    },
    monolithLvlButtonStyle(false, (isAccentButton || isAccentPremiumButton))
  )

  return {
    watch = [playerStats, stashItems, backpackItems, inventoryItems, safepackItems, currentMonolithLevel]
    size = static [ flex(), hdpx(94) ]
    flow = FLOW_HORIZONTAL
    gap = hdpx(6)
    children =
      lvlBought ? alreadyBoughtButton :
      !lvlAvailable ? lockedAccessButton :
      monolythTokensBuyButton
  }
}


let mkLevelInteractiveBlock = @(levelData) @() {
  watch = [ playerStats, stashItems ]
  size = FLEX_H
  flow = FLOW_VERTICAL
  gap = hdpx(6)
  vplace = ALIGN_BOTTOM
  halign = ALIGN_RIGHT
  children = [
    mkRequirementsBlock(levelData)
    mkNextLevelButton(levelData)
  ]
}

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
  if (level == 0)
    return { size = static [rightPanelSize, flex()] }
  let data = levels?[level]
  return {
    size = static [rightPanelSize, flex()]
    children = mkLevelInteractiveBlock(data)
  }
}

let permanentLevleDesc = mkTextArea(loc("monolith/permanentLevelDesc"), body_txt)

let unlocksList = @(list, levels) function() {
  if ((list?.len() ?? 0) == 0)
    return { watch = monolithSelectedLevel }

  let level = levels[monolithSelectedLevel.get()]

  let isLevelUnlocked = !isOnboarding.get()&& (playerStats.get()?.purchasedUniqueMarketOffers
    .findindex(@(v) v.tostring() == level.offerId) != null || level?.isPermanent)

  let currentList = list[monolithSelectedLevel.get()]
  let unlockOffers = []
  let itemOffers = []
  let baseUpgradeOffers = []
  let immidiateAccessAfterLevelUnlocking = []
  let refinerRecipeOffers = []
  let suitsOffers = []
  foreach (offer in currentList) {
    if (offer?.itemType == "baseUpgrades")
      baseUpgradeOffers.append(offer)
    if (offer?.itemType == "suits")
      suitsOffers.append(offer)
    else if (offer?.itemType == "unlock")
      unlockOffers.append(offer)
    else if (offer?.itemType == "chronogene")
      itemOffers.append(offer)
    else if (offer?.itemType == "immidiateAccessAfterLevelUnlocking")
      immidiateAccessAfterLevelUnlocking.append(offer)
    else if (offer?.itemType == "refinerRecipe")
      refinerRecipeOffers.append(offer)
  }

  let unlocksArr = []
  let sortOffers = @(a, b) ((a?.levelSorting ?? 0) <=> (b?.levelSorting ?? 0) || a.offerId <=> b.offerId)
  fillUnlockBlock(isLevelUnlocked, immidiateAccessAfterLevelUnlocking, loc("monolith/immidiateAccessAfterLevelUnlockingBlock"), unlocksArr)
  fillUnlockBlock(isLevelUnlocked, suitsOffers, loc("monolith/suits"), unlocksArr)
  fillUnlockBlock(isLevelUnlocked, unlockOffers.sort(sortOffers), loc("monolith/unlockBlock"), unlocksArr)
  fillUnlockBlock(isLevelUnlocked, itemOffers.sort(sortOffers), loc("monolith/itemBlock"), unlocksArr)
  fillUnlockBlock(isLevelUnlocked, baseUpgradeOffers.sort(sortOffers), loc("monolith/baseUpgradeBlock"), unlocksArr)
  fillUnlockBlock(isLevelUnlocked, refinerRecipeOffers.sort(sortOffers), loc("monolith/refinerRecipeBlock"), unlocksArr)
  let scrollHandler = ScrollHandler()

  if (monolithSelectedLevel.get() == 0)
    unlocksArr.insert(0, permanentLevleDesc)
  return {
    watch = [monolithSelectedLevel, currentMonolithLevel, playerStats]
    size = flex()
    flow = FLOW_HORIZONTAL
    gap = hdpx(20)
    onAttach = @() scrollHandler.scrollToChildren(@(desc) desc?.key == selectedMonolithUnlock.get(), 2, false, true)
    children = [
      makeVertScrollExt({
        size = FLEX_H
        flow = FLOW_VERTICAL
        gap = hdpx(4)
        xmbNode = XmbContainer({
          canFocus = false
          wrap = false
          scrollSpeed = 5.0
        })
        children = unlocksArr
      }, {
        scrollHandler
        size = flex()
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

let mkTextForMonolith = @(text) mkText(text, static {fontFx = null }.__update(body_txt))
let acceptMonoltyhText = mkTextForMonolith(loc("monolith/letsGoToTheMonolith/msgbox/ok"))
let closeMonolythText = mkTextForMonolith(loc("monolith/letsGoToTheMonolith/msgbox/cancel"))

let buttonSize = [math.max(hdpx(180), calc_str_box(acceptMonoltyhText)[0], calc_str_box(closeMonolythText)[0]) + hdpx(40), hdpx(50)]

let acceptMonolithBtn = button(
  acceptMonoltyhText,
  activateMonolith,
  static {
    size = buttonSize
    halign = ALIGN_CENTER
  }.__update(accentButtonStyle)
)

let mkCloseMonolithBtn = @(text) button(
  text,
  @() removeModalWindow(MONOLITH_REWARD_WND),
  {
    size = buttonSize
    halign = ALIGN_CENTER
    hotkeys = [[$"^{JB.B} | Esc", { description = loc("Cancel") }]]
  }
)
let closeMonolithBtn = mkCloseMonolithBtn(closeMonolythText)
let cantOpenMonolithBtn = mkCloseMonolithBtn(mkTextForMonolith(loc("Ok")))

let blueDoorBlock = @() {
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
          rendObj = ROBJ_IMAGE
          pos = [0, hdpx(28)]
          size = suitRewardSize
          image = Picture("ui/monolith_door_icon_blue.avif:0:P")
        }
        {
          size = flex()
          flow = FLOW_VERTICAL
          gap = hdpx(20)
          halign = ALIGN_RIGHT
          children = [
            mkDescTextarea(loc("monolith/blueDoorDesc"), {
              halign = ALIGN_RIGHT
              pos = [0, hdpx(20)]
            }.__update(body_txt))
          ]
        }
      ]
    }
    mkDescTextarea(loc("monolith/blueDoorDesc/rewards"), {
      halign = ALIGN_RIGHT
      valign = ALIGN_BOTTOM
      vplace = ALIGN_BOTTOM
      pos = [0, hdpx(20)]
    }.__update(body_txt))

  ]
}

let redDoorBlock = @() {
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
        {
          size = flex()
          flow = FLOW_VERTICAL
          halign = ALIGN_RIGHT
          gap = hdpx(20)
          children = [
            mkDescTextarea(loc("monolith/redDoorDesc"), {
              pos = [0, hdpx(20)]
            }.__update(body_txt))
          ]
        }
        {
          rendObj = ROBJ_IMAGE
          pos = [0, hdpx(28)]
          size = suitRewardSize
          image = Picture("ui/monolith_door_icon_red.avif:0:P")
        }
      ]
    }
    mkDescTextarea(loc("monolith/redDoorDesc/rewards"), {
      pos = [0, hdpx(20)]
      valign = ALIGN_BOTTOM
      vplace = ALIGN_BOTTOM
    }.__update(body_txt))
  ]
}

let resetProgressMessageBox = @() showMsgbox(
  { text = loc("monolith/resetPlayerProgressDesc"),
  buttons = [
    {
      text = loc("Yes")
      action = @() eventbus_send("profile_server.wipe_player_progress")
      isCurrent = true
    },
    {
      text = loc("No")
      isCancel = true
    }
  ]
})

let monolithActivationMessagebox = @() addModalWindow({
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
      maxWidth = hdpx(1920)
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
        size = FLEX_H
        halign = ALIGN_CENTER
        flow = FLOW_VERTICAL
        gap = hdpx(30)
        children = [
          {
            flow = FLOW_HORIZONTAL
            gap = hdpx(30)
            children = !isUnlocked ? cantOpenMonolithBtn : [ closeMonolithBtn, acceptMonolithBtn ]
          }
        ]
      }
    }
  ]
})

function letsGoToTheMonolithButton() {
  let accessLevel = currentMonolithLevel.get()
  let isUnlocked = playerStats.get()?.unlocks.contains("unlock_monolith_gate")
  let hasAlreadyOpenedMonolith = playerStats.get()?.unlocks.contains("unlock_monolith_path_choosed") ?? false
  let watch = [playerStats, currentMonolithLevel]
  if ((accessLevel < SHOW_MONOLITH_ACTIVATE_BUTTON_ON_LEVEL && !isUnlocked))
    return { watch }
  let buttonStyle = isUnlocked ? accentButtonStyle : {}
  if (hasAlreadyOpenedMonolith)
    return {
      watch
      size = FLEX_H
      children = button({
          hplace = ALIGN_CENTER
          vplace = ALIGN_CENTER
          children = mkText(loc("monolith/resetPlayerProgress"), { fontFx = null }.__update(h2_txt))
          padding = static [ hdpx(20), hdpx(5) ]
        },
        resetProgressMessageBox, {
          size = FLEX_H
        }.__update(buttonStyle)
      )
    }

  return {
    watch
    size = FLEX_H
    children = button({
        hplace = ALIGN_CENTER
        vplace = ALIGN_CENTER
        children = mkText(loc("monolith/letsGoToTheMonolithButton"), { fontFx = null }.__update(h2_txt))
        padding = static [ hdpx(20), hdpx(5) ]
      },
      monolithActivationMessagebox, {
        size = FLEX_H
      }.__update(buttonStyle)
    )
  }
}

function monolithGateUi() {
  let levelsArr = monolithLevelOffers.get()
  let permanentLevelsArr = permanentMonolithLevelOffers.get()

  let monolithOffers = [].resize(levelsArr.len(), null).map(@(_) [])
  let permanentOffers = [].resize(permanentLevelsArr.len(), null).map(@(_) [])

  foreach (k, v in marketItems.get()) {
    let { requirements = {}, isPermanent = false } = v
    let accessLevel = requirements?.monolithAccessLevel ?? 0
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
    if (isPermanent)
      permanentOffers.append(v.__merge({
        offerId = k
        requirements = v?.requirements ?? {}
      }))
    else
      monolithOffers[accessLevel-1].append(v.__merge({offerId = k}))
  }

  if (monolithOffers?[0])
    monolithOffers[0].append(money, shegolskoe, stashDevice)
  let offers =  @() {
    watch = [monolithLevelOffers, permanentMonolithLevelOffers]
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
            size = static [hdpx(377), flex()]
            gap = hdpx(20)
            children = [
              levelsList(levelsArr, 1) 
              letsGoToTheMonolithButton
            ]
          }
          unlocksList([permanentOffers].extend(monolithOffers), [].extend(permanentLevelsArr, levelsArr))
        ]
      }
    ]
  }

  if (permanentLevelsArr.len() > 1) {
    logerr("[Monolith menu] More than 1 permanent level found")
  }
  let permLevel = permanentLevelsArr?[0]
  return {
    size = flex()
    children = [
      {
        hplace = ALIGN_RIGHT
        halign = ALIGN_CENTER
        size = [rightPanelSize, hdpx(670)]
        
        gap = hdpx(8)
        children = [
          levelImage
          {
            padding = hdpx(20)
            hplace = ALIGN_LEFT
            size = static [ rightPanelSize, SIZE_TO_CONTENT ]
            children = permLevel ? mkLevelPanel(permLevel, 0) : null
          }
        ]
        
      }
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
