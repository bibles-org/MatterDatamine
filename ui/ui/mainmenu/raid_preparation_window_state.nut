from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

from "%ui/squad/squadState.nut" import squadLeaderState
from "%sqGlob/dasenums.nut" import ContractType
from "%ui/profile/profileState.nut" import playerProfileCurrentContracts

let { getLotFromItem, isLotAvailable } = require("%ui/mainMenu/market/inventoryToMarket.nut")
let { marketItems } = require("%ui/profile/profileState.nut")
let { getSlotAvailableMods } = require("%ui/hud/state/item_info.nut")
let faComp = require("%ui/components/faComp.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let { fontawesome } = require("%ui/fonts_style.nut")
let { weaponsList } = require("%ui/hud/state/hero_weapons.nut")
let { previewPreset } = require("%ui/equipPresets/presetsState.nut")
let { ceil } = require("math")
let { utf8ToLower } = require("%sqstd/string.nut")
let { currentMenuId, convertMenuId } = require("%ui/hud/hud_menus_state.nut")
let { mkFakeItem } = require("%ui/hud/menus/components/fakeItem.nut")

const PREPARATION_SUBMENU_ID = "PREPARATION_SUBMENU_ID"
const PREPARATION_NEXUS_SUBMENU_ID = "PREPARATION_NEXUS_SUBMENU_ID"
const Raid_id = "Raid"

let mintEditState = Watched(false)
let currentPrimaryContractIds = Watched({})

function closePreparationsScreens(){
  let sid = currentMenuId.get()
  let id = sid[0]
  if (id == Raid_id)
    currentMenuId.set(Raid_id)
}
let isPreparationOpened_ = @(subid) Computed(function() {
  let [id, sumbenus] = convertMenuId(currentMenuId.get())
  return id==Raid_id && subid==sumbenus?[0]
})

let isPreparationOpened = isPreparationOpened_(PREPARATION_SUBMENU_ID)
let isNexusPreparationOpened = isPreparationOpened_(PREPARATION_NEXUS_SUBMENU_ID)

let slotsWithWarning = Watched({})

function isItemCanBePurchased(marketId, playerStat) {
  let marketItem = marketItems.get()?[marketId]
  if (marketItem == null) {
    return false
  }
  return isLotAvailable(marketItem, playerStat)
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
          toBuyItems.append({ id = modMarketId, count = itemsToPurchase })
        }
      }
    }

    if (marketId != 0) {
      let itemsToPurchase = countPerStack > 1 ?
        ceil(noSuitableItemForPresetFoundCount.tofloat() / countPerStack.tofloat()) :
        noSuitableItemForPresetFoundCount
      toBuyItems.append({ id = marketId, count = itemsToPurchase })
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
      ret.append({ id = lotId, count = toBuyCount })
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

function checkWeaponAmmo(weapon, loadout, templateName) {
  let gunMods = weapon?.getCompValNullable("gun_mods__slots").getAll() ?? {}
  let magazineSlotTemplateName = gunMods?.magazine
  if (!magazineSlotTemplateName) {
    let weapons = weaponsList.get()
    let weaponToCheck = weapons.findvalue(@(v) v?.itemTemplate == templateName)
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
    if(!checkWeaponAmmo(template, loadout, itemInSlot.templateName)) {
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

function getNexusStashItems(stashItems, openedRecipes, allRecipes, shopItems, pStats, allowedTypes = []) {
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
      
      item.itemTemplate in itemTbl ||
      
      bannedMintItem(item?.itemTemplate)
    )
  }

  foreach (item in stashItems) {
    if ( isItemNotForNexusStash(item) ) {
      continue
    }

    itemTbl[item.itemTemplate] <- mkFakeItem(item.itemTemplate, { canDrop = false, canTake = true })
  }

  foreach (recipe in openedRecipes) {
    foreach (k, v in (allRecipes?[recipe.prototypeId].results ?? {})) {
      let marketItem = shopItems?[k]

      if (marketItem) {
        foreach (item in v?.children.items ?? {}) {
          if (item.templateName in itemTbl)
            continue

          let fake = mkFakeItem(item.itemTemplate, { canDrop = false, canTake = true })

          if(!isItemNotForNexusStash(fake))
            itemTbl[item.templateName] <- fake
        }
      }
      else {
        if (k not in itemTbl) {
          let fake = mkFakeItem(k, { canDrop = false, canTake = true })
          if(!isItemNotForNexusStash(fake))
            itemTbl[k] <- fake
        }
      }
    }
  }

  foreach (_marketItemKey, marketItemVal in shopItems) {
    if (!isLotAvailable(marketItemVal, pStats))
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


return {
  getPresetMissedItemsMarketIds
  getPresetMissedBoxedItemsMarketIds
  checkImportantSlotEmptiness
  checkImportantPresetSlotEmptiness
  slotsWithWarning
  PREPARATION_SUBMENU_ID
  PREPARATION_NEXUS_SUBMENU_ID
  closePreparationsScreens
  Raid_id
  isPreparationOpened
  isNexusPreparationOpened
  mkWarningSign
  mintEditState
  currentPrimaryContractIds
  getNexusStashItems
  bannedMintItem
}
