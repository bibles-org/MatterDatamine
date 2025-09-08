import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let {Point2} = require("dagor.math")
let {watchedHeroEid} = require("%ui/hud/state/watched_hero.nut")
let {INVALID_ITEM_ID} = require("humaninv")
let { is_item_useful_for_weapon, is_item_use_blocked,
  is_move_mod_from_weapon, get_current_revive_price, ceil_volume, is_hero_can_use_item } = require("das.inventory")
let {get_sync_time} = require("net")
let is_teams_friendly = require("%ui/hud/state/is_teams_friendly.nut")
let get_player_team = require("%ui/hud/state/get_player_team.nut")
let {localPlayerTeam} = require("%ui/hud/state/local_player.nut")
let {logerr} = require("dagor.debug")
let {getHeroModValue} = require("%ui/hud/state/hero_entity_mods_state.nut")
let {locTable} = require("%ui/helpers/time.nut")


let is_item_potentially_useful = @(...) true


function mkItemType(comp){
  let typ = comp["item__lootType"]
  if (typ == "gun" || typ == "melee")
    return "weapon"
  else if (typ=="food")
    return typ
  else if (typ=="mod")
    return "artifact"
  else if (typ=="container")
    return "special"
  else if (typ=="scope")
    return typ
  else if (typ=="armor" || typ == "bag")
    return "equipment"
  else if (typ=="grenade" && comp?["item__currentBoxedItemCount"] == null)
    return "grenade"
  else if (typ=="magazine" || (typ=="grenade" && comp?["item__currentBoxedItemCount"] != null))
    return "ammo"
  return "other"
}

let mkAttachedChar = @(slot, animchar, objTexReplaceS=[]) {
  shading = "same"
  active = true
  attachType = "slot"
  animchar = animchar
  slot = slot
  objTexReplace = "objTexReplaceRules{{0}}".subst("".join(objTexReplaceS))
}

let item_comps = [
  ["item__id", ecs.TYPE_INT, INVALID_ITEM_ID],
  ["uniqueId", ecs.TYPE_STRING, "-1"],
  ["gunAttachable__slotName", ecs.TYPE_STRING, null],
  ["item__proto", ecs.TYPE_STRING, null],
  ["item__iconOffset", ecs.TYPE_POINT2, Point2(0,0)],
  ["item__name", ecs.TYPE_STRING, ""],
  ["item__desc", ecs.TYPE_STRING, null],
  ["item__lootType", ecs.TYPE_STRING, ""],
  ["item__iconYaw", ecs.TYPE_FLOAT, 0.0],
  ["item__iconPitch", ecs.TYPE_FLOAT, 0.0],
  ["item__iconRoll", ecs.TYPE_FLOAT, 0.0],
  ["item__iconScale", ecs.TYPE_FLOAT, 1.0],
  ["item__iconRecalcAnimation", ecs.TYPE_BOOL, false],
  ["item__volume", ecs.TYPE_FLOAT, 0.0],
  ["item__weight", ecs.TYPE_FLOAT, 0.0],
  ["am_storage__value", ecs.TYPE_INT, null],
  ["am_storage__maxValue", ecs.TYPE_INT, null],
  ["item__count", ecs.TYPE_INT, 1],
  ["item__alwaysShowCount", ecs.TYPE_TAG, null],
  ["item__equipmentSlots", ecs.TYPE_STRING_LIST, null],
  ["item__useTime", ecs.TYPE_FLOAT, null],
  ["ammo_holder__id", ecs.TYPE_INT, null],
  ["gun__ammoHolderIds", ecs.TYPE_INT_LIST, null],
  ["gun_mods__slots", ecs.TYPE_SHARED_OBJECT, null],
  ["gun__ammo", ecs.TYPE_INT, null],
  ["gun_boxed_ammo_reload__reloadState", ecs.TYPE_INT, null],
  ["gun__boxedAmmoHolderTemplate", ecs.TYPE_STRING, null],
  ["item__currentBoxedItemCount", ecs.TYPE_INT, null],
  ["item_holder__maxItemCount", ecs.TYPE_INT, null],
  ["boxed_item__template", ecs.TYPE_STRING, null],
  ["item_holder__boxedItemTemplate", ecs.TYPE_STRING, null],
  ["item__countPerStack", ecs.TYPE_INT, 0],
  ["item__volumePerStack", ecs.TYPE_FLOAT, 0.0],
  ["item__weapTemplate", ecs.TYPE_STRING, null],
  ["item__weaponSlots", ecs.TYPE_STRING_LIST, null],
  ["item__nonDroppable", ecs.TYPE_TAG, null],
  ["item__weapType", ecs.TYPE_STRING, null],
  ["playerItemOwner", ecs.TYPE_EID, ecs.INVALID_ENTITY_ID],
  ["animchar__objTexReplace", ecs.TYPE_OBJECT, null],
  ["item__inventoryExtension", ecs.TYPE_FLOAT, 0.0],
  ["item__useMessage", ecs.TYPE_STRING, ""],
  ["item__recognizeTime", ecs.TYPE_FLOAT, 0.0],
  ["item__recognizeTimeLeft", ecs.TYPE_FLOAT, 0.0],
  ["item__containerOwnerEid", ecs.TYPE_EID, ecs.INVALID_ENTITY_ID],
  ["item__canBeQuickUsed", ecs.TYPE_TAG, null],
  ["item__hp", ecs.TYPE_FLOAT, null],
  ["item__amount", ecs.TYPE_INT, null],
  ["item_created_by_zone", ecs.TYPE_TAG, null],
  ["weapon_mod_move__weaponEid", ecs.TYPE_EID, ecs.INVALID_ENTITY_ID],
  ["weaponMod", ecs.TYPE_TAG, null],
  ["item__invisible", ecs.TYPE_TAG, null],
  ["item__disablePickup", ecs.TYPE_BOOL, false],
  ["slot_attach__slotName", ecs.TYPE_STRING, null],
  ["gunAttachable__slotName", ecs.TYPE_STRING, null],
  ["equipmentAttachable__slotName", ecs.TYPE_STRING, null],
  ["slot_attach__attachedTo", ecs.TYPE_EID, ecs.INVALID_ENTITY_ID],
  ["gun_mods__curModInSlots", ecs.TYPE_OBJECT, null],
  ["equipment_mods__slots", ecs.TYPE_SHARED_OBJECT, null],
  ["equipment_mods__curModInSlots", ecs.TYPE_OBJECT, null],
  ["itemContainer", ecs.TYPE_EID_LIST, null],
  ["questItem", ecs.TYPE_TAG, null],
  ["cortical_vault", ecs.TYPE_TAG, null],
  ["cortical_vault_inactive__ownerNickname", ecs.TYPE_STRING, null],
  ["dm_part_armor__protection", ecs.TYPE_FLOAT_LIST, null],
  ["dm_part_armor__protectionMinHpKoef", ecs.TYPE_FLOAT, null],
  ["human_inventory__maxVolumeInt", ecs.TYPE_INT, 0],
  ["item_enriched", ecs.TYPE_TAG, null],
  ["item_replica", ecs.TYPE_TAG, null],
  ["item__isDirectlyUsable", ecs.TYPE_TAG, null],
  ["item__uiSortingPriority", ecs.TYPE_INT, -1],
  ["item__filterType", ecs.TYPE_STRING, "loot"],
  ["animchar_dynmodel_nodes_hider__hiddenNodes", ecs.TYPE_STRING_LIST, null],
  ["gun__firingModeNames", ecs.TYPE_ARRAY, null],
  ["item__healTemplateName", ecs.TYPE_STRING, null],
  ["item_healkit_magazine", ecs.TYPE_TAG, null],
  ["fake_weapon_mod__realModEid", ecs.TYPE_EID, ecs.INVALID_ENTITY_ID],
  ["item__boostTemplateName", ecs.TYPE_STRING, ""],
  ["ammo_holder__ammoCountKnown", ecs.TYPE_EID_LIST, null],
  ["item__marketPrice", ecs.TYPE_INT, null],
  ["animchar__res", ecs.TYPE_STRING, ""],
  ["item__animcharInInventoryName", ecs.TYPE_STRING, null],
  ["gun_jamming__isJammed", ecs.TYPE_BOOL, false]
  
  
]

let item_comps2 = [
  ["default_stub_item", ecs.TYPE_TAG, null]
]

let get_item_info_query = ecs.SqQuery("get_item_info_query", {
  comps_ro = item_comps
})

let get_item_info2_query = ecs.SqQuery("get_item_info2_query", {
  comps_ro = item_comps2
})

function getSlotAvailableMods(slot_template_name) {
  let slotTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(slot_template_name)
  if (slotTemplate == null) {
    logerr($"Invalid slot_template_name={slot_template_name}!")
    return []
  }

  return slotTemplate?.getCompValNullable("slot_holder__availableItems")?.getAll() ?? []
}

function getItemProtoFields(itemComps) {
  if (itemComps.item__proto == null) {
    
    
    
    return {}
  }
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(itemComps.item__proto)
  let iconOffs = template?.getCompValNullable("item__iconOffset")
  return {
    iconName = template?.getCompValNullable("animchar__res") ?? ""
    itemName = template?.getCompValNullable("item__name") ?? ""

    iconYaw = template?.getCompValNullable("item__iconYaw") ?? 0.0
    iconPitch = template?.getCompValNullable("item__iconPitch") ?? 0.0
    iconRoll = template?.getCompValNullable("item__iconRoll") ?? 0.0
    iconRecalcAnimation = template?.getCompValNullable("item__iconRecalcAnimation") ?? false
    iconScale = template?.getCompValNullable("item__iconScale") ?? 1.0

    iconOffsX = iconOffs?.x ?? 0
    iconOffsY = iconOffs?.y ?? 0
  }
}

function getTemplateNameByEid(eid) {
  return ecs.g_entity_mgr.getEntityTemplateName(eid)?.split("+")[0]
}

function getItemInfo(eid, comp){
  if (comp.fake_weapon_mod__realModEid != ecs.INVALID_ENTITY_ID) {
    let itemInfo = get_item_info_query.perform(comp.fake_weapon_mod__realModEid, getItemInfo)
    itemInfo.isUsable = false
    itemInfo.canDrop = false
    itemInfo.isDelayedMoveMod = true
    itemInfo.inactiveItem = is_move_mod_from_weapon(comp.fake_weapon_mod__realModEid)
    itemInfo.stacks = false
    return itemInfo
  }

  let uniqueId = comp["uniqueId"]
  let iconOffs = comp["item__iconOffset"]
  let equipSlots = comp["item__equipmentSlots"]?.getAll?() ?? []
  local validWeaponSlots = []
  if ([null, ""].indexof(comp["item__weapTemplate"])==null && comp["item__weaponSlots"]?.getAll()!=null)
    validWeaponSlots = comp["item__weaponSlots"].getAll()
  let useMsg = comp["item__useMessage"]
  let isUsable = ((comp["item__useTime"] ?? 0) > 0 || useMsg != "" || comp["item__isDirectlyUsable"]) && !is_item_use_blocked(eid) && is_hero_can_use_item(eid)
  let isWeaponMod = comp["gunAttachable__slotName"] != null
  let isEquipmentMod = comp["equipmentAttachable__slotName"] != null && comp["equipmentAttachable__slotName"] != ""
  let add = {}
  if (isWeaponMod) {
    add.__update({
      weapModSlotName = comp["gunAttachable__slotName"]
    })
  }
  let heroEid = watchedHeroEid.value ?? ecs.INVALID_ENTITY_ID
  let mods = {}
  if (comp["gun_mods__slots"]) {
    foreach (slotName, slotTemplateName in comp["gun_mods__slots"]) {
      mods[slotName] <- {
        slotTemplateName
        allowed_items = getSlotAvailableMods(slotTemplateName)
      }
    }
    add.__update({
      mods
    })
  }
  if (comp["equipment_mods__slots"]) {
    foreach (slotName, slotTemplateName in comp["equipment_mods__slots"]) {
      mods[slotName] <- {
        slotTemplateName
        allowed_items = getSlotAvailableMods(slotTemplateName)
      }
    }
    add.__update({
      mods
    })
  }

  let ownerName = comp["playerItemOwner"] != ecs.INVALID_ENTITY_ID ? ecs.obsolete_dbg_get_comp_val(comp["playerItemOwner"], "name") : loc("teammate")
  let itemName = comp["item__name"] ?? "unknown"

  local key = $"{itemName}_{ownerName}"

  let objTexReplace = comp["animchar__objTexReplace"] ?? []
  let objTexReplaceS = []
  foreach(from, to in objTexReplace)
    objTexReplaceS.append("objTexReplace:t={0};objTexReplace:t={1};".subst(from, to))

  let isDelayedMoveMod = false
  let inactiveItem = false

  let revivePrice = comp.cortical_vault ? is_teams_friendly(localPlayerTeam.value, get_player_team(comp["playerItemOwner"])) && get_current_revive_price(comp["playerItemOwner"]) : null

  let hp = comp["item__hp"]
  let amount = comp["item__amount"]

  local modInSlots = {}
  local iconAttachments = []

  function addMod(v, k) {
    get_item_info_query.perform(v, function(mod_eid, mod_comp) {
      let modObjTexReplace = mod_comp["animchar__objTexReplace"] ?? []
      let modObjTexReplaceS = []
      let itemTemplate = getTemplateNameByEid(mod_eid)
      foreach(from, to in modObjTexReplace)
        modObjTexReplaceS.append("objTexReplace:t={0};objTexReplace:t={1};".subst(from, to))
      modInSlots[k] <- {
        eid = mod_eid
        name = mod_comp.item__name
        itemTemplate
        itemProtoFields = getItemProtoFields(mod_comp)
        isCorrupted = mod_comp.item_enriched != null
        isReplica = mod_comp.item_replica != null
        itemName = mod_comp["item__name"] ?? "unknown"
      }
      let attachSlot = mod_comp?.gunAttachable__slotName ?? mod_comp?.slot_attach__slotName
      if (attachSlot != null && mod_comp.item__invisible == null)
        iconAttachments.append(mkAttachedChar(attachSlot, mod_comp.animchar__res, modObjTexReplaceS))
    })
  }

  if (comp.gun_mods__curModInSlots) {
    comp.gun_mods__curModInSlots.getAll().each(addMod)
  }
  else if (comp.equipment_mods__curModInSlots) {
    comp.equipment_mods__curModInSlots.getAll().each(addMod)
  }

  let heroRecognitionSpeed = getHeroModValue("itemRecognitionSpeed", 1)
  let itemTemplate = getTemplateNameByEid(eid)
  let tmpl = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(itemTemplate)
  let itemRarity = tmpl?.getCompValNullable("item__rarity")
  let maxHp = tmpl?.getCompValNullable("item__maxHp")
  let maxAmount = tmpl?.getCompValNullable("item__maxAmount")
  let canLoadOnlyOnBase = tmpl?.getCompValNullable("item_holder__canLoadOnlyOnBase") != null

  return {
    eid
    eids = [eid]
    owner = comp["item__containerOwnerEid"]
    uniqueId
    uniqueIds = [uniqueId]
    isUseful = is_item_useful_for_weapon(heroEid, eid)
    isPotentiallyUseful = is_item_potentially_useful(heroEid, eid)
    itemName
    itemDescription = comp.item__desc
    key
    iconName = comp.item__animcharInInventoryName ?? comp.animchar__res
    iconYaw = comp["item__iconYaw"]
    iconPitch = comp["item__iconPitch"]
    iconRoll = comp["item__iconRoll"]
    iconRecalcAnimation = comp["item__iconRecalcAnimation"]
    itemType = mkItemType(comp)
    iconOffsX = iconOffs.x
    iconOffsY = iconOffs.y
    iconScale = comp["item__iconScale"]
    recognizeTime = comp["item__recognizeTime"] / heroRecognitionSpeed
    recognizeTimeLeft = comp["item__recognizeTimeLeft"] / heroRecognitionSpeed
    volume = ceil_volume(comp["item__volume"])
    weight = comp["item__weight"],
    countPerItem = comp["item__count"],
    id = comp["item__id"]
    count = 1
    alwaysShowCount = comp["item__alwaysShowCount"] != null
    maxCount = comp["item_holder__maxItemCount"] != null ? comp["item_holder__maxItemCount"] : -1,
    countPerStack = comp["item__countPerStack"]
    volumePerStack = ceil_volume(comp["item__volumePerStack"])
    currentStackVolume = ceil_volume(comp["item__countPerStack"] > 0 ? min(comp["item__volumePerStack"], comp["item__volume"]) : comp["item__volume"])
    isEquipment = (equipSlots?.len?() ?? 0) > 0,
    canDrop = !(type(comp["item__nonDroppable"])=="string"),
    isUsable,
    useMsg,
    equipmentSlots = equipSlots,
    validWeaponSlots = validWeaponSlots,
    isWeapon =  validWeaponSlots.len() > 0,
    weapType =  comp["item__weapType"],
    isWeaponMod,
    isEquipmentMod,
    isAmmo = comp["ammo_holder__id"]!=null,
    isCorticalVault = comp.am_storage__maxValue != null,
    isBoxedItem = comp["boxed_item__template"] != null,
    isHealkit = comp.item__healTemplateName != null || comp.item_healkit_magazine != null || comp.item__boostTemplateName != "",
    isAmStorage = comp.am_storage__value != null,
    ammoId = comp["ammo_holder__id"],
    ammoHolders = comp["gun__ammoHolderIds"]?.getAll() ?? [],
    gunAmmo = comp.gun__ammo
    gunDirectlyUseBoxedAmmo = comp.gun_boxed_ammo_reload__reloadState != null
    gunBoxedAmmoTemplate = comp.gun__boxedAmmoHolderTemplate
    boxTemplate = comp["boxed_item__template"],
    boxId = comp["boxed_item__template"] == null ? null : ecs.calc_hash(comp["boxed_item__template"]),
    boxedItemTemplate = comp["item_holder__boxedItemTemplate"],
    ownerNickname = comp["cortical_vault_inactive__ownerNickname"],
    objTexReplace = "objTexReplaceRules{{0}}".subst("".join(objTexReplaceS))
    stacks = !isDelayedMoveMod
    hp
    maxHp
    amount
    maxAmount
    createdByZone = comp.item_created_by_zone
    charges = (comp.am_storage__value ??
               ((!comp.boxed_item__template  && !inactiveItem) ? comp.item__currentBoxedItemCount : null) ??
               hp ?? amount)
    countKnown = comp?.ammo_holder__ammoCountKnown?.getAll()?.contains(watchedHeroEid.get()) ?? true
    maxCharges = (comp.am_storage__maxValue ??
                  ((!comp.boxed_item__template && !inactiveItem) ? comp.item_holder__maxItemCount : null) ??
                  maxHp ?? maxAmount)
    ammoCount = comp.item__currentBoxedItemCount
    maxAmmoCount = comp.item_holder__maxItemCount
    inventoryExtension = comp["item__inventoryExtension"]
    isFoundInRaid = uniqueId == 0
    canBeQuickUsed = comp["item__canBeQuickUsed"]
    isDelayedMoveMod
    inactiveItem
    syncTime = get_sync_time()
    isPickable = !comp.item__disablePickup
    modInSlots
    iconAttachments
    hideNodes = comp.animchar_dynmodel_nodes_hider__hiddenNodes?.getAll() ?? []
    firingModeNames = comp.gun__firingModeNames?.getAll() ?? []
    itemContainerItems = comp.itemContainer?.getAll()
    isQuestItem = comp["questItem"] != null
    revivePrice
    protection = comp["dm_part_armor__protection"]?.getAll() ?? []
    protectionMinHpKoef = comp["dm_part_armor__protectionMinHpKoef"]
    inventoryMaxVolume = comp["human_inventory__maxVolumeInt"] / 10.0
    attachedTo = comp["slot_attach__attachedTo"]
    isCorrupted = comp.item_enriched != null
    isReplica = comp.item_replica != null
    sortingPriority = comp.item__uiSortingPriority
    filterType = comp.item__filterType
    itemTemplate
    itemProto = comp?["item__proto"]
    itemCanBeRepaired = comp["item__hp"] != null && maxHp != null
    itemMarketPrice = comp["item__marketPrice"] 
    itemProtoFields = getItemProtoFields(comp)
    itemRarity
    canLoadOnlyOnBase
    isJammed = comp.gun_jamming__isJammed
  }.__update(add)
}

function getItemInfo2(_eid, comp){
  return {
    isStubItem = comp["default_stub_item"] != null
  }
}

function get_item_info(item_eid) {
  local info = get_item_info_query.perform(item_eid, getItemInfo)
  if (info != null) {
    let info2 = get_item_info2_query.perform(item_eid, getItemInfo2)
    if (info2 != null)
      info.__update(info2)
  }

  return info
}

function get_nearby_item_info(item_eid) {
  let info = get_item_info(item_eid)
  if (info != null)
    info.isUsable <- false
  return info
}

let calcProtection = @(v) (1.0 - 1.0 / (v ?? 1.0)) * 100.0

let chronogeneStatCustom = {
  shockReduction = { calc = @(v) v ?? 0.0, defVal = 0.0, measurement = loc(locTable.seconds) }
  meleeProtectionMult = { calc = calcProtection, defVal = 1.0 }
  bulletProtectionMult = { calc = calcProtection, defVal = 1.0 }
  hrFatigueThresholdAdd = { calc = @(v) v ?? 0.0, defVal = 0.0, measurement = "" }
  fasterChangePoseMult = { defVal = 4.0 }
}

let chronogeneEffectCalc = {
  add = @(defVal, v) defVal + (v ?? 0.0)
  add_diminishing = @(defVal, v) defVal + (v ?? 0.0)
  mult = @(defVal, v) defVal * (v ?? 1.0)
  mult_diminishing = @(defVal, v) defVal * (v ?? 1.0)
}

let chronogeneStatDefault = { calc = @(v) (v ?? 1.0) * 100.0, defVal = 1.0, measurement = "%" }

function get_equipped_magazine_current_ammo_count(item) {
  if ((item?.isWeaponMod ?? false) && (item?.attachedTo ?? ecs.INVALID_ENTITY_ID) != ecs.INVALID_ENTITY_ID &&
    item?.charges != null && item?.maxCharges != null) {
    let gunInfo = get_item_info(item?.attachedTo)
    let gunAmmo = gunInfo?.gunAmmo ?? 0
    let isGunJammed = gunInfo?.isJammed ?? false
    let bulletInBarrel = isGunJammed ? 0 : 1
    let ammo = (item?.boxedItemTemplate ?? "") != "" ? max(0, gunAmmo - bulletInBarrel) : gunAmmo
    return ammo
  }

  return null
}

let itemCompExtraInfoQuery = ecs.SqQuery("itemCompExtraInfoQuery",
  {
    comps_ro = [
      ["item_holder__customUiProps", ecs.TYPE_SHARED_OBJECT, null],
    ]
  }
)

return {
  item_comps
  getSlotAvailableMods
  getItemInfo
  get_item_info
  get_equipped_magazine_current_ammo_count
  get_nearby_item_info
  mkItemType
  mkAttachedChar
  chronogeneStatCustom
  chronogeneStatDefault
  chronogeneEffectCalc
  itemCompExtraInfoQuery
  getTemplateNameByEid
}