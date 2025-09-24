from "%sqstd/string.nut" import utf8ToLower

from "%ui/mainMenu/market/inventoryToMarket.nut" import getLotFromItem, isLotAvailable
from "%ui/hud/state/item_info.nut" import getSlotAvailableMods
import "%ui/components/faComp.nut" as faComp
from "%ui/components/cursors.nut" import setTooltip
from "%ui/fonts_style.nut" import fontawesome
from "math" import ceil
from "%ui/hud/hud_menus_state.nut" import convertMenuId
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem
from "%ui/state/queueState.nut" import isQueueHiddenBySchedule
from "%ui/state/matchingUtils.nut" import get_matching_utc_time
from "%ui/components/msgbox.nut" import showMsgbox

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

from "%ui/squad/squadState.nut" import squadLeaderState
from "%sqGlob/dasenums.nut" import ContractType
from "%ui/profile/profileState.nut" import playerProfileCurrentContracts

let { marketItems, trialData } = require("%ui/profile/profileState.nut")
let { weaponsList } = require("%ui/hud/state/hero_weapons.nut")
let { previewPreset } = require("%ui/equipPresets/presetsState.nut")
let { currentMenuId, setCurrentMenuId } = require("%ui/hud/hud_menus_state.nut")
let { isInQueue } = require("%ui/state/queueState.nut")
let { selectedRaid, leaderSelectedRaid } = require("%ui/gameModeState.nut")
let { PREPARATION_NEXUS_SUBMENU_ID, nexusItemCost } = require("%ui/hud/menus/mintMenu/mintState.nut")

const PREPARATION_SUBMENU_ID = "PREPARATION_SUBMENU_ID"
const Missions_id = "Missions"

let mintEditState = Watched(false)
let currentPrimaryContractIds = Watched({})

function closePreparationsScreens(){
  let sid = convertMenuId(currentMenuId.get())
  let id = sid[0]
  if (id == Missions_id)
    setCurrentMenuId(Missions_id)
}
let isPreparationOpened_ = @(subid) Computed(function() {
  let [id, sumbenus] = convertMenuId(currentMenuId.get())
  return id==Missions_id && subid==sumbenus?[0]
})

let isPreparationOpened = isPreparationOpened_(PREPARATION_SUBMENU_ID)
let isNexusPreparationOpened = isPreparationOpened_(PREPARATION_NEXUS_SUBMENU_ID)

function checkRaidAvailability() {
  let raid = selectedRaid.get()
  let isHidden = isQueueHiddenBySchedule(raid, get_matching_utc_time())
  if (isHidden) {
    if (!isInQueue.get()) {
      showMsgbox({ text = loc("missions/unavailable") })
      leaderSelectedRaid.set({ raidData = null, isOffline = false })
      closePreparationsScreens()
    }
  }
}

let slotsWithWarning = Watched({})

function isItemCanBePurchased(marketId, playerStat) {
  let marketItem = marketItems.get()?[marketId]
  if (marketItem == null) {
    return false
  }
  return isLotAvailable(marketItem, playerStat, trialData.get())
}

function getPresetMissedItemsMarketIds(preset, playerStat) {
  let scanItems = [
    preset?.flashlight
    preset?.pouch
    preset?.backpack
    preset?.helmet
  ].extend(
    preset?.chronogene_primary_1.values() ?? []
    preset?.pouch.values() ?? []
    preset?.weapons ?? []
    preset?.inventories.myItems.items ?? []
    preset?.inventories.backpack.items ?? []
  ).filter(@(v) v?.itemTemplate != null)

  let toBuyItems = []
  foreach (item in scanItems) {
    let { countPerStack = 1, noSuitableItemForPresetFoundCount = 0, attachments = {} } = item
    let marketId = getLotFromItem(item)
    if (noSuitableItemForPresetFoundCount == 0 || !isItemCanBePurchased(marketId, playerStat))
      continue

    if (noSuitableItemForPresetFoundCount == 0 && attachments.len() > 0) {
      let anyAttachMissed = attachments.findvalue(@(att) (att?.noSuitableItemForPresetFoundCount ?? 0) > 0) != null
      if (!anyAttachMissed)
        continue
    }

    if (attachments.len() > 0) {
      let marketItem = marketItems.get()?[marketId]
      foreach (mod in attachments) {
        if ((mod?.noSuitableItemForPresetFoundCount ?? 0) <= 0
          || marketItem?.children.items.findvalue(@(v) v?.templateName == mod.itemTemplate) != null
        )
          continue
        let modMarketId = getLotFromItem({ itemTemplate = mod?.itemTemplate ?? mod })
        if (modMarketId != null && isItemCanBePurchased(modMarketId, playerStat)) {
          let itemsToPurchase = countPerStack > 1
            ? ceil((mod?.noSuitableItemForPresetFoundCount ?? noSuitableItemForPresetFoundCount).tofloat() / countPerStack.tofloat())
            : (mod?.noSuitableItemForPresetFoundCount ?? noSuitableItemForPresetFoundCount)
          toBuyItems.append({ id = modMarketId, count = itemsToPurchase, usePremium = false })
        }
      }
    }

    if (marketId != 0) {
      let itemsToPurchase = countPerStack > 1 ?
        ceil(noSuitableItemForPresetFoundCount.tofloat() / countPerStack.tofloat()) :
        noSuitableItemForPresetFoundCount
      toBuyItems.append({ id = marketId, count = itemsToPurchase, usePremium = false })
    }
  }
  return toBuyItems
}


function getPresetMissedBoxedItemsMarketIds(preset, playerStat) {
  let missed = preset?.boxedItemMissed ?? {}
  let ret = []
  foreach (k, v in missed) {
    let lotId = getLotFromItem({itemTemplate = v})
    if (!isItemCanBePurchased(lotId, playerStat))
      continue

    let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(k)
    let countPerStack = template?.getCompValNullable("item__countPerStack") ?? 1

    
    let toBuyCount = v / countPerStack + 1

    if (lotId)
      ret.append({ id = lotId, count = toBuyCount, usePremium = false })
  }
  return ret
}

let slotsToCheck = ["safepack", "backpack", "pouch"]
let presetSlotsToCheck = ["pouch"]
let weaponSlotsToCheck = ["weapon_0", "weapon_1", "weapon_2"]
let weaponSlots = {
  weapon_0 = "primary"
  weapon_1 = "secondary"
  weapon_2 = "tertiary"
}

function isMagazineInLoadoutWithAmmo(magName, loadout) {
  return loadout.findindex(@(v) v.templateName == magName && (v?.charges ?? 0) > 0) != null
}

function checkWeaponAmmo(weapon, loadout, slot) {
  let gunMods = weapon?.getCompValNullable("gun_mods__slots").getAll() ?? {}
  let magazineSlotTemplateName = gunMods?.magazine
  if (!magazineSlotTemplateName) {
    let weapons = weaponsList.get()
    let weaponToCheck = weapons.findvalue(@(v) v?.currentWeaponSlotName == weaponSlots?[slot])
    return (weaponToCheck?.curAmmo ?? 0) > 0
  }

  let magazines = getSlotAvailableMods(magazineSlotTemplateName)
  let hasAmmo = magazines.findindex(@(v) isMagazineInLoadoutWithAmmo(v, loadout)) != null
  return hasAmmo
}

function getWarningSlots(loadout) {
  let weapWithoutAmmo = []
  let slotsWithoutItem = []
  let weaponSlotsWithoutItem = []
  foreach (slot in slotsToCheck) {
    let itemInSlot = loadout.findvalue(@(v) v?.slotName == slot)
    if(!itemInSlot)
      slotsWithoutItem.append(weaponSlots?[slot] ?? slot)
  }
  foreach (slot in weaponSlotsToCheck) {
    let itemInSlot = loadout.findvalue(@(v) v?.slotName == slot)
    if(!itemInSlot)
      weaponSlotsWithoutItem.append(weaponSlots?[slot] ?? slot)
    let isWeapon = slot in weaponSlots
    if (!isWeapon || itemInSlot?.templateName == null)
      continue
    let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(itemInSlot.templateName)
    if(!checkWeaponAmmo(template, loadout, slot)) {
      let locname = template?.getCompValNullable("item__name") ?? "unknown"
      weapWithoutAmmo.append({ slot = weaponSlots?[slot] ?? slot, weapon = locname })
    }
  }
  return { weapWithoutAmmo, slotsWithoutItem, weaponSlotsWithoutItem }
}

function checkImportantSlotEmptiness(loadout) {
  if (loadout == null || loadout.len() == 0) {
    slotsWithWarning.set({})
    return
  }
  let { weapWithoutAmmo, slotsWithoutItem, weaponSlotsWithoutItem } = getWarningSlots(loadout)
  let res = {}
  slotsWithoutItem.each(@(v) res[v] <- { reason = "warning/empty" })
  weapWithoutAmmo.each(function(v) {
    let { slot, weapon } = v
    res[slot] <- { reason = "warning/noAmmo", weapon }
  })

  if (weaponSlotsWithoutItem.len() == weaponSlotsToCheck.len())
    weaponSlotsWithoutItem.each(@(v) res[v] <- { reason = "warning/empty" })

  slotsWithWarning.set(res)
}

function checkPresetWeaponMagazine(weapon, presetSlot) {
  let gunMods = weapon?.getCompValNullable("gun_mods__slots").getAll() ?? {}
  return ("magazine" in gunMods && "magazine" not in (presetSlot?.attachments ?? {}))
}

function getWarningPresetSlots(preset) {
  let weapWithoutMagazine = []
  let slotsWithoutItem = []
  let weaponSlotsWithoutItem = []
  foreach (slot in presetSlotsToCheck) {
    let itemInSlot = slot in preset
    if (!itemInSlot)
      slotsWithoutItem.append(weaponSlots?[slot] ?? slot)
  }
  foreach (idx, _slot in weaponSlotsToCheck) {
    let { weapons = [] } = preset
    let itemInSlot = weapons?[idx] ?? {}
    if (itemInSlot.len() <= 0)
      weaponSlotsWithoutItem.append(weaponSlots[weaponSlotsToCheck[idx]])
    if (itemInSlot?.itemTemplate == null)
      continue
    let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(itemInSlot.itemTemplate)
    if (checkPresetWeaponMagazine(template, itemInSlot)) {
      let locname = template?.getCompValNullable("item__name") ?? "unknown"
      weapWithoutMagazine.append({ slot = weaponSlots[weaponSlotsToCheck[idx]], weapon = locname })
    }
  }
  return { weapWithoutMagazine, slotsWithoutItem, weaponSlotsWithoutItem }
}

function checkImportantPresetSlotEmptiness(preset) {
  if (preset == null || preset.len() == 0) {
    slotsWithWarning.set({})
    return
  }
  let { weapWithoutMagazine, slotsWithoutItem, weaponSlotsWithoutItem } = getWarningPresetSlots(preset)
  let res = {}
  slotsWithoutItem.each(@(v) res[v] <- { reason = "warning/empty" })
  weapWithoutMagazine.each(function(v) {
    let { slot, weapon } = v
    res[slot] <- { reason = "warning/noMagazine", weapon }
  })

  if (weaponSlotsWithoutItem.len() == weaponSlotsToCheck.len())
    weaponSlotsWithoutItem.each(@(v) res[v] <- { reason = "warning/empty" })

  slotsWithWarning.set(res)
}

let mkWarningSign = @(slotNameLocId, reason, weapon = null) function() {
  let watch = previewPreset
  if (previewPreset.get() != null && !isNexusPreparationOpened.get())
    return { watch }

  return {
    watch
    children = faComp("exclamation-triangle", {
      rendObj = ROBJ_INSCRIPTION
      behavior = Behaviors.Button
      onHover = function(on) {
        let tip = weapon == null
          ? loc(reason, { slot = utf8ToLower(loc(slotNameLocId)) })
          : loc(reason, { weapon = utf8ToLower(loc(weapon)) })
        setTooltip(on ? tip : null)
      }
      color = Color(245, 100, 30)
      hplace = ALIGN_RIGHT
      vplace = ALIGN_BOTTOM
      eventPassThrough = true
      padding = hdpx(2)
      transform = {}
      animations = [
        { prop = AnimProp.opacity, to = 0.5, duration = 1, play = true, easing = CosineFull, loop = true }
      ]
    }.__update(fontawesome))
  }
}

function bannedMintItem(itemTemplate) {
  
  if (itemTemplate == null) {
    return true
  }
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(itemTemplate)
  return template?.getCompValNullable("mintBannedItem") ?? false
}

function getNexusStashItems(allItms, openedRecipes, allRecipes, shopItems, pStats, allowedTypes = []) {
  let itemTbl = {}

  function isItemNotForNexusStash(item) {
    return (
      
      item?.filterType == null ||
      item?.filterType == "alters" ||
      item?.filterType == "chronogene" ||
      item?.filterType == "dog_tags" ||
      item?.filterType == "loot" ||
      item?.filterType == "other" ||
      item?.filterType == "keys" ||
      item?.filterType == "goods" ||
      
      item.itemTemplate in itemTbl ||
      
      bannedMintItem(item?.itemTemplate)
    )
  }

  foreach (item in allItms) {
    let faked = mkFakeItem(item.templateName, { canDrop = false, canTake = true })
    if ( isItemNotForNexusStash(faked) ) {
      continue
    }

    itemTbl[faked.templateName] <- faked
  }

  foreach (recipeKey, _ in openedRecipes) {
    foreach (craftResult in (allRecipes?[recipeKey].results ?? [])) {
      foreach (itemName, _itemSlot in craftResult) {
        if (itemName not in itemTbl) {
          let fake = mkFakeItem(itemName, { canDrop = false, canTake = true })
          if(!isItemNotForNexusStash(fake))
            itemTbl[itemName] <- fake
        }
      }
    }
  }

  foreach (_marketItemKey, marketItemVal in shopItems) {
    if (!isLotAvailable(marketItemVal, pStats, trialData.get()))
      continue

    foreach (item in marketItemVal?.children.items ?? []) {
      if (item.templateName not in itemTbl) {
        let fake = mkFakeItem(item.templateName, { canDrop = false, canTake = true })
        if(!isItemNotForNexusStash(fake)) {
          itemTbl[item.templateName] <- fake
        }
      }
    }
  }

  local res = itemTbl.values()
  if (allowedTypes.len() > 0)
    res = res.filter(@(v) allowedTypes.contains(v.filterType))
  return res
}


function getNexusStashItemsForChocolateMenu(curItem, allItms, openedRecipes, allRecipes, shopItems, pStats, allowedTypes = []) {
  let costs = nexusItemCost.get()
  function setNexusCost(itm) {
    if (curItem?.itemTemplate && curItem.itemTemplate  == itm.itemTemplate)
      return itm.__update({ nexusCost = curItem?.nexusCost })

    if (itm?.item__nexusCost == null)
      return itm

    if (costs?[itm.itemTemplate].cost == null)
      return itm.__update({ nexusCost = itm.item__nexusCost })

    return itm.__update({ nexusCost = costs[itm.itemTemplate].cost })
  }

  return getNexusStashItems(allItms, openedRecipes, allRecipes, shopItems, pStats, allowedTypes).map(setNexusCost)
}


return {
  getPresetMissedItemsMarketIds
  getPresetMissedBoxedItemsMarketIds
  checkImportantSlotEmptiness
  checkImportantPresetSlotEmptiness
  slotsWithWarning
  PREPARATION_SUBMENU_ID
  PREPARATION_NEXUS_SUBMENU_ID
  closePreparationsScreens
  Missions_id
  isPreparationOpened
  isNexusPreparationOpened
  mkWarningSign
  mintEditState
  currentPrimaryContractIds
  getNexusStashItems
  getNexusStashItemsForChocolateMenu
  bannedMintItem
  checkRaidAvailability
}
