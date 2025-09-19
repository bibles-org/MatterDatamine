from "%sqstd/math.nut" import truncateToMultiple, min
from "%sqstd/string.nut" import toIntegerSafe
from "%ui/hud/menus/inventories/refinerInventory.nut" import dropToRefiner, removeFromRefiner, considerRefine, getPriceOfNonCorruptedItem, getMinimalRefinerItem, additionalDescFunc
from "%ui/fonts_style.nut" import h2_txt, body_txt, sub_txt, tiny_txt
from "%ui/components/colors.nut" import BtnBgSelected, InfoTextValueColor, BtnPrimaryTextNormal, RedWarningColor, SelBgNormal, TextNormal, BtnPrimaryBgSelected, ConsoleHeaderFillColor, ConsoleFillColor
from "%ui/components/commonComponents.nut" import mkText, bluredPanel, mkTextArea, mkTooltiped, mkSelectPanelItem, BD_LEFT
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem
from "%ui/helpers/timers.nut" import mkCountdownTimerPerSec
from "%ui/helpers/time.nut" import secondsToStringLoc
from "%ui/components/msgbox.nut" import showMessageWithContent, showMsgbox
from "%ui/components/profileAnswerMsgBox.nut" import showMsgBoxResult
from "eventbus" import eventbus_subscribe_onehit, eventbus_send
from "%ui/hud/menus/components/inventoryItemsList.nut" import itemsPanelList, setupPanelsData, inventoryItemSorting
from "%ui/hud/menus/components/inventoryCommon.nut" import mkInventoryHeader
from "%ui/hud/menus/components/inventoryItemUtils.nut" import mergeNonUniqueItems
from "%ui/hud/menus/components/inventoryItemsListChecksCommon.nut" import MoveForbidReason
from "%ui/components/accentButton.style.nut" import accentButtonStyle
from "%ui/hud/menus/components/inventoryItemImages.nut" import inventoryItemImage
from "%ui/components/scrollbar.nut" import makeVertScroll, makeVertScrollExt, thinAndReservedPaddingStyle
import "%ui/hud/menus/components/dropMarker.nut" as dropMarker
from "%ui/hud/menus/components/inventoryStashFiltersWidget.nut" import inventoryFiltersWidget
from "%ui/components/button.nut" import textButton, button, buttonWithGamepadHotkey
from "%ui/components/cursors.nut" import setTooltip
from "%ui/hud/menus/components/inventoryFilter.nut" import filterItemByInventoryFilter
from "%ui/hud/menus/components/inventoryItem.nut" import addStorageType
from "%ui/hud/menus/components/inventoryStyle.nut" import itemHeight
from "%ui/components/modalWindows.nut" import addModalWindow, removeModalWindow
from "%ui/hud/menus/components/inventoryItemTooltip.nut" import buildInventoryItemTooltip
from "%ui/hud/menus/components/inventoryVolumeWidget.nut" import mkVolumeHdr, volumeHdrHeight
from "%ui/mainMenu/stdPanel.nut" import mkCloseStyleBtn, stdBtnSize
from "%ui/popup/player_event_log.nut" import addPlayerLog, mkPlayerLog
from "%ui/components/itemIconComponent.nut" import itemIconNoBorder
from "%ui/context_hotkeys.nut" import contextHotkeys
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
import "%ui/components/faComp.nut" as faComp
import "%ui/components/colorize.nut" as colorize
from "%ui/mainMenu/currencyIcons.nut" import creditsColor, creditsTextIcon, chronotraceTextIcon, chronotracesColor
from "%ui/hud/menus/components/inventoryItemImages.nut" import inventoryImageParams
from "%ui/mainMenu/craft_common_pkg.nut" import mkMonolithLinkIcon
from "%ui/hud/hud_menus_state.nut" import openMenu
from "%ui/hud/menus/inventories/refinerInventoryCommon.nut" import itemsInRefiner, keepItemsInRefiner
from "%ui/profile/profileState.nut" import cleanableItems, playerProfileAMConvertionRate, refinedItemsList, refinerFusingRecipes,
  allRecipes, amProcessingTask, marketPriceSellMultiplier, marketItems, playerProfileAMConvertionRate
from "%ui/mainMenu/clonesMenu/clonesMenuCommon.nut" import mkChronogeneImage

let { currentKeyItem } = require("%ui/hud/menus/components/inventoryItemUtils.nut")
let { stashItems, backpackItems, inventoryItems, safepackItems } = require("%ui/hud/state/inventory_items_es.nut")
let { draggedData, shiftPressedMonitor, isAltPressedMonitor, isCtrlPressedMonitor,
  mutationForbidenDueToInQueueState } = require("%ui/hud/state/inventory_state.nut")
let { REFINER_STASH, REFINER_ON_PLAYER, REFINER, STASH } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { activeFilters } = require("%ui/hud/menus/components/inventoryStashFiltersWidget.nut")
let { inventoryItemClickActions, moveItemWithKeyboardMode } = require("%ui/hud/menus/inventoryActions.nut")
let { currentRefinerIsReadOnly, refineGettingInProgress, refinerFillAmount } = require("%ui/hud/menus/inventories/refinerInventory.nut")
let { recognitionImagePattern } = require("%ui/hud/menus/components/inventoryItem.nut")
let { stashVolume, stashMaxVolume } = require("%ui/state/allItems.nut")
let { shuffle } = require("%sqstd/rand.nut")
let { currentMenuId } = require("%ui/hud/hud_menus_state.nut")
let { MonolithMenuId, monolithSelectedLevel, monolithSectionToReturn, selectedMonolithUnlock, currentTab } = require("%ui/mainMenu/monolith/monolith_common.nut")

let templatePrefix = "fuse_result_" 

let buttonHeight = hdpx(45)
let itemCountsToActivateKeyItemSlot = 2

let refinesReady = Watched(0)
let selectedRecipe = Watched(null)
let autoFinishRefine = Watched(false)

function corruptedItemsCount(items) {
  let curruptedCount = items.reduce(function(acc, v) {
    if (v.isCorrupted)
      acc++
    return acc
  }, 0)
  return curruptedCount
}

function isFusePossible(refinerContainer) {
  return corruptedItemsCount(refinerContainer) >= itemCountsToActivateKeyItemSlot
}

function refineIsProcessing(task) {
  if (task?.taskId == null)
    return false
  return task.taskId != ""
}

let selectAmItemName = loc("amClean/selectItem")

function patchRefineData(items) {
  foreach (item in items) {
    item.__update({ additionalDescFunc = @(itemToDesc) additionalDescFunc(itemToDesc, playerProfileAMConvertionRate.get()) })
  }
}

let processStashRefineItems = function(items) {
  items = items.map(function(item) {
    if (item.filterType == "alters" || item.filterType == "chronogene" || item.filterType == "stub_melee_weapon" || item.filterType == "dogtag_chronogene")
      throw null

    let newItem = considerRefine(item)
    if (newItem == null)
      throw null

    return newItem
  })
  if (activeFilters.get().len() != 0) {
    items = items.filter(@(item) filterItemByInventoryFilter(item))
  }
  patchRefineData(items)
  return mergeNonUniqueItems(items).sort(inventoryItemSorting)
}

let processContainerItems = function(items) {
  items = mergeNonUniqueItems(items)
  patchRefineData(items)
  items.sort(inventoryItemSorting)

  let sorted = items.filter(@(v) v?.sortAfterEid == null && !v?.hasFoldedItems )
  let folded = items.filter(@(v) v?.sortAfterEid != null ).reverse()
  let hasFolded = items.filter(@(v) v?.hasFoldedItems )
  foreach (foldedItem in folded) {
    let sortIdx = hasFolded.findindex(@(item) item.eids.contains(foldedItem.sortAfterEid) )
    if (sortIdx != null)
      hasFolded.insert(sortIdx+1, foldedItem)
  }

  return sorted.extend(hasFolded)
}

let processingTimeToText = @(t) t > 0 ? secondsToStringLoc(t) :
  loc("amClean/Done")

function isRefinerReadyToStart(itemsIn, currentRecipe) {
  if (itemsIn.len() == 0)
    return false

  if (currentRecipe == null)
    return true

  local isOk = true
  foreach (component in currentRecipe[1].components) {
    isOk = isOk && (itemsIn.findindex(@(v) v.itemTemplate == component) != null)
  }

  return isOk
}

function cleanRefinerWithTask(task) {
  if (!refineIsProcessing(task)) {
    itemsInRefiner.set([])
    currentKeyItem.set(null)
    currentRefinerIsReadOnly.set(false)
    refinesReady.set(0)
  }
}

function finishRefine(refiner, quickRefine=false) {
  refineGettingInProgress.set(true)
  let taskId = refiner?.taskId

  let itemsInside = refiner?.itemsInside ?? {}

  let itemsToSell = itemsInside.sellItemTemplateNames ?? {}
  let fuseItemTemplateNames = itemsInside?.fuseItemTemplateNames ?? {}
  let itemsReplicaTemplates = itemsInside?.replicaItemTemplateNames ?? {}

  let inside = []
  foreach (templateName, _count in {}.__update(itemsToSell, fuseItemTemplateNames, itemsReplicaTemplates)) {
    inside.append({ templateName })
  }

  let oldFusingRecipes = clone(refinerFusingRecipes.get())
  eventbus_subscribe_onehit($"profile_server.complete_refine_task.result#{taskId}", function(result) {
    let newFuseBox = []
    foreach (fuseName, fuseVal in refinerFusingRecipes.get()) {
      if (fuseVal.totalResults > 0 && fuseVal.totalResults != (oldFusingRecipes?[fuseName].totalResults)) {
        newFuseBox.append({
          templateName = fuseVal.relatedKey
        })
      }
    }
    result.__update({
      newFuseBox
    })
    if (!quickRefine || result.itemsAdd || result.chronotraces || result.newFuseBox.len() || result.researches.len()) {
      showMsgBoxResult(loc("craft/resultReceived"), result, { itemsAdd = inside })
    }
    else if ((result?.currency ?? 0) > 0) {

      addPlayerLog({
        id = $"refiner_{taskId}"
        content = mkPlayerLog({
          titleFaIcon = "user"
          bodyIcon = itemIconNoBorder("credit_coins_pile", { width = hdpx(64), height = hdpx(64) })
          titleText = loc("item/received")
          bodyText = $"{result.currency} {loc("credits")}"
        })
      })
    }
    refineGettingInProgress.set(false)
    cleanRefinerWithTask(amProcessingTask.get())
  })
  eventbus_send("profile_server.complete_refine_task", taskId)
}

function uptadeRefinerWithTask(task) {
  if (refineIsProcessing(task) && currentMenuId.get() == "Am_clean") {
    let itemsInside = task?.itemsInside ?? {}

    let itemsToSell = itemsInside.sellItemTemplateNames ?? {}
    let fuseItemTemplateNames = itemsInside?.fuseItemTemplateNames ?? {}
    let itemsReplicaTemplates = itemsInside?.replicaItemTemplateNames ?? {}

    function fakeRefinerItem(templateName, override) {
      let item = mkFakeItem(templateName, override)

      if (item.isBoxedItem) {
        item.__update({
          ammoCount = item.count
          count = 1
        })
      }
      else {
        item.__update({
          countPerStack = 1 
        })
      }

      return item
    }

    
    let inside = fuseItemTemplateNames.map(function(count, templateName) {
      return fakeRefinerItem(templateName, {
        itemId = 0
        count = count
        isCorrupted = true
        forceLockIcon = true
      })
    }).__update(
      
      itemsToSell.map(function(count, templateName) {
        return fakeRefinerItem(templateName, {
          itemId = 0
          count = count
          isCorrupted = false
          forceLockIcon = true
        })
      }),
      
      itemsReplicaTemplates.map(function(count, templateName) {
        return fakeRefinerItem(templateName, {
          itemId = 0
          count = count
          isCorrupted = false
          forceLockIcon = true
          isReplica = true 
        })
      })
    )
    itemsInRefiner.set(inside)
    currentRefinerIsReadOnly.set(true)
  }
}

function startRefine() {
  if (itemsInRefiner.get().len() == 0) {
    showMessageWithContent({
      content = {
        rendObj = ROBJ_TEXT
        text = loc("amClean/selectNewItem")
      }.__update(h2_txt)
    })
    return
  }

  if (!isRefinerReadyToStart(itemsInRefiner.get(), selectedRecipe.get())) {
    showMsgbox({ text = loc("amClean/recipeNotReady") })
    return
  }

  let itemsToRefine = itemsInRefiner.get()
  if (currentKeyItem.get() && !isFusePossible(itemsToRefine)) {
    let itemsMore = itemCountsToActivateKeyItemSlot - corruptedItemsCount(itemsToRefine)
    showMsgbox({ text = loc("amClean/fuseIsNotPossibleNeedMoreItems", { itemsMore }) })
    return
  }
  refineGettingInProgress.set(true)
  eventbus_subscribe_onehit($"profile_server.add_refine_task.result", function(_) {
    refineGettingInProgress.set(false)
    uptadeRefinerWithTask(amProcessingTask.get())
  })

  let unique_item = itemsToRefine.filter(@(v) v?.sortAfterEid == null).reduce(function(acc, v) {
    acc[v.uniqueId.tostring()] <- (v.isBoxedItem ? v.ammoCount : 1)
    return acc
  }, {})

  eventbus_send("profile_server.add_refine_task", {
    unique_item
    fuse_recipe_id = selectedRecipe.get()?[0]
  })
}

function startQuickRefine() {
  let itemsToRefine = itemsInRefiner.get()

  refineGettingInProgress.set(true)
  autoFinishRefine.set(true)
  eventbus_subscribe_onehit($"profile_server.add_refine_task.result", function(_) {
    refineGettingInProgress.set(false)
  })

  let unique_item = itemsToRefine.filter(@(v) v?.sortAfterEid == null).reduce(function(acc, v) {
    acc[v.uniqueId.tostring()] <- (v.isBoxedItem ? v.ammoCount : 1)
    return acc
  }, {})

  eventbus_send("profile_server.add_refine_task", {
    unique_item
    fuse_recipe_id = selectedRecipe.get()?[0]
  })
}

let mkProgressBarBg = @(timeLeftWatched) @() {
  watch = timeLeftWatched
  size = [hdpx(425), flex()]
  rendObj = ROBJ_SOLID
  color = BtnBgSelected
  transform = {
    scale = [1 - (timeLeftWatched.get() / 10.0).tofloat(), 1.0]
    pivot = [0.0, 0.5]
  }
}

let mkRewardSubpanel = @(title, v) v.len() == 0 ? null : {
  flow = FLOW_VERTICAL
  children = [title].extend(v)
  size = FLEX_H
  padding = hdpx(5)
}.__merge(bluredPanel)

function itemsForRecipe(items, recipe) {
  let compList = {}
  foreach (comp in recipe?[1].components ?? []) {
    foreach (item in items) {
      if (!item?.isCorrupted)
        continue

      if (item.itemTemplate == comp) {
        if (compList?[comp] == null)
          compList[comp] <- []

        compList[comp].append(item.eid)
      }
    }
  }

  local minComps = -1
  foreach (comp in compList) {
    if (minComps < 0)
      minComps = comp.len()
    else
      minComps = min(minComps, comp.len())
  }

  let ret = []
  foreach (comp in compList) {
    ret.extend(comp.resize(minComps))
  }

  return ret
}

function mkExpectedRewardInfo(items, currentTask, keyItem, currentRecipe) {
  let useInRecipe = itemsForRecipe(items, currentRecipe)
  let isUsedInRecipe = @(item) useInRecipe.findindex(@(v) v == item.eid) != null

  let cleanable = cleanableItems.get()
  local minAm = currentTask?.resultAmRange.x ?? 0
  local maxAm = currentTask?.resultAmRange.y ?? 0
  local nonCorruptedPrice = currentTask?.resultCredits ?? 0
  local minChronotraces = currentTask?.resultChronotraceRange.x ?? 0
  local maxChronotraces = currentTask?.resultChronotraceRange.y ?? 0
  local priceForAmmo = 0

  if ((currentTask?.taskId ?? "") == "") {
    function proceedMods(itemWithMods) {
      foreach (mod in (itemWithMods?.modInSlots ?? {})) {
        let modAm = cleanable?[mod.itemTemplate].amContains
        if (mod.isCorrupted && modAm && !isUsedInRecipe(mod)) {
          minAm += modAm.x
          maxAm += modAm.y
        }
        else if (!isUsedInRecipe(mod)){
          nonCorruptedPrice += getPriceOfNonCorruptedItem(marketPriceSellMultiplier.get(), mod)
        }

        let chronotraces = cleanable?[mod.itemTemplate]?.refineChronotraces
        if (chronotraces?.isCorrupted && chronotraces && !isUsedInRecipe(mod)) {
          minChronotraces += chronotraces.x
          maxChronotraces += chronotraces.x
        }
      }
    }

    function proceedContainerItems(itemsInContainer) {
      foreach (itemEid in itemsInContainer) {
        let item = getMinimalRefinerItem(itemEid)
        if (item == null)
          continue

        if (item?.itemContainerItems.len())
          proceedContainerItems(item.itemContainerItems)

        let foldedItemAm = cleanable?[item.itemTemplate].amContains
        if (item.isCorrupted && foldedItemAm && !isUsedInRecipe(item)) {
          minAm += foldedItemAm.x
          maxAm += foldedItemAm.y
        }
        else if (!isUsedInRecipe(item)) {
          nonCorruptedPrice += getPriceOfNonCorruptedItem(marketPriceSellMultiplier.get(), item)
        }

        let chronotraces = cleanable?[item.itemTemplate]?.refineChronotraces
        if (item.isCorrupted && chronotraces && !isUsedInRecipe(item)) {
          minChronotraces += chronotraces.x
          maxChronotraces += chronotraces.x
        }

        proceedMods(item)
      }
    }

    let itemsToProcess = (keyItem ? [keyItem].extend(items) : items).filter(@(v) v?.sortAfterEid == null)
    foreach ( item in itemsToProcess ) {
      let ammoInside = item?.gunAmmo ?? item?.ammoCount
      if (ammoInside) {
        priceForAmmo += ammoInside
      }
      let am = cleanable?[item.itemTemplate]?.amContains
      if (item.isCorrupted && am && !isUsedInRecipe(item)) {
        minAm += am.x
        maxAm += am.y
      }
      else if (!isUsedInRecipe(item)) {
        nonCorruptedPrice += getPriceOfNonCorruptedItem(marketPriceSellMultiplier.get(), item)
      }

      let chronotraces = cleanable?[item.itemTemplate]?.refineChronotraces
      if (item.isCorrupted && chronotraces && !isUsedInRecipe(item)) {
        minChronotraces += chronotraces.x
        maxChronotraces += chronotraces.x
      }

      
      if (item?.itemContainerItems.len())
        proceedContainerItems(item.itemContainerItems)

      proceedMods(item)
    }
  }

  local recipeResultString = null
  if (currentRecipe && isRefinerReadyToStart(items, currentRecipe)) {
    let recipeTemplate = $"{templatePrefix}{currentRecipe[1].name}"
    let lootboxTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(recipeTemplate)
    recipeResultString = colorize(InfoTextValueColor, loc(lootboxTemplate?.getCompValNullable("item__name") ?? "unknown"))
  }
  let credits = colorize(creditsColor, creditsTextIcon)
  
  local amMoneyString = null
  if (minAm > 0 || maxAm > 0) {
    let conversation = playerProfileAMConvertionRate.get()
    let minAmDevided = minAm / 10.0
    let maxAmDevided = maxAm / 10.0
    amMoneyString = minAmDevided == maxAmDevided ?
      loc("amClean/expectedMoneySingle", {minVal=colorize(InfoTextValueColor, $"{credits}{truncateToMultiple(minAmDevided * conversation, 1)}")}) :
      loc("amClean/expectedMoney", {
          minVal=colorize(InfoTextValueColor, $"{credits}{truncateToMultiple(minAmDevided * conversation, 1)}"),
          maxVal=colorize(InfoTextValueColor, truncateToMultiple(maxAmDevided * conversation, 1))})
  }

  local nonCorruptedPriceString = null
  nonCorruptedPrice += priceForAmmo
  if (nonCorruptedPrice > 0) {
    nonCorruptedPriceString = loc("amClean/expectedMoneyFromNonCorruptedItems", { minVal = colorize(InfoTextValueColor, $"{credits}{nonCorruptedPrice}") })
  }

  local chronotracesString = null
  let cronotraces = colorize(chronotracesColor, chronotraceTextIcon)
  if (minChronotraces > 0) {
    if (minChronotraces == maxChronotraces) {
      chronotracesString = loc("amClean/expectedMoneyFromNonCorruptedItemsOnlyMin", { minVal = colorize(InfoTextValueColor, $"{cronotraces}{minChronotraces}") })
    }
    else {
      chronotracesString = loc("amClean/expectedMoneyFromNonCorruptedItemsMinMax", {
        minVal = colorize(InfoTextValueColor, $"{cronotraces}{minChronotraces}"),
        maxVal = colorize(InfoTextValueColor, $"{maxChronotraces}")
      })
    }
  }

  local overallMoneyIncomeString = null
  if (minAm > 0 || nonCorruptedPrice > 0) {
    let conversation = playerProfileAMConvertionRate.get()
    let overallMin = truncateToMultiple(minAm / 10.0 * conversation, 1) + nonCorruptedPrice
    let overallMax = truncateToMultiple(maxAm / 10.0 * conversation, 1) + nonCorruptedPrice

    overallMoneyIncomeString = overallMax == overallMin ?
      colorize(InfoTextValueColor, $"{credits}{overallMin}") :
      colorize(InfoTextValueColor, $"{credits}{overallMin}-{overallMax}")
  }

  return {
    chronotraces = chronotracesString
    nonCorruptedPrice = nonCorruptedPriceString
    amMoney = amMoneyString
    recipeResult = recipeResultString
    overallMoneyIncome = overallMoneyIncomeString
  }
}

let mkRefinerSlot = function(refiner) {
  let isProcessing = refineIsProcessing(refiner)
  let countdown = isProcessing ? mkCountdownTimerPerSec(Watched(refiner.endTimeAt.tointeger() + 1.0), "refiner_end_time_countdown") : Watched(0)
  let hasCountDown = Computed(@() isProcessing && countdown.get() != 0)
  let isRefinerReady = Computed(@() isRefinerReadyToStart(itemsInRefiner.get(), selectedRecipe.get()))

  return function() {
    let action = isProcessing && !hasCountDown.get() ? @() finishRefine(refiner)
      : isProcessing ? @() showMsgbox({ text = loc("amClean/processing")})
      : startRefine

    let refinerReadyForRefine = (isRefinerReady.get() && !currentKeyItem.get()) || (currentKeyItem.get())
    let isAccent = (isProcessing && !hasCountDown.get()) || (!isProcessing && refinerReadyForRefine)
    let textColor = isAccent ? BtnPrimaryTextNormal : null
    let defTxtStyle = {
      color = textColor
      fontSize = hdpx(16)
      fontFxColor = Color(0,0,0,0)
    }
    return {
      watch = [ currentRefinerIsReadOnly, hasCountDown, isRefinerReady,
        refineGettingInProgress, currentKeyItem]
      size = FLEX_H
      children = buttonWithGamepadHotkey(
        {
          size = FLEX_H
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          children = [
            {
              size = FLEX_H
              children = isProcessing && hasCountDown.get() ? mkProgressBarBg(countdown) : null
            }
            @() {
              watch = [countdown, itemsInRefiner]
              halign = ALIGN_CENTER
              children = [
                isProcessing ? null : mkText(loc("amClean/start"), defTxtStyle.__merge(body_txt))
                !isProcessing ? null : mkText(processingTimeToText(countdown?.get()), defTxtStyle.__merge(body_txt))
              ]
            }
          ]
        }
        action,
        {
          size = static [flex(), buttonHeight]
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          isEnabled = !refineGettingInProgress.get()
          hotkeys = [["J:Y", { description = { skip = true } }]]
        }.__update(isAccent ? accentButtonStyle : {})
      )
    }
  }
}

let mkRefinerButtons = @() {
    size = FLEX_H
    flow = FLOW_VERTICAL
    gap = -1
    children =
      @() {
        watch = amProcessingTask
        size = FLEX_H
        children = mkRefinerSlot(amProcessingTask.get())
      }
}

let mkInventory = function(panelData, list, watches, headers = null) {
  panelData.resetScrollHandlerData()
  return @() {
    watch = watches
    size = FLEX_V
    clipChildren = true
    children = itemsPanelList({
      outScrollHandlerInfo=panelData.scrollHandlerData,
      list_type=list,
      itemsPanelData=panelData.itemsPanelData,
      headers
      can_drop_dragged_cb=function(item) {
        if (currentKeyItem.get()?.uniqueId == item.uniqueId)
          return MoveForbidReason.NONE

        if (item?.refiner__fromList.name != list.name)
          return MoveForbidReason.ITEM_ALREADY_IN

        return MoveForbidReason.NONE
      },
      on_item_dropped_to_list_cb = function(item, list_type) {
        moveItemWithKeyboardMode(item, list_type)
      },
      item_actions = inventoryItemClickActions[list.name],
      xSize = 4
    })
  }.__update(bluredPanel)
}

let inProgressPanel = @(color) {
  rendObj = ROBJ_WORLD_BLUR_PANEL
  size = flex()
  stopMouse = true
  transform = static {}
  animations = static [
    { prop=AnimProp.opacity, from=0.3, to=0.8, duration=2, play=true, loop=true, easing=CosineFull }
  ]
  fillColor = color
}

let itemsCountPerRow = 10
let possibleItemsColumnWidth = (itemHeight * itemsCountPerRow) + (itemsCountPerRow - 1) * hdpx(4)

const RuseResulsInfoId = "fuseResulsInfo"
function onSelect(val){
  selectedRecipe.set(val)
  removeModalWindow(RuseResulsInfoId)
}

let visual_params_recipe_all_components = static {
  padding = static [hdpx(2), hdpx(10)]
  halign = ALIGN_CENTER
  margin = 0
  xmbNode = XmbNode()
  size = SIZE_TO_CONTENT
  style = { SelBdNormal = BtnPrimaryBgSelected }
}

let visual_params_recipe_no_components = static visual_params_recipe_all_components.__merge({style = {SelBdNormal = null}})

let arrow = static faComp("arrow-right", static {
  fontSize = hdpx(25)
  size = FLEX_V
  valign = ALIGN_CENTER
  color = Color(60, 60, 60, 180)
})

let arrowLine = freeze({
  gap = hdpx(4)
  flow = FLOW_VERTICAL
  size = FLEX_V
  children = [
    { size = calc_str_box(mkText("A", tiny_txt)) }
    arrow
  ]
})

let mkPossibleResults = @(children) {
  flow = FLOW_VERTICAL
  gap = hdpx(4)
  children = [
    static mkText(loc("amClean/possibleResults"), tiny_txt)
    {
      size = static [ possibleItemsColumnWidth, SIZE_TO_CONTENT ]
      flow = FLOW_VERTICAL
      gap = hdpx(4)
      children
    }
  ]
}
let mkRequiredComp = @(children) {
  rendObj = ROBJ_BOX
  size = static [ SIZE_TO_CONTENT, itemHeight ]
  borderRadius = hdpx(2)
  fillColor = ConsoleFillColor
  borderWidth = hdpx(1)
  borderColor = Color(60, 60, 60, 120)
  flow = FLOW_HORIZONTAL
  children
}

let mkRequiredComponents = @(header, item) {
  flow = FLOW_VERTICAL
  valign = ALIGN_CENTER
  gap = hdpx(4)
  children = [
    header
    item
  ]
}
let requiredText = static mkText(loc("amClean/requiredComponents"), tiny_txt)
let requiredTextHgt = calc_str_box(requiredText)[1]

let requiredItemsWidth = max(itemHeight*3.2, calc_str_box(requiredText)[0])

let mkRecipeItemRow = @(headerComp, requiredComponentsCol, possibleResultsCol) {
  gap = static hdpx(2)
  flow = FLOW_VERTICAL
  children = [
    headerComp
    {
      flow = FLOW_HORIZONTAL
      gap = static hdpx(40)
      padding = static [0, hdpx(25)]
      children = [
        {
          size = [requiredItemsWidth, SIZE_TO_CONTENT]
          children = requiredComponentsCol
          halign = ALIGN_CENTER
        }
        arrowLine
        {size = [possibleItemsColumnWidth, SIZE_TO_CONTENT] children = possibleResultsCol}
      ]
    }
  ]
}

function fuseResultInfoRow(keyVal, allPossibleItems, isOpened) {
  let fuseKey = keyVal[1]?.name ?? ""

  let componentTemplate = keyVal[1]?.components ?? []
  let results = keyVal[1].results
  let totalResults = keyVal[1]?.totalResults ?? 0

  let lootboxTemplatename = $"fuse_result_{fuseKey}"

  let keyItemComp = []
  let resultsComp = []
  local hasAllComponents = true
  if (componentTemplate.len() > 0) {
    foreach (keyTemp in componentTemplate) {
      let keyItemFaked = mkFakeItem(keyTemp)
      let foundItem = allPossibleItems.findvalue(@(v) v.itemTemplate == keyTemp)
      if (hasAllComponents && foundItem == null)
        hasAllComponents = false

      keyItemComp.append({
        behavior = Behaviors.Button
        children = keyItemFaked?.filterType == "chronogene" ? mkChronogeneImage(keyItemFaked, inventoryImageParams) : inventoryItemImage(keyItemFaked, inventoryImageParams)
        eventPassThrough = true
        skipDirPadNav = true
        onHover = @(on) setTooltip(on ? buildInventoryItemTooltip(keyItemFaked) : null)
      })
    }
  }
  else {
    let offer = marketItems.get().findvalue(@(of) of.children.craftRecipes.findindex(@(v) v == keyVal[0]) != null)
    keyItemComp.append(
      mkTooltiped({
        size = [ itemHeight, itemHeight ]
        children = [
          recognitionImagePattern
          {
            padding = hdpx(4)
            children = mkMonolithLinkIcon({ text = loc("amClean/unknownRecipeKeyItemTooltip") }, function() {
              if (offer == null)
                return

              keepItemsInRefiner.set(true)
              monolithSelectedLevel.set(offer.requirements.monolithAccessLevel)
              selectedMonolithUnlock.set(keyVal[0])
              monolithSectionToReturn.set("Am_clean")
              currentTab.set("monolithLevelId")
              openMenu(MonolithMenuId)
              removeModalWindow(RuseResulsInfoId)
            })
          }
        ]
      }, loc("amClean/unknownRecipeKeyItemTooltip"), static { size = itemHeight })
    )
  }

  foreach (resultScheme in results) {
    let resultTemplate = resultScheme.reduce(@(a,v,k) v.len() == 0 ? k : a, "")
    let faked = mkFakeItem(resultTemplate)
    resultsComp.append({
      behavior = Behaviors.Button
      skipDirPadNav = true
      onHover = function(on) {
        if (on)
          setTooltip(buildInventoryItemTooltip(faked))
        else
          setTooltip(null)
      }
      children = faked?.filterType == "chronogene" ? mkChronogeneImage(faked, inventoryImageParams) : inventoryItemImage(faked, inventoryImageParams)
    })
  }
  for (local i=results.len(); i < totalResults; i++) {
    resultsComp.append(
      mkTooltiped(recognitionImagePattern, loc("amClean/unknownRecipeItemTooltip"), { size = itemHeight })
    )
  }

  let resultsLists = []
  function mkRows(itemInRow) {
    return {
      flow = FLOW_HORIZONTAL
      gap = hdpx(4)
      children = itemInRow
    }
  }
  for (local i=0; i < totalResults; i+=itemsCountPerRow) {
    resultsLists.append(mkRows(resultsComp.slice(i, i + itemsCountPerRow)))
  }

  let lootboxTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(lootboxTemplatename)
  let lootboxName = lootboxTemplate?.getCompValNullable("item__name")

  return mkSelectPanelItem({
      idx = keyVal
      state = selectedRecipe
      border_align = BD_LEFT
      visual_params = hasAllComponents && isOpened ? visual_params_recipe_all_components : visual_params_recipe_no_components
      onSelect = function(val){
        if (componentTemplate.len() > 0) {
          onSelect(val)
        }
        else {
          let recipeId = keyVal[0]
          let offer = marketItems.get().findvalue(function(of) {
            return of.children.craftRecipes.findindex(@(v) v == recipeId) != null
          })

          if (offer == null)
            return

          monolithSelectedLevel.set(offer.requirements.monolithAccessLevel)
          selectedMonolithUnlock.set(recipeId)
          monolithSectionToReturn.set("Am_clean")
          currentTab.set("monolithLevelId")
          openMenu(MonolithMenuId)
          removeModalWindow(RuseResulsInfoId)
        }
      }
      children = mkRecipeItemRow(
        mkText(loc(lootboxName), static { color=InfoTextValueColor }.__update(sub_txt)),
        mkRequiredComponents(requiredText, mkRequiredComp(keyItemComp))
        mkPossibleResults(resultsLists)
      )
    }
  )
}

let clearRecipe = @() selectedRecipe.set(null)

let noRecipe = function() {
  let creditsFaked = mkFakeItem("credit_coins_pile")
  let chronotracesFaked = mkFakeItem("chronotrace_coins_pile")

  let fakedResult = function(fakeItem) {
    return {
      rendObj = ROBJ_BOX
      borderRadius = hdpx(2)
      fillColor = ConsoleFillColor
      borderWidth = hdpx(1)
      borderColor = Color(60, 60, 60, 120)
      behavior = Behaviors.Button
      children = inventoryItemImage(fakeItem, inventoryImageParams)
      eventPassThrough = true
      skipDirPadNav = true
      onHover = @(on) setTooltip(on ? buildInventoryItemTooltip(fakeItem) : null)
    }
  }

  let credits = fakedResult(creditsFaked)
  let chronotraces = fakedResult(chronotracesFaked)

  return mkSelectPanelItem({
    onSelect
    idx = null
    state = selectedRecipe
    visual_params = static visual_params_recipe_all_components.__merge({xmbNode = XmbNode()})
    border_align = BD_LEFT
    children = mkRecipeItemRow(
      null, 
      mkRequiredComponents(
        static {size = [0, requiredTextHgt]},
        { size = static [SIZE_TO_CONTENT, itemHeight] halign = ALIGN_CENTER, valign = ALIGN_CENTER children = mkText(loc("amClean/anyItemComponent", "Any Item")) }
      ),
      mkPossibleResults({flow = FLOW_HORIZONTAL children = [credits, chronotraces], gap = hdpx(4)})
    )
  })
}()

let closeRefineBtn = mkCloseStyleBtn(@() removeModalWindow(RuseResulsInfoId))

function filterMonolithOfferRecipes(offer) {
  let { requirements = {}, itemType = null } = offer
  let accessLevel = requirements?.monolithAccessLevel ?? 0

  if (itemType == "refinerRecipe" && accessLevel > 0)
    return true

  return false
}

let fuseResulsInfo = {
  rendObj = ROBJ_WORLD_BLUR_PANEL
  key = RuseResulsInfoId
  size = flex()
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = function() {
    let allPossibleItems = [].extend(
      inventoryItems.get()
      backpackItems.get()
      safepackItems.get()
      stashItems.get()
    )

    let recipesInMonolith = {}
    marketItems.get().filter(filterMonolithOfferRecipes).each(function(v) {
      foreach (recipe in v?.children.craftRecipes ?? []) {
        recipesInMonolith[recipe] <- true
      }
    })

    let notOpenedRecipes = allRecipes.get().filter(@(_v, k) recipesInMonolith?[k] && refinerFusingRecipes.get()?[k] == null)
    return {
      watch = [inventoryItems, backpackItems, safepackItems, stashItems, refinerFusingRecipes, allRecipes]
      size = static [ SIZE_TO_CONTENT, sh(85) ]
      rendObj = ROBJ_WORLD_BLUR_PANEL
      fillColor = mul_color(ConsoleHeaderFillColor, 0.5)

      halign = ALIGN_CENTER
      children = {
        size = FLEX_V
        flow = FLOW_VERTICAL
        children = [
          static {
            size = FLEX_H
            valign = ALIGN_CENTER
            padding = [hdpx(4), 0, hdpx(4), hdpx(10)]
            children = static [
              mkText(loc("amClean/selectRecipe"), body_txt),
              {
                hplace = ALIGN_RIGHT
                children = closeRefineBtn
              }
            ]
          }
          makeVertScrollExt(@() {
            xmbNode = XmbContainer({
              canFocus = false
              wrap = false
              scrollSpeed = 5.0
            })
              hplace = ALIGN_CENTER
              vplace = ALIGN_TOP
              flow = FLOW_VERTICAL
              gap = hdpx(5)
              
              children = [noRecipe].extend(
                  refinerFusingRecipes.get().topairs()
                    .sort(@(a, b) b[0] <=> a[0])
                    .map(@(v) fuseResultInfoRow(v, allPossibleItems, true)),
                  [
                    static {
                      size = FLEX_H
                      valign = ALIGN_CENTER
                      padding = static [hdpx(2), 0, hdpx(2), hdpx(10)]
                      children = static mkText(loc("amClean/unknownRecipesTitle"), body_txt),
                    }
                  ]
                  notOpenedRecipes.topairs()
                    .sort(@(a, b) b[0] <=> a[0])
                    .map(@(v) fuseResultInfoRow(v, allPossibleItems, false)),
                )
            },
            static {
              size = FLEX_V
              styling = thinAndReservedPaddingStyle
            }
          )
        ]
      }
    }
  }
}

function fillItemsForFuse(fuseRecipe) {
  if ((amProcessingTask.get()?.taskId ?? "") != "") {
    showMsgbox(static { text = loc("amClean/autofill/taskAlreadyRunned")})
    return
  }

  if (fuseRecipe == null) {
    showMsgbox(static { text = loc("amClean/autofill/haveNoItems")})
    return
  }

  let allPossibleItems = shuffle([].extend(
    inventoryItems.get()
    backpackItems.get()
    safepackItems.get()
    stashItems.get()
  ))

  local hasAllComponents = true
  let itemsToDrop = []
  let alreadyInRefiner = @(item) itemsInRefiner.get().findindex(@(v) v.eid == item.eid) != null
  foreach (component in fuseRecipe.components) {
    let foundItem = allPossibleItems.findvalue(@(v) v.isCorrupted && v.itemTemplate == component && !alreadyInRefiner(v))
    if (foundItem == null) {
      hasAllComponents = false
      continue
    }
    itemsToDrop.append(foundItem)
  }

  if (hasAllComponents) {
    foreach (item in itemsToDrop) {
      dropToRefiner(item, REFINER_STASH, 1)
    }
  }

  if (!hasAllComponents) {
    showMsgbox(static { text = loc("amClean/autofill/haveNoItems")})
    return
  }
}

let openFuseWindow = @() addModalWindow(fuseResulsInfo)

function refineRecipeSelection() {
  let onClick = refinerFusingRecipes.get()?.len() ? openFuseWindow : @() showMsgbox(static { text = loc("amClean/noRecipesKnown") })

  function mkComponentImage(componentTemplate) {
    let fakedComponent = mkFakeItem(componentTemplate)
    return {
      behavior = Behaviors.Button
      skipDirPadNav = true
      children = [
        {
          rendObj = ROBJ_BOX
          color = SelBgNormal
          fillColor = ConsoleFillColor
          size = flex()
        }
        inventoryItemImage(fakedComponent, inventoryImageParams)
      ]
      onClick
      onHover = @(on) setTooltip(on ? buildInventoryItemTooltip(fakedComponent) : null)
    }
  }

  return function() {
    local fakedRecipeItem = null

    if (selectedRecipe.get()) {
      let currentRecipeTemplate = selectedRecipe.get() ? $"{templatePrefix}{selectedRecipe.get()?[1].name}" : null

      fakedRecipeItem = mkFakeItem(currentRecipeTemplate)
    }
    return {
      watch = selectedRecipe
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap = hdpx(4)
      children = [
        buttonWithGamepadHotkey(
          {
            size = FLEX_H
            flow = FLOW_VERTICAL
            valign = ALIGN_CENTER
            children = [
              mkText(
                fakedRecipeItem?.itemName ? loc(fakedRecipeItem?.itemName) : loc("amClean/selectRecipe"),
                static {
                  size = [ flex(), stdBtnSize[1] ]
                  vplace = ALIGN_CENTER
                  halign = ALIGN_CENTER
                  valign = ALIGN_CENTER
                }.__update(sub_txt)
              )
              selectedRecipe.get() ? {
                hplace = ALIGN_CENTER
                flow = FLOW_HORIZONTAL
                gap = hdpx(10)
                padding = hdpx(16)
                children = [
                  {
                    rendObj = ROBJ_BOX
                    borderRadius = hdpx(2)
                    fillColor = 0
                    borderWidth = hdpx(1)
                    borderColor = Color(60, 60, 60, 120)
                    flow = FLOW_HORIZONTAL
                    gap = hdpx(5)
                    children = (selectedRecipe.get()?[1].components ?? []).map(@(v) mkComponentImage(v))
                  }
                  arrow
                  {
                    rendObj = ROBJ_BOX
                    borderRadius = hdpx(2)
                    fillColor = ConsoleFillColor
                    borderWidth = hdpx(1)
                    borderColor = Color(60, 60, 60, 120)
                    flow = FLOW_HORIZONTAL
                    skipDirPadNav = true
                    behavior = Behaviors.Button
                    onClick
                    onHover = @(on) setTooltip(on ? buildInventoryItemTooltip(fakedRecipeItem) : null)
                    children = inventoryItemImage(fakedRecipeItem, inventoryImageParams)
                  }
                ]
              } : null
            ]
          },
          onClick,
          static {
            size = FLEX_H,
            hotkeys = [["J:RS", { description = { skip = true } }]]
          }
        )
        fakedRecipeItem ? button(
          static mkText(loc("amClean/refillContainer"), sub_txt),
            @() fillItemsForFuse(selectedRecipe.get()?[1]),
          static {
            size = FLEX_H
            hplace = ALIGN_RIGHT
            vplace = ALIGN_CENTER
            valign = ALIGN_CENTER
            halign = ALIGN_CENTER
            padding = static [hdpx(10), 0]
          }
        ) : null
      ]
    }
  }
}

function keyItemPanel() {
  return {
    size = FLEX_H
    gap = hdpx(4)
    padding = hdpx(8)
    halign = ALIGN_CENTER
    children = [
      refineRecipeSelection()
      @() {
        watch = selectedRecipe
        hplace = ALIGN_RIGHT
        vplace = ALIGN_TOP
        children = selectedRecipe.get() ? mkCloseStyleBtn(clearRecipe, { stopHover = true, onHover = @(on) setTooltip(on ? loc("amClean/selectNoRecipe") : null ) }) : null
      }
    ]
  }
}

let isItemInRefiner = @(itemTemplate, refinerItems) refinerItems.findindex(@(v) v.itemTemplate == itemTemplate ) != null

function warningNeedMoreItemsToFuze() {
  let warningText = Computed(function() {
    if (selectedRecipe.get()?[1].relatedKey == null)
      return null

    if (!isItemInRefiner(selectedRecipe.get()?[1].relatedKey, itemsInRefiner.get()))
      return loc("amClean/needKeyItemForRecipe", { item = loc(mkFakeItem(selectedRecipe.get()?[1].relatedKey)?.itemName) })

    let corruptedCount = corruptedItemsCount(itemsInRefiner.get())

    if (corruptedCount >= (itemCountsToActivateKeyItemSlot + 1))
      return null

    return loc("amClean/fuseIsNotPossibleNeedMoreItems", { itemsMore = (itemCountsToActivateKeyItemSlot + 1) - corruptedItemsCount(itemsInRefiner.get()) })
  })

  return @() {
    watch = warningText
    size = warningText.get() ? [ flex(), hdpx(60) ] : [0,0]
    children = mkTextArea(
      warningText.get(),
      {
        color = RedWarningColor
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        size = flex()
      }
    )
  }.__merge(bluredPanel)
}

let keyItemPanelWithTitle = @() {
  flow = FLOW_VERTICAL
  size = FLEX_H
  children = [
    {
      size = static [ flex(), hdpx(45) ]
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      flow = FLOW_HORIZONTAL
      gap = hdpx(10)
      children = mkText(loc("amClean/keyItemPanelTitle"))
    }.__merge(bluredPanel)
    keyItemPanel
    warningNeedMoreItemsToFuze()
  ]
}.__merge(bluredPanel)

let itemsOnPlayer = Computed(function() {
  return []
    .extend(
      inventoryItems.get()
      backpackItems.get()
      safepackItems.get()
    )
    .map(@(item) addStorageType(item, stashItems.get(), inventoryItems.get(), backpackItems.get(), safepackItems.get()))
})

let stashItemsToRefine = Computed(function() {
  return stashItems.get().map(@(item) addStorageType(item, stashItems.get(), inventoryItems.get(), backpackItems.get(), safepackItems.get()))
})

let stashRefineItemsPanelData = setupPanelsData(stashItemsToRefine,
                                  4,
                                  [stashItemsToRefine, itemsInRefiner, activeFilters, currentKeyItem, refinedItemsList, refinerFusingRecipes],
                                  processStashRefineItems)

let playerRefineItemsPanelData = setupPanelsData(itemsOnPlayer,
                                  4,
                                  [itemsOnPlayer, itemsInRefiner, activeFilters, currentKeyItem, refinedItemsList, refinerFusingRecipes],
                                  processStashRefineItems)

let containerItemsPanelData = setupPanelsData(itemsInRefiner,
                                  4,
                                  [itemsInRefiner],
                                  processContainerItems)

uptadeRefinerWithTask(amProcessingTask.get())

function mkAmProcessingItemPanel() {

  function incomePanel() {
    let watch = [ itemsInRefiner, currentKeyItem ]
    if (!itemsInRefiner.get().len() && !currentKeyItem.get()) {
      return {
        watch
        size = flex()
      }
    }

    return {
      size = flex()
      watch = [ itemsInRefiner, currentKeyItem, selectedRecipe ]
      gap = hdpx(5)
      flow = FLOW_VERTICAL
      children = [
        {
          padding = hdpx(5)
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          children = mkText(loc("amClean/expectedReward"))
          size = static [ flex(), hdpx(45) ]
        }.__merge(bluredPanel)
        makeVertScroll({
            size = FLEX_H
            children = function() {
              let { chronotraces = null, nonCorruptedPrice = null, amMoney = null, recipeResult = null}
                = mkExpectedRewardInfo(itemsInRefiner.get(), amProcessingTask.get(), currentKeyItem.get(), selectedRecipe.get())
              return {
                watch = [ itemsInRefiner, currentKeyItem, selectedRecipe, amProcessingTask ]
                flow = FLOW_VERTICAL
                gap = hdpx(5)
                size = FLEX_H
                children = [
                  chronotraces ? mkRewardSubpanel(null, [mkTextArea(chronotraces)] ) : null
                  nonCorruptedPrice ? mkRewardSubpanel(null, [mkTextArea(nonCorruptedPrice)] ) : null
                  amMoney ? mkRewardSubpanel(null, [mkTextArea(amMoney)] ) : null
                  recipeResult ? mkRewardSubpanel(null, [mkTextArea(recipeResult)] ) : null
                ]
              }
            }
          }
        )
      ]
    }.__update(bluredPanel)
  }

  function cleanInfoBlock() {
    function refinerInventory() {
      containerItemsPanelData.resetScrollHandlerData()

      let can_drop_dragged_cb = function(item) {
        if (currentRefinerIsReadOnly.get())
          return MoveForbidReason.REFINER_IN_USE
        if (currentKeyItem.get()?.uniqueId == item.uniqueId)
          return MoveForbidReason.NONE
        if (item.fromList.name == REFINER.name)
          return MoveForbidReason.ITEM_ALREADY_IN

        return MoveForbidReason.NONE
      }

      let mkCompleteBtn = @(refiner) @() {
        watch = refineGettingInProgress
        size = FLEX_H
        children = buttonWithGamepadHotkey(mkText(loc("amClean/Done"), { hplace = ALIGN_CENTER }.__merge(body_txt)),
          @() finishRefine(refiner),
          {
            size = FLEX_H
            isEnabled = !refineGettingInProgress.get()
            hotkeys = [["J:Y", { description = { skip = true } }]]
            padding = static [0, hdpx(6)]
          }.__update(accentButtonStyle))
      }
      function mkInProgressBox(task) {
        let countdown = mkCountdownTimerPerSec(Watched(task.endTimeAt.tointeger() + 1.0), task.taskId)
        let hasCountDown = Computed(@() countdown.get() > 0)
        return function() {
          return {
            watch = hasCountDown
            size = flex()
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            children = [
              inProgressPanel(countdown.get() == 0 ? static Color(10, 30, 50, 0) : static Color(10,10,10,10))
              !hasCountDown.get() ? mkCompleteBtn(task) : null
            ]
          }
        }
      }

      let rmbAction = inventoryItemClickActions?[REFINER.name].rmbAction
      return {
        size = FLEX_V
        watch = [ containerItemsPanelData.numberOfPanels ]
        hplace = ALIGN_RIGHT
        children = [
          itemsPanelList({
            outScrollHandlerInfo=containerItemsPanelData.scrollHandlerData,
            list_type = REFINER,
            itemsPanelData=containerItemsPanelData.itemsPanelData,
            headers = {
              padding = hdpx(6)
              size = FLEX_H
              children = static mkInventoryHeader(loc("amClean/itemsList"), null)
            }
            can_drop_dragged_cb,
            on_item_dropped_to_list_cb = function(item, _list_type) {
              moveItemWithKeyboardMode(item, REFINER)
            },
            item_actions={
              rmbAction = rmbAction
              lmbAction = @(item) removeFromRefiner(item, item?.isBoxedItem ? item.countPerStack : 1)
              lmbShiftAction = @(item) removeFromRefiner(item, item?.isBoxedItem ? item.ammoCount : item.eids.len())
            },
            dropMarkerConstructor = function(sf) {
              if (draggedData.get() == null)
                return null
              let forbidReason = can_drop_dragged_cb(draggedData.get())
              if (forbidReason == MoveForbidReason.NONE)
                return dropMarker(sf.get())
              if (forbidReason == MoveForbidReason.VOLUME)
                return dropMarker(sf.get(), true)
              if (forbidReason == MoveForbidReason.REFINER_IN_USE) {
                return dropMarker(sf.get(), true, "")
              }

              return null
            }
            itemIconParams = currentRefinerIsReadOnly.get() ? static inventoryImageParams.__merge( { opacity = 0.3 } ) : inventoryImageParams
            xSize = 5
          }).__update(bluredPanel),
          @() {
            watch = amProcessingTask
            size = flex()
            children = refineIsProcessing(amProcessingTask.get()) ? mkInProgressBox(amProcessingTask.get()) : null
          }
        ]
      }
    }

    return {
      size = FLEX_V
      flow = FLOW_VERTICAL
      gap = hdpx(10)
      children = [
        refinerInventory
        keyItemPanelWithTitle
        incomePanel
        mkRefinerButtons
      ]
    }
  }

  let stashVolumeForRefiner = Computed(function() {
    let refiner = itemsInRefiner.get()

    local inRefinerVol = 0
    foreach (item in refiner) {
      if (item?.refiner__fromList.name == REFINER_STASH.name) {
        inRefinerVol += item.volume
      }
    }
    return stashVolume.get() - inRefinerVol
  })

  let inventoryPanel = @() {
    size = FLEX_V
    gap = hdpx(5)
    flow = FLOW_HORIZONTAL
    watch = [ refinedItemsList, refinerFusingRecipes ]
    children = [
      @() {
        watch = mutationForbidenDueToInQueueState
        size = FLEX_V
        children = [
          mkInventory(playerRefineItemsPanelData, REFINER_ON_PLAYER, [ playerRefineItemsPanelData.numberOfPanels, refinedItemsList, refinerFusingRecipes ], {
            padding = hdpx(6)
            size = FLEX_H
            flow = FLOW_VERTICAL
            children = [
              static mkInventoryHeader(loc("inventory/refiner/items"), null)
              static {size = [ 0, volumeHdrHeight ]}
            ]
          })
          mutationForbidenDueToInQueueState.get() ? {
            
            behavior = Behaviors.Button
            rendObj = ROBJ_WORLD_BLUR_PANEL
            color = Color(255,255,255,220)
            eventPassThrough = false
            size = flex()
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            flow = FLOW_VERTICAL
            gap = hdpx(10)
            children = [
              static faComp("lock", { fontSize = hdpxi(50) })
              static mkTextArea(loc("amClean/itemsOnPlayerMutationForbidden") {
                halign = ALIGN_CENTER
                size = FLEX_H
                margin = static [0, hdpx(10)]
              })
            ]
          } : null
        ]
      }
      mkInventory(stashRefineItemsPanelData, REFINER_STASH, [ stashRefineItemsPanelData.numberOfPanels, refinedItemsList, refinerFusingRecipes ], {
        padding = hdpx(6)
        size = FLEX_H
        flow = FLOW_VERTICAL
        children = [
          static mkInventoryHeader(loc("inventory/itemsInStash"), null)
          mkVolumeHdr(stashVolumeForRefiner, stashMaxVolume, STASH.name)
        ]
      })
      inventoryFiltersWidget
    ]
  }

  let infoPanel = @() {
    watch = [ refinerFillAmount, itemsInRefiner ]
    size = FLEX_V
    children = cleanInfoBlock
  }

  return {
    onAttach = function() {
      keepItemsInRefiner.set(false)
      containerItemsPanelData.onAttach()
      stashRefineItemsPanelData.onAttach()
      playerRefineItemsPanelData.onAttach()
      uptadeRefinerWithTask(amProcessingTask.get())
      if (amProcessingTask.get()?.keyItemTemplateName.len()) {
        let fake = mkFakeItem(amProcessingTask.get()?.keyItemTemplateName)
        currentKeyItem.set(fake)
      }
    }
    onDetach = function() {
      containerItemsPanelData.onDetach()
      stashRefineItemsPanelData.onDetach()
      playerRefineItemsPanelData.onDetach()
      if (!keepItemsInRefiner.get()) {
        itemsInRefiner.set([])
        currentKeyItem.set(null)
        selectedRecipe.set(null)
      }
    }

    size = FLEX_V
    halign = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    hplace = ALIGN_CENTER
    gap = static hdpx(10)
    children = [
      infoPanel
      inventoryPanel
      isCtrlPressedMonitor
      shiftPressedMonitor
      isAltPressedMonitor
      contextHotkeys
    ]
  }
}

return {
  mkAmProcessingItemPanel
  selectAmItemName
  refineIsProcessing
  refinesReady
  autoFinishRefine
  finishRefine
  startQuickRefine
  mkExpectedRewardInfo
  openFuseWindow
  selectedRecipe
}
