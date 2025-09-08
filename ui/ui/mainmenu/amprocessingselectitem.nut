from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { h2_txt, body_txt } = require("%ui/fonts_style.nut")
let { BtnBgSelected, InfoTextValueColor, panelRowColor, BtnPrimaryTextNormal, RedWarningColor } = require("%ui/components/colors.nut")
let { mkText, bluredPanel, mkTextArea, mkTooltiped } = require("%ui/components/commonComponents.nut")
let { truncateToMultiple } = require("%sqstd/math.nut")
let { creditsTextIcon, chronotraceTextIcon } = require("%ui/mainMenu/currencyIcons.nut")
let { cleanableItems, playerProfileAMConvertionRate, marketItems,
  refinedItemsList, refinerFusingRecipes, amProcessingTask, marketPriceSellMultiplier
} = require("%ui/profile/profileState.nut")
let { mkFakeItem } = require("%ui/hud/menus/components/fakeItem.nut")
let { mkCountdownTimerPerSec } = require("%ui/helpers/timers.nut")
let { secondsToStringLoc } = require("%ui/helpers/time.nut")
let { showMessageWithContent, showMsgbox } = require("%ui/components/msgbox.nut")
let { showMsgBoxResult } = require("%ui/components/profileAnswerMsgBox.nut")
let { eventbus_subscribe_onehit, eventbus_send } = require("eventbus")
let { itemsPanelList, setupPanelsData, inventoryItemSorting } = require("%ui/hud/menus/components/inventoryItemsList.nut")
let { mkInventoryHeader } = require("%ui/hud/menus/components/inventoryCommon.nut")
let { mergeNonUniqueItems, currentKeyItem } = require("%ui/hud/menus/components/inventoryItemUtils.nut")
let { stashItems, backpackItems, inventoryItems, safepackItems } = require("%ui/hud/state/inventory_items_es.nut")
let { MoveForbidReason } = require("%ui/hud/menus/components/inventoryItemsListChecksCommon.nut")
let { shiftPressedMonitor, draggedData, isCtrlPressedMonitor } = require("%ui/hud/state/inventory_state.nut")
let { accentButtonStyle } = require("%ui/components/accentButton.style.nut")
let { inventoryImageParams, inventoryItemImage } = require("%ui/hud/menus/components/inventoryItemImages.nut")
let { makeVertScroll, makeVertScrollExt, thinAndReservedPaddingStyle } = require("%ui/components/scrollbar.nut")
let dropMarker = require("%ui/hud/menus/components/dropMarker.nut")
let { REFINER_STASH, REFINER, STASH } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { inventoryFiltersWidget, activeFilters } = require("%ui/hud/menus/components/inventoryStashFiltersWidget.nut")
let { textButton, button } = require("%ui/components/button.nut")
let colorize = require("%ui/components/colorize.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let { inventoryItemClickActions } = require("%ui/hud/menus/inventoryActions.nut")
let { itemsInRefiner, currentRefinerIsReadOnly, refineGettingInProgress, dropToRefiner, removeFromRefiner, getPriceOfNonCorruptedItem
      getMinimalRefinerItem, refinerFillAmount, patchItemRefineData
    } = require("%ui/hud/menus/inventories/refinerInventory.nut")
let { filterItemByInventoryFilter } = require("%ui/hud/menus/components/inventoryFilter.nut")
let { addStorageType, recognitionImagePattern } = require("%ui/hud/menus/components/inventoryItem.nut")
let { template2MarketOffer } = require("%ui/mainMenu/market/inventoryToMarket.nut")
let { itemHeight } = require("%ui/hud/menus/components/inventoryStyle.nut")
let { addModalWindow, removeModalWindow } = require("%ui/components/modalWindows.nut")
let { buildInventoryItemTooltip } = require("%ui/hud/menus/components/inventoryItemTooltip.nut")
let { mkCloseStyleBtn } = require("%ui/mainMenu/stdPanel.nut")
let { toIntegerSafe } = require("%sqstd/string.nut")
let { mkVolumeHdr } = require("%ui/hud/menus/components/inventoryVolumeWidget.nut")
let { stashVolume, stashMaxVolume } = require("%ui/state/allItems.nut")

const AmProcessingItemId = "Am_clean_select_item"
let templatePrefix = "fuse_result_" 

let buttonHeight = 45
let itemCountsToActivateKeyItemSlot = 2

let refinesReady = Watched(0)
let selectedRecipe = Watched(null)

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
    
    patchItemRefineData(item)
  }
}

let processStashRefineItems = function(items) {
  items = items.filter(function(item) {
    if (item.isBoxedItem || item.filterType == "alters" || item.filterType == "chronogene" || (currentKeyItem.get() && currentKeyItem.get()?.uniqueId == item.uniqueId))
      return false
    return itemsInRefiner.get().findindex(@(itemInContainer) itemInContainer.uniqueId == item.uniqueId) == null
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

  if (currentRecipe != null && itemsIn.findindex(@(v) v.itemTemplate == currentRecipe?[1].relatedKey) == null)
    return false

  if (currentRecipe && itemsIn.filter(@(v) v?.isCorrupted).len() < (itemCountsToActivateKeyItemSlot + 1))
    return false

  return true
}

function finishRefine(refiner) {
  refineGettingInProgress.set(true)
  let taskId = refiner?.taskId
  let inside = refiner.itemInsideTemplateNames.map(@(v) { templateName = v })

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
    showMsgBoxResult(loc("craft/resultReceived"), result, { itemsAdd = inside })
    refineGettingInProgress.set(false)
  })
  itemsInRefiner.set([])
  currentKeyItem.set(null)
  refinesReady.set(0)
  eventbus_send("profile_server.complete_refine_task", taskId)
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
  })
  eventbus_send("profile_server.add_refine_task", {
    unique_item_ids = itemsToRefine.filter(@(v) v?.sortAfterEid == null).reduce(@(acc, v) acc.append(v.uniqueId), [])
    fuse_recipe_id = selectedRecipe.get()?[0]
  })
}

let mkProgressBarBg = @(timeLeftWatched) @() {
  watch = timeLeftWatched
  size = flex()
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
  size = const [ flex(), SIZE_TO_CONTENT ]
  padding = hdpx(5)
}.__merge(bluredPanel)

function mkExpectedRewardPanel(items, keyItem, currentRecipe) {
  let cleanable = cleanableItems.get()
  local minAm = 0
  local maxAm = 0
  local nonCorruptedPrice = 0
  local minChronotraces = 0
  local maxChronotraces = 0

  function proceedMods(itemWithMods) {
    foreach (mod in (itemWithMods?.modInSlots ?? {})) {
      let modAm = cleanable?[mod.itemTemplate].amContains
      if (mod.isCorrupted && modAm) {
        minAm += modAm.x
        maxAm += modAm.y
      }
      else {
        nonCorruptedPrice += getPriceOfNonCorruptedItem(template2MarketOffer.get(), marketPriceSellMultiplier.get(), mod)
      }

      let chronotraces = cleanable?[mod.itemTemplate]?.refineChronotraces
      if (chronotraces?.isCorrupted && chronotraces) {
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
      if (item.isCorrupted && foldedItemAm) {
        minAm += foldedItemAm.x
        maxAm += foldedItemAm.y
      }
      else {
        nonCorruptedPrice += getPriceOfNonCorruptedItem(template2MarketOffer.get(), marketPriceSellMultiplier.get(), item)
      }

      let chronotraces = cleanable?[item.itemTemplate]?.refineChronotraces
      if (item.isCorrupted && chronotraces) {
        minChronotraces += chronotraces.x
        maxChronotraces += chronotraces.x
      }

      proceedMods(item)
    }
  }

  let itemsToProcess = (keyItem ? [keyItem].extend(items) : items).filter(@(v) v?.sortAfterEid == null)
  foreach ( item in itemsToProcess ) {
    let am = cleanable?[item.itemTemplate]?.amContains
    if (item.isCorrupted && am) {
      minAm += am.x
      maxAm += am.y
    }
    else {
      nonCorruptedPrice += getPriceOfNonCorruptedItem(template2MarketOffer.get(), marketPriceSellMultiplier.get(), item)
    }

    let chronotraces = cleanable?[item.itemTemplate]?.refineChronotraces
    if (item.isCorrupted && chronotraces) {
      minChronotraces += chronotraces.x
      maxChronotraces += chronotraces.x
    }

    proceedMods(item)

    
    if (item?.itemContainerItems.len())
      proceedContainerItems(item.itemContainerItems)
  }

  local recipeResultString = null
  if (currentRecipe && isRefinerReadyToStart(items, currentRecipe)) {
    let recipeTemplate = $"{templatePrefix}{currentRecipe[0]}"
    let lootboxTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(recipeTemplate)
    recipeResultString = colorize(InfoTextValueColor, loc(lootboxTemplate?.getCompValNullable("item__name")))
  }

  
  local amMoneyString = null
  if (minAm > 0 || maxAm > 0) {
    let conversation = playerProfileAMConvertionRate.get()
    minAm /= 10.0
    maxAm /= 10.0
    amMoneyString = minAm == maxAm ?
      loc("amClean/expectedMoneySingle", {minVal=colorize(InfoTextValueColor, $"{creditsTextIcon}{truncateToMultiple(minAm * conversation, 1)}")}) :
      loc("amClean/expectedMoney", {
          minVal=colorize(InfoTextValueColor, $"{creditsTextIcon}{truncateToMultiple(minAm * conversation, 1)}"),
          maxVal=colorize(InfoTextValueColor, truncateToMultiple(maxAm * conversation, 1))})
  }

  local nonCorruptedPriceString = null
  if (nonCorruptedPrice > 0) {
    nonCorruptedPriceString = loc("amClean/expectedMoneyFromNonCorruptedItems", { minVal = colorize(InfoTextValueColor, $"{creditsTextIcon}{nonCorruptedPrice}") })
  }

  local chronotracesString = null
  if (minChronotraces > 0) {
    if (minChronotraces == maxChronotraces) {
      chronotracesString = loc("amClean/expectedMoneyFromNonCorruptedItemsOnlyMin", { minVal = colorize(InfoTextValueColor, $"{chronotraceTextIcon}{minChronotraces}") })
    }
    else {
      chronotracesString = loc("amClean/expectedMoneyFromNonCorruptedItemsMinMax", {
        minVal = colorize(InfoTextValueColor, $"{chronotraceTextIcon}{minChronotraces}"),
        maxVal = colorize(InfoTextValueColor, $"{maxChronotraces}")
      })
    }
  }

  return [
    chronotracesString ? mkRewardSubpanel(null, [mkTextArea(chronotracesString)] ) : null
    nonCorruptedPriceString ? mkRewardSubpanel(null, [mkTextArea(nonCorruptedPriceString)] ) : null
    amMoneyString ? mkRewardSubpanel(null, [mkTextArea(amMoneyString)] ) : null
    recipeResultString ? mkRewardSubpanel(null, [mkTextArea(recipeResultString)] ) : null
  ]
}

let mkRefinerSlot = function(refiner) {
  let isProcessing = refineIsProcessing(refiner)
  let countdown = isProcessing ? mkCountdownTimerPerSec(Watched(refiner.endTimeAt.tointeger())) : Watched(0)
  let hasCountDown = Computed(@() isProcessing && countdown.get() != 0)
  let isRefinerReady = Computed(@() isRefinerReadyToStart(itemsInRefiner.get(), selectedRecipe.get()))

  return function() {
    let action = isProcessing && !hasCountDown.get() ? @() finishRefine(refiner)
      : isProcessing ? @() showMsgbox({ text = loc("amClean/processing")})
      : startRefine

    let refinerReadyForRefine = (isRefinerReady.get() && !currentKeyItem.get()) || (currentKeyItem.get())
    let isAccent = (isProcessing && !hasCountDown.get()) || (!isProcessing && refinerReadyForRefine)
    let textColor = isAccent ? BtnPrimaryTextNormal : null
    let refinerHeader = loc("amClean/refinerHeader")
    let defTxtStyle = {
      color = textColor
      fontSize = hdpx(16)
      fontFxColor = Color(0,0,0,0)
    }
    return {
      watch = [ currentRefinerIsReadOnly, hasCountDown, isRefinerReady,
        refineGettingInProgress, currentKeyItem]
      size = [flex(), SIZE_TO_CONTENT]
      children = button(
        {
          size = [flex(), hdpx(buttonHeight)]
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          padding = hdpx(2)
          children = [
            isProcessing && hasCountDown.get() ? mkProgressBarBg(countdown) : null
            function() {
              return {
                watch = itemsInRefiner
                size = [flex(), SIZE_TO_CONTENT]
                flow = FLOW_HORIZONTAL
                gap = hdpx(4)
                halign = ALIGN_CENTER
                children = [
                  { size = [hdpx(35), 0] }
                  {
                    size = [flex(), SIZE_TO_CONTENT]
                    flow = FLOW_VERTICAL
                    gap = -hdpx(6)
                    halign = ALIGN_CENTER
                    children = [
                      @() {
                        watch = countdown
                        size = [flex(), SIZE_TO_CONTENT]
                        halign = ALIGN_CENTER
                        children = [
                          isProcessing ? null : const mkText(loc("amClean/start"), defTxtStyle)
                          !isProcessing ? null : mkText(processingTimeToText(countdown?.get()), defTxtStyle)
                        ]
                      }
                      mkText(refinerHeader, defTxtStyle)
                    ]
                  }
                ]
              }
            }
          ]
        }
        action,
        {
          size = [flex(), SIZE_TO_CONTENT]
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          isEnabled = !refineGettingInProgress.get()
        }.__update(isAccent ? accentButtonStyle : {})
      )
    }
  }
}

let mkRefinerButtons = @() {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = -1
    children =
      @() {
        watch = amProcessingTask
        size = [flex(), SIZE_TO_CONTENT]
        children = mkRefinerSlot(amProcessingTask.get())
      }
}

let mkInventory = function(panelData, list, watches) {
  panelData.resetScrollHandlerData()
  let rmbAction = inventoryItemClickActions?[list.name].rmbAction
  return @() {
    watch = watches
    size = const [ SIZE_TO_CONTENT, flex() ]
    clipChildren = true
    children = itemsPanelList({
      outScrollHandlerInfo=panelData.scrollHandlerData,
      list_type=list,
      itemsPanelData=panelData.itemsPanelData,
      headers = {
        padding = hdpx(6)
        size = const [ flex(), SIZE_TO_CONTENT ]
        flow = FLOW_VERTICAL
        children = [
          const mkInventoryHeader(loc("inventory/refiner/items"), null)
          mkVolumeHdr(stashVolume, stashMaxVolume, STASH.name)
        ]
      }
      can_drop_dragged_cb=function(item) {
        if (currentKeyItem.get()?.uniqueId == item.uniqueId)
          return MoveForbidReason.NONE

        if (item?.refiner__fromList.name != list.name)
          return MoveForbidReason.ITEM_ALREADY_IN

        return MoveForbidReason.NONE
      },
      on_item_dropped_to_list_cb = function(item, _list_type) {
        if (item.uniqueId == currentKeyItem.get()?.uniqueId) {
          currentKeyItem.set(null)
          return
        }
        removeFromRefiner(item)
      },
      item_actions = {
        lmbAction = @(item) dropToRefiner(item, list)
        lmbShiftAction = @(item) dropToRefiner(item, list)
        rmbAction = @(item, event) rmbAction?(item, event)
      },
      xSize = 5
    })
  }.__update(bluredPanel)
}

let inProgressPanel = @(color) {
  rendObj = ROBJ_WORLD_BLUR_PANEL
  size = flex()
  stopMouse = true
  transform = {}
  animations = [
    { prop=AnimProp.opacity, from=0.3, to=0.8, duration=2, play=true, loop=true, easing=CosineFull }
  ]
  fillColor = color
}

let itemsCountPerRow = 10
let keyItemColumnWidth = hdpx(100)
let possibleItemsColumnWidth = (itemHeight * itemsCountPerRow) + (itemsCountPerRow - 1) * hdpx(4)
function fuseResultInfoRow(keyVal) {
  let fuseKey = keyVal[0]
  let fuseVal = keyVal[1]
  let lootboxTemplatename = $"fuse_result_{fuseKey}"

  function onClick() {
    selectedRecipe.set(keyVal)
    removeModalWindow("fuseResulsInfo")
  }
  let keyItemFaked = mkFakeItem(fuseVal.relatedKey)

  let results = []

  foreach (templateOrId in fuseVal.fuseResult) {
    let marketLotId = toIntegerSafe(templateOrId, 0, false)
    let marketLot = marketItems.get()?[templateOrId].children.items
    let resultTemplate = marketLotId == 0 ? templateOrId : marketLot?[0].templateName ?? ""
    let faked = mkFakeItem(resultTemplate)
    results.append({
      behavior = Behaviors.Button
      onHover = function(on) {
        if (on)
          setTooltip(buildInventoryItemTooltip(faked))
        else
          setTooltip(null)
      }
      children = inventoryItemImage(faked, inventoryImageParams)
    })
  }
  for (local i=results.len(); i < fuseVal.totalResults; i++) {
    results.append(
      mkTooltiped(recognitionImagePattern, loc("amClean/unknownRecipeItemTooltip"), { size = [itemHeight, itemHeight] })
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
  for (local i=0; i < fuseVal.totalResults; i+=itemsCountPerRow) {
    resultsLists.append(mkRows(results.slice(i, i + itemsCountPerRow)))
  }

  let lootboxTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(lootboxTemplatename)
  let lootboxName = lootboxTemplate?.getCompValNullable("item__name")

  return button({
      gap = hdpx(10)
      padding = hdpx(10)
      flow = FLOW_VERTICAL
      children = [
        mkText(loc(lootboxName), { hplace = ALIGN_CENTER }.__update(body_txt))
        {
          flow = FLOW_HORIZONTAL
          children = [
            {
              size = [ keyItemColumnWidth, flex() ]
              children = {
                vplace = ALIGN_CENTER
                hplace = ALIGN_CENTER
                size = [itemHeight, itemHeight]
                children = {
                  behavior = Behaviors.Button
                  children = inventoryItemImage(keyItemFaked, inventoryImageParams)
                  eventPassThrough = true
                  onHover = function(on) {
                    if (on)
                      setTooltip(buildInventoryItemTooltip(keyItemFaked))
                    else
                      setTooltip(null)
                  }
                }
              }
            }
            {
              size = [ possibleItemsColumnWidth, SIZE_TO_CONTENT ]
              flow = FLOW_VERTICAL
              gap = hdpx(4)
              children = resultsLists
            }
          ]
        }
      ]
    },
    onClick
  )
}

function clearRecipe() {
  selectedRecipe.set(null)
}

function noRecipe() {
  function onClick() {
    clearRecipe()
    removeModalWindow("fuseResulsInfo")
  }

  return button(
    mkText(loc("amClean/selectNoRecipe"), { hplace = ALIGN_CENTER, vplace = ALIGN_CENTER }.__update(body_txt)),
    onClick,
    {
      size = [ flex(), hdpx(120) ]
    }
  )
}

let fuseResulsInfo = {
  rendObj = ROBJ_WORLD_BLUR_PANEL
  key = "fuseResulsInfo"
  size = flex()
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = @() {
    watch = refinerFusingRecipes
    size = const [ flex(), sh(80) ]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = {
      flow = FLOW_VERTICAL
      size = [ SIZE_TO_CONTENT, flex() ]
      gap = hdpx(10)
      children = [
        noRecipe()
        {
          hplace = ALIGN_LEFT
          flow = FLOW_HORIZONTAL
          gap = hdpx(10)
          rendObj = ROBJ_BOX
          fillColor = panelRowColor
          children = [
            {
              padding = hdpx(6)
              halign = ALIGN_CENTER
              size = [ keyItemColumnWidth, SIZE_TO_CONTENT ]
              children = mkText(loc("amClean/keyItemResultTableColumn/keyItem"))
            }
            {
              padding = hdpx(6)
              halign = ALIGN_CENTER
              size = [ possibleItemsColumnWidth, SIZE_TO_CONTENT ]
              children = mkText(loc("amClean/keyItemResultTableColumn/possibleResults"))
            }
          ]
        }
        makeVertScrollExt({
            hplace = ALIGN_CENTER
            vplace = ALIGN_TOP
            flow = FLOW_VERTICAL
            gap = hdpx(20)
            
            children = refinerFusingRecipes.get().topairs().sort(@(a, b) b[0] == "default" ? -1 : (b[0] <=> a[0])).map(fuseResultInfoRow)
          },
          {
            size = flex()
            styling = thinAndReservedPaddingStyle
          }
        )
      ]
    }
  }
}

function fillItemsForFuse(fuseRecipe) {
  if ((amProcessingTask.get()?.taskId ?? "") != "") {
    showMsgbox({ text = loc("amClean/autofill/taskAlreadyRunned")})
    return
  }

  if (fuseRecipe == null) {
    showMsgbox({ text = loc("amClean/autofill/haveNoItems")})
    return
  }

  let allPossibleItems = [].extend(
    inventoryItems.get()
    backpackItems.get()
    safepackItems.get()
    stashItems.get()
  )

  local keyItem = null
  let trashItemsCategory = []
  let usefullItems = []
  let otherKeyItems = []
  foreach (item in allPossibleItems) {
    if (!item.isCorrupted)
      continue

    if (keyItem == null && item.itemTemplate == fuseRecipe.relatedKey) {
      keyItem = item
      continue
    }

    if (refinerFusingRecipes.get().findindex(@(v) v.relatedKey == item.itemTemplate) != null) {
      if (otherKeyItems.len() <= itemCountsToActivateKeyItemSlot)
        otherKeyItems.append(item)
    }
    else if (item?.filterType == "loot")
      trashItemsCategory.append(item)
    else if (usefullItems.len() < itemCountsToActivateKeyItemSlot)
      usefullItems.append(item)

    if (trashItemsCategory.len() >= itemCountsToActivateKeyItemSlot && keyItem != null)
      break
  }

  if (keyItem == null) {
    showMsgbox({ text = loc("amClean/autofill/haveNoItems")})
    return
  }

  local ret = trashItemsCategory.slice(0, itemCountsToActivateKeyItemSlot - trashItemsCategory.len())
  ret = ret.extend(usefullItems.slice(0, itemCountsToActivateKeyItemSlot - ret.len()))
  ret = ret.extend(otherKeyItems.slice(0, itemCountsToActivateKeyItemSlot - ret.len()))

  if (ret.len() < itemCountsToActivateKeyItemSlot) {
    showMsgbox({ text = loc("amClean/autofill/haveNoItems")})
    return
  }

  itemsInRefiner.set([])

  dropToRefiner(keyItem, REFINER_STASH)
  foreach (item in ret) {
    dropToRefiner(item, REFINER_STASH)
  }
}

function refineRecipeSelection() {
  let onClick = @() refinerFusingRecipes.get()?.len() ? addModalWindow(fuseResulsInfo) : showMsgbox({ text = loc("amClean/noRecipesKnown") })

  return function() {
    local fakedKeyItem = null
    local fakedRecipeItem = null

    if (selectedRecipe.get()) {
      let currentRecipeComponentTemplate = selectedRecipe.get() ? selectedRecipe.get()?[1].relatedKey : null
      let currentRecipeTemplate = selectedRecipe.get() ? $"{templatePrefix}{selectedRecipe.get()?[0]}" : null

      fakedKeyItem = mkFakeItem(currentRecipeComponentTemplate)
      fakedRecipeItem = mkFakeItem(currentRecipeTemplate)
    }
    return {
      watch = selectedRecipe
      size = [ flex(), SIZE_TO_CONTENT ]
      flow = FLOW_VERTICAL
      gap = hdpx(6)
      children = [
        button({
            size = [ flex(), SIZE_TO_CONTENT ]
            flow = FLOW_HORIZONTAL
            children = [
              mkTextArea(fakedRecipeItem?.itemName ? loc(fakedRecipeItem?.itemName) : loc("amClean/selectRecipe"), {
                size = flex()
                hplace = ALIGN_CENTER
                vplace = ALIGN_CENTER
                halign = ALIGN_CENTER
                valign = ALIGN_CENTER
                minHeight = inventoryImageParams.slotSize[1] * 1.2
              }.__update(body_txt))
              fakedKeyItem ? {
                padding = [ 0, hdpx(20), 0, 0 ]
                behavior = Behaviors.Button
                onClick
                vplace = ALIGN_CENTER
                onHover = function(on) {
                  if (on)
                    setTooltip(buildInventoryItemTooltip(fakedKeyItem))
                  else
                    setTooltip(null)
                }
                children = inventoryItemImage(fakedKeyItem, inventoryImageParams)
              } : null
            ]
          },
          onClick,
          {
            size = [ flex(), SIZE_TO_CONTENT ]
          }
        )
        fakedKeyItem ? button(
          mkText(loc("amClean/refillContainer"), body_txt),
          @() fillItemsForFuse(selectedRecipe.get()?[1]),
          {
            size = [ flex(), SIZE_TO_CONTENT ]
            hplace = ALIGN_RIGHT
            vplace = ALIGN_CENTER
            valign = ALIGN_CENTER
            halign = ALIGN_CENTER
          }
        ) : null
      ]
    }
  }
}

function keyItemPanel() {
  return {
    size = [ flex(), SIZE_TO_CONTENT ]
    gap = hdpx(4)
    padding = hdpx(8)
    halign = ALIGN_CENTER
    children = [
      refineRecipeSelection()
      @() {
        watch = selectedRecipe
        hplace = ALIGN_RIGHT
        vplace = ALIGN_TOP
        children = selectedRecipe.get() ? mkCloseStyleBtn(clearRecipe, { stopHover = true }) : null
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

let keyItemPanelWithTitle = {
  flow = FLOW_VERTICAL
  size = [ flex(), SIZE_TO_CONTENT ]
  children = [
    {
      size = [ flex(), hdpx(45) ]
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

function mkAmProcessingItemPanel() {
  function updateRefinerData(task) {
    if (refineIsProcessing(task)) {
      let itemsToSell = task.sellItemInsideTemplateNames
      let itemsInsideTemplates = task.itemInsideTemplateNames
      let itemsReplicaTemplates = task.replicaItemInsideTemplateNames
      
      let inside = itemsInsideTemplates.map(function(v, index) {
        return mkFakeItem(v, {
          itemId = 0
          ammoCount = null
          isCorrupted = true
          forceLockIcon = true
          ui_order = index
          countPerStack = 1 
        })
      }).extend(
        
        itemsToSell.map(function(v, index) {
          return mkFakeItem(v, {
            itemId = 0
            ammoCount = null
            isCorrupted = false
            forceLockIcon = true
            ui_order = index
            countPerStack = 1 
          })
        }),
        
        itemsReplicaTemplates.map(function(v, index) {
          return mkFakeItem(v, {
            itemId = 0
            ammoCount = null
            isCorrupted = false
            forceLockIcon = true
            ui_order = index
            countPerStack = 1 
            isReplica = true 
          })
        })
      )

      itemsInRefiner.set(inside)
      currentRefinerIsReadOnly.set(true)
    }
    else {
      itemsInRefiner.set([])
      currentKeyItem.set(null)
      currentRefinerIsReadOnly.set(false)
    }
  }
  amProcessingTask.subscribe(updateRefinerData)
  updateRefinerData(amProcessingTask.get())

  let itemsOnPlayer = Computed(function() {
    return []
      .extend(
        inventoryItems.get()
        backpackItems.get()
        safepackItems.get()
        stashItems.get()
      )
      .map(@(item) addStorageType(item, stashItems.get(), inventoryItems.get(), backpackItems.get(), safepackItems.get()))
  })

  let stashRefineItemsPanelData = setupPanelsData(itemsOnPlayer,
                                    3,
                                    [itemsOnPlayer, itemsInRefiner, activeFilters, currentKeyItem, refinedItemsList, refinerFusingRecipes],
                                    processStashRefineItems)

  let containerItemsPanelData = setupPanelsData(itemsInRefiner,
                                    3,
                                    [itemsInRefiner],
                                    processContainerItems)

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
          size = [ flex(), hdpx(45) ]
        }.__merge(bluredPanel)
        makeVertScroll({
            flow = FLOW_VERTICAL
            gap = hdpx(5)
            size = [ flex(), SIZE_TO_CONTENT ]
            children = mkExpectedRewardPanel(itemsInRefiner.get(), currentKeyItem.get(), selectedRecipe.get())
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
        if (item.fromList.name == "containerItemsList")
          return MoveForbidReason.ITEM_ALREADY_IN

        return MoveForbidReason.NONE
      }

      let mkCompleteBtn = @(refiner) @() {
        watch = [ refineGettingInProgress ]
        children = textButton(loc("amClean/Done"), function() {
          finishRefine(refiner)
        },
        {
          isEnabled = !refineGettingInProgress.get()
        }.__update(accentButtonStyle))
      }
      function mkInProgressBox(task) {
        let countdown = mkCountdownTimerPerSec(Watched(task.endTimeAt.tointeger()))
        let hasCountDown = Computed(@() countdown.get() > 0)
        return function() {
          return {
            watch = hasCountDown
            size = flex()
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            children = [
              inProgressPanel(countdown.get() == 0 ? const Color(10, 30, 50, 0) : const Color(10,10,10,10))
              !hasCountDown.get() ? mkCompleteBtn(task) : null
            ]
          }
        }
      }

      let rmbAction = inventoryItemClickActions?[REFINER.name].rmbAction
      return {
        size = [SIZE_TO_CONTENT, flex()]
        watch = [ containerItemsPanelData.numberOfPanels ]
        hplace = ALIGN_RIGHT
        children = [
          itemsPanelList({
            outScrollHandlerInfo=containerItemsPanelData.scrollHandlerData,
            list_type = REFINER,
            itemsPanelData=containerItemsPanelData.itemsPanelData,
            headers = {
              padding = hdpx(6)
              size = [ flex(), SIZE_TO_CONTENT ]
              children = const mkInventoryHeader(loc("amClean/itemsList"), null)
            }
            can_drop_dragged_cb,
            on_item_dropped_to_list_cb = function(item, _list_type) {
              if (currentKeyItem.get()?.uniqueId == item.uniqueId) {
                dropToRefiner(currentKeyItem.get(), item.fromList)
                currentKeyItem.set(null)
              }
              else
                dropToRefiner(item, item.fromList)
            },
            item_actions={
              rmbAction = rmbAction
              lmbAction = removeFromRefiner
              lmbShiftAction = removeFromRefiner
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
            itemIconParams = currentRefinerIsReadOnly.get() ? const inventoryImageParams.__merge( { opacity = 0.3 } ) : inventoryImageParams
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
      size = [SIZE_TO_CONTENT, flex()]
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

  let inventoryPanel = @() {
    size = const [ SIZE_TO_CONTENT, flex() ]
    gap = hdpx(5)
    flow = FLOW_HORIZONTAL
    watch = [ refinedItemsList, refinerFusingRecipes ]
    children = [
      mkInventory(stashRefineItemsPanelData, REFINER_STASH, [ stashRefineItemsPanelData.numberOfPanels, refinedItemsList, refinerFusingRecipes ])
      inventoryFiltersWidget
    ]
  }

  let infoPanel = @() {
    watch = [ refinerFillAmount, itemsInRefiner ]
    size = const [SIZE_TO_CONTENT, flex()]
    children = cleanInfoBlock
  }

  return {
    onAttach = function() {
      containerItemsPanelData.onAttach()
      stashRefineItemsPanelData.onAttach()

      if (amProcessingTask.get()?.keyItemTemplateName.len()) {
        let fake = mkFakeItem(amProcessingTask.get()?.keyItemTemplateName)
        currentKeyItem.set(fake)
      }
    }
    onDetach = function() {
      containerItemsPanelData.onDetach()
      stashRefineItemsPanelData.onDetach()
      itemsInRefiner.set([])
      currentKeyItem.set(null)
    }

    size = const [ SIZE_TO_CONTENT, flex() ]
    halign = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    hplace = ALIGN_CENTER
    gap = const hdpx(10)
    children = [
      infoPanel
      inventoryPanel
      isCtrlPressedMonitor
      shiftPressedMonitor
    ]
  }
}

return {
  mkAmProcessingItemPanel
  AmProcessingItemId
  selectAmItemName
  refineIsProcessing
  refinesReady
}
