from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { mkItemType, mkAttachedChar, getSlotAvailableMods } = require("%ui/hud/state/item_info.nut")
let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")
let { getTemplateVisuals } = require("%ui/hud/menus/inventoryItemInSlots.nut")


function getTemplateParams(itemTemplate) {
  if (!itemTemplate)
    return {}
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(itemTemplate)
  if (!template) {
    log($"[Faked item] Item template <{itemTemplate}> does not exists. Inserting default values to the fields.")
  }

  let isBoxedItem = template?.getCompValNullable("boxedItem") != null

  let maxHp = template?.getCompValNullable("item__maxHp")
  let hp = maxHp
  let isAmmo =  template?.getCompValNullable("ammo_holder__id") != null
  let validWeaponSlots = template?.getCompValNullable("item__weaponSlots")?.getAll()
  let isWeapon = (validWeaponSlots ?? []).len() > 0
  let charges = isWeapon ? null : (
    template?.getCompValNullable("item__countPerStack") ??
    template?.getCompValNullable("item_holder__maxItemCount") ??
    template?.getCompValNullable("gun__maxAmmo") ?? hp
  )

  let mods = {}
  foreach (slotName, slotTemplateName in (template?.getCompValNullable("equipment_mods__slots") ?? {})) {
    mods[slotName] <- {
      slotTemplateName
      allowed_items = getSlotAvailableMods(slotTemplateName)
    }
  }

  foreach (slotName, slotTemplateName in (template?.getCompValNullable("gun_mods__slots") ?? {})) {
    mods[slotName] <- {
      slotTemplateName
      allowed_items = getSlotAvailableMods(slotTemplateName)
    }
  }
  let inventoryMaxVolumeFloat = template?.getCompValNullable("human_inventory__maxVolume") ?? 0

  let fakeItem = {
    isQuestItem = template?.getCompValNullable("questItem") != null
    isCorticalVault = template?.getCompValNullable("am_storage__maxValue") != null
    isWeapon
    validWeaponSlots
    weapType = template?.getCompValNullable("item__weapType")
    isAmmo
    isWeaponMod = template?.getCompValNullable("gunAttachable__slotName") != null
    isEquipment = (template?.getCompValNullable("item__equipmentSlots")?.getAll() ?? []).len() > 0
    isHealkit = template?.getCompValNullable("item__healTemplateName") != null
      || template?.getCompValNullable("item_healkit_magazine") != null
    itemName = template?.getCompValNullable("item__fakeName") ?? template?.getCompValNullable("item__name") ?? "unknown"
    volumePerStack = template?.getCompValNullable("item__volumePerStack") ?? 0
    volume = template?.getCompValNullable("item__volume") ?? 0
    countPerStack = template?.getCompValNullable("item__countPerStack") ?? 0
    gunAmmo = template?.getCompValNullable("gun__ammo") ?? 0
    item__lootType = template?.getCompValNullable("item__lootType") ?? ""
    filterType = template?.getCompValNullable("item__filterType") ?? "loot"
    item__currentBoxedItemCount = template?.getCompValNullable("item__currentBoxedItemCount")
    alwaysShowCount = template?.getCompValNullable("item__alwaysShowCount") ?? false
    isBoxedItem
    charges
    owner = controlledHeroEid.get()
    ammoCount = template?.getCompValNullable("item__countPerStack") ?? (isAmmo ? 0 : null)
    maxCharges = template?.getCompValNullable("am_storage__maxValue") ??
      template?.getCompValNullable("item_holder__maxItemCount") ?? maxHp
    hp
    id = itemTemplate
    equipmentSlots = template?.getCompValNullable("item__equipmentSlots")?.getAll?() ?? []
    inventoryExtension = template?.getCompValNullable("item__inventoryExtension") ?? 0
    inventoryMaxVolumeFloat
    inventoryMaxVolume = inventoryMaxVolumeFloat
    protectionMinHpKoef = template?.getCompValNullable("dm_part_armor__protectionMinHpKoef") ?? 0
    valuableItem = template?.getCompValNullable("valuableItem")
    isDefaultStubItem = template?.getCompValNullable("default_stub_item") != null
    itemRarity = template?.getCompValNullable("item__rarity")
    iconName = template?.getCompValNullable("item__animcharInInventoryName") ?? template?.getCompValNullable("animchar__res")
    hideNodes = template?.getCompValNullable("animchar_dynmodel_nodes_hider__hiddenNodes")?.getAll() ?? []
    mods = mods.len() > 0 ? mods : null
    canLoadOnlyOnBase = template?.getCompValNullable("item_holder__canLoadOnlyOnBase") != null
    maxAmmoCount = template?.getCompValNullable("item_holder__maxItemCount")
    weapModSlotName = template?.getCompValNullable("gunAttachable__slotName")
    boxedItemTemplate = template?.getCompValNullable("item_holder__boxedItemTemplate")
    boxTemplate = template?.getCompValNullable("boxed_item__template")
    gunBoxedAmmoTemplate = template?.getCompValNullable("gun__boxedAmmoHolderTemplate")
  }

  let itemType = mkItemType(fakeItem)

  return fakeItem.__update({
    itemType
  })
}


let fakeDynamicFields = {
  recognizeTimeLeft = 0
  count = 1
  eid = ecs.INVALID_ENTITY_ID
  isCorrupted = false
  isCorticalVault = false
  isDelayedMoveMod = false
  stacks = true
  eids = []
  uniqueId = 0
  uniqueIds = []
  countPerItem = 0
  modInSlots = {}
  itemContainerItems = []
  recognizeTime = 0
  boxId = null
  itemPropsId = 0
  canDrop = false
  isAmStorage = false
  countKnown = true
}

function mkFakeAttachments(attachments) {
  return attachments.map(function(templateName) {
    if (templateName == null || templateName == "")
      return null
    let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
    let attachSlot = template?.getCompValNullable("gunAttachable__slotName")
      ?? template?.getCompValNullable("slot_attach__slotName")
    let animchar__res = template?.getCompValNullable("animchar__res")
    return mkAttachedChar(attachSlot, animchar__res)
  })
}

function mkFakeItem(itemTemplate, additionalFields = {}, attachments=[]) {
  let iconAttachments = mkFakeAttachments(attachments ?? [])
  let itemData = {
    itemTemplate
    iconAttachments
    templateName = itemTemplate
  }
  return itemData.__update(
    fakeDynamicFields,
    getTemplateVisuals(itemTemplate) ?? {},
    getTemplateParams(itemTemplate),
    additionalFields
  )
}

return {
  mkFakeItem
  mkFakeAttachments
}