from "%ui/components/commonComponents.nut" import mkTextArea
from "math" import ceil
from "%ui/components/colors.nut" import RedWarningColor, BtnTextHighlight
from "%ui/mainMenu/currencyIcons.nut" import creditsTextIcon, premiumCreditsTextIcon, premiumColor, creditsColor
from "%ui/profile/profileState.nut" import playerProfileCreditsCount, playerProfilePremiumCredits,
  marketItems, playerStats
import "%ui/components/colorize.nut" as colorize
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


let template2MarketIds = Computed(function() {
  let market = marketItems.get()
  let ret = {}
  foreach (id, itm in market) {
    if(!itm.buyable || (itm.children?.items.len() ?? 0 ) == 0)
      continue
    ret[itm.children.items[0].templateName] <- id
  }
  return ret
})


let template2MarketOffer = keepref(Computed(function() {
  let market = marketItems.get()
  let ret = {}
  foreach (_id, itm in market) {
    if((itm.children?.items.len() ?? 0 ) == 0)
      continue
    ret[itm.children.items[0].templateName] <- itm
  }
  return ret
}))

function getItemType(inventoryItem) {
  return (inventoryItem.isEquipment ? "equipment" :
    inventoryItem.isWeapon ? "weapons" :
    inventoryItem.isWeaponMod ? "weapon_mods" :
    inventoryItem.isAmmo ? "ammunition" :
    inventoryItem.isHealkit ? "medicines" :
    "itemsOnMe")
}

function getLotsFromInventory(inventoryItems, itemIn) {
  let items = {}
  function addItm(itm) {
    if (!itm?.eid || itm?.currentWeaponSlotName == "grenade")
      return
    let fullTemplateName = ecs.g_entity_mgr.getEntityTemplateName(itm.eid)
    let templateName = fullTemplateName?.slice(0, fullTemplateName?.indexof("+") ?? 0)
    if (!templateName)
      return
    if(items?[templateName])
      return

    let marketId = template2MarketIds.get()?[templateName] ?? templateName
    let lot = marketItems.get()?[marketId]
    items[templateName] <- {
      requirements = {
        stats = lot?.requirements?.stats ?? {}
        unlocks = lot?.requirements?.unlocks ?? []
      }
      itemType = lot?.itemType ?? getItemType(itm)
      id = marketId
      playerHasIn = itemIn
      children = {
        recipes = []
        items = [{
          insertIntoSlot = ""
          charges = 0
          insertIntoIdx = -1
          templateName = templateName
        }]
      }
      reqMoney = lot?.reqMoney ?? -1
      offerName = ""
      buyable = false
    }
  }
  inventoryItems.each(addItm)
  return items
}

function getLotFromItem(item) {
  let templateName = item?.itemTemplate
  if ((templateName?.len() ?? 0) == 0)
    return 0
  let needToShowInShop = item?.itemType == "weapon" || item?.itemType == "ammo"
  let result = marketItems.get().findindex(function(lot) {
    if (needToShowInShop)
      return (lot.children.items?[0]?.templateName ?? "") == templateName && lot?.itemType != "presets"
    else
      return (lot.children.items?[0]?.templateName ?? "") == templateName
        && lot?.itemType != "presets" && lot?.buyable
  })

  return result ?? 0
}

function getBaseUpgradeFromItem(item) {
  let templateName = item?.itemTemplate
  if ((templateName?.len() ?? 0) == 0)
    return 0
  let result = marketItems.get().findindex(@(lot) (lot.children.baseUpgrades?[0] ?? "") == templateName && lot?.buyable)
  return result ?? 0
}

function getPriceFromLot(lot) {
  let marketItem = marketItems.get()?[lot]
  let { reqMoney = -1, additionalPrice = {} } = marketItem
  let isPremium = (additionalPrice?.premiumCreditsCount ?? 0) > 0
  return {
    isPremium
    price = isPremium ? additionalPrice.premiumCreditsCount : reqMoney
  }
}

function isLotAvailable(item, playerStat) {
  let isAdmin = (playerStat?.unlocks ?? []).findindex(@(v) v == "__ADMIN__") != null
  if (isAdmin)
    return true
  let { reqMoney = 0, buyable = false, additionalPrice = {} } = item
  let isPremium = (additionalPrice?.premiumCreditsCount ?? 0) > 0
  let price = isPremium ? additionalPrice.premiumCreditsCount : reqMoney
  if (!buyable || price <= 0)
    return false

  let req = item.requirements
  foreach(md, mdNeed in req.stats) {
    foreach(st, statsNeed in mdNeed) {
      let plStatVal = (playerStat.stats?[md]?[st] ?? 0.0)
      let needMore = statsNeed - plStatVal
      if (needMore > 0)
        return false
    }
  }

  foreach(unl in req.unlocks) {
    let unlocked = (playerStat.unlocks.findindex(@(v) unl == v) != null)
    if (!unlocked)
      return false
  }

  return true
}

function mkItemPrice(priceData, override = {}) {
  let { price, isPremium } = priceData
  let currencyIcon = isPremium ? premiumCreditsTextIcon : creditsTextIcon
  let color = isPremium ? premiumColor : creditsColor
  let currency = colorize(color, currencyIcon)
  return @() {
    watch = [playerProfileCreditsCount, playerProfilePremiumCredits]
    rendObj = ROBJ_BOX
    borderRadius = [0, 0, 0,  hdpx(5)]
    fillColor = Color(67, 67, 67)
    hplace = ALIGN_RIGHT
    vplace = ALIGN_TOP
    padding = hdpx(3)
    children = mkTextArea($"{currency}{price}", {
      color = isPremium
        ? (price <= playerProfilePremiumCredits.get() ? BtnTextHighlight : RedWarningColor)
        : (price <= playerProfileCreditsCount.get() ? BtnTextHighlight : RedWarningColor)
        size = SIZE_TO_CONTENT
    }.__update(override))
  }
}

function getWeaponModsPrice(weaponMarketItem, attachments, playerStat) {
  local res = 0

  foreach (mod in attachments) {
    let { itemTemplate = mod, noSuitableItemForPresetFoundCount = 0, countPerStack = 1 } = mod
    if (weaponMarketItem?.children.items.findvalue(@(v) v?.templateName == itemTemplate) != null)
      continue
    let modMarketId = getLotFromItem({ itemTemplate })
    if (modMarketId == null)
      continue
    let modMarketItem = marketItems.get()?[modMarketId]
    if (modMarketItem == null)
      continue

    if (!isLotAvailable(weaponMarketItem, playerStat))
      continue
    let modPrice = getPriceFromLot(modMarketId).price
    let modPriceToAdd = countPerStack > 1
      ? modPrice * ceil(noSuitableItemForPresetFoundCount.tofloat() / countPerStack.tofloat())
      : modPrice * noSuitableItemForPresetFoundCount
    res += modPriceToAdd
  }
  return res
}

function getItemPriceToShow(item) {
  let lot = getLotFromItem(item)
  if (lot == null)
    return null

  let marketItem = marketItems.get()?[lot]
  if (!isLotAvailable(marketItem, playerStats.get()))
    return null

  let { noSuitableItemForPresetFoundCount = 0, countPerStack = 1, needToShowPrice = false } = item
  if (noSuitableItemForPresetFoundCount == 0 && !needToShowPrice)
    return null

  let { price, isPremium } = getPriceFromLot(lot)
  local priceToShow = countPerStack > 1
    ? price * ceil(noSuitableItemForPresetFoundCount.tofloat() / countPerStack.tofloat())
    : price * noSuitableItemForPresetFoundCount

  return { price = priceToShow, isPremium }
}

return {
  isLotAvailable
  template2MarketIds
  getLotsFromInventory
  getLotFromItem
  getBaseUpgradeFromItem
  getItemPriceToShow
  getPriceFromLot
  mkItemPrice
  getWeaponModsPrice
  template2MarketOffer
}