from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { cleanableItems, marketPriceSellMultiplier, playerProfileAMConvertionRate,
      refinedItemsList, refinerFusingRecipes } = require("%ui/profile/profileState.nut")
let { isShiftPressed } = require("%ui/hud/state/inventory_state.nut")
let { get_item_info, getTemplateNameByEid } = require("%ui/hud/state/item_info.nut")
let { ceil } = require("math")
let { template2MarketOffer } = require("%ui/mainMenu/market/inventoryToMarket.nut")
let { truncateToMultiple } = require("%sqstd/math.nut")
let { creditsTextIcon } = require("%ui/mainMenu/currencyIcons.nut")
let colorize = require("%ui/components/colorize.nut")
let { InfoTextValueColor } = require("%ui/components/colors.nut")

enum RefinedInfo {
  UNKNOWN = 0
  REGULAR_ITEM = 1
  KEY_ITEM = 2
}

let itemsInRefiner = Watched([])
let currentRefinerIsReadOnly = Watched(false)
let refineGettingInProgress = Watched(false)

let maxFoldedItemsToShow = 7

const REFINER_ALARM = "refinerAlarmAnimation"

let refinerFillAmount = Computed(function() {
  let cont = itemsInRefiner.get()
  return cont.reduce(function(acc, v) {
    acc += v?.volume ?? 0
    return acc
  }, 0)
})

let minimalRefinerItemComp = [
  ["item_enriched", ecs.TYPE_TAG, null],
  ["item__name", ecs.TYPE_STRING, ""],
  ["itemContainer", ecs.TYPE_EID_LIST, null],
  ["gun_mods__curModInSlots", ecs.TYPE_OBJECT, null],
  ["equipment_mods__curModInSlots", ecs.TYPE_OBJECT, null],
]
let get_item_minimal_refiler_data = ecs.SqQuery("get_item_minimal_refiler_data", {
  comps_ro = minimalRefinerItemComp
})

function getMinimalRefinerItem(eid) {
  let recursive = callee()
  return get_item_minimal_refiler_data.perform(eid, function(itemEid, itemComp) {
    let modtable = (itemComp.gun_mods__curModInSlots?.getAll() ?? itemComp.equipment_mods__curModInSlots?.getAll() ?? {}).map(recursive)
    return {
      itemTemplate = getTemplateNameByEid(itemEid)
      itemName = itemComp.item__name
      isCorrupted = itemComp?.item_enriched != null
      itemContainerItems = itemComp?.itemContainer.getAll()
      modInSlots = modtable
    }
  })
}

function getPriceOfNonCorruptedItem(templateToMarket, priceMult, item) {
  if (item?.isReplica)
    return 1
  return ceil((templateToMarket?[item.itemTemplate].reqMoney ?? 0) * priceMult)
}

function itemRefinedResult(item, refinedList, refinerRecipes) {
  if (!refinedList.contains(item.itemTemplate))
    return RefinedInfo.UNKNOWN

  let isKeyItem = refinerRecipes.findindex(@(v) v.totalResults != 0 && v.relatedKey == item.itemTemplate) != null
  return isKeyItem ? RefinedInfo.KEY_ITEM : RefinedInfo.REGULAR_ITEM
}

function patchItemRefineData(item) {
  let stringsFromAttachments = {}
  let stringsFromItemsInside = {}

  local nonCorruptedModPrice = 0
  local minModAm = 0
  local maxModAm = 0
  function refineDataFromAttachedMods(itemWithAttaches) {
    foreach (mod in (itemWithAttaches?.modInSlots ?? {})) {
      let str = loc(mod?.itemName)
      if (str) {
        if (mod.itemTemplate in stringsFromAttachments)
          stringsFromAttachments[mod.itemTemplate].count++
        else {
          stringsFromAttachments[mod.itemTemplate] <- {
            str = str
            count = 1
          }
        }
      }

      let cleanableMod = cleanableItems.get()?[mod.itemTemplate]
      if (mod.isCorrupted && cleanableMod != null) {
        minModAm += cleanableMod.amContains.x
        maxModAm += cleanableMod.amContains.y
      }
      else {
        nonCorruptedModPrice += getPriceOfNonCorruptedItem(template2MarketOffer.get(), marketPriceSellMultiplier.get(), mod)
      }
    }
  }

  function refineDataFromContainerItems(containerItems) {
    foreach (itemEid in containerItems) {
      let foldedItem = getMinimalRefinerItem(itemEid)

      if (foldedItem == null)
        continue

      refineDataFromAttachedMods(foldedItem)
      let str = loc(foldedItem?.itemName)
      if (str) {
        if (foldedItem.itemTemplate in stringsFromItemsInside)
          stringsFromItemsInside[foldedItem.itemTemplate].count++
        else {
          stringsFromItemsInside[foldedItem.itemTemplate] <- {
            str = str
            count = 1
          }
        }
      }

      if (foldedItem?.itemContainerItems.len())
        refineDataFromContainerItems(foldedItem.itemContainerItems)

      let cleanData = cleanableItems.get()?[foldedItem.itemTemplate]
      if (foldedItem.isCorrupted && cleanData != null) {
        minModAm += cleanData.amContains.x
        maxModAm += cleanData.amContains.y
      }
      else {
        nonCorruptedModPrice += getPriceOfNonCorruptedItem(template2MarketOffer.get(), marketPriceSellMultiplier.get(), foldedItem)
      }
    }
  }

  refineDataFromAttachedMods(item)
  if (item?.itemContainerItems.len())
    refineDataFromContainerItems(item.itemContainerItems)

  local minMoney = 0
  local maxMoney = 0
  local nonCorruptedPrice = 0

  let cleanableItem = cleanableItems.get()?[item.itemTemplate]
  if (item.isCorrupted && cleanableItem) {
    minMoney = truncateToMultiple((cleanableItem.amContains.x) / 10.0 * playerProfileAMConvertionRate.get(), 1) 
    maxMoney = truncateToMultiple((cleanableItem.amContains.y) / 10.0 * playerProfileAMConvertionRate.get(), 1)
  }
  else {
    nonCorruptedPrice = getPriceOfNonCorruptedItem(template2MarketOffer.get(), marketPriceSellMultiplier.get(), item)
  }

  let stringsToShow = []
  if (minMoney > 0 || maxMoney > 0) {
    let moneyStr = minMoney==maxMoney ?
      loc("amClean/expectedMoneySingle", {minVal=$"{creditsTextIcon}{minMoney}"}) :
      loc("amClean/expectedMoney", {minVal=$"{creditsTextIcon}{minMoney}", maxVal=$"{maxMoney}"})
    stringsToShow.append(moneyStr)
  }
  if (nonCorruptedPrice > 0) {
    let moneyStr = loc("amClean/expectedMoneyFromNonCorruptedItems", {minVal=$"{creditsTextIcon}{nonCorruptedPrice}"})
    stringsToShow.append(moneyStr)
  }

  if (stringsFromAttachments.len() > 0) {
    local it = 0
    stringsToShow.append($"{loc("amClean/attachedItems")}")
    foreach (attach in stringsFromAttachments) {
      stringsToShow.append($"  {loc("ui/multiply")}{attach.count} {colorize(InfoTextValueColor, attach.str)}")
      it++
      if (it > maxFoldedItemsToShow) {
        stringsToShow.append("...")
        break
      }
    }
  }
  if (stringsFromItemsInside.len() > 0) {
    local it = 0
    stringsToShow.append($"\n{loc("desc/inventory_items_inside")}")
    foreach (folded in stringsFromItemsInside) {
      stringsToShow.append($"  {loc("ui/multiply")}{folded.count} {colorize(InfoTextValueColor, folded.str)}")
      it++
      if (it > maxFoldedItemsToShow) {
        stringsToShow.append("...")
        break
      }
    }
  }

  if (minModAm > 0 || maxModAm > 0) {
    stringsToShow.append("")
    let moneyStr = minModAm==maxModAm ?
      loc("amClean/expectedMoneySingle", {minVal=$"{creditsTextIcon}{minModAm}"}) :
      loc("amClean/expectedMoney", {minVal=$"{creditsTextIcon}{minModAm}", maxVal=$"{maxModAm}"})
    stringsToShow.append(moneyStr)
  }
  if (nonCorruptedModPrice > 0) {
    stringsToShow.append("")
    let moneyStr = loc("amClean/expectedMoneyFromNonCorruptedItems", {minVal=$"{creditsTextIcon}{nonCorruptedModPrice}"})
    stringsToShow.append(moneyStr)
  }

  let refined = item?.isCorrupted == true ? itemRefinedResult(item, refinedItemsList.get(), refinerFusingRecipes.get()) : RefinedInfo.REGULAR_ITEM
  if (refined == RefinedInfo.REGULAR_ITEM) {
    stringsToShow.append(loc("amClean/regularItemTooltip"))
  }
  else if (refined == RefinedInfo.KEY_ITEM) {
    stringsToShow.append(loc("amClean/keyItemTooltip"))
  }
  else {
    stringsToShow.append(loc("amClean/unknownResultTooltip"))
  }

  item["additionalDesc"] <- stringsToShow
}

function dropToRefiner(item, fromListName) {
  if (currentRefinerIsReadOnly.get())
    return

  let indexToProceed = isShiftPressed.get() ? item.uniqueIds.len() : 1
  itemsInRefiner.mutate(function(refiner) {
    for (local i=0; i < indexToProceed; i++) {
      let defParams = {
        count = 1
        charges = null
      }
      let additionalFields = {
        uniqueId = item.uniqueIds[i]
        uniqueIds = [ item.uniqueIds[i] ]
        eid = item.eids[i]
        eids = [ item.eids[i] ]
        refiner__fromList = fromListName
        id = item.id
      }.__update(defParams)
      let foldedItemParams = {
        inactiveSlot = true
        picSaturate = 0.0
        opacity = 0.4
        backgroundColor = Color(40,40,40,205)
        isDragAndDropAvailable = false
        countPerStack = 1 
      }

      local hasFoldedItems = false
      foreach (_k, v in (item?.itemContainerItems ?? {} )) {
        refiner.append(get_item_info(v).__update(foldedItemParams, { sortAfterEid = item.eid }))
        hasFoldedItems = true
      }
      foreach (_k, v in (item?.modInSlots ?? {} )) {
        refiner.append(get_item_info(v.eid).__update(foldedItemParams, { sortAfterEid = item.eid }))
        hasFoldedItems = true
      }

      refiner.append(item?.itemOverridedWithProto ?
        get_item_info(item.eids[i]).__update(additionalFields, hasFoldedItems ? { hasFoldedItems } : {} ) :
        item.__merge(additionalFields, hasFoldedItems ? { hasFoldedItems } : {})
      )
    }
  })
}

function removeFromRefiner(item) {
  if (currentRefinerIsReadOnly.get() || item?.inactiveSlot)
    return

  let indexToProceed = isShiftPressed.get() ? item.uniqueIds.len() : 1
  let eidsToRemove = []
  for(local i=0; i < indexToProceed; i++){
    let eid = item.eids[i]
    eidsToRemove.append(eid)
    if (item?.hasFoldedItems) {
      foreach (refinerItem in itemsInRefiner.get()) {
        if (refinerItem?.sortAfterEid == eid)
          eidsToRemove.append(refinerItem.eid)
      }
    }
  }
  itemsInRefiner.set(itemsInRefiner.get().filter(@(v) !eidsToRemove.contains(v.eid) ))
}

return {
  itemsInRefiner
  currentRefinerIsReadOnly
  refineGettingInProgress
  refinerFillAmount
  dropToRefiner
  removeFromRefiner
  REFINER_ALARM
  patchItemRefineData
  getPriceOfNonCorruptedItem
  getMinimalRefinerItem
  maxFoldedItemsToShow
}